import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ExampleScriptTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.tmp = self.root / "tmp"
        self.tmp.mkdir()
        docker = self.root / "docker"
        docker.write_text(
            "#!/bin/sh\n"
            'printf "%s\\n" "$@" > "$DOCKER_ARGS_FILE"\n'
            'case "$FAKE_MODE" in\n'
            '  error) echo "container error" >&2; exit 1 ;;\n'
            '  orca-error) echo "ORCA finished by error termination"; exit 0 ;;\n'
            '  orca-serial) echo "ORCA TERMINATED NORMALLY"; exit 0 ;;\n'
            '  orca-ok) echo "Program running with 2 parallel MPI-processes"; '
            'echo "FINAL SINGLE POINT ENERGY -1"; echo "ORCA TERMINATED NORMALLY" ;;\n'
            '  xtb-ok) echo "TOTAL ENERGY -5"; echo "normal termination of xtb" ;;\n'
            '  xtb-no-energy) echo "normal termination of xtb" ;;\n'
            '  xtb-no-termination) echo "TOTAL ENERGY -5" ;;\n'
            '  censo-empty) echo "calculation incomplete" ;;\n'
            '  censo-workflow-ok) echo "CENSO all done!" ;;\n'
            '  vina-ok|vina-no-output) '
            'while [ "$#" -gt 0 ]; do '
            'if [ "$1" = "-v" ]; then shift; work=${1%:/work}; break; fi; shift; done; '
            'if [ "$FAKE_MODE" = vina-ok ]; then '
            'echo "MODEL 1" > "$work/docked.pdbqt"; fi ;;\n'
            '  crest-no-termination) echo "CREST error" ;;\n'
            '  crest-no-output) echo "CREST terminated normally." ;;\n'
            '  crest-ok|crest-invalid) '
            'while [ "$#" -gt 0 ]; do '
            'if [ "$1" = "-v" ]; then shift; work=${1%:/work}; break; fi; shift; done; '
            'if [ "$FAKE_MODE" = crest-ok ]; then echo "    3" > "$work/crest_conformers.xyz"; '
            'else echo "2" > "$work/crest_conformers.xyz"; fi; '
            'echo "CREST terminated normally." ;;\n'
            "esac\n",
            encoding="utf-8",
        )
        docker.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{self.root}{os.pathsep}{os.environ['PATH']}",
            "TMPDIR": str(self.tmp),
            "EXAMPLE_OUTPUT_DIR": str(self.tmp),
            "DOCKER_ARGS_FILE": str(self.root / "docker-args"),
        }

    def run_example(self, example, mode, *arguments):
        result = subprocess.run(
            [str(ROOT / "examples" / example / "test.sh"), *arguments],
            cwd="/",
            env={**self.env, "FAKE_MODE": mode},
            capture_output=True,
            text=True,
            check=False,
        )
        if not arguments:
            line = next(line for line in result.stdout.splitlines() if line.startswith("Output directory: "))
            output = Path(line.removeprefix("Output directory: "))
            self.assertTrue(output.is_dir())
            self.assertEqual(output.parent, self.tmp)
        return result

    def test_orca_requires_normal_termination(self):
        for mode in ("error", "orca-error"):
            with self.subTest(mode=mode):
                result = self.run_example("orca", mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
        result = self.run_example("orca", "orca-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ORCA completed", result.stdout)

    def test_pymol_propagates_docker_errors_and_rejects_arguments(self):
        result = self.run_example("pymol", "error")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("container error", result.stderr)
        result = self.run_example("pymol", "success", "unexpected")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Usage:", result.stderr)

    def test_xtb_requires_energy_and_normal_termination(self):
        for mode in ("error", "xtb-no-energy", "xtb-no-termination"):
            with self.subTest(mode=mode):
                result = self.run_example("xtb", mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
        result = self.run_example("xtb", "xtb-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("xTB completed", result.stdout)

    def test_crest_requires_termination_and_expected_output(self):
        for mode in ("error", "crest-no-termination", "crest-no-output"):
            with self.subTest(mode=mode):
                result = self.run_example("crest", mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
        result = self.run_example("crest", "crest-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("CREST completed", result.stdout)

    def test_censo_workflow_requires_normal_completion(self):
        for mode in ("error", "censo-empty"):
            with self.subTest(mode=mode):
                result = self.run_example("censo", mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
        result = self.run_example("censo", "censo-workflow-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("CENSO workflow completed", result.stdout)
        args = (self.root / "docker-args").read_text(encoding="utf-8").splitlines()
        for flag in ("--prescreening", "--screening", "--optimization",
                     "--refinement", "--nmr", "--uvvis"):
            self.assertIn(flag, args)
        self.assertNotIn("--rot", args)

    def test_vina_requires_output_and_retains_inputs(self):
        for mode in ("error", "vina-no-output"):
            with self.subTest(mode=mode):
                result = self.run_example("autodock-vina", mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
        result = self.run_example("autodock-vina", "vina-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("AutoDock Vina completed", result.stdout)
        output = Path(result.stdout.splitlines()[0].removeprefix("Output directory: "))
        for name in ("receptor.pdbqt", "ligand.pdbqt", "receptor.box.txt"):
            self.assertEqual(
                (output / name).read_bytes(),
                (ROOT / "examples" / "autodock-vina" / name).read_bytes(),
            )
        for name in ("vina.out", "docked.pdbqt"):
            self.assertTrue((output / name).is_file())
        args = (self.root / "docker-args").read_text(encoding="utf-8").splitlines()
        for flag, value in (("--receptor", "receptor.pdbqt"),
                            ("--ligand", "ligand.pdbqt"),
                            ("--config", "receptor.box.txt")):
            self.assertEqual(args[args.index(flag) + 1], value)
        self.assertNotIn("--center_x", args)
        self.assertIn("--seed", args)
        self.assertIn("docked.pdbqt", args)

    def test_outputs_are_retained_without_overwriting_previous_runs(self):
        first = self.run_example("xtb", "xtb-ok")
        second = self.run_example("xtb", "xtb-ok")
        first_path = Path(first.stdout.splitlines()[0].removeprefix("Output directory: "))
        second_path = Path(second.stdout.splitlines()[0].removeprefix("Output directory: "))
        self.assertNotEqual(first_path, second_path)
        self.assertTrue((first_path / "xtb.out").is_file())
        self.assertTrue((second_path / "xtb.out").is_file())

    def test_failed_run_keeps_its_log(self):
        result = self.run_example("pymol", "error")
        output = Path(result.stdout.splitlines()[0].removeprefix("Output directory: "))
        self.assertIn("container error", (output / "pymol.out").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
