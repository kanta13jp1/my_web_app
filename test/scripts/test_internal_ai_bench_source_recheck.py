import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import internal_ai_bench
from scripts import internal_ai_bench_source_recheck


def fake_fetch(url: str, timeout: float) -> tuple[int | None, str, str]:
    bodies = {
        "https://openai.com/index/introducing-gpt-5-5/": "Introducing GPT-5.5 API",
        "https://developers.openai.com/api/docs/models/gpt-5.5": (
            "GPT-5.5 Pricing 1,050,000 context window Responses"
        ),
        "https://www.anthropic.com/news/claude-opus-4-7": (
            "Claude Opus 4.7 claude-opus-4-7 Opus 4.6"
        ),
        "https://ai.google.dev/gemini-api/docs/models": (
            "Gemini 3.1 Pro Preview deprecated Gemini 3 Pro Preview"
        ),
        "https://platform.kimi.ai/docs/models": "kimi-k2.6 Kimi K2.6 Context 256k",
        "https://api-docs.deepseek.com/updates/": (
            "DeepSeek-V4 deepseek-v4-flash V4-Flash Anthropic interface"
        ),
        "https://api-docs.deepseek.com/quick_start/pricing/": "deepseek pricing v4",
        "https://docs.x.ai/developers/models": "grok-4.3 Which model should I choose? pricing",
        "https://arxiv.org/abs/2604.14148": "Seedance 2.0 video",
    }
    return 200, bodies.get(url, ""), ""


class InternalAiBenchSourceRecheckTest(unittest.TestCase):
    def test_recheck_passes_verified_sources_without_live_calls(self) -> None:
        report = internal_ai_bench_source_recheck.recheck_report(
            internal_ai_bench.default_report(),
            fetch=fake_fetch,
        )

        self.assertFalse(report["live_provider_calls"])
        labels = {entry["label"]: entry for entry in report["models"]}
        self.assertTrue(labels["openai/gpt-5.5"]["rankable_after_recheck"])
        self.assertTrue(labels["anthropic/claude-opus-4-7"]["rankable_after_recheck"])
        self.assertFalse(labels["bytedance/seedance-2.0"]["rankable_after_recheck"])
        self.assertFalse(labels["mimo/mimo-v2.5-pro"]["rankable_after_recheck"])
        self.assertTrue(
            any(
                claim["claim"] == "anthropic/opus-4.7-fast"
                for claim in report["rejected_sns_claims"]
            )
        )

    def test_verified_slot_failure_emits_warning(self) -> None:
        def failing_fetch(url: str, timeout: float) -> tuple[int | None, str, str]:
            if "openai.com" in url:
                return 404, "missing", "not found"
            return fake_fetch(url, timeout)

        report = internal_ai_bench_source_recheck.recheck_report(
            internal_ai_bench.default_report(),
            fetch=failing_fetch,
        )

        self.assertIn(
            "openai/gpt-5.5: verified slot failed current source recheck",
            report["warnings"],
        )

    def test_cli_writes_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            input_path = root / "template.json"
            out_json = root / "source_recheck.json"
            out_md = root / "source_recheck.md"
            input_path.write_text(
                json.dumps(internal_ai_bench.default_report()),
                encoding="utf-8",
            )

            original_fetch = internal_ai_bench_source_recheck.default_fetch
            try:
                internal_ai_bench_source_recheck.default_fetch = fake_fetch
                self.assertEqual(
                    internal_ai_bench_source_recheck.main(
                        [
                            "--input",
                            str(input_path),
                            "--output-json",
                            str(out_json),
                            "--output-md",
                            str(out_md),
                            "--strict",
                        ]
                    ),
                    0,
                )
            finally:
                internal_ai_bench_source_recheck.default_fetch = original_fetch

            normalized = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertFalse(normalized["live_provider_calls"])
            markdown = out_md.read_text(encoding="utf-8")
            self.assertIn("Live provider calls: disabled", markdown)
            self.assertIn("Rejected SNS Claims", markdown)


if __name__ == "__main__":
    unittest.main()
