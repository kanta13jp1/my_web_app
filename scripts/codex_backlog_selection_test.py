"""Exercise the actual backlog workflow jq selectors with synthetic PRs."""
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def select_prs(variable, prs):
    source = (ROOT / ".github/workflows/codex-backlog-check.yml").read_text(encoding="utf-8")
    block = source.split(variable + "=$(gh pr list", 1)[1]
    expression = re.search(r"--jq '([\s\S]*?)'", block).group(1)
    result = subprocess.run(
        ["jq", "-r", expression],
        input=json.dumps(prs), text=True, capture_output=True, check=True,
    )
    return [row.split("\t") for row in result.stdout.splitlines()]


def fixture(number, branch, draft):
    return {
        "number": number, "headRefName": branch, "isDraft": draft,
        "title": "Synthetic PR", "url": "https://example.invalid/pull/" + str(number),
        "reviewDecision": "",
        "statusCheckRollup": [{"status": "COMPLETED", "conclusion": "SUCCESS"}],
    }


class CodexBacklogSelectionTest(unittest.TestCase):
    def test_conflict_candidates_include_drafts_and_ready_codex_prs(self):
        rows = select_prs("conflicted_prs", [
            fixture(1, "codex/draft", True),
            fixture(2, "codex/ready", False),
            fixture(3, "feature/other", True),
        ])
        self.assertEqual([row[0] for row in rows], ["1", "2"])
        self.assertEqual(rows[0][2], "[Draft] Synthetic PR")
        self.assertEqual(rows[1][2], "Synthetic PR")

    def test_ready_candidates_still_exclude_drafts(self):
        rows = select_prs("ready_prs", [
            fixture(1, "codex/draft", True),
            fixture(2, "codex/ready", False),
        ])
        self.assertEqual([row[0] for row in rows], ["2"])

    def test_failed_checks_do_not_become_ready(self):
        pr = fixture(1, "codex/failing", False)
        pr["statusCheckRollup"][0]["conclusion"] = "FAILURE"
        self.assertEqual(select_prs("ready_prs", [pr]), [])


if __name__ == "__main__":
    unittest.main()
