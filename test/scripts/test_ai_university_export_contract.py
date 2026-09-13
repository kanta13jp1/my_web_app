import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import ai_university_export_contract as contract


def row(**overrides: object) -> dict[str, object]:
    value: dict[str, object] = {
        "id": "course-1",
        "provider": "01ai",
        "title": "Model list",
        "source_url": "https://platform.01.ai/docs",
        "is_active": True,
        "target_audience": None,
        "observable_learning_outcome": None,
        "assessment_verification_method": None,
        "evidence_source_url": None,
        "evidence_verified_at": None,
    }
    value.update(overrides)
    return value


class AiUniversityExportContractTest(unittest.TestCase):
    def test_accepts_legacy_row_only_when_all_evidence_keys_are_present(self) -> None:
        report = contract.validate_export([row()])
        self.assertTrue(report["valid"])
        self.assertEqual(report["legacy_null_evidence_row_count"], 1)

        incomplete = row()
        del incomplete["target_audience"]
        report = contract.validate_export([incomplete])
        self.assertFalse(report["valid"])
        self.assertEqual(report["errors"][0]["code"], "required_fields_missing")

    def test_accepts_complete_attributed_evidence(self) -> None:
        report = contract.validate_export(
            [
                row(
                    target_audience="Developers evaluating Yi models",
                    observable_learning_outcome="Compare the documented model variants",
                    assessment_verification_method="Match the comparison to the model list",
                    evidence_source_url="https://platform.01.ai/docs",
                    evidence_verified_at="2026-08-29T12:00:00Z",
                )
            ]
        )
        self.assertTrue(report["valid"])
        self.assertEqual(report["evidenced_row_count"], 1)

    def test_accepts_external_catalog_envelope(self) -> None:
        report = contract.validate_export(
            {
                "schema_version": 2,
                "courses": [row()],
            }
        )

        self.assertTrue(report["valid"])
        self.assertEqual(report["input_shape"], "catalog_envelope")
        self.assertEqual(report["row_count"], 1)

    def test_rejects_partial_or_unattributed_evidence(self) -> None:
        partial = contract.validate_export([row(target_audience="Developers")])
        self.assertFalse(partial["valid"])
        self.assertEqual(partial["errors"][0]["code"], "partial_evidence")

        invalid = contract.validate_export(
            [
                row(
                    target_audience="Developers",
                    observable_learning_outcome="Compare models",
                    assessment_verification_method="Review output",
                    evidence_source_url="http://example.com",
                    evidence_verified_at="2026-08-29",
                )
            ]
        )
        self.assertFalse(invalid["valid"])
        self.assertEqual(
            {error["field"] for error in invalid["errors"]},
            {"evidence_source_url", "evidence_verified_at"},
        )

    def test_cli_returns_nonzero_and_persists_report_for_old_export_projection(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "export.json"
            output = root / "report.json"
            source.write_text(
                json.dumps(
                    [
                        {
                            "id": "course-1",
                            "provider": "01ai",
                            "title": "Model list",
                            "source_url": "https://platform.01.ai/docs",
                            "is_active": True,
                        }
                    ]
                ),
                encoding="utf-8",
            )
            self.assertEqual(
                contract.main([str(source), "--output-json", str(output)]), 1
            )
            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertFalse(report["valid"])
            self.assertEqual(len(report["errors"]), 1)


if __name__ == "__main__":
    unittest.main()
