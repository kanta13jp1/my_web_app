"""Generate intro/outro PNG cards for the NotebookLM video pipeline (Win版#132 part 33).

Used by .github/workflows/notebooklm-video-pipeline.yml Step 4.

Renders two 1280x720 PNGs in `<output_dir>/intro.png` and `<output_dir>/outro.png`
matching the Orange+Indigo dark theme from docs/DESIGN.md and the bg color
(#0F111E) used by Step 5 ffmpeg pad. Fonts: Noto Sans CJK JP with sane
fallbacks for Linux CI (fonts-noto-cjk) and Windows local dev.

Env vars:
    CARD_TITLE   — Intro title (required). Wrapped to ~14 chars per line.
    CARD_SERIES  — Series tag, e.g. '#3' (default '').
    CARD_OUTRO   — Outro headline (default '視聴ありがとうございました').
    CARD_BRAND   — Bottom-right brand link (default 'my-web-app-b67f4.web.app').
    NOTO_SANS_FONT — Path to a CJK-capable .ttf/.otf/.ttc to force-use.

Usage:
    CARD_TITLE='Nomic Platform' CARD_SERIES='#3' python scripts/video/make_cards.py
    python scripts/video/make_cards.py --output-dir /tmp/cards
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CANVAS_W = 1280
CANVAS_H = 720
BG = (15, 17, 30)
TEXT = (255, 255, 255)
TEXT_DIM = (176, 176, 176)
ACCENT_ORANGE = (255, 107, 53)
ACCENT_INDIGO = (121, 134, 203)

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    "C:/Windows/Fonts/NotoSansJP-VF.ttf",
    "C:/Windows/Fonts/YuGothB.ttc",
    "C:/Windows/Fonts/YuGothM.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
]


def find_font_path() -> str:
    override = os.environ.get("NOTO_SANS_FONT", "").strip()
    if override:
        if Path(override).exists():
            return override
        sys.exit(f"NOTO_SANS_FONT not found: {override}")
    for c in FONT_CANDIDATES:
        if Path(c).exists():
            return c
    sys.exit(
        "no CJK-capable font found. Install fonts-noto-cjk on Linux or set "
        "NOTO_SANS_FONT to a .ttf/.otf/.ttc path."
    )


def load_font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size=size)
    except OSError as e:
        sys.exit(f"failed to load font {path} at size {size}: {e}")


def text_size(draw: ImageDraw.ImageDraw, s: str, font: ImageFont.FreeTypeFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), s, font=font)
    return box[2] - box[0], box[3] - box[1]


def wrap_title(title: str, max_chars: int = 14) -> list[str]:
    """Greedy wrap on character count — appropriate for CJK where 1 char ≈ 1 cell."""
    if len(title) <= max_chars:
        return [title]
    lines: list[str] = []
    cur = ""
    for ch in title:
        if len(cur) >= max_chars and ch != " ":
            lines.append(cur.rstrip())
            cur = ""
        cur += ch
    if cur:
        lines.append(cur.rstrip())
    return lines[:3]


def draw_intro(out_path: Path, title: str, series: str, font_path: str) -> None:
    img = Image.new("RGB", (CANVAS_W, CANVAS_H), BG)
    draw = ImageDraw.Draw(img)

    badge_font = load_font(font_path, 28)
    title_font = load_font(font_path, 80)
    series_font = load_font(font_path, 56)

    badge = "自分株式会社 AI大学"
    draw.text((64, 56), badge, font=badge_font, fill=ACCENT_INDIGO)

    accent_y = 56 + 28 + 12
    draw.rectangle((64, accent_y, 64 + 80, accent_y + 4), fill=ACCENT_ORANGE)

    lines = wrap_title(title)
    line_h = 96
    total_h = line_h * len(lines)
    start_y = (CANVAS_H - total_h) // 2

    for i, line in enumerate(lines):
        w, _ = text_size(draw, line, title_font)
        x = (CANVAS_W - w) // 2
        y = start_y + i * line_h
        draw.text((x, y), line, font=title_font, fill=TEXT)

    if series:
        sw, sh = text_size(draw, series, series_font)
        sx = CANVAS_W - sw - 64
        sy = CANVAS_H - sh - 56
        draw.text((sx, sy), series, font=series_font, fill=ACCENT_ORANGE)

    img.save(out_path, "PNG", optimize=True)


def draw_outro(out_path: Path, headline: str, brand: str, series: str, font_path: str) -> None:
    img = Image.new("RGB", (CANVAS_W, CANVAS_H), BG)
    draw = ImageDraw.Draw(img)

    headline_font = load_font(font_path, 64)
    brand_font = load_font(font_path, 32)
    series_font = load_font(font_path, 40)

    hw, hh = text_size(draw, headline, headline_font)
    hx = (CANVAS_W - hw) // 2
    hy = (CANVAS_H - hh) // 2 - 40
    draw.text((hx, hy), headline, font=headline_font, fill=TEXT)

    accent_y = hy + hh + 24
    draw.rectangle(((CANVAS_W - 120) // 2, accent_y, (CANVAS_W + 120) // 2, accent_y + 4), fill=ACCENT_ORANGE)

    bw, bh = text_size(draw, brand, brand_font)
    bx = (CANVAS_W - bw) // 2
    by = accent_y + 32
    draw.text((bx, by), brand, font=brand_font, fill=ACCENT_INDIGO)

    if series:
        sw, sh = text_size(draw, series, series_font)
        sx = CANVAS_W - sw - 64
        sy = CANVAS_H - sh - 56
        draw.text((sx, sy), series, font=series_font, fill=TEXT_DIM)

    img.save(out_path, "PNG", optimize=True)


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate intro/outro PNG cards for the video pipeline")
    ap.add_argument("--output-dir", type=Path, default=Path("videos"),
                    help="Directory to write intro.png and outro.png (default: videos)")
    args = ap.parse_args()

    title = os.environ.get("CARD_TITLE", "").strip()
    if not title:
        sys.exit("CARD_TITLE env var is required")
    series = os.environ.get("CARD_SERIES", "").strip()
    outro_headline = os.environ.get("CARD_OUTRO", "視聴ありがとうございました")
    brand = os.environ.get("CARD_BRAND", "my-web-app-b67f4.web.app")

    font_path = find_font_path()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    intro_path = args.output_dir / "intro.png"
    outro_path = args.output_dir / "outro.png"
    draw_intro(intro_path, title, series, font_path)
    draw_outro(outro_path, outro_headline, brand, series, font_path)

    print(f"wrote {intro_path} ({intro_path.stat().st_size // 1024} KB)")
    print(f"wrote {outro_path} ({outro_path.stat().st_size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
