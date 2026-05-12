#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

import generate_release_notes as release_notes


class GenerateReleaseNotesTest(unittest.TestCase):
    def test_generates_required_current_fields_and_dedupes_prs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            base = Path(tmp_dir)
            pubspec = base / "pubspec.yaml"
            prs = base / "prs.json"
            releases = base / "releases.json"
            output = base / "release-notes.json"
            pubspec.write_text("name: app\nversion: 2.3.4+567\n", encoding="utf-8")
            prs.write_text(
                json.dumps(
                    [
                        {
                            "number": 10,
                            "title": "ci: sync release notes",
                            "mergedAt": "2026-05-03T01:00:00Z",
                            "url": "https://github.com/o/r/pull/10",
                            "labels": [{"name": "automation"}],
                        },
                        {
                            "number": 10,
                            "title": "ci: sync release notes",
                            "mergedAt": "2026-05-03T01:00:00Z",
                            "url": "https://github.com/o/r/pull/10",
                            "labels": [{"name": "automation"}],
                        },
                    ]
                ),
                encoding="utf-8",
            )
            releases.write_text(
                json.dumps(
                    [
                        {
                            "tagName": "v2.3.4",
                            "name": "Release 2.3.4",
                            "url": "https://github.com/o/r/releases/tag/v2.3.4",
                            "isDraft": False,
                        }
                    ]
                ),
                encoding="utf-8",
            )

            code = release_notes.main(
                [
                    "--repo",
                    "o/r",
                    "--pubspec",
                    str(pubspec),
                    "--pull-requests-json",
                    str(prs),
                    "--releases-json",
                    str(releases),
                    "--date",
                    "2026-05-03",
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(code, 0)
            data = json.loads(output.read_text(encoding="utf-8"))
            current = data["current"]
            self.assertEqual(current["version"], "2.3.4")
            self.assertEqual(current["build"], "567")
            self.assertEqual(current["date"], "2026-05-03")
            self.assertEqual(current["category"], "release")
            self.assertEqual(current["summary"], "Release 2.3.4")
            self.assertEqual(current["links"][0]["type"], "release")
            self.assertEqual(len(data["versions"][0]["changes"]), 1)
            self.assertEqual(data["versions"][0]["changes"][0]["category"], "automation")

    def test_check_fails_when_manual_output_is_out_of_date(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            base = Path(tmp_dir)
            pubspec = base / "pubspec.yaml"
            prs = base / "prs.json"
            releases = base / "releases.json"
            output = base / "release-notes.json"
            pubspec.write_text("version: 1.0.0+1\n", encoding="utf-8")
            prs.write_text("[]", encoding="utf-8")
            releases.write_text("[]", encoding="utf-8")
            output.write_text("{}\n", encoding="utf-8")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                code = release_notes.main(
                    [
                        "--repo",
                        "o/r",
                        "--pubspec",
                        str(pubspec),
                        "--pull-requests-json",
                        str(prs),
                        "--releases-json",
                        str(releases),
                        "--date",
                        "2026-05-03",
                        "--output",
                        str(output),
                        "--check",
                    ]
                )

            self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
