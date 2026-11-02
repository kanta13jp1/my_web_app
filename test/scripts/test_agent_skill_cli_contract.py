import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SKILLS_ROOT = REPO_ROOT / ".agents" / "skills"


def script_help(script_name: str) -> str:
    environment = os.environ.copy()
    environment["PYTHONUTF8"] = "1"
    result = subprocess.run(
        [sys.executable, str(REPO_ROOT / "scripts" / script_name), "--help"],
        cwd=REPO_ROOT,
        env=environment,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.stdout


class AgentSkillCliContractTest(unittest.TestCase):
    def skill_text(self, name: str) -> str:
        return (SKILLS_ROOT / name / "SKILL.md").read_text(encoding="utf-8")

    def test_local_cli_flags_match_skill_examples(self) -> None:
        compile_help = script_help("wiki_compile.py")
        self.assertIn("--apply", compile_help)
        self.assertIn("--json", compile_help)
        self.assertNotIn("--report", compile_help)

        lint_help = script_help("knowledge_vault_lint.py")
        self.assertIn("--output", lint_help)
        self.assertIn("--json-out", lint_help)
        self.assertNotIn("--report", lint_help)

        cleanup_contracts = {
            "wiki_broken_cleanup.py": ("--lint-json", "--dry-run"),
            "wiki_dup_h1_cleanup.py": ("--lint-json", "--dry-run"),
            "wiki_orphan_batch.py": (
                "--lint-json",
                "--source",
                "--prefixes",
                "--marker",
                "--dry-run",
            ),
            "memory_ingest.py": ("--mode", "--print"),
        }
        for script_name, required_flags in cleanup_contracts.items():
            with self.subTest(script=script_name):
                help_text = script_help(script_name)
                for flag in required_flags:
                    self.assertIn(flag, help_text)

    def test_active_wiki_skills_use_current_commands(self) -> None:
        lint_skill = self.skill_text("wiki-lint")
        self.assertIn("knowledge_vault_lint.py --output", lint_skill)
        self.assertNotIn("knowledge_vault_lint.py --report", lint_skill)

        compile_skill = self.skill_text("wiki-compile")
        self.assertIn("python scripts/wiki_compile.py --json", compile_skill)
        self.assertIn("python scripts/wiki_compile.py --apply", compile_skill)

        query_skill = self.skill_text("wiki-query")
        self.assertIn("notebooklm ask", query_skill)
        self.assertNotIn("notebooklm query", query_skill)

        orphan_skill = self.skill_text("wiki-orphan-batch")
        for flag in ("--source", "--top", "--prefixes", "--marker"):
            self.assertIn(flag, orphan_skill)

    def test_notebooklm_ask_when_cli_is_installed(self) -> None:
        executable = shutil.which("notebooklm")
        if executable is None:
            self.skipTest("notebooklm CLI is not installed")

        result = subprocess.run(
            [executable, "ask", "--help"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertIn("Ask a notebook a question", result.stdout)
        self.assertIn("--notebook", result.stdout)
        self.assertIn("--json", result.stdout)


if __name__ == "__main__":
    unittest.main()
