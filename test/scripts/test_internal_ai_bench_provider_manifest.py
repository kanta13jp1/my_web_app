import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import internal_ai_bench
from scripts import internal_ai_bench_provider_manifest


class InternalAiBenchProviderManifestTest(unittest.TestCase):
    def test_default_manifest_excludes_partial_and_unverified_models(self) -> None:
        manifest = internal_ai_bench_provider_manifest.build_manifest(
            internal_ai_bench.default_report()
        )

        labels = {
            f"{run['provider']}/{run['model']}"
            for run in manifest["runs"]
        }
        skipped = {entry["label"] for entry in manifest["skipped_models"]}

        self.assertIn("openai/gpt-5.5", labels)
        self.assertIn("anthropic/claude-opus-4-7", labels)
        self.assertNotIn("bytedance/seedance-2.0", labels)
        self.assertIn("bytedance/seedance-2.0", skipped)
        self.assertIn("mimo/mimo-v2.5-pro", skipped)
        self.assertFalse(manifest["live_provider_calls"])

    def test_manifest_run_contains_source_env_and_prompt_package(self) -> None:
        manifest = internal_ai_bench_provider_manifest.build_manifest(
            internal_ai_bench.default_report(),
            selected_tasks=["B1"],
            providers=["anthropic"],
        )

        self.assertEqual(len(manifest["runs"]), 1)
        run = manifest["runs"][0]
        self.assertEqual(run["task_id"], "B1")
        self.assertEqual(run["required_env"], ["ANTHROPIC_API_KEY"])
        self.assertIn("https://www.anthropic.com/news/claude-opus-4-7", run["official_sources"])
        self.assertIn("thinking_budget", run["prompt_package"]["scoring_axes"])
        self.assertIn("synthetic", run["prompt_package"]["input_policy"].lower())

    def test_cli_writes_manifest_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_path = root / "template.json"
            out_json = root / "manifest.json"
            out_md = root / "manifest.md"
            report_path.write_text(
                json.dumps(internal_ai_bench.default_report()),
                encoding="utf-8",
            )

            self.assertEqual(
                internal_ai_bench_provider_manifest.main(
                    [
                        "--input",
                        str(report_path),
                        "--task",
                        "R1",
                        "--provider",
                        "openai",
                        "--output-json",
                        str(out_json),
                        "--output-md",
                        str(out_md),
                        "--strict",
                    ]
                ),
                0,
            )

            manifest = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(manifest["runs"][0]["run_id"], "R1-openai-gpt-5.5")
            markdown = out_md.read_text(encoding="utf-8")
            self.assertIn("Live provider calls: disabled", markdown)
            self.assertIn("OPENAI_API_KEY", markdown)


if __name__ == "__main__":
    unittest.main()
