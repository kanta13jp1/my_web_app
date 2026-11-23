from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import utf8_safe_replace as target  # noqa: E402


class Utf8SafeReplaceTests(unittest.TestCase):
    def test_replaces_multibyte_utf8_with_backup_and_preserves_lf(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            doc = Path(td) / "COMPRESSED_PROMPT_V3.md"
            doc.write_bytes(
                "# 見出し 🚀\n旧ルール: 日本語テスト✅\n末尾行\n".encode("utf-8")
            )
            res = target.apply_utf8_replace(
                doc,
                "旧ルール: 日本語テスト✅",
                "新ルール: マルチバイト置換完了 🎯",
                expected_count=1,
                create_backup=True,
            )
            self.assertTrue(res.changed)
            self.assertEqual(res.match_count, 1)
            self.assertEqual(res.replaced_count, 1)
            self.assertIsNotNone(res.backup_path)
            self.assertTrue(Path(res.backup_path).is_file())
            raw = doc.read_bytes()
            self.assertNotIn(b"\r\n", raw)
            self.assertIn("新ルール: マルチバイト置換完了 🎯", raw.decode("utf-8"))

    def test_fail_closed_on_missing_or_mismatched_expected_count(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            doc = Path(td) / "sample.md"
            original = "重複テスト\n重複テスト\n"
            doc.write_text(original, encoding="utf-8", newline="\n")

            with self.assertRaises(LookupError):
                target.apply_utf8_replace(doc, "存在しない文字列", "置換")

            with self.assertRaises(ValueError):
                target.apply_utf8_replace(
                    doc,
                    "重複テスト",
                    "一回のみ",
                    expected_count=1,
                )

            self.assertEqual(doc.read_text(encoding="utf-8"), original)

    def test_regex_dry_run_and_invalid_utf8_rejection(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            doc = Path(td) / "notes.md"
            doc.write_text("v1: テスト\nv2: テスト\n", encoding="utf-8", newline="\n")
            dry = target.apply_utf8_replace(
                doc,
                r"^v\d+:\s*テスト$",
                "v9: 更新済み",
                use_regex=True,
                dry_run=True,
            )
            self.assertEqual(dry.match_count, 2)
            self.assertEqual(doc.read_text(encoding="utf-8"), "v1: テスト\nv2: テスト\n")

            bad = Path(td) / "bad_shiftjis.bin"
            bad.write_bytes(b"\xff\xfe\x82\xa0")
            with self.assertRaises(ValueError):
                target.apply_utf8_replace(bad, "あ", "い")

    def test_cli_with_pythonutf8_and_file_args(self) -> None:
        script = Path(__file__).resolve().parents[2] / "scripts" / "utf8_safe_replace.py"
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            doc = root / "doc.md"
            find_file = root / "find.txt"
            replace_file = root / "replace.txt"
            doc.write_text("項目A：変更前📌\n項目B\n", encoding="utf-8", newline="\n")
            find_file.write_text("項目A：変更前📌", encoding="utf-8", newline="\n")
            replace_file.write_text("項目A：変更後✨", encoding="utf-8", newline="\n")

            env = os.environ.copy()
            env["PYTHONUTF8"] = "1"
            proc = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    str(script),
                    "--file",
                    str(doc),
                    "--find-file",
                    str(find_file),
                    "--replace-file",
                    str(replace_file),
                    "--expected-count",
                    "1",
                    "--require-utf8-env",
                    "--json",
                ],
                env=env,
                capture_output=True,
                text=True,
                encoding="utf-8",
            )
            self.assertEqual(proc.returncode, 0, msg=proc.stderr)
            payload = json.loads(proc.stdout)
            self.assertTrue(payload["changed"])
            self.assertTrue(payload["utf8_env_active"])
            self.assertIn("項目A：変更後✨", doc.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
