"""Execute the workflow's actual planner with synthetic data, never GitHub."""
import contextlib
import io
import json
from pathlib import Path
import textwrap
import unittest
from unittest.mock import mock_open, patch

WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/issue-to-wbs.yml"


def plan(records):
    source = WORKFLOW.read_text(encoding="utf-8")
    block = source.split("python3 <<'PY' > /tmp/duplicate-issues.tsv\n", 1)[1]
    block = textwrap.dedent(block.split("          PY", 1)[0])
    output = io.StringIO()
    with patch("builtins.open", mock_open(read_data=json.dumps(records))):
        with contextlib.redirect_stdout(output):
            exec(compile(block, str(WORKFLOW), "exec"), {})
    return [line.split("\t")[:2] for line in output.getvalue().splitlines()]


def issue(number, title="same", state="OPEN"):
    return dict(number=number, title=title, state=state)


class DedupeSafetyTest(unittest.TestCase):
    def test_repeated_canonical_is_never_closed(self):
        self.assertEqual(plan([issue(1362), issue(1362)]), [])

    def test_repeated_duplicate_is_emitted_once(self):
        self.assertEqual(plan([issue(2), issue(1), issue(2), issue(1)]), [["2", "1"]])

    def test_conflicting_snapshot_is_excluded(self):
        self.assertEqual(plan([issue(1), issue(1, state="CLOSED"), issue(2)]), [])
        self.assertEqual(plan([issue(1), issue(1, title="changed"), issue(2)]), [])

    def test_distinct_titles_closed_and_invalid_ids_are_ignored(self):
        self.assertEqual(plan([issue(1), issue(2, title="other"),
                               issue(3, state="CLOSED"), issue(True), issue(0)]), [])

    def test_normalized_titles_keep_oldest_number(self):
        self.assertEqual(plan([issue(3, "[Issue #99] SAME"), issue(1)]), [["3", "1"]])

    def test_execution_boundary_rejects_self_reference(self):
        source = WORKFLOW.read_text(encoding="utf-8")
        loop = source.split("while IFS=$'\\t' read -r duplicate keep title; do", 1)[1]
        before_close = loop.split('gh issue close "$duplicate"', 1)[0]
        self.assertIn('[ "$duplicate" != "$keep" ] || continue', before_close)
        self.assertIn('"$keep" =~ ^[1-9][0-9]*$', before_close)


if __name__ == "__main__":
    unittest.main()
