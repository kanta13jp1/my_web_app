from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts import resolve_append_only_conflicts as resolver


class ResolveAppendOnlyConflictsTests(unittest.TestCase):
    def test_gitattributes_rules_match_tracked_files_and_allowlist(self) -> None:
        gitattributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
        self.assertIn(
            "services/video-inference-worker/patches/*.patch text eol=lf",
            gitattributes,
        )
        tracked = set(
            subprocess.check_output(
                ["git", "-C", str(ROOT), "ls-files"],
                text=True,
                encoding="utf-8",
            ).splitlines()
        )
        union_patterns = [
            line.split()[0]
            for line in gitattributes.splitlines()
            if line.strip()
            and not line.lstrip().startswith("#")
            and "merge=union" in line.split()[1:]
        ]
        self.assertGreaterEqual(len(union_patterns), 5)
        self.assertEqual(set(union_patterns), set(resolver.APPEND_ONLY_PATH_PATTERNS))
        for pattern in union_patterns:
            regex = (
                "^"
                + re.escape(pattern)
                .replace(r"\*", "[^/]*")
                + "$"
            )
            matched = [path for path in tracked if re.match(regex, path)]
            self.assertTrue(
                matched,
                f".gitattributes merge=union pattern {pattern!r} matched no tracked files",
            )
            for path in matched:
                self.assertTrue(
                    resolver.is_append_only_path(path),
                    f"Allowlist missing .gitattributes tracked path {path}",
                )

    def test_resolves_two_way_conflict_retaining_both_additions(self) -> None:
        raw = (
            "# Growth Roadmap\n"
            "- Existing entry\n"
            "<<<<<<< HEAD\n"
            "- Added on feature branch A\n"
            "- Common heading\n"
            "=======\n"
            "- Common heading\n"
            "- Added on feature branch B\n"
            ">>>>>>> origin/main\n"
            "- Tail\n"
        )
        res = resolver.resolve_conflict_text(raw)
        self.assertEqual(res.conflicts_found, 1)
        self.assertTrue(res.changed)
        self.assertEqual(
            res.resolved_text,
            (
                "# Growth Roadmap\n"
                "- Existing entry\n"
                "- Added on feature branch A\n"
                "- Common heading\n"
                "- Added on feature branch B\n"
                "- Tail\n"
            ),
        )
        self.assertEqual(res.duplicate_lines_skipped, 1)

    def test_resolves_diff3_and_no_dedupe_option(self) -> None:
        raw = (
            "<<<<<<< HEAD\n"
            "- Entry 1\n"
            "||||||| merged common ancestors\n"
            "- Old base line\n"
            "=======\n"
            "- Entry 1\n"
            "- Entry 2\n"
            ">>>>>>> origin/main\n"
        )
        deduped = resolver.resolve_conflict_text(raw, dedupe_blocks=True)
        self.assertNotIn("- Old base line", deduped.resolved_text)
        self.assertEqual(deduped.resolved_text.count("- Entry 1"), 1)
        self.assertIn("- Entry 2", deduped.resolved_text)

        raw_kept = resolver.resolve_conflict_text(raw, dedupe_blocks=False)
        self.assertEqual(raw_kept.resolved_text.count("- Entry 1"), 2)
        self.assertNotIn("- Old base line", raw_kept.resolved_text)

    def test_rejects_malformed_markers_and_placeholders(self) -> None:
        for broken in (
            "<<<<<<< HEAD\n- unclosed block\n",
            "=======\n- stray separator\n",
            "<<<<<<< HEAD\n<<<<<<< nested\n=======\n>>>>>>> end\n",
            "<<<<<<< HEAD\nPLACEHOLDER_FULL_CONTENT\n=======\n- safe\n>>>>>>> end\n",
        ):
            with self.subTest(broken=broken[:20]), self.assertRaises(
                resolver.ConflictParseError
            ):
                resolver.resolve_conflict_text(broken)

    def test_refuses_non_append_only_path_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            code_file = root / "lib" / "main.dart"
            code_file.parent.mkdir(parents=True)
            conflicted = (
                "void main() {\n"
                "<<<<<<< HEAD\n  print('a');\n=======\n  print('b');\n>>>>>>> main\n"
                "}\n"
            )
            code_file.write_text(conflicted, encoding="utf-8")

            report = resolver.resolve_file(code_file, repo_root=root, write=True)
            self.assertEqual(report.status, "rejected_non_append_only")
            self.assertFalse(report.wrote_file)
            self.assertEqual(code_file.read_text(encoding="utf-8"), conflicted)

    def test_cli_check_dry_run_and_write_modes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            roadmap = root / "docs" / "GROWTH_STRATEGY_ROADMAP.md"
            roadmap.parent.mkdir(parents=True)
            roadmap.write_bytes(
                (
                    "# Roadmap\n"
                    "<<<<<<< HEAD\n- Feature X\n=======\n- Feature Y\n>>>>>>> main\n"
                ).encode("utf-8")
            )
            json_out = root / "report.json"
            md_out = root / "report.md"

            rc_check = resolver.main(
                [
                    "--repo-root",
                    str(root),
                    "--check",
                    "--json-out",
                    str(json_out),
                    "--markdown-out",
                    str(md_out),
                    "docs/GROWTH_STRATEGY_ROADMAP.md",
                ]
            )
            self.assertEqual(rc_check, 1)
            self.assertEqual(
                json.loads(json_out.read_text(encoding="utf-8"))["reports"][0][
                    "status"
                ],
                "would_resolve",
            )
            self.assertIn("Append-Only Conflict Resolution Report", md_out.read_text(encoding="utf-8"))

            rc_write = resolver.main(
                [
                    "--repo-root",
                    str(root),
                    "--write",
                    "docs/GROWTH_STRATEGY_ROADMAP.md",
                ]
            )
            self.assertEqual(rc_write, 0)
            written = roadmap.read_bytes()
            self.assertNotIn(b"\r\n", written)
            self.assertEqual(
                written.decode("utf-8"),
                "# Roadmap\n- Feature X\n- Feature Y\n",
            )

            rc_recheck = resolver.main(
                [
                    "--repo-root",
                    str(root),
                    "--check",
                    "docs/GROWTH_STRATEGY_ROADMAP.md",
                ]
            )
            self.assertEqual(rc_recheck, 0)

    def test_self_test_flag_passes(self) -> None:
        self.assertEqual(resolver.main(["--self-test"]), 0)


if __name__ == "__main__":
    unittest.main()
