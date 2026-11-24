#!/usr/bin/env python3
"""Tests for Flutter Web bundled font subsetting (`scripts/optimize_web_fonts.py`)."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

from scripts.optimize_web_fonts import (
    CORE_UI_EMOJI,
    build_emoji_codepoints,
    build_japanese_codepoints,
    collect_repo_codepoints,
    jis_x_0208_codepoints,
    main,
    optimize_build_fonts,
)


def _create_synthetic_ttf(dest: Path, extra_chars: str) -> None:
    """Create a tiny valid TrueType font without storing binary fixtures."""
    chars = sorted({" "} | set("ABCあいう漢字✅") | set(extra_chars))
    glyph_names = [".notdef"] + [f"u{ord(c):04X}" for c in chars]
    cmap = {ord(c): f"u{ord(c):04X}" for c in chars}

    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(glyph_names)
    fb.setupCharacterMap(cmap)
    pen = TTGlyphPen(None)
    pen.moveTo((50, 0))
    pen.lineTo((50, 700))
    pen.lineTo((450, 700))
    pen.lineTo((450, 0))
    pen.closePath()
    empty = pen.glyph()
    fb.setupGlyf({name: empty for name in glyph_names})
    metrics = {name: (500, 50) for name in glyph_names}
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "TestFont", "styleName": "Regular"})
    fb.setupOS2()
    fb.setupPost()
    dest.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(dest))


class OptimizeWebFontsTest(unittest.TestCase):
    def test_jis_x_0208_covers_level1_and_level2_kanji_and_kana(self) -> None:
        jis = jis_x_0208_codepoints()
        self.assertGreater(len(jis), 6000)
        for sample in ("自", "分", "株", "式", "会", "社", "薔", "薇", "あ", "ア"):
            self.assertIn(ord(sample), jis)

    def test_repo_codepoint_scan_ignores_bundled_fonts_and_preserves_ui_text(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir()
            (root / "web" / "assets" / "fonts").mkdir(parents=True)
            (root / "lib" / "sample.dart").write_text("final title = '今日やる1件 🚀';", encoding="utf-8")
            (root / "web" / "llms.txt").write_text("# 自分株式会社\n", encoding="utf-8")
            (root / "web" / "assets" / "fonts" / "fake.txt").write_text("龍", encoding="utf-8")

            repo_cps = collect_repo_codepoints(root)
            self.assertIn(ord("今"), repo_cps)
            self.assertIn(ord("🚀"), repo_cps)
            self.assertNotIn(ord("龍"), repo_cps)

            jp_cps = build_japanese_codepoints(repo_cps)
            self.assertIn(ord("株"), jp_cps)
            self.assertIn(ord("A"), jp_cps)

            emoji_cps = build_emoji_codepoints(repo_cps)
            self.assertIn(ord("🚀"), emoji_cps)
            for ch in "✅❌⚠️":
                self.assertIn(ord(ch), emoji_cps)
            self.assertNotIn(ord("株"), emoji_cps)

    def test_optimize_build_fonts_subsets_atomically_and_writes_json_report(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir()
            (root / "lib" / "app.dart").write_text("const s = 'あいうABC';", encoding="utf-8")
            build_dir = root / "build" / "web"
            fonts_dir = build_dir / "assets" / "web" / "assets" / "fonts"

            extra_unused = "".join(chr(cp) for cp in range(0x2F800, 0x2F840))
            _create_synthetic_ttf(fonts_dir / "NotoSansJP-Regular.ttf", extra_chars=extra_unused)
            _create_synthetic_ttf(fonts_dir / "NotoColorEmoji.ttf", extra_chars=CORE_UI_EMOJI + "𠮷")

            report_path = root / "report.json"
            exit_code = main(
                [
                    "--build-dir",
                    str(build_dir),
                    "--repo-root",
                    str(root),
                    "--require-fonts",
                    "--json-report",
                    str(report_path),
                ]
            )
            self.assertEqual(exit_code, 0)
            self.assertTrue(report_path.is_file())
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(len(report), 2)
            self.assertFalse(report[0]["skipped"])
            self.assertLessEqual(report[0]["raw_after"], report[0]["raw_before"])

    def test_require_fonts_raises_when_font_missing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with self.assertRaises(FileNotFoundError):
                optimize_build_fonts(root / "missing", root, require_fonts=True)


if __name__ == "__main__":
    unittest.main()
