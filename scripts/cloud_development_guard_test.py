"""Exercise the workflow's real Bash guards without Flutter or credentials."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest

WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/cloud-development.yml"
SOURCE = WORKFLOW.read_text(encoding="utf-8")

def block(name):
    section = SOURCE.split("      - name: " + name + "\n", 1)[1]
    section = section.split("\n      - name:", 1)[0]
    return textwrap.dedent(section.split("        run: |\n", 1)[1]).strip()

class GuardsTest(unittest.TestCase):
    def run_guard(self, name, root, **env):
        return subprocess.run(
            ["bash", "-c", block(name)], cwd=root,
            env={**os.environ, **env}, text=True, capture_output=True,
            timeout=15,
        )

    def test_six_profiles_and_invalid_values(self):
        expected = ["workspace", "format", "analyze", "test", "web-build", "full"]
        options = SOURCE.split("        options:\n", 1)[1].split("      expected_head_sha:", 1)[0]
        self.assertEqual(re.findall(r"- (\S+)", options), expected)
        for value in expected + ["", "unknown", "full; exit 0", "FORMAT"]:
            with self.subTest(value=value):
                result = self.run_guard("Validate selected profile", WORKFLOW.parent, CLOUD_PROFILE=value)
                self.assertEqual(result.returncode == 0, value in expected, result.stderr)

    def test_sha_guard_with_real_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(["git", "init", "-q", directory], check=True)
            subprocess.run(["git", "-c", "user.name=Guard", "-c", "user.email=guard@example.invalid",
                            "commit", "--allow-empty", "-qm", "fixture"], cwd=directory, check=True)
            sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=directory, text=True).strip()
            for expected in [sha, sha.upper(), "0" * 40, "", sha[:39], sha + "0", "main"]:
                with self.subTest(expected=expected):
                    result = self.run_guard("Verify immutable handoff revision", directory, EXPECTED_HEAD_SHA=expected)
                    self.assertEqual(result.returncode == 0, expected == sha, result.stdout + result.stderr)

    def test_tracked_archives_rejected(self):
        for suffix in [".enex", ".enex.gz", ".enex.zip"]:
            with self.subTest(suffix=suffix), tempfile.TemporaryDirectory() as directory:
                subprocess.run(["git", "init", "-q", directory], check=True)
                root = Path(directory)
                self.assertEqual(self.run_guard("Reject personal migration archives in Git", root).returncode, 0)
                (root / ("fixture" + suffix)).write_text("synthetic", encoding="utf-8")
                subprocess.run(["git", "add", "."], cwd=root, check=True)
                self.assertNotEqual(self.run_guard("Reject personal migration archives in Git", root).returncode, 0)

    def test_guard_order_and_format_preserved(self):
        names = ["Verify immutable handoff revision", "Validate selected profile",
                 "Reject personal migration archives in Git", "Test cloud handoff guards",
                 "Set up repository-pinned Flutter SDK", "Resolve dependencies in cloud"]
        positions = [SOURCE.index("- name: " + name) for name in names]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("github.event_name == 'workflow_dispatch' || inputs.expected_head_sha != ''", SOURCE)
        self.assertIn("if: env.CLOUD_PROFILE == 'format'", SOURCE)
        self.assertIn('dart format "${files[@]}"', SOURCE)
        self.assertIn("path: cloud-format-output\n", SOURCE)
        self.assertIn("retention-days: 1", SOURCE)

if __name__ == "__main__":
    unittest.main()
