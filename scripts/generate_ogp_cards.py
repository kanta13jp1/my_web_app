#!/usr/bin/env python3
"""Deterministic OGP and X-post card generator for 自分株式会社.

Renders high-DPI (2x supersampled + LANCZOS downsampled) brand-unified PNG cards
matching the production Flutter landing palette (#07111E navy, #F0E5D0 cream
gold, #EF8E67 warm coral) using Pillow and locally available/bundled CJK fonts.
No external image API calls or build-time network requests are required.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import sys
from typing import Callable, Sequence

from PIL import Image, ImageDraw, ImageFilter, ImageFont


REPO_ROOT = Path(__file__).resolve().parents[1]

# Canonical output filenames produced into --output-dir (e.g. build/web).
OGP_SIZE = (1200, 630)
X_CARD_SIZE = (1200, 675)

GENERATED_OGP_FILES: dict[str, tuple[int, int]] = {
    "ogp-lp-v2.png": OGP_SIZE,
    "ogp.png": OGP_SIZE,
    "ogp-ai-university-v2.png": OGP_SIZE,
    "ogp-competitors-v2.png": OGP_SIZE,
    "ogp-philosophy-v2.png": OGP_SIZE,
    "ogp-growth-v2.png": OGP_SIZE,
    "x-card-feature-update-v2.png": X_CARD_SIZE,
}

# Brand palette aligned with lib/widgets/landing_page_content.dart.
BG_TOP = (7, 17, 30)
BG_BOTTOM = (13, 30, 53)
CREAM_GOLD = (240, 229, 208)
TEXT_PRIMARY = (248, 245, 238)
TEXT_SECONDARY = (206, 217, 232)
TEXT_MUTED = (158, 176, 198)
CORAL = (239, 142, 103)
MINT = (52, 211, 153)
MINT_SOFT = (167, 243, 208)
SKY_ACCENT = (96, 165, 250)
ROSE_MUTED = (248, 113, 113)
ROSE_SOFT = (254, 202, 202)
DARK_INK = (16, 26, 36)

BOLD_FONT_CANDIDATES = (
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansJP-Bold.otf",
    "C:/Windows/Fonts/YuGothB.ttc",
    "C:/Windows/Fonts/BIZ-UDGothicB.ttc",
    "C:/Windows/Fonts/meiryob.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
    str(REPO_ROOT / "web/assets/fonts/NotoSansJP-Regular.ttf"),
)

REGULAR_FONT_CANDIDATES = (
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansJP-Regular.otf",
    "C:/Windows/Fonts/YuGothM.ttc",
    "C:/Windows/Fonts/BIZ-UDGothicR.ttc",
    "C:/Windows/Fonts/meiryo.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
    str(REPO_ROOT / "web/assets/fonts/NotoSansJP-Regular.ttf"),
)


@dataclass(frozen=True)
class FontResolver:
    bold_path: str
    regular_path: str
    bold_is_fallback_regular: bool

    def font(self, weight: str, size: int) -> ImageFont.FreeTypeFont:
        path = self.bold_path if weight == "bold" else self.regular_path
        return ImageFont.truetype(path, size=size)

    def stroke_for(self, weight: str) -> int:
        if weight == "bold" and self.bold_is_fallback_regular:
            return 2
        return 0


class LayerPainter:
    """Alpha-safe vector/text painter over an opaque RGBA base canvas.

    Pillow's ImageDraw overwrites destination alpha when drawing translucent RGBA
    colors directly onto an image, which turns translucent fills opaque when
    converting to RGB. LayerPainter composites every translucent shape onto the
    backing canvas via local alpha_composite patches so glass layers always
    render identically to CSS/Flutter opacity.
    """

    def __init__(self, canvas: Image.Image) -> None:
        self.canvas = canvas
        self.draw = ImageDraw.Draw(canvas, "RGBA")

    def alpha_patch(
        self,
        box: tuple[int, int, int, int],
        pad: int,
        paint_fn: Callable[[ImageDraw.ImageDraw, tuple[int, int, int, int]], None],
    ) -> None:
        x0, y0, x1, y1 = box
        px0 = max(0, x0 - pad)
        py0 = max(0, y0 - pad)
        px1 = min(self.canvas.width, x1 + pad)
        py1 = min(self.canvas.height, y1 + pad)
        pw = max(1, px1 - px0)
        ph = max(1, py1 - py0)
        patch = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        p_draw = ImageDraw.Draw(patch, "RGBA")
        local_box = (x0 - px0, y0 - py0, x1 - px0, y1 - py0)
        paint_fn(p_draw, local_box)
        self.canvas.alpha_composite(patch, dest=(px0, py0))

    def rounded_rect(
        self,
        box: tuple[int, int, int, int],
        *,
        radius: int,
        fill: tuple[int, int, int, int] | None = None,
        outline: tuple[int, int, int, int] | None = None,
        width: int = 2,
    ) -> None:
        def _paint(d: ImageDraw.ImageDraw, lb: tuple[int, int, int, int]) -> None:
            d.rounded_rectangle(lb, radius=radius, fill=fill, outline=outline, width=width)

        self.alpha_patch(box, pad=width + 2, paint_fn=_paint)

    def ellipse(
        self,
        box: tuple[int, int, int, int],
        *,
        fill: tuple[int, int, int, int] | None = None,
        outline: tuple[int, int, int, int] | None = None,
        width: int = 1,
    ) -> None:
        def _paint(d: ImageDraw.ImageDraw, lb: tuple[int, int, int, int]) -> None:
            d.ellipse(lb, fill=fill, outline=outline, width=width)

        self.alpha_patch(box, pad=width + 2, paint_fn=_paint)

    def line(
        self,
        points: Sequence[tuple[int, int]],
        *,
        fill: tuple[int, int, int, int],
        width: int = 2,
    ) -> None:
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        box = (min(xs), min(ys), max(xs), max(ys))

        def _paint(d: ImageDraw.ImageDraw, _lb: tuple[int, int, int, int]) -> None:
            px0 = max(0, box[0] - width - 2)
            py0 = max(0, box[1] - width - 2)
            shifted = [(p[0] - px0, p[1] - py0) for p in points]
            d.line(shifted, fill=fill, width=width)

        self.alpha_patch(box, pad=width + 2, paint_fn=_paint)

    def text(
        self,
        xy: tuple[int, int],
        value: str,
        *,
        font: ImageFont.FreeTypeFont,
        fill: tuple[int, int, int],
        stroke_width: int = 0,
    ) -> None:
        self.draw.text(
            xy,
            value,
            font=font,
            fill=fill + (255,),
            stroke_width=stroke_width if stroke_width else 0,
            stroke_fill=fill + (255,) if stroke_width else None,
        )


def resolve_fonts() -> FontResolver:
    bold_path = next((p for p in BOLD_FONT_CANDIDATES if Path(p).is_file()), "")
    reg_path = next((p for p in REGULAR_FONT_CANDIDATES if Path(p).is_file()), "")
    if not bold_path and reg_path:
        bold_path = reg_path
    if not reg_path and bold_path:
        reg_path = bold_path
    if not bold_path or not reg_path:
        raise FileNotFoundError(
            "No CJK-capable font found. Install fonts-noto-cjk or bundle "
            "web/assets/fonts/NotoSansJP-Regular.ttf."
        )
    bold_is_fallback = Path(bold_path).name == "NotoSansJP-Regular.ttf"
    return FontResolver(
        bold_path=bold_path,
        regular_path=reg_path,
        bold_is_fallback_regular=bold_is_fallback,
    )


def _measure(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.FreeTypeFont,
) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1]


def _draw_fitted_line(
    painter: LayerPainter,
    xy: tuple[int, int],
    text: str,
    fonts: FontResolver,
    weight: str,
    start_size: int,
    max_width: int,
    fill: tuple[int, int, int],
    min_size: int = 24,
) -> tuple[int, int]:
    size = start_size
    font = fonts.font(weight, size)
    w, h = _measure(painter.draw, text, font)
    while w > max_width and size > min_size:
        size -= 2
        font = fonts.font(weight, size)
        w, h = _measure(painter.draw, text, font)
    painter.text(
        xy,
        text,
        font=font,
        fill=fill,
        stroke_width=fonts.stroke_for(weight),
    )
    return w, h


def _draw_fitted_multiline(
    painter: LayerPainter,
    x: int,
    y: int,
    lines: Sequence[str],
    fonts: FontResolver,
    weight: str,
    start_size: int,
    max_width: int,
    line_gap: int,
    fill: tuple[int, int, int],
    min_size: int = 24,
) -> int:
    size = start_size
    while size > min_size:
        font = fonts.font(weight, size)
        if all(_measure(painter.draw, line, font)[0] <= max_width for line in lines):
            break
        size -= 2
    font = fonts.font(weight, size)
    stroke = fonts.stroke_for(weight)
    cur_y = y
    for line in lines:
        painter.text((x, cur_y), line, font=font, fill=fill, stroke_width=stroke)
        _, h = _measure(painter.draw, line, font)
        cur_y += h + line_gap
    return cur_y - line_gap


def _create_base_canvas(
    width: int,
    height: int,
    bg_asset_name: str | None = None,
) -> Image.Image:
    """Create a 2x super-sampled RGBA navy canvas with subtle artwork and glow."""
    canvas = Image.new("RGBA", (width, height), BG_TOP + (255,))
    grad = Image.new("RGBA", (1, height))
    g_draw = ImageDraw.Draw(grad)
    for row in range(height):
        t = row / max(1, height - 1)
        r = int(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t)
        g_draw.point((0, row), fill=(r, g, b, 255))
    canvas.paste(grad.resize((width, height), Image.Resampling.BILINEAR), (0, 0))

    if bg_asset_name:
        asset_path = REPO_ROOT / "assets" / "landing_journey" / bg_asset_name
        if asset_path.is_file():
            with Image.open(asset_path) as raw:
                art = raw.convert("RGBA")
                scale = max(width / art.width, height / art.height)
                resized = art.resize(
                    (int(art.width * scale), int(art.height * scale)),
                    Image.Resampling.LANCZOS,
                )
                crop_x = max(0, (resized.width - width) // 2)
                crop_y = max(0, (resized.height - height) // 2)
                cropped = resized.crop((crop_x, crop_y, crop_x + width, crop_y + height))
                alpha = cropped.getchannel("A").point(lambda v: int(v * 0.28))
                cropped.putalpha(alpha)
                canvas = Image.alpha_composite(canvas, cropped)

    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        (int(width * 0.56), int(-height * 0.15), int(width * 1.05), int(height * 0.85)),
        fill=(239, 142, 103, 38),
    )
    glow_draw.ellipse(
        (int(-width * 0.10), int(height * 0.45), int(width * 0.42), int(height * 1.15)),
        fill=(59, 130, 246, 30),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=140))
    canvas = Image.alpha_composite(canvas, glow)

    scrim = Image.new("RGBA", (width, 1), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(scrim)
    for col in range(width):
        ratio = col / max(1, width - 1)
        alpha_val = int(220 * max(0.0, 1.0 - ratio * 1.32))
        s_draw.point((col, 0), fill=(BG_TOP[0], BG_TOP[1], BG_TOP[2], alpha_val))
    canvas = Image.alpha_composite(
        canvas,
        scrim.resize((width, height), Image.Resampling.BILINEAR),
    )

    dots = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d_draw = ImageDraw.Draw(dots)
    for gx in range(width - 420, width - 80, 36):
        for gy in range(72, 240, 36):
            d_draw.ellipse((gx - 2, gy - 2, gx + 2, gy + 2), fill=(240, 229, 208, 32))
    canvas = Image.alpha_composite(canvas, dots)
    return canvas


def _draw_brand_pill(
    painter: LayerPainter,
    x: int,
    y: int,
    label: str,
    fonts: FontResolver,
) -> int:
    font = fonts.font("bold", 30)
    tw, th = _measure(painter.draw, label, font)
    pad_x = 34
    pad_y = 16
    icon_w = 24
    gap = 16
    pill_w = pad_x * 2 + icon_w + gap + tw
    pill_h = pad_y * 2 + th
    painter.rounded_rect(
        (x, y, x + pill_w, y + pill_h),
        radius=pill_h // 2,
        fill=(240, 229, 208, 34),
        outline=(240, 229, 208, 138),
        width=3,
    )
    ix = x + pad_x
    iy = y + (pill_h - 26) // 2
    painter.rounded_rect((ix, iy, ix + 20, iy + 26), radius=10, fill=CORAL + (255,))
    painter.ellipse((ix + 4, iy + 4, ix + 14, iy + 14), fill=CREAM_GOLD + (255,))

    painter.text(
        (ix + icon_w + gap, y + pad_y - 3),
        label,
        font=font,
        fill=CREAM_GOLD,
        stroke_width=fonts.stroke_for("bold"),
    )
    return y + pill_h


def _draw_check_icon(
    painter: LayerPainter,
    cx: int,
    cy: int,
    radius: int,
    circle_fill: tuple[int, int, int, int],
    check_fill: tuple[int, int, int],
) -> None:
    painter.ellipse(
        (cx - radius, cy - radius, cx + radius, cy + radius),
        fill=circle_fill,
    )
    painter.draw.line(
        [
            (cx - int(radius * 0.45), cy + int(radius * 0.05)),
            (cx - int(radius * 0.12), cy + int(radius * 0.38)),
            (cx + int(radius * 0.48), cy - int(radius * 0.32)),
        ],
        fill=check_fill + (255,),
        width=max(4, radius // 4),
    )


def _draw_benefit_chips(
    painter: LayerPainter,
    x: int,
    y: int,
    labels: Sequence[str],
    fonts: FontResolver,
    max_row_width: int = 1240,
) -> None:
    font = fonts.font("bold", 28)
    stroke = fonts.stroke_for("bold")
    cur_x = x
    cur_y = y
    chip_h = 62
    for label in labels:
        tw, th = _measure(painter.draw, label, font)
        chip_w = 24 + 28 + 14 + tw + 28
        if cur_x > x and cur_x + chip_w > x + max_row_width:
            cur_x = x
            cur_y += chip_h + 18
        painter.rounded_rect(
            (cur_x, cur_y, cur_x + chip_w, cur_y + chip_h),
            radius=chip_h // 2,
            fill=(20, 39, 64, 218),
            outline=(240, 229, 208, 105),
            width=2,
        )
        _draw_check_icon(
            painter,
            cur_x + 34,
            cur_y + chip_h // 2,
            15,
            MINT + (245,),
            DARK_INK,
        )
        painter.text(
            (cur_x + 62, cur_y + (chip_h - th) // 2 - 3),
            label,
            font=font,
            fill=TEXT_PRIMARY,
            stroke_width=stroke,
        )
        cur_x += chip_w + 18


def _draw_glass_panel(
    painter: LayerPainter,
    box: tuple[int, int, int, int],
    radius: int = 36,
    fill: tuple[int, int, int, int] = (13, 27, 46, 236),
    outline: tuple[int, int, int, int] = (72, 106, 146, 205),
    width: int = 3,
) -> None:
    x0, y0, x1, y1 = box
    painter.rounded_rect(
        (x0 + 8, y0 + 16, x1 + 8, y1 + 16),
        radius=radius,
        fill=(2, 6, 14, 150),
        width=0,
    )
    painter.rounded_rect(
        (x0, y0, x1, y1),
        radius=radius,
        fill=fill,
        outline=outline,
        width=width,
    )
    painter.line(
        [(x0 + radius, y0 + 2), (x1 - radius, y0 + 2)],
        fill=(240, 229, 208, 92),
        width=2,
    )


def _draw_arrow_down(
    painter: LayerPainter,
    cx: int,
    y0: int,
    y1: int,
    color: tuple[int, int, int],
) -> None:
    painter.draw.line([(cx, y0), (cx, y1 - 10)], fill=color + (255,), width=6)
    painter.draw.polygon(
        [(cx - 14, y1 - 16), (cx + 14, y1 - 16), (cx, y1 + 4)],
        fill=color + (255,),
    )


def _draw_arrow_right(
    painter: LayerPainter,
    x0: int,
    x1: int,
    cy: int,
    color: tuple[int, int, int],
) -> None:
    painter.draw.line([(x0, cy), (x1 - 10, cy)], fill=color + (255,), width=8)
    painter.draw.polygon(
        [(x1 - 22, cy - 18), (x1 - 22, cy + 18), (x1 + 4, cy)],
        fill=color + (255,),
    )


def _finalize(canvas: Image.Image, target_size: tuple[int, int], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    downsampled = canvas.convert("RGB").resize(target_size, Image.Resampling.LANCZOS)
    downsampled.save(out_path, format="PNG", optimize=True)


def _render_standard_ogp(
    *,
    fonts: FontResolver,
    bg_asset: str,
    pill: str,
    headline: Sequence[str],
    subcopy: Sequence[str],
    chips: Sequence[str],
    render_right_card: Callable[[LayerPainter, tuple[int, int, int, int], FontResolver], None],
    out_path: Path,
) -> None:
    # 2x supersampled canvas: 2400x1260 -> 1200x630.
    # Safe zone: keep key elements above y=1032 (516px @ 1x) so X's bottom-left
    # title badge never overlaps text or product cards.
    w, h = 2400, 1260
    canvas = _create_base_canvas(w, h, bg_asset)
    painter = LayerPainter(canvas)

    left_x = 128
    left_max_w = 1200

    next_y = _draw_brand_pill(painter, left_x, 124, pill, fonts)
    next_y = _draw_fitted_multiline(
        painter,
        left_x,
        next_y + 46,
        headline,
        fonts,
        "bold",
        start_size=122,
        max_width=left_max_w,
        line_gap=20,
        fill=TEXT_PRIMARY,
    )
    next_y = _draw_fitted_multiline(
        painter,
        left_x,
        next_y + 42,
        subcopy,
        fonts,
        "regular",
        start_size=44,
        max_width=left_max_w,
        line_gap=14,
        fill=TEXT_SECONDARY,
    )
    _draw_benefit_chips(
        painter,
        left_x,
        max(next_y + 52, 780),
        chips,
        fonts,
        max_row_width=1240,
    )

    render_right_card(painter, (1400, 124, 2272, 996), fonts)

    _finalize(canvas, OGP_SIZE, out_path)


def _right_card_lp(
    painter: LayerPainter,
    box: tuple[int, int, int, int],
    fonts: FontResolver,
) -> None:
    x0, y0, x1, y1 = box
    _draw_glass_panel(painter, box, radius=40)
    pad = 44
    ix = x0 + pad
    iw = (x1 - x0) - pad * 2

    _draw_fitted_line(
        painter, (ix, y0 + 40), "悩み入力（登録不要）", fonts, "bold", 30, iw, TEXT_MUTED
    )
    painter.rounded_rect(
        (ix, y0 + 94, x1 - pad, y0 + 240),
        radius=24,
        fill=(22, 43, 70, 232),
        outline=(86, 118, 158, 185),
        width=2,
    )
    _draw_fitted_multiline(
        painter,
        ix + 28,
        y0 + 124,
        ("「予定や固定費が散らばって、", "　今日なにから始めるか迷う…」"),
        fonts,
        "regular",
        31,
        iw - 56,
        12,
        TEXT_PRIMARY,
    )

    mid_x = (x0 + x1) // 2
    _draw_arrow_down(painter, mid_x, y0 + 256, y0 + 362, CORAL)
    painter.rounded_rect(
        (mid_x - 180, y0 + 276, mid_x + 180, y0 + 334),
        radius=29,
        fill=(32, 34, 48, 240),
        outline=CORAL + (235,),
        width=2,
    )
    pill_font = fonts.font("bold", 26)
    pill_text = "AIが最優先を1件特定"
    ptw, pth = _measure(painter.draw, pill_text, pill_font)
    painter.text(
        (mid_x - ptw // 2, y0 + 276 + (58 - pth) // 2 - 2),
        pill_text,
        font=pill_font,
        fill=CORAL,
        stroke_width=fonts.stroke_for("bold"),
    )

    out_y0 = y0 + 382
    painter.rounded_rect(
        (ix, out_y0, x1 - pad, y1 - 40),
        radius=28,
        fill=(22, 46, 74, 245),
        outline=CREAM_GOLD + (190,),
        width=3,
    )
    painter.rounded_rect(
        (ix + 30, out_y0 + 32, ix + 242, out_y0 + 84),
        radius=26,
        fill=CREAM_GOLD + (255,),
    )
    _draw_fitted_line(
        painter, (ix + 54, out_y0 + 42), "今日やる 1 件", fonts, "bold", 26, 180, DARK_INK
    )
    painter.rounded_rect(
        (x1 - pad - 210, out_y0 + 32, x1 - pad - 30, out_y0 + 84),
        radius=26,
        fill=(18, 62, 68, 235),
        outline=MINT + (220,),
        width=2,
    )
    _draw_fitted_line(
        painter, (x1 - pad - 182, out_y0 + 42), "所要 10分", fonts, "bold", 26, 150, MINT_SOFT
    )

    _draw_fitted_multiline(
        painter,
        ix + 30,
        out_y0 + 112,
        ("止まっている案件を1件開き", "最初の連絡文を3行だけ書く"),
        fonts,
        "bold",
        40,
        iw - 60,
        14,
        TEXT_PRIMARY,
    )
    painter.line(
        [(ix + 30, out_y0 + 258), (x1 - pad - 30, out_y0 + 258)],
        fill=(240, 229, 208, 70),
        width=2,
    )
    _draw_fitted_multiline(
        painter,
        ix + 30,
        out_y0 + 284,
        ("理由：対象と最初の動作を1つに絞ると、", "先送りの迷いが消えて即着手できるため。"),
        fonts,
        "regular",
        30,
        iw - 60,
        12,
        TEXT_SECONDARY,
    )


def _right_card_ai_university(
    painter: LayerPainter,
    box: tuple[int, int, int, int],
    fonts: FontResolver,
) -> None:
    x0, y0, x1, y1 = box
    _draw_glass_panel(painter, box, radius=40)
    pad = 44
    ix = x0 + pad
    iw = (x1 - x0) - pad * 2

    _draw_fitted_line(
        painter, (ix, y0 + 40), "主要 AI プロバイダー学習", fonts, "bold", 34, iw, CREAM_GOLD
    )
    providers = [
        ("Google", "Gemini", (66, 133, 244)),
        ("OpenAI", "GPT / Codex", MINT),
        ("Anthropic", "Claude", CORAL),
        ("Meta", "Llama", SKY_ACCENT),
        ("xAI", "Grok", CREAM_GOLD),
        ("DeepSeek", "Open Models", (129, 140, 248)),
    ]
    col_gap = 24
    row_gap = 22
    tile_w = (iw - col_gap) // 2
    tile_h = 132
    grid_y = y0 + 112
    for idx, (name, sub, dot_color) in enumerate(providers):
        col = idx % 2
        row = idx // 2
        tx0 = ix + col * (tile_w + col_gap)
        ty0 = grid_y + row * (tile_h + row_gap)
        painter.rounded_rect(
            (tx0, ty0, tx0 + tile_w, ty0 + tile_h),
            radius=22,
            fill=(22, 43, 70, 235),
            outline=(78, 110, 148, 185),
            width=2,
        )
        painter.ellipse((tx0 + 24, ty0 + 34, tx0 + 48, ty0 + 58), fill=dot_color + (255,))
        _draw_fitted_line(
            painter, (tx0 + 64, ty0 + 24), name, fonts, "bold", 34, tile_w - 86, TEXT_PRIMARY
        )
        _draw_fitted_line(
            painter, (tx0 + 64, ty0 + 76), sub, fonts, "regular", 26, tile_w - 86, TEXT_MUTED
        )

    prog_y0 = grid_y + 3 * (tile_h + row_gap) + 16
    painter.rounded_rect(
        (ix, prog_y0, x1 - pad, y1 - 40),
        radius=26,
        fill=(22, 46, 74, 245),
        outline=MINT + (175,),
        width=2,
    )
    _draw_fitted_line(
        painter, (ix + 28, prog_y0 + 30), "理解度クイズ · 進捗 80%", fonts, "bold", 32, iw - 230, TEXT_PRIMARY
    )
    painter.rounded_rect(
        (x1 - pad - 182, prog_y0 + 24, x1 - pad - 24, prog_y0 + 76),
        radius=26,
        fill=MINT + (245,),
    )
    _draw_fitted_line(
        painter, (x1 - pad - 154, prog_y0 + 34), "レベル 3", fonts, "bold", 26, 120, DARK_INK
    )
    bar_x0, bar_y0, bar_x1, bar_y1 = ix + 28, prog_y0 + 100, x1 - pad - 28, prog_y0 + 128
    painter.rounded_rect((bar_x0, bar_y0, bar_x1, bar_y1), radius=14, fill=(40, 66, 98, 255))
    fill_x1 = bar_x0 + int((bar_x1 - bar_x0) * 0.80)
    painter.rounded_rect((bar_x0, bar_y0, fill_x1, bar_y1), radius=14, fill=MINT + (255,))
    _draw_fitted_line(
        painter, (ix + 28, prog_y0 + 150), "毎日1問から · 学習記録を自動保存", fonts, "regular", 26, iw - 56, TEXT_MUTED
    )


def _right_card_competitors(
    painter: LayerPainter,
    box: tuple[int, int, int, int],
    fonts: FontResolver,
) -> None:
    x0, y0, x1, y1 = box
    _draw_glass_panel(painter, box, radius=40)
    pad = 44
    ix = x0 + pad
    iw = (x1 - x0) - pad * 2

    _draw_fitted_line(
        painter, (ix, y0 + 40), "散らばった業務ツールを 1 つに", fonts, "bold", 34, iw, CREAM_GOLD
    )
    sources = [
        ("ノート・知識", "Notion / Evernote"),
        ("タスク・予定", "Todo / カレンダー"),
        ("家計・固定費", "MoneyForward"),
        ("AI 学習・対話", "複数AIの往復"),
    ]
    tile_w = (iw - 24) // 2
    tile_h = 148
    for idx, (title, sub) in enumerate(sources):
        col = idx % 2
        row = idx // 2
        tx0 = ix + col * (tile_w + 24)
        ty0 = y0 + 114 + row * (tile_h + 24)
        painter.rounded_rect(
            (tx0, ty0, tx0 + tile_w, ty0 + tile_h),
            radius=24,
            fill=(22, 43, 70, 232),
            outline=(78, 110, 148, 185),
            width=2,
        )
        _draw_fitted_line(
            painter, (tx0 + 26, ty0 + 30), title, fonts, "bold", 32, tile_w - 52, TEXT_PRIMARY
        )
        _draw_fitted_line(
            painter, (tx0 + 26, ty0 + 84), sub, fonts, "regular", 26, tile_w - 52, TEXT_MUTED
        )

    mid_x = (x0 + x1) // 2
    _draw_arrow_down(painter, mid_x, y0 + 456, y0 + 550, CORAL)

    hub_y0 = y0 + 566
    painter.rounded_rect(
        (ix, hub_y0, x1 - pad, y1 - 40),
        radius=30,
        fill=(22, 46, 74, 245),
        outline=CREAM_GOLD + (205,),
        width=3,
    )
    _draw_fitted_line(
        painter, (ix + 34, hub_y0 + 38), "自分株式会社 AI OS", fonts, "bold", 42, iw - 68, CREAM_GOLD
    )
    _draw_fitted_multiline(
        painter,
        ix + 34,
        hub_y0 + 110,
        ("174社との違いを比べながら、", "同じ画面で今日やる1件まで整理。"),
        fonts,
        "regular",
        30,
        iw - 68,
        12,
        TEXT_SECONDARY,
    )


def _right_card_philosophy(
    painter: LayerPainter,
    box: tuple[int, int, int, int],
    fonts: FontResolver,
) -> None:
    x0, y0, x1, y1 = box
    _draw_glass_panel(painter, box, radius=40)
    pad = 44
    ix = x0 + pad
    iw = (x1 - x0) - pad * 2

    _draw_fitted_line(
        painter, (ix, y0 + 40), "個人経営の基本構造 (P/L · B/S)", fonts, "bold", 34, iw, CREAM_GOLD
    )
    quads = [
        ("売上", "届けた価値", "仕事・学び・発信で", "人へ届けた成果", SKY_ACCENT),
        ("経費", "使った資源", "お金だけでなく時間と", "集中力・回復力", CORAL),
        ("資産", "積み上がる力", "スキル・健康・信用・", "再利用できる知識", MINT),
        ("利益", "次を選ぶ余白", "次の挑戦に使える", "お金・時間・心の余白", CREAM_GOLD),
    ]
    tile_w = (iw - 24) // 2
    tile_h = 290
    for idx, (label, sub, d1, d2, accent) in enumerate(quads):
        col = idx % 2
        row = idx // 2
        tx0 = ix + col * (tile_w + 24)
        ty0 = y0 + 114 + row * (tile_h + 24)
        painter.rounded_rect(
            (tx0, ty0, tx0 + tile_w, ty0 + tile_h),
            radius=26,
            fill=(22, 43, 70, 235),
            outline=accent + (175,),
            width=2,
        )
        painter.rounded_rect(
            (tx0 + 24, ty0 + 26, tx0 + 128, ty0 + 78),
            radius=26,
            fill=(accent[0], accent[1], accent[2], 46),
            outline=accent + (180,),
            width=2,
        )
        _draw_fitted_line(
            painter, (tx0 + 44, ty0 + 36), label, fonts, "bold", 30, 80, accent
        )
        _draw_fitted_line(
            painter, (tx0 + 144, ty0 + 36), sub, fonts, "bold", 28, tile_w - 166, TEXT_PRIMARY
        )
        _draw_fitted_multiline(
            painter,
            tx0 + 26,
            ty0 + 118,
            (d1, d2),
            fonts,
            "regular",
            28,
            tile_w - 52,
            12,
            TEXT_SECONDARY,
        )


def _right_card_growth(
    painter: LayerPainter,
    box: tuple[int, int, int, int],
    fonts: FontResolver,
) -> None:
    x0, y0, x1, y1 = box
    _draw_glass_panel(painter, box, radius=40)
    pad = 44
    ix = x0 + pad
    iw = (x1 - x0) - pad * 2

    _draw_fitted_line(
        painter, (ix, y0 + 40), "BUILD IN PUBLIC · 公開開発", fonts, "bold", 34, iw, CREAM_GOLD
    )
    items = [
        ("要望から毎日アップデート", "改善履歴・開発進捗をリアルタイム公開", MINT),
        ("開発ロードマップを共有", "これから作る機能と優先度を誰でも確認", SKY_ACCENT),
        ("紹介＆ストアで支援と還元", "Pro 月額1か月分クレジット特典つき", CORAL),
    ]
    row_h = 150
    for idx, (title, desc, accent) in enumerate(items):
        ry0 = y0 + 116 + idx * (row_h + 22)
        painter.rounded_rect(
            (ix, ry0, x1 - pad, ry0 + row_h),
            radius=24,
            fill=(22, 43, 70, 235),
            outline=accent + (165,),
            width=2,
        )
        _draw_check_icon(painter, ix + 44, ry0 + row_h // 2, 18, accent + (245,), DARK_INK)
        _draw_fitted_line(
            painter, (ix + 86, ry0 + 28), title, fonts, "bold", 34, iw - 110, TEXT_PRIMARY
        )
        _draw_fitted_line(
            painter, (ix + 86, ry0 + 84), desc, fonts, "regular", 27, iw - 110, TEXT_SECONDARY
        )

    chart_y0 = y0 + 636
    painter.rounded_rect(
        (ix, chart_y0, x1 - pad, y1 - 40),
        radius=24,
        fill=(22, 46, 74, 245),
        outline=CREAM_GOLD + (155,),
        width=2,
    )
    _draw_fitted_line(
        painter, (ix + 28, chart_y0 + 24), "毎日の積み上げが資産になる", fonts, "bold", 30, iw - 56, CREAM_GOLD
    )
    pts = [
        (ix + 34, y1 - 74),
        (ix + 160, y1 - 92),
        (ix + 300, y1 - 84),
        (ix + 440, y1 - 116),
        (ix + 580, y1 - 128),
        (x1 - pad - 44, y1 - 154),
    ]
    painter.draw.line(pts, fill=MINT + (255,), width=7)
    for px, py in pts:
        painter.ellipse((px - 8, py - 8, px + 8, py + 8), fill=CREAM_GOLD + (255,))


def render_feature_update_card(
    out_path: Path,
    fonts: FontResolver | None = None,
    *,
    badge: str = "自分株式会社 · 機能改善",
    title: str = "支払い忘れも、二重チェックもゼロへ。",
    subtitle: str = "毎月の「支払いリマインダー」がより安心して使えるようになりました",
    before_items: Sequence[str] = (
        "支払い済みでも通知が残ってしまう",
        "連続タップで二重に記録される不安",
        "エラー時に何を直せばよいか分かりづらい",
    ),
    after_items: Sequence[str] = (
        "今月支払い済みは自動で完了扱いに",
        "連打しても二重登録を自動でブロック",
        "見やすく押しやすい操作画面に改善",
    ),
    footer: str = "毎月の支出管理も「今日やる1件」も、登録なしで無料体験できます",
) -> None:
    """Render a 16:9 (1200x675) X-feed card with zero dev jargon or version IDs."""
    resolved_fonts = fonts or resolve_fonts()
    w, h = 2400, 1350
    canvas = _create_base_canvas(w, h, "02-unified.webp")
    painter = LayerPainter(canvas)

    margin_x = 120
    content_w = w - margin_x * 2

    pill_bottom = _draw_brand_pill(painter, margin_x, 88, badge, resolved_fonts)
    _, head_h = _draw_fitted_line(
        painter,
        (margin_x, pill_bottom + 34),
        title,
        resolved_fonts,
        "bold",
        start_size=90,
        max_width=content_w,
        fill=TEXT_PRIMARY,
    )
    _, sub_h = _draw_fitted_line(
        painter,
        (margin_x, pill_bottom + 34 + head_h + 22),
        subtitle,
        resolved_fonts,
        "regular",
        start_size=38,
        max_width=content_w,
        fill=TEXT_SECONDARY,
    )

    cards_y0 = pill_bottom + 34 + head_h + 22 + sub_h + 48
    cards_y1 = 1086
    card_w = 924
    left_card = (margin_x, cards_y0, margin_x + card_w, cards_y1)
    right_card = (w - margin_x - card_w, cards_y0, w - margin_x, cards_y1)

    # Before Card
    _draw_glass_panel(
        painter,
        left_card,
        radius=36,
        fill=(18, 28, 44, 232),
        outline=(118, 136, 162, 180),
        width=2,
    )
    painter.rounded_rect(
        (left_card[0] + 40, cards_y0 + 36, left_card[0] + 276, cards_y0 + 94),
        radius=29,
        fill=(248, 113, 113, 38),
        outline=ROSE_MUTED + (185,),
        width=2,
    )
    _draw_fitted_line(
        painter,
        (left_card[0] + 68, cards_y0 + 48),
        "これまでの悩み",
        resolved_fonts,
        "bold",
        28,
        195,
        ROSE_SOFT,
    )
    for idx, item in enumerate(before_items[:3]):
        iy = cards_y0 + 136 + idx * 148
        painter.rounded_rect(
            (left_card[0] + 40, iy, left_card[2] - 40, iy + 118),
            radius=22,
            fill=(28, 40, 58, 215),
            outline=(92, 108, 132, 115),
            width=2,
        )
        cx, cy = left_card[0] + 84, iy + 59
        painter.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), fill=(248, 113, 113, 46))
        painter.draw.line([(cx - 8, cy - 8), (cx + 8, cy + 8)], fill=ROSE_MUTED + (255,), width=5)
        painter.draw.line([(cx + 8, cy - 8), (cx - 8, cy + 8)], fill=ROSE_MUTED + (255,), width=5)
        _draw_fitted_line(
            painter,
            (left_card[0] + 124, iy + 40),
            item,
            resolved_fonts,
            "regular",
            32,
            card_w - 184,
            TEXT_SECONDARY,
        )

    # Center transition arrow
    arrow_cy = (cards_y0 + cards_y1) // 2
    _draw_arrow_right(painter, left_card[2] + 54, right_card[0] - 54, arrow_cy, CORAL)

    # After Card
    _draw_glass_panel(
        painter,
        right_card,
        radius=36,
        fill=(18, 42, 68, 244),
        outline=CREAM_GOLD + (210,),
        width=3,
    )
    painter.rounded_rect(
        (right_card[0] + 40, cards_y0 + 36, right_card[0] + 250, cards_y0 + 94),
        radius=29,
        fill=(18, 72, 68, 235),
        outline=MINT + (225,),
        width=2,
    )
    _draw_fitted_line(
        painter,
        (right_card[0] + 68, cards_y0 + 48),
        "改善後の体験",
        resolved_fonts,
        "bold",
        28,
        166,
        MINT_SOFT,
    )
    for idx, item in enumerate(after_items[:3]):
        iy = cards_y0 + 136 + idx * 148
        painter.rounded_rect(
            (right_card[0] + 40, iy, right_card[2] - 40, iy + 118),
            radius=22,
            fill=(20, 62, 74, 230),
            outline=MINT + (145,),
            width=2,
        )
        _draw_check_icon(
            painter,
            right_card[0] + 84,
            iy + 59,
            18,
            MINT + (245,),
            DARK_INK,
        )
        _draw_fitted_line(
            painter,
            (right_card[0] + 124, iy + 40),
            item,
            resolved_fonts,
            "bold",
            32,
            card_w - 184,
            TEXT_PRIMARY,
        )

    # Bottom Trust Bar
    footer_y0 = 1136
    painter.rounded_rect(
        (margin_x, footer_y0, w - margin_x, 1244),
        radius=26,
        fill=(26, 44, 68, 232),
        outline=CREAM_GOLD + (145,),
        width=2,
    )
    _draw_check_icon(painter, margin_x + 54, (footer_y0 + 1244) // 2, 16, MINT + (245,), DARK_INK)
    _draw_fitted_line(
        painter,
        (margin_x + 92, footer_y0 + 34),
        footer,
        resolved_fonts,
        "bold",
        34,
        content_w - 130,
        CREAM_GOLD,
    )

    _finalize(canvas, X_CARD_SIZE, out_path)


def generate_all_cards(output_dir: Path) -> list[Path]:
    fonts = resolve_fonts()
    output_dir.mkdir(parents=True, exist_ok=True)
    generated: list[Path] = []

    lp_path = output_dir / "ogp-lp-v2.png"
    _render_standard_ogp(
        fonts=fonts,
        bg_asset="04-action.webp",
        pill="自分株式会社 · PERSONAL AI OS",
        headline=("迷う毎日を、", "今日やる1件へ。"),
        subcopy=("予定・メモ・家計・学習をAIが整理", "登録前に1件、その場で体験できます"),
        chips=("登録なしで試せる", "カード不要", "基本無料"),
        render_right_card=_right_card_lp,
        out_path=lp_path,
    )
    generated.append(lp_path)

    legacy_ogp_path = output_dir / "ogp.png"
    legacy_ogp_path.write_bytes(lp_path.read_bytes())
    generated.append(legacy_ogp_path)

    ai_uni_path = output_dir / "ogp-ai-university-v2.png"
    _render_standard_ogp(
        fonts=fonts,
        bg_asset="03-prioritized.webp",
        pill="自分株式会社 · AI大学",
        headline=("主要AI 250社を、", "体系的に学ぶ。"),
        subcopy=("Google・OpenAI・Anthropic から最新まで", "実務への活かし方を毎日キャッチアップ"),
        chips=("1日3分クイズ", "学習記録＆バッジ", "完全無料"),
        render_right_card=_right_card_ai_university,
        out_path=ai_uni_path,
    )
    generated.append(ai_uni_path)

    comp_path = output_dir / "ogp-competitors-v2.png"
    _render_standard_ogp(
        fonts=fonts,
        bg_asset="02-unified.webp",
        pill="自分株式会社 · 統合ワークスペース",
        headline=("散らばるツールを、", "ひとつの仕事OSへ。"),
        subcopy=("ノート・タスク・家計・習慣・AI学習を統合", "アプリを行き来する迷いを終わらせます"),
        chips=("174社と比較", "Markdown移行対応", "無料コア"),
        render_right_card=_right_card_competitors,
        out_path=comp_path,
    )
    generated.append(comp_path)

    phil_path = output_dir / "ogp-philosophy-v2.png"
    _render_standard_ogp(
        fonts=fonts,
        bg_asset="04-action.webp",
        pill="自分株式会社 · 自己経営OS",
        headline=("自分の人生を、", "ひとつの会社にする。"),
        subcopy=("自分がCEOとして時間・お金・スキルを経営", "昨日の自分を超える運営サイクルを回す"),
        chips=("個人P/L・B/S", "6部署で点検", "AIは伴走役"),
        render_right_card=_right_card_philosophy,
        out_path=phil_path,
    )
    generated.append(phil_path)

    growth_path = output_dir / "ogp-growth-v2.png"
    _render_standard_ogp(
        fonts=fonts,
        bg_asset="02-unified.webp",
        pill="自分株式会社 · OPEN BUILD",
        headline=("AI駆動の公開開発、", "毎日進化する人生OS。"),
        subcopy=("開発ロードマップと改善実績をすべて公開", "使う人の声とデータで機能が増え続けます"),
        chips=("公開ロードマップ", "毎日の改善ログ", "紹介＆ストア対応"),
        render_right_card=_right_card_growth,
        out_path=growth_path,
    )
    generated.append(growth_path)

    x_card_path = output_dir / "x-card-feature-update-v2.png"
    render_feature_update_card(x_card_path, fonts)
    generated.append(x_card_path)

    return generated


def verify_output_dir(output_dir: Path) -> list[str]:
    errors: list[str] = []
    for filename, expected_size in GENERATED_OGP_FILES.items():
        path = output_dir / filename
        if not path.is_file():
            errors.append(f"missing generated image: {path}")
            continue
        raw = path.read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append(f"invalid PNG header: {path}")
            continue
        with Image.open(path) as img:
            if img.size != expected_size:
                errors.append(
                    f"unexpected dimensions for {filename}: {img.size} != {expected_size}"
                )
    return errors


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "build" / "web",
        help="Target directory where generated PNG assets will be written.",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Verify existing generated PNG assets in --output-dir without rendering.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.verify_only:
        errors = verify_output_dir(args.output_dir)
        if errors:
            for err in errors:
                print(err, file=sys.stderr)
            return 1
        print(f"Verified {len(GENERATED_OGP_FILES)} OGP/X images in {args.output_dir}")
        return 0

    generated = generate_all_cards(args.output_dir)
    errors = verify_output_dir(args.output_dir)
    if errors:
        for err in errors:
            print(err, file=sys.stderr)
        return 1
    for path in generated:
        print(f"GENERATED: {path.name} ({path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
