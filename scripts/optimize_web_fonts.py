#!/usr/bin/env python3
"""Subset bundled Flutter Web fonts (NotoSansJP & NotoColorEmoji) cleanly.

Reduces initial cold-load transfer bloat while retaining 100% of:
- All characters occurring across `lib/**/*.dart` and `web/**/*.{html,json,txt,md}`
- Complete JIS X 0208 Level 1 + Level 2 Kanji/symbols (deterministic EUC-JP enumeration)
- Complete ASCII, Latin-1 Supplement, General Punctuation/Currency/Arrows/Math/Symbols,
  Hiragana, Katakana, and Halfwidth/Fullwidth Forms
- Active UI/content emoji + core status/reaction emoji in `NotoColorEmoji.ttf`

Preserves SFNT TTF outline format and keeps `FontManifest.json` entries intact so both
Flutter CanvasKit and `structured_tab_pdf_service.dart` work identically.
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import gzip
import json
import os
from pathlib import Path
import sys
from typing import Iterable, Sequence

from fontTools import subset
from fontTools.ttLib import TTFont


REPO_TEXT_EXTENSIONS = frozenset({".dart", ".html", ".json", ".txt", ".md"})
UNICODE_BLOCKS: tuple[tuple[int, int], ...] = (
    (0x0020, 0x007E),  # Basic Latin
    (0x00A0, 0x00FF),  # Latin-1 Supplement
    (0x2000, 0x206F),  # General Punctuation
    (0x20A0, 0x20CF),  # Currency Symbols
    (0x2190, 0x21FF),  # Arrows
    (0x25A0, 0x26FF),  # Geometric Shapes & Misc Symbols
    (0x3000, 0x303F),  # CJK Symbols and Punctuation
    (0x3040, 0x309F),  # Hiragana
    (0x30A0, 0x30FF),  # Katakana
    (0xFF00, 0xFFEF),  # Halfwidth and Fullwidth Forms
)
CORE_UI_EMOJI = (
    "✅❌⚠️⚡🔥🎯✨🚀💡📌📋🔍🎉🔒🔓💳📱💻⭐❤👍🙌👇👆👉🔗📊📈📉🕒📅💬🛠🌐🧠"
)


@dataclass(frozen=True)
class FontOptimizationResult:
    font_name: str
    path: str
    raw_before: int
    raw_after: int
    gzip_before: int
    gzip_after: int
    glyphs_after: int
    cmap_after: int
    skipped: bool = False


def collect_repo_codepoints(repo_root: Path) -> set[int]:
    """Scan `lib/` and `web/` (excluding bundled fonts) for used codepoints."""
    codepoints: set[int] = set()
    fonts_dir = (repo_root / "web" / "assets" / "fonts").resolve()
    for base_name in ("lib", "web"):
        base_dir = repo_root / base_name
        if not base_dir.is_dir():
            continue
        for file_path in base_dir.rglob("*"):
            if not file_path.is_file():
                continue
            if file_path.suffix.lower() not in REPO_TEXT_EXTENSIONS:
                continue
            resolved = file_path.resolve()
            if resolved == fonts_dir or fonts_dir in resolved.parents:
                continue
            text = file_path.read_text(encoding="utf-8", errors="replace")
            for ch in text:
                cp = ord(ch)
                if cp >= 0x20 and not (0xD800 <= cp <= 0xDFFF):
                    codepoints.add(cp)
    return codepoints


def jis_x_0208_codepoints() -> set[int]:
    """Return Unicode codepoints for all JIS X 0208 Level 1 & Level 2 characters."""
    cps: set[int] = set()
    for b1 in range(0xA1, 0xFF):
        for b2 in range(0xA1, 0xFF):
            try:
                ch = bytes((b1, b2)).decode("euc_jp")
            except UnicodeDecodeError:
                continue
            if len(ch) == 1:
                cps.add(ord(ch))
    return cps


def build_japanese_codepoints(repo_codepoints: Iterable[int]) -> set[int]:
    """Build complete Japanese + repo UI codepoint set."""
    cps = set(jis_x_0208_codepoints())
    for start, end in UNICODE_BLOCKS:
        cps.update(range(start, end + 1))
    for cp in repo_codepoints:
        if cp >= 0x20 and not (0xD800 <= cp <= 0xDFFF):
            cps.add(cp)
    return cps


def build_emoji_codepoints(repo_codepoints: Iterable[int]) -> set[int]:
    """Build emoji subset codepoints from repo usage + core status/action emoji."""
    cps = {
        cp
        for cp in repo_codepoints
        if cp >= 0x2000
        and not (0x3000 <= cp <= 0x9FFF)
        and not (0xF900 <= cp <= 0xFAFF)
        and not (0xFF00 <= cp <= 0xFFEF)
    }
    for ch in CORE_UI_EMOJI + "0123456789#*":
        cps.add(ord(ch))
    cps.update((0xFE0F, 0x200D, 0x20E3))
    return cps


def subset_font_file(
    font_path: Path,
    unicodes: set[int],
    drop_tables: Sequence[str],
    dry_run: bool = False,
) -> FontOptimizationResult:
    """Subset a single SFNT TTF font atomically in place (unless `dry_run`)."""
    raw_before_bytes = font_path.read_bytes()
    gz_before = len(gzip.compress(raw_before_bytes))

    opts = subset.Options()
    opts.drop_tables += list(drop_tables)
    font = subset.load_font(str(font_path), opts)
    tmp_path = font_path.with_suffix(".subset.tmp")
    try:
        subsetter = subset.Subsetter(opts)
        subsetter.populate(unicodes=unicodes)
        subsetter.subset(font)
        subset.save_font(font, str(tmp_path), opts)
    finally:
        font.close()

    raw_after_bytes = tmp_path.read_bytes()
    gz_after = len(gzip.compress(raw_after_bytes))
    verified = TTFont(tmp_path)
    try:
        glyphs_after = int(verified["maxp"].numGlyphs)
        cmap_after = len(verified.getBestCmap() or {})
    finally:
        verified.close()

    if dry_run:
        tmp_path.unlink(missing_ok=True)
    else:
        os.replace(tmp_path, font_path)

    return FontOptimizationResult(
        font_name=font_path.name,
        path=str(font_path),
        raw_before=len(raw_before_bytes),
        raw_after=len(raw_after_bytes),
        gzip_before=gz_before,
        gzip_after=gz_after,
        glyphs_after=glyphs_after,
        cmap_after=cmap_after,
    )


def optimize_build_fonts(
    build_dir: Path,
    repo_root: Path,
    dry_run: bool = False,
    require_fonts: bool = False,
) -> list[FontOptimizationResult]:
    """Optimize bundled NotoSansJP and NotoColorEmoji inside `build_dir`."""
    fonts_dir = build_dir / "assets" / "web" / "assets" / "fonts"
    repo_cps = collect_repo_codepoints(repo_root)
    targets: tuple[tuple[str, set[int], tuple[str, ...]], ...] = (
        ("NotoSansJP-Regular.ttf", build_japanese_codepoints(repo_cps), ("VORG", "vhea", "vmtx")),
        ("NotoColorEmoji.ttf", build_emoji_codepoints(repo_cps), ("vhea", "vmtx")),
    )
    results: list[FontOptimizationResult] = []
    for filename, cps, drop_tables in targets:
        target_path = fonts_dir / filename
        if not target_path.is_file():
            if require_fonts:
                raise FileNotFoundError(f"Expected bundled font missing: {target_path}")
            results.append(
                FontOptimizationResult(
                    font_name=filename,
                    path=str(target_path),
                    raw_before=0,
                    raw_after=0,
                    gzip_before=0,
                    gzip_after=0,
                    glyphs_after=0,
                    cmap_after=0,
                    skipped=True,
                )
            )
            continue
        results.append(
            subset_font_file(
                font_path=target_path,
                unicodes=cps,
                drop_tables=drop_tables,
                dry_run=dry_run,
            )
        )
    return results


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Subset Flutter Web bundled NotoSansJP & NotoColorEmoji fonts."
    )
    parser.add_argument(
        "--build-dir",
        type=Path,
        default=Path("build/web"),
        help="Flutter Web build output directory (default: build/web).",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path("."),
        help="Repository root to scan lib/ and web/ text codepoints.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Compute subsetted sizes without overwriting target font files.",
    )
    parser.add_argument(
        "--require-fonts",
        action="store_true",
        help="Fail with non-zero exit code if either target font is missing.",
    )
    parser.add_argument(
        "--json-report",
        type=Path,
        help="Optional path to write JSON optimization summary.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    results = optimize_build_fonts(
        build_dir=args.build_dir,
        repo_root=args.repo_root,
        dry_run=args.dry_run,
        require_fonts=args.require_fonts,
    )
    for res in results:
        if res.skipped:
            print(f"SKIP: {res.font_name} not present at {res.path}")
            continue
        raw_pct = 100.0 * (1.0 - (res.raw_after / max(res.raw_before, 1)))
        gz_pct = 100.0 * (1.0 - (res.gzip_after / max(res.gzip_before, 1)))
        print(
            f"OPTIMIZED {res.font_name}: "
            f"raw {res.raw_before:,} -> {res.raw_after:,} B (-{raw_pct:.1f}%) | "
            f"gzip {res.gzip_before:,} -> {res.gzip_after:,} B (-{gz_pct:.1f}%) | "
            f"glyphs={res.glyphs_after} cmap={res.cmap_after}"
        )

    if args.json_report is not None:
        args.json_report.parent.mkdir(parents=True, exist_ok=True)
        args.json_report.write_text(
            json.dumps([asdict(r) for r in results], ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
