import tempfile
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.kg_index_common import (
    SourceRecord,
    content_hash,
    detect_pii,
    filter_payloads,
    record_payload,
    write_jsonl,
)


class KgIndexCommonTest(unittest.TestCase):
    def test_detect_pii_catches_email_and_luhn_card(self) -> None:
        hits = detect_pii("Contact test@example.com or card 4242 4242 4242 4242")

        self.assertIn("email", hits)
        self.assertIn("credit_card", hits)

    def test_filter_payloads_skips_pii_records(self) -> None:
        clean = SourceRecord(
            source_type="doc",
            source_id="docs/clean.md",
            title="Clean",
            content="Project docs without personal data.",
        )
        pii = SourceRecord(
            source_type="issue",
            source_id="1",
            title="Leak",
            content="mail me at owner@example.com",
        )

        payloads, skipped = filter_payloads([clean, pii])

        self.assertEqual(len(payloads), 1)
        self.assertEqual(payloads[0]["source_id"], "docs/clean.md")
        self.assertEqual(len(skipped), 1)
        self.assertEqual(skipped[0]["source_type"], "issue")

    def test_record_payload_has_stable_hash_and_excerpt(self) -> None:
        record = SourceRecord(
            source_type="wbs",
            source_id="docs/WBS.md",
            title="WBS",
            content="alpha " * 100,
        )

        payload = record_payload(record)

        self.assertEqual(payload["content_hash"], content_hash(record.content.strip()))
        self.assertLessEqual(len(payload["excerpt"]), 280)

    def test_write_jsonl_creates_parent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "nested" / "records.jsonl"
            count = write_jsonl(output, [{"a": 1}, {"b": 2}])

            self.assertEqual(count, 2)
            self.assertEqual(len(output.read_text(encoding="utf-8").splitlines()), 2)


if __name__ == "__main__":
    unittest.main()
