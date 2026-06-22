from __future__ import annotations

import unittest

from scripts.check_roadmap_append_only import compare_roadmap_text, stats_for_text


class RoadmapAppendOnlyGuardTest(unittest.TestCase):
    def test_allows_append_only_growth(self) -> None:
        base = "\n".join(["# Roadmap", "entry 1", "entry 2"])
        head = base + "\nentry 3\n"

        self.assertEqual(compare_roadmap_text(base, head), [])

    def test_detects_destructive_line_drop(self) -> None:
        base = "\n".join(f"entry {index}" for index in range(1000))
        head = "\n".join(f"entry {index}" for index in range(5))

        findings = compare_roadmap_text(base, head)

        self.assertEqual(findings[0].code, "line-drop")

    def test_ignores_small_trim(self) -> None:
        base = "\n".join(f"entry {index}" for index in range(1000))
        head = "\n".join(f"entry {index}" for index in range(950))

        self.assertEqual(compare_roadmap_text(base, head), [])

    def test_detects_placeholder_marker(self) -> None:
        findings = compare_roadmap_text(
            "entry\n" * 1000,
            "# Roadmap\nPLACEHOLDER_FULL_CONTENT\n",
        )

        self.assertTrue(any(finding.code == "placeholder" for finding in findings))

    def test_stats_reports_placeholder_markers(self) -> None:
        stats = stats_for_text("a\n[[ROADMAP_CONTENT_PLACEHOLDER]]\n")

        self.assertEqual(stats.lines, 2)
        self.assertIn("[[ROADMAP_CONTENT_PLACEHOLDER]]", stats.placeholder_markers)


if __name__ == "__main__":
    unittest.main()
