#!/usr/bin/env python3
"""Tests for the deterministic OGP and X-post card generator."""

from __future__ import annotations

import inspect
import struct
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from scripts import generate_ogp_cards


FORBIDDEN_COPY_FRAGMENTS = (
    "草礎",
    "遂捗",
    "Levl",
    "マイメモ",
    "総登録者",
    "v1.0.",
    "5分だけ無料で試す",
)


class GenerateOgpCardsTest(unittest.TestCase):
    def test_generates_all_expected_pngs_with_exact_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            out_dir = Path(temp_dir)
            generated = generate_ogp_cards.generate_all_cards(out_dir)

            self.assertEqual(
                len(generated),
                len(generate_ogp_cards.GENERATED_OGP_FILES),
            )
            errors = generate_ogp_cards.verify_output_dir(out_dir)
            self.assertEqual(errors, [])

            for name, expected_size in generate_ogp_cards.GENERATED_OGP_FILES.items():
                path = out_dir / name
                raw = path.read_bytes()
                self.assertEqual(raw[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(
                    struct.unpack(">II", raw[16:24]),
                    expected_size,
                )
                self.assertLess(
                    len(raw),
                    450_000,
                    f"{name} should remain lightweight for social crawlers",
                )
                with Image.open(path) as img:
                    extrema = img.convert("RGB").getextrema()
                    # Ensure image is non-flat (real contrast across RGB channels).
                    self.assertTrue(
                        any(hi - lo > 120 for lo, hi in extrema),
                        f"{name} appears unexpectedly flat: {extrema}",
                    )
                    # Check dark navy background near bottom-left safe area.
                    pixel = img.getpixel((10, expected_size[1] - 10))
                    self.assertLess(pixel[0], 45)
                    self.assertLess(pixel[1], 60)
                    self.assertLess(pixel[2], 90)

    def test_legacy_ogp_matches_refreshed_lp_card(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            out_dir = Path(temp_dir)
            generate_ogp_cards.generate_all_cards(out_dir)
            self.assertEqual(
                (out_dir / "ogp.png").read_bytes(),
                (out_dir / "ogp-lp-v2.png").read_bytes(),
            )

    def test_card_copy_excludes_legacy_typos_and_dev_jargon(self) -> None:
        source = inspect.getsource(generate_ogp_cards)
        for fragment in FORBIDDEN_COPY_FRAGMENTS:
            self.assertNotIn(fragment, source)

    def test_custom_feature_update_card_renders_clean_png(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            target = Path(temp_dir) / "custom-x.png"
            generate_ogp_cards.render_feature_update_card(
                target,
                title="テスト用アップデート",
                before_items=("旧操作1", "旧操作2", "旧操作3"),
                after_items=("新操作1", "新操作2", "新操作3"),
            )
            self.assertTrue(target.is_file())
            with Image.open(target) as img:
                self.assertEqual(img.size, generate_ogp_cards.X_CARD_SIZE)


if __name__ == "__main__":
    unittest.main()
