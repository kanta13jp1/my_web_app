import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from scripts import obsidian_vault_migration_manifest as vault_manifest


class ObsidianVaultMigrationManifestTest(unittest.TestCase):
    def _fixture(self, root: Path) -> Path:
        vault = root / "company"
        (vault / "Projects").mkdir(parents=True)
        (vault / "Attachments").mkdir()
        (vault / ".obsidian").mkdir()
        (vault / "scripts").mkdir()
        (vault / "Templates").mkdir()
        (vault / ".batch-backup").mkdir()

        (vault / "HOME.md").write_text(
            """---
title: Home
tags:
  - private
---
# Home
[[Projects/Plan|Plan]]
![[Attachments/photo.jpg|300]]
[[Missing]]
[external](https://example.com)
> [!warning] Review
- [x] done
- [ ] todo
""",
            encoding="utf-8",
        )
        (vault / "Projects" / "Plan.md").write_text(
            "# Plan\n[[HOME]]\n", encoding="utf-8"
        )
        (vault / "FINANCIAL_RECORDS.md").write_text(
            "# Finance\naccount: private-value\n", encoding="utf-8"
        )
        (vault / "Attachments" / "photo.jpg").write_bytes(b"jpeg fixture")
        (vault / "Attachments" / "unused.pdf").write_bytes(b"pdf fixture")
        (vault / ".obsidian" / "app.json").write_text(
            '{"secret": "must-not-be-read"}', encoding="utf-8"
        )
        (vault / "scripts" / "helper.py").write_text(
            "TOKEN = 'must-not-be-read'\n", encoding="utf-8"
        )
        (vault / "Templates" / "Daily.md").write_text(
            "secret: must-not-be-read\n", encoding="utf-8"
        )
        (vault / "AGENTS.md").write_text(
            "secret: must-not-be-read\n", encoding="utf-8"
        )
        (vault / "service-account.json").write_text(
            '{"private_key": "must-not-be-read"}', encoding="utf-8"
        )
        (vault / "catalog.json").write_text(
            '{"kind": "benign-but-review-first"}', encoding="utf-8"
        )
        (vault / ".batch-backup" / "old.md").write_text(
            "must-not-be-read\n", encoding="utf-8"
        )
        return vault

    def test_builds_structural_manifest_and_resolves_graph(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            vault = self._fixture(Path(temporary_directory))

            manifest = vault_manifest.build_manifest(vault)

            self.assertTrue(manifest["local_only"])
            self.assertFalse(manifest["source_absolute_path_included"])
            self.assertEqual(manifest["summary"]["file_count"], 12)
            self.assertEqual(manifest["summary"]["review_required_count"], 1)
            self.assertEqual(manifest["summary"]["credential_candidate_count"], 1)
            self.assertEqual(
                manifest["summary"]["unresolved_wikilink_occurrences"], 1
            )
            self.assertEqual(manifest["summary"]["unreferenced_attachment_count"], 1)

            by_path = {
                entry["relative_path"]: entry for entry in manifest["entries"]
            }
            home = by_path["HOME.md"]
            self.assertEqual(home["markdown"]["property_keys"], ["tags", "title"])
            self.assertEqual(home["markdown"]["external_link_count"], 1)
            self.assertEqual(home["markdown"]["callout_types"], {"warning": 1})
            self.assertEqual(home["markdown"]["task_count"], 2)
            self.assertEqual(home["markdown"]["completed_task_count"], 1)
            targets = {
                link["target"]: link for link in home["markdown"]["wikilinks"]
            }
            self.assertEqual(
                targets["Projects/Plan"]["resolved_relative_path"],
                "Projects/Plan.md",
            )
            self.assertEqual(
                targets["Attachments/photo.jpg"]["resolved_relative_path"],
                "Attachments/photo.jpg",
            )
            self.assertFalse(targets["Missing"]["resolved"])
            self.assertEqual(
                by_path["Attachments/photo.jpg"]["referenced_by"], ["HOME.md"]
            )

            self.assertEqual(
                by_path["FINANCIAL_RECORDS.md"]["migration_action"],
                "review_required",
            )
            for excluded in (
                ".obsidian/app.json",
                "scripts/helper.py",
                "Templates/Daily.md",
                "AGENTS.md",
                "service-account.json",
                "catalog.json",
                ".batch-backup/old.md",
            ):
                self.assertEqual(by_path[excluded]["migration_action"], "exclude")
                self.assertIsNone(by_path[excluded]["sha256"])
                self.assertFalse(by_path[excluded]["content_inspected"])
            self.assertEqual(by_path["catalog.json"]["category"], "structured_data")
            self.assertEqual(by_path[".batch-backup/old.md"]["category"], "hidden_path")

            rendered = json.dumps(manifest, ensure_ascii=False)
            self.assertNotIn("must-not-be-read", rendered)
            self.assertNotIn("private-value", rendered)

    def test_excluded_credentials_are_never_hashed_or_opened(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            vault = root / "vault"
            vault.mkdir()
            note = vault / "note.md"
            credential = vault / "company-service-account.json"
            note.write_text("# Safe\n", encoding="utf-8")
            credential.write_text('{"private_key": "blocked"}', encoding="utf-8")

            original_hash = vault_manifest._sha256
            original_metadata = vault_manifest._read_markdown_metadata

            def guarded_hash(path: Path) -> str:
                self.assertNotEqual(path, credential)
                return original_hash(path)

            def guarded_metadata(path: Path):
                self.assertNotEqual(path, credential)
                return original_metadata(path)

            with mock.patch.object(vault_manifest, "_sha256", side_effect=guarded_hash), mock.patch.object(
                vault_manifest,
                "_read_markdown_metadata",
                side_effect=guarded_metadata,
            ):
                manifest = vault_manifest.build_manifest(vault)

            credential_record = next(
                entry
                for entry in manifest["entries"]
                if entry["relative_path"] == credential.name
            )
            self.assertEqual(credential_record["category"], "credential_candidate")
            self.assertIsNone(credential_record["sha256"])

    def test_explicit_credential_path_is_classified_without_reading_json(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            vault = Path(temporary_directory) / "vault"
            vault.mkdir()
            credential = vault / "random-id.json"
            credential.write_text('{"private_key": "blocked"}', encoding="utf-8")

            with mock.patch.object(
                vault_manifest,
                "_sha256",
                side_effect=AssertionError("credential must not be hashed"),
            ), mock.patch.object(
                vault_manifest,
                "_read_markdown_metadata",
                side_effect=AssertionError("credential must not be opened"),
            ):
                manifest = vault_manifest.build_manifest(
                    vault, credential_paths=[credential.name]
                )

            record = manifest["entries"][0]
            self.assertEqual(record["category"], "credential_candidate")
            self.assertEqual(record["reason"], "explicit_credential_path")

    def test_output_inside_vault_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            vault = Path(temporary_directory) / "vault"
            vault.mkdir()
            output = vault / "manifest.json"
            with self.assertRaisesRegex(ValueError, "outside the vault"):
                vault_manifest._validate_paths(vault, output)

    def test_cli_output_is_deterministic_and_fail_on_review_returns_two(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            vault = self._fixture(root)
            output = root / "manifest.json"
            command = ["--vault", str(vault), "--output", str(output)]

            self.assertEqual(vault_manifest.main(command), 0)
            first = output.read_bytes()
            self.assertEqual(vault_manifest.main(command), 0)
            self.assertEqual(output.read_bytes(), first)
            self.assertEqual(vault_manifest.main([*command, "--fail-on-review"]), 2)


if __name__ == "__main__":
    unittest.main()
