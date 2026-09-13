import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import hedra_model_watch


def model(model_id: str, *, name: str, credits: int = 10) -> dict:
    return {
        "id": model_id,
        "name": name,
        "type": "video",
        "aspect_ratios": ["9:16", "16:9"],
        "durations": ["10", "5"],
        "pricing": {"credits_per_second": credits, "modifiers": {}},
    }


class HedraModelWatchTest(unittest.TestCase):
    def test_normalization_is_stable_for_model_and_capability_order(self) -> None:
        first = [model("b", name="Beta"), model("a", name="Alpha")]
        second = [model("a", name="Alpha"), model("b", name="Beta")]
        second[0]["aspect_ratios"] = ["16:9", "9:16"]
        second[0]["durations"] = ["5", "10"]

        normalized_first = hedra_model_watch.normalize_catalog(first)
        normalized_second = hedra_model_watch.normalize_catalog(second)

        self.assertEqual(normalized_first, normalized_second)
        self.assertEqual(
            hedra_model_watch.stable_digest(normalized_first),
            hedra_model_watch.stable_digest(normalized_second),
        )

    def test_duplicate_model_ids_fail_closed(self) -> None:
        with self.assertRaisesRegex(hedra_model_watch.WatchError, "duplicate"):
            hedra_model_watch.normalize_catalog(
                [model("same", name="One"), model("same", name="Two")]
            )

    def test_empty_catalog_fails_closed(self) -> None:
        with self.assertRaisesRegex(hedra_model_watch.WatchError, "must not be empty"):
            hedra_model_watch.normalize_catalog([])

    def test_baseline_then_add_remove_and_modify(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            snapshot = Path(tmp) / "models.json"
            baseline = [model("a", name="Alpha"), model("b", name="Beta")]
            initial = hedra_model_watch.process_catalog(
                baseline,
                snapshot_path=snapshot,
                checked_at="2026-09-03T00:00:00Z",
            )
            self.assertEqual(initial["status"], "baseline_created")
            self.assertFalse(initial["changed"])
            self.assertTrue(snapshot.exists())

            changed = hedra_model_watch.process_catalog(
                [
                    model("a", name="Alpha 2", credits=12),
                    model("c", name="Gamma"),
                ],
                snapshot_path=snapshot,
                checked_at="2026-09-10T00:00:00Z",
            )

            self.assertEqual(changed["status"], "changed")
            self.assertTrue(changed["changed"])
            self.assertEqual(
                [item["id"] for item in changed["differences"]["added"]],
                ["c"],
            )
            self.assertEqual(
                [item["id"] for item in changed["differences"]["removed"]],
                ["b"],
            )
            self.assertEqual(
                changed["differences"]["changed"][0]["changed_fields"],
                ["name", "pricing"],
            )

    def test_unchanged_run_keeps_original_snapshot_timestamp(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            snapshot = Path(tmp) / "models.json"
            catalog = [model("a", name="Alpha")]
            hedra_model_watch.process_catalog(
                catalog,
                snapshot_path=snapshot,
                checked_at="2026-09-03T00:00:00Z",
            )
            before = snapshot.read_text(encoding="utf-8")

            report = hedra_model_watch.process_catalog(
                catalog,
                snapshot_path=snapshot,
                checked_at="2026-09-10T00:00:00Z",
            )

            self.assertEqual(report["status"], "unchanged")
            self.assertFalse(report["changed"])
            self.assertEqual(snapshot.read_text(encoding="utf-8"), before)

    def test_cli_fixture_writes_reports_and_actions_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixture = root / "fixture.json"
            snapshot = root / "models.json"
            markdown = root / "report.md"
            report_json = root / "report.json"
            outputs = root / "outputs.txt"
            fixture.write_text(
                json.dumps([model("a", name="Alpha")]),
                encoding="utf-8",
            )

            with mock.patch.dict(os.environ, {"GITHUB_OUTPUT": str(outputs)}):
                exit_code = hedra_model_watch.main(
                    [
                        "--fixture",
                        str(fixture),
                        "--snapshot",
                        str(snapshot),
                        "--report",
                        str(markdown),
                        "--json-report",
                        str(report_json),
                        "--checked-at",
                        "2026-09-03T00:00:00Z",
                    ]
                )

            self.assertEqual(exit_code, 0)
            self.assertIn("status=baseline_created", outputs.read_text(encoding="utf-8"))
            self.assertIn("changed=false", outputs.read_text(encoding="utf-8"))
            self.assertIn("baseline", markdown.read_text(encoding="utf-8"))
            self.assertEqual(
                json.loads(report_json.read_text(encoding="utf-8"))["model_count"],
                1,
            )

    def test_issue_summary_strips_multiline_markdown_control_text(self) -> None:
        summary = hedra_model_watch.model_summary(
            model("a`\n@team", name="Alpha\n@everyone")
        )

        self.assertEqual(summary["id"], "a' ＠team")
        self.assertEqual(summary["name"], "Alpha ＠everyone")


if __name__ == "__main__":
    unittest.main()
