import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "build.sh"


class BuildScriptTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.script = self.root / "build.sh"
        shutil.copy2(SCRIPT, self.script)
        self.images = self.root / "docker-files"
        self.images.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "docker.log"
        docker = self.bin / "docker"
        docker.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" >> "$DOCKER_LOG"\n'
            'if [ "${FAIL_TAG:-}" = "$3" ]; then exit 7; fi\n',
            encoding="utf-8",
        )
        docker.chmod(0o755)
        self.env = os.environ.copy()
        self.env["PATH"] = f"{self.bin}{os.pathsep}{self.env['PATH']}"
        self.env["DOCKER_LOG"] = str(self.log)
        self.env.pop("ORCA_BINARY_DIR", None)
        self.env.pop("OPENMPI_BINARY_DIR", None)
        self.env.pop("OPENMPI_DEB_DIR", None)
        self.env.pop("OPENMPI_DEB", None)
        self.env.pop("ORCA_ARCHIVE", None)
        self.env.pop("OPENMPI_ARCHIVE", None)

    def image(self, name, dockerfile=True):
        directory = self.images / name
        directory.mkdir()
        if dockerfile:
            (directory / "Dockerfile").write_text("FROM scratch\n", encoding="utf-8")
        return directory

    def run_script(self, *arguments, **env):
        return subprocess.run(
            ["/bin/sh", str(self.script), *arguments], cwd="/",
            env={**self.env, **env}, capture_output=True, text=True, check=False,
        )

    def test_builds_each_direct_directory_with_matching_tag(self):
        first = self.image("alpha")
        second = self.image("beta")
        (self.images / "notes.txt").write_text("not an image", encoding="utf-8")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(),
                         [f"build -t alpha {first}", f"build -t beta {second}"])

    def test_missing_dockerfile_fails_before_building(self):
        self.image("alpha")
        self.image("broken", dockerfile=False)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing Dockerfile", result.stderr)
        self.assertFalse(self.log.exists())

    def test_stops_on_docker_build_failure(self):
        self.image("alpha")
        self.image("beta")
        result = self.run_script(FAIL_TAG="alpha")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(len(self.log.read_text().splitlines()), 1)

    def test_empty_directory_and_arguments_fail(self):
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertNotEqual(self.run_script("extra").returncode, 0)
        self.assertFalse(self.log.exists())

    def test_legacy_openmpi_package_options_fail_explicitly(self):
        self.image("orca")
        for key in ("OPENMPI_DEB", "OPENMPI_DEB_DIR"):
            with self.subTest(key=key):
                result = self.run_script(**{key: "old"})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("no longer supported", result.stderr)
                self.assertFalse(self.log.exists())

    def test_orca_uses_external_build_contexts(self):
        image = self.image("orca")
        archive_dir = self.root / "ORCA binaries"
        package_dir = self.root / "MPI binaries"
        archive_dir.mkdir()
        package_dir.mkdir()
        (archive_dir / "orca_6_1_1_linux_arm64_shared_openmpi418.tar.xz").touch()
        (package_dir / "openmpi-4.1.8-linux-arm64.tar.gz").touch()
        result = self.run_script(
            ORCA_BINARY_DIR=str(archive_dir), OPENMPI_BINARY_DIR=str(package_dir)
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.log.read_text().strip(),
            f"build --platform linux/arm64 --build-context orca_binaries={archive_dir} "
            f"--build-context mpi_binaries={package_dir} "
            "--build-arg ORCA_ARCHIVE=orca_6_1_1_linux_arm64_shared_openmpi418.tar.xz "
            f"--build-arg OPENMPI_ARCHIVE=openmpi-4.1.8-linux-arm64.tar.gz -t orca {image}",
        )

    def test_orca_selects_custom_filenames(self):
        image = self.image("orca")
        archive_dir = self.root / "archives"
        package_dir = self.root / "packages"
        archive_dir.mkdir()
        package_dir.mkdir()
        (archive_dir / "custom-orca.tar.xz").touch()
        (package_dir / "custom-openmpi.tar.gz").touch()
        (archive_dir / "orca_other_linux_arm64_shared_openmpi418.tar.xz").touch()
        result = self.run_script(
            ORCA_BINARY_DIR=str(archive_dir), OPENMPI_BINARY_DIR=str(package_dir),
            ORCA_ARCHIVE="custom-orca.tar.xz", OPENMPI_ARCHIVE="custom-openmpi.tar.gz",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            f"--build-arg ORCA_ARCHIVE=custom-orca.tar.xz "
            f"--build-arg OPENMPI_ARCHIVE=custom-openmpi.tar.gz -t orca {image}",
            self.log.read_text(),
        )

    def test_orca_rejects_missing_or_invalid_selected_filenames(self):
        self.image("orca")
        archive_dir = self.root / "archives"
        package_dir = self.root / "packages"
        archive_dir.mkdir()
        package_dir.mkdir()
        (archive_dir / "custom.tar.xz").touch()
        (package_dir / "custom.tar.gz").touch()
        env = dict(ORCA_BINARY_DIR=str(archive_dir), OPENMPI_BINARY_DIR=str(package_dir))
        for archive, package in [
            ("../custom.tar.xz", "custom.tar.gz"), ("missing.tar.xz", "custom.tar.gz"),
            ("custom.tar.xz", "../custom.tar.gz"), ("custom.tar.xz", "missing.tar.gz"),
            ("custom.zip", "custom.tar.gz"), ("custom.tar.xz", "custom.tar"),
        ]:
            with self.subTest(archive=archive, package=package):
                result = self.run_script(**env, ORCA_ARCHIVE=archive, OPENMPI_ARCHIVE=package)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr)
                self.assertFalse(self.log.exists())

    def test_missing_or_ambiguous_orca_inputs_fail_before_building(self):
        self.image("alpha")
        self.image("orca")
        archive_dir = self.root / "archives"
        package_dir = self.root / "packages"
        archive_dir.mkdir()
        package_dir.mkdir()
        env = dict(ORCA_BINARY_DIR=str(archive_dir), OPENMPI_BINARY_DIR=str(package_dir))
        self.assertNotEqual(self.run_script(**env).returncode, 0)
        (archive_dir / "orca_a_linux_arm64_shared_openmpi418.tar.xz").touch()
        (archive_dir / "orca_b_linux_arm64_shared_openmpi418.tar.xz").touch()
        (package_dir / "openmpi-4.1.8-linux-arm64.tar.gz").touch()
        self.assertNotEqual(self.run_script(**env).returncode, 0)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
