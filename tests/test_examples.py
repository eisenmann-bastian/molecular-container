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
            'case "$FAKE_MODE" in\n'
            '  error) echo "container error" >&2; exit 1 ;;\n'
            '  orca-error) echo "ORCA finished by error termination"; exit 0 ;;\n'
            '  orca-serial) echo "ORCA TERMINATED NORMALLY"; exit 0 ;;\n'
            '  orca-ok) echo "Program running with 2 parallel MPI-processes"; '
            'echo "FINAL SINGLE POINT ENERGY -1"; echo "ORCA TERMINATED NORMALLY" ;;\n'
            "esac\n",
            encoding="utf-8",
        )
        docker.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{self.root}{os.pathsep}{os.environ['PATH']}",
            "TMPDIR": str(self.tmp),
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
        self.assertEqual(list(self.tmp.iterdir()), [])
        return result

    def test_orca_requires_normal_parallel_termination(self):
        for mode in ("error", "orca-error", "orca-serial"):
            with self.subTest(mode=mode):
                result = self.run_example("orca", mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
        result = self.run_example("orca", "orca-ok")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ORCA test passed", result.stdout)

    def test_pymol_propagates_docker_errors_and_rejects_arguments(self):
        result = self.run_example("pymol", "error")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("container error", result.stderr)
        result = self.run_example("pymol", "success", "unexpected")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
