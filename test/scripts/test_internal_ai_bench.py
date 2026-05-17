import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import internal_ai_bench


def scored_report() -> dict:
    report = internal_ai_bench.default_report()
    report["bench_id"] = "B1"
    report["models"] = [
        {
            "provider": "anthropic",
            "model": "claude-opus-4-7",
            "verification_status": "verified",
            "official_sources": ["https://www.anthropic.com/news/claude-opus-4-7"],
            "scores": {axis: 2 for axis in internal_ai_bench.AXES},
            "notes": "Verified baseline.",
        },
        {
            "provider": "sns",
            "model": "mimo-v2.5-pro",
            "verification_status": "unverified",
            "official_sources": [],
            "scores": {axis: 3 for axis in internal_ai_bench.AXES},
            "notes": "Synthetic high score must not rank.",
        },
    ]
    return report


class InternalAiBenchTest(unittest.TestCase):
    def test_template_contains_required_provider_slots(self) -> None:
        report = internal_ai_bench.default_report()
        labels = {
            f"{entry['provider']}/{entry['model']}"
            for entry in report["models"]
        }

        self.assertIn("openai/gpt-5.5", labels)
        self.assertIn("anthropic/claude-opus-4-7", labels)
        self.assertIn("google/gemini-3.1-pro-preview", labels)
        self.assertIn("moonshot/kimi-k2.6", labels)
        self.assertIn("deepseek/deepseek-v4-flash", labels)
        self.assertIn("thinking_budget", report["axes"])

    def test_unverified_model_is_never_ranked(self) -> None:
        evaluation = internal_ai_bench.evaluate_report(scored_report())

        ranked_labels = {entry["label"] for entry in evaluation["ranked_models"]}
        holdout_labels = {entry["label"] for entry in evaluation["holdout_models"]}

        self.assertIn("anthropic/claude-opus-4-7", ranked_labels)
        self.assertNotIn("sns/mimo-v2.5-pro", ranked_labels)
        self.assertIn("sns/mimo-v2.5-pro", holdout_labels)
        self.assertTrue(any("not rankable" in warning for warning in evaluation["warnings"]))

    def test_markdown_forbids_fixed_strongest_language(self) -> None:
        markdown = internal_ai_bench.render_markdown(
            internal_ai_bench.evaluate_report(scored_report())
        )

        self.assertIn("task-specific fit", markdown)
        self.assertIn("fixed strongest model ranking", markdown)
        self.assertIn("## Holdouts", markdown)

    def test_cli_writes_template_and_reports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            template_path = root / "template.json"
            out_json = root / "report.json"
            out_md = root / "report.md"

            self.assertEqual(
                internal_ai_bench.main(["--write-template", str(template_path)]),
                0,
            )
            template = json.loads(template_path.read_text(encoding="utf-8"))
            template["models"] = scored_report()["models"]
            template_path.write_text(json.dumps(template), encoding="utf-8")

            self.assertEqual(
                internal_ai_bench.main(
                    [
                        "--input",
                        str(template_path),
                        "--output-json",
                        str(out_json),
                        "--output-md",
                        str(out_md),
                    ]
                ),
                0,
            )

            normalized = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(normalized["ranked_models"][0]["label"], "anthropic/claude-opus-4-7")
            self.assertIn("No fixed strongest model", out_md.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
