import json
from pathlib import Path
import tempfile
import unittest

from scripts import artifact_intake


class ArtifactIntakeTest(unittest.TestCase):
    def test_hashes_sorts_and_deduplicates_without_copying_matches(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            first = root / "first"
            second = root / "second"
            first.mkdir()
            second.mkdir()
            sensitive = "api_key=sk-proj-abcdefghijklmnopqrstuvwxyz\nuser@example.com\n"
            (first / "artifact.txt").write_text(sensitive, encoding="utf-8")
            (second / "copy.txt").write_text(sensitive, encoding="utf-8")
            output = root / "manifest.json"

            exit_code = artifact_intake.main(
                [
                    str(second),
                    str(first),
                    "--source-tool",
                    "codex",
                    "--intake-method",
                    "local_workspace",
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(exit_code, 0)
            manifest = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(manifest["local_only"])
            self.assertEqual(manifest["summary"]["unique_artifacts"], 1)
            entry = manifest["entries"][0]
            self.assertEqual(len(entry["provenance"]), 2)
            self.assertFalse(entry["risk_scan"]["matched_values_included"])
            rendered = output.read_text(encoding="utf-8")
            self.assertNotIn("sk-proj-abcdefghijklmnopqrstuvwxyz", rendered)
            self.assertNotIn("user@example.com", rendered)
            self.assertEqual(
                {finding["category"] for finding in entry["risk_scan"]["findings"]},
                {"secret", "pii"},
            )

    def test_existing_manifest_merge_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            artifact = root / "draft.md"
            artifact.write_text("A human-edited draft.\n", encoding="utf-8")
            output = root / "manifest.json"
            command = [
                str(artifact),
                "--source-tool",
                "claude_code",
                "--intake-method",
                "local_workspace",
                "--output",
                str(output),
            ]

            self.assertEqual(artifact_intake.main(command), 0)
            first_render = output.read_bytes()
            self.assertEqual(artifact_intake.main(command), 0)

            self.assertEqual(output.read_bytes(), first_render)

    def test_explicit_kind_supports_ambiguous_sellable_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            artifact = root / "concept.md"
            artifact.write_text("Human-curated product concept.\n", encoding="utf-8")
            output = root / "manifest.json"

            exit_code = artifact_intake.main(
                [
                    str(artifact),
                    "--source-tool",
                    "antigravity",
                    "--intake-method",
                    "local_workspace",
                    "--artifact-kind",
                    "idea",
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(exit_code, 0)
            entry = json.loads(output.read_text(encoding="utf-8"))["entries"][0]
            self.assertEqual(entry["artifact_kind"], "idea")

    def test_explicit_kind_supports_application_bundles(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            artifact = root / "windows-app.zip"
            artifact.write_bytes(b"PK\x03\x04application")
            output = root / "manifest.json"

            exit_code = artifact_intake.main(
                [
                    str(artifact),
                    "--source-tool",
                    "codex",
                    "--intake-method",
                    "local_workspace",
                    "--artifact-kind",
                    "application",
                    "--output",
                    str(output),
                ]
            )

            self.assertEqual(exit_code, 0)
            entry = json.loads(output.read_text(encoding="utf-8"))["entries"][0]
            self.assertEqual(entry["artifact_kind"], "application")

    def test_chatgpt_local_workspace_intake_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact = Path(temporary_directory) / "export.txt"
            artifact.write_text("export", encoding="utf-8")
            with self.assertRaises(SystemExit):
                artifact_intake._arguments(
                    [
                        str(artifact),
                        "--source-tool",
                        "chatgpt",
                        "--intake-method",
                        "local_workspace",
                        "--output",
                        "-",
                    ]
                )

    def test_chatgpt_audio_is_a_blocking_rights_finding(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            audio = root / "voice.mp3"
            audio.write_bytes(b"ID3test")
            output = root / "manifest.json"

            exit_code = artifact_intake.main(
                [
                    str(audio),
                    "--source-tool",
                    "chatgpt",
                    "--intake-method",
                    "explicit_export",
                    "--output",
                    str(output),
                    "--fail-on-risk",
                ]
            )

            self.assertEqual(exit_code, 2)
            findings = json.loads(output.read_text(encoding="utf-8"))["entries"][0][
                "risk_scan"
            ]["findings"]
            self.assertIn(
                "chatgpt_voice_output_standalone_audio",
                {finding["rule_id"] for finding in findings},
            )


if __name__ == "__main__":
    unittest.main()
