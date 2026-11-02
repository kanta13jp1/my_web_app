import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DESIGN_DOC = REPO_ROOT / "docs" / "DESIGN.md"


class DesignSsotContractTest(unittest.TestCase):
    def test_retired_duplicate_entry_points_are_absent(self) -> None:
        retired_paths = (
            REPO_ROOT / ".claude" / "skills" / "ui-design" / "SKILL.md",
            REPO_ROOT / ".claude" / "commands" / "design-review.md",
            REPO_ROOT / ".agents" / "skills" / "ui-design" / "SKILL.md",
            REPO_ROOT
            / ".agents"
            / "skills"
            / "source-command-design-review"
            / "SKILL.md",
        )
        for path in retired_paths:
            with self.subTest(path=path):
                self.assertFalse(path.exists())

    def test_design_doc_owns_implementation_and_review_contracts(self) -> None:
        text = DESIGN_DOC.read_text(encoding="utf-8")
        for heading in (
            "## 単一 SSOT 契約",
            "### UI 実装フロー",
            "### デザインレビュー手順",
        ):
            self.assertIn(heading, text)

    def test_design_entry_points_are_thin_and_reference_ssot(self) -> None:
        entry_points = (
            REPO_ROOT / ".claude" / "agents" / "design-skills.md",
            REPO_ROOT / ".claude" / "commands" / "design-check.md",
            REPO_ROOT / ".claude" / "commands" / "design-component.md",
            REPO_ROOT / ".claude" / "commands" / "design-workflow.md",
            REPO_ROOT / ".claude" / "commands" / "claude-design-handoff.md",
            REPO_ROOT / "docs" / "DESIGN_TOOLING_SETUP.md",
        )
        token_pattern = re.compile(r"(?:0xFF|#[0-9A-Fa-f]{6})")
        for path in entry_points:
            with self.subTest(path=path):
                text = path.read_text(encoding="utf-8")
                self.assertIn("docs/DESIGN.md", text)
                self.assertIsNone(token_pattern.search(text))


if __name__ == "__main__":
    unittest.main()
