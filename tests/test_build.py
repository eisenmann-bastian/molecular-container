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


if __name__ == "__main__":
    unittest.main()
