import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_university_source_audit as audit


CHECKED_AT = datetime(2026, 8, 24, 12, 0, tzinfo=timezone.utc)


def fetched(url: str, timeout: float) -> audit.FetchResult:
    del timeout
    return audit.FetchResult(
        status_code=200,
        etag=f'"{Path(url).name}"',
        last_modified="Sun, 24 Aug 2026 10:00:00 GMT",
        content_digest="a" * 64,
    )


class AiUniversitySourceAuditTest(unittest.TestCase):
    def test_catalog_inventory_keeps_ids_but_drops_titles_and_inactive_rows(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            catalog = Path(tmp) / "catalog.json"
            catalog.write_text(
                json.dumps(
                    [
                        {
                            "id": "course-1",
                            "provider": "openai",
                            "title": "must not enter audit output",
                            "source_url": "https://example.com/docs",
                            "is_active": True,
                        },
                        {
                            "id": "course-2",
                            "provider": "old",
                            "source_url": "https://example.com/old",
                            "is_active": False,
                        },
                    ]
                ),
                encoding="utf-8",
            )
            sources = audit.extract_catalog_sources(catalog)
            self.assertEqual(
                sources,
                [
                    {
                        "provider": "openai",
                        "url": "https://example.com/docs",
                        "name": "openai",
                        "record_id": "course-1",
                        "target_audience": None,
                        "observable_learning_outcome": None,
                        "assessment_verification_method": None,
                        "evidence_source_url": None,
                        "evidence_verified_at": None,
                    }
                ],
            )
            self.assertNotIn("title", sources[0])

    def test_extracts_only_active_workflow_sources(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workflow = Path(tmp) / "workflow.yml"
            workflow.write_text(
                '  upsert_provider "openai" "https://example.com/feed" "OpenAI"\n'
                '  # upsert_provider "ignored" "https://example.com/x" "Ignored"\n',
                encoding="utf-8",
            )
            self.assertEqual(
                audit.extract_sources(workflow),
                [
                    {
                        "provider": "openai",
                        "url": "https://example.com/feed",
                        "name": "OpenAI",
                    }
                ],
            )

    def test_records_signals_and_targets_changed_source_for_recheck(self) -> None:
        source = {
            "provider": "openai",
            "url": "https://example.com/feed.xml",
            "name": "OpenAI",
        }
        baseline = {
            source["url"]: {
                "url": source["url"],
                "checked_at": (CHECKED_AT - timedelta(hours=1)).isoformat(),
                "status_code": 200,
                "etag": '"old"',
                "last_modified": "Sun, 24 Aug 2026 10:00:00 GMT",
                "content_digest": "b" * 64,
            }
        }

        report = audit.audit_sources(
            [source], fetch=fetched, baseline=baseline, checked_at=CHECKED_AT
        )

        self.assertEqual(report["checked_at"], CHECKED_AT.isoformat())
        self.assertEqual(report["changed_count"], 1)
        row = report["sources"][0]
        self.assertEqual(row["changed_signals"], ["etag", "content_digest"])
        self.assertEqual(row["recheck_reasons"], ["source_changed"])
        self.assertEqual(report["recheck_sources"][0]["provider"], "openai")

    def test_unchanged_recent_baseline_has_no_recheck_target(self) -> None:
        source = {
            "provider": "openai",
            "url": "https://example.com/feed.xml",
            "name": "OpenAI",
        }
        result = fetched(source["url"], 1)
        baseline = {
            source["url"]: {
                "url": source["url"],
                "checked_at": CHECKED_AT.isoformat(),
                "status_code": result.status_code,
                "etag": result.etag,
                "last_modified": result.last_modified,
                "content_digest": result.content_digest,
            }
        }
        report = audit.audit_sources(
            [source], fetch=fetched, baseline=baseline, checked_at=CHECKED_AT
        )
        self.assertEqual(report["recheck_count"], 0)

    def test_cli_writes_machine_and_human_reports_without_network(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            workflow = root / "workflow.yml"
            output_json = root / "report.json"
            output_md = root / "report.md"
            workflow.write_text(
                'upsert_provider "openai" "https://example.com/feed" "OpenAI"\n',
                encoding="utf-8",
            )
            original = audit.default_fetch
            try:
                audit.default_fetch = fetched
                self.assertEqual(
                    audit.main(
                        [
                            "--workflow",
                            str(workflow),
                            "--output-json",
                            str(output_json),
                            "--output-md",
                            str(output_md),
                        ]
                    ),
                    0,
                )
            finally:
                audit.default_fetch = original
            self.assertEqual(
                json.loads(output_json.read_text(encoding="utf-8"))["source_count"],
                1,
            )
            self.assertIn(
                "Explicit recheck targets",
                output_md.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()
