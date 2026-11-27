#!/usr/bin/env python3
"""Deterministic converter from Claude Design JSON tokens to Flutter ThemeData Dart code."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path
from typing import Any

try:
    from fix_design_tokens_generic import normalize_flutter_web_tokens
except ModuleNotFoundError:
    from scripts.fix_design_tokens_generic import normalize_flutter_web_tokens


DEFAULT_INPUT_PATH = "config/claude_design_tokens.json"
DEFAULT_OUTPUT_PATH = "lib/theme/claude_design_generated_theme.dart"

DEFAULT_COLORS: dict[str, str] = {
    "primary": "#FF6B35",
    "secondary": "#3D5AFE",
    "success": "#4CAF50",
    "warning": "#FFC107",
    "error": "#E53935",
    "surface0": "#0A0A0A",
    "surface1": "#1A1A1A",
    "surface2": "#1E1E1E",
    "text": "#FFFFFF",
    "textMuted": "#B0B0B0",
    "border": "#2A2A2A",
}

DEFAULT_SPACING: dict[str, float] = {
    "xs": 4.0,
    "sm": 8.0,
    "md": 16.0,
    "lg": 24.0,
    "xl": 32.0,
}

DEFAULT_RADIUS: dict[str, float] = {
    "sm": 8.0,
    "md": 12.0,
    "lg": 16.0,
    "xl": 24.0,
}

HEX_COLOR_RE = re.compile(r"^#?(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$")
CLASS_NAME_RE = re.compile(r"^[A-Z][A-Za-z0-9_]{0,63}$")


class TokenSchemaError(ValueError):
    """Raised when Claude Design token JSON contains invalid values or identifiers."""


def parse_hex_color_literal(raw: Any, *, field_name: str = "color") -> str:
    if not isinstance(raw, str) or not HEX_COLOR_RE.fullmatch(raw.strip()):
        raise TokenSchemaError(
            f"Invalid hex color for {field_name!r}: {raw!r} (expected #RRGGBB or #AARRGGBB)"
        )
    cleaned = raw.strip().lstrip("#").upper()
    if len(cleaned) == 6:
        cleaned = "FF" + cleaned
    return f"0x{cleaned}"


def _parse_positive_number(raw: Any, *, field_name: str) -> float:
    if isinstance(raw, bool) or not isinstance(raw, (int, float)):
        raise TokenSchemaError(f"Expected numeric value for {field_name!r}, got {raw!r}")
    value = float(raw)
    if value < 0 or value > 1024:
        raise TokenSchemaError(f"Numeric token {field_name!r} out of safe range (0..1024): {value}")
    return value


def _format_num(value: float) -> str:
    if value.is_integer():
        return f"{int(value)}"
    return f"{value:.2f}".rstrip("0").rstrip(".")


def extract_tokens(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise TokenSchemaError("Root token JSON must be an object.")
    raw_bundle = payload.get("tokens") if "tokens" in payload else payload
    if not isinstance(raw_bundle, dict):
        raise TokenSchemaError("'tokens' field must be an object.")

    raw_colors = raw_bundle.get("colors") or {}
    if not isinstance(raw_colors, dict):
        raise TokenSchemaError("'tokens.colors' must be an object.")
    colors = dict(DEFAULT_COLORS)
    for key, val in raw_colors.items():
        if not isinstance(key, str) or not key.strip():
            raise TokenSchemaError(f"Invalid color token key: {key!r}")
        parse_hex_color_literal(val, field_name=f"colors.{key}")
        colors[key.strip()] = str(val).strip()

    raw_spacing = raw_bundle.get("spacing") or {}
    if not isinstance(raw_spacing, dict):
        raise TokenSchemaError("'tokens.spacing' must be an object.")
    spacing = dict(DEFAULT_SPACING)
    for key, val in raw_spacing.items():
        spacing[str(key).strip()] = _parse_positive_number(val, field_name=f"spacing.{key}")

    raw_radius = raw_bundle.get("radius") or {}
    if not isinstance(raw_radius, dict):
        raise TokenSchemaError("'tokens.radius' must be an object.")
    radius = dict(DEFAULT_RADIUS)
    for key, val in raw_radius.items():
        radius[str(key).strip()] = _parse_positive_number(val, field_name=f"radius.{key}")

    raw_typo = raw_bundle.get("typography") or {}
    if not isinstance(raw_typo, dict):
        raise TokenSchemaError("'tokens.typography' must be an object.")
    body = raw_typo.get("bodyMedium") or raw_typo.get("body") or {}
    heading = raw_typo.get("headlineMedium") or raw_typo.get("heading") or {}
    body_size = _parse_positive_number(body.get("fontSize", 14.0), field_name="typography.body.fontSize") if isinstance(body, dict) else 14.0
    body_height = _parse_positive_number(body.get("lineHeight", 1.5), field_name="typography.body.lineHeight") if isinstance(body, dict) else 1.5
    heading_size = _parse_positive_number(heading.get("fontSize", 22.0), field_name="typography.heading.fontSize") if isinstance(heading, dict) else 22.0
    heading_height = _parse_positive_number(heading.get("lineHeight", 1.4), field_name="typography.heading.lineHeight") if isinstance(heading, dict) else 1.4

    source_bundle_id = payload.get("sourceBundleId") or "claude-design-canonical-v1"
    if not isinstance(source_bundle_id, str) or not re.fullmatch(r"[A-Za-z0-9_.:-]{1,80}", source_bundle_id):
        raise TokenSchemaError(f"Invalid sourceBundleId: {source_bundle_id!r}")

    return {
        "source_bundle_id": source_bundle_id,
        "colors": colors,
        "spacing": spacing,
        "radius": radius,
        "body_size": body_size,
        "body_height": body_height,
        "heading_size": heading_size,
        "heading_height": heading_height,
    }


def generate_theme_data_dart(
    payload: Any,
    *,
    class_name: str = "ClaudeDesignGeneratedTheme",
) -> str:
    """Compile normalized Claude Design tokens into analyzer-clean Dart 3.6 ThemeData code."""
    if not CLASS_NAME_RE.fullmatch(class_name):
        raise TokenSchemaError(f"Invalid Dart class name: {class_name!r}")

    parsed = extract_tokens(payload)
    colors = parsed["colors"]
    spacing = parsed["spacing"]
    radius = parsed["radius"]

    def color_hex(key: str, fallback: str) -> str:
        return parse_hex_color_literal(colors.get(key, fallback), field_name=f"colors.{key}")

    primary_hex = color_hex("primary", DEFAULT_COLORS["primary"])
    secondary_hex = color_hex("secondary", colors.get("accent", DEFAULT_COLORS["secondary"]))
    error_hex = color_hex("error", DEFAULT_COLORS["error"])
    surface0_hex = color_hex("surface0", DEFAULT_COLORS["surface0"])
    surface1_hex = color_hex("surface1", DEFAULT_COLORS["surface1"])
    surface2_hex = color_hex("surface2", DEFAULT_COLORS["surface2"])
    text_hex = color_hex("text", DEFAULT_COLORS["text"])
    text_muted_hex = color_hex("textMuted", DEFAULT_COLORS["textMuted"])
    border_hex = color_hex("border", DEFAULT_COLORS["border"])

    radius_md = _format_num(radius.get("md", 12.0))
    radius_lg = _format_num(radius.get("lg", 16.0))
    space_md = _format_num(spacing.get("md", 16.0))
    space_sm = _format_num(spacing.get("sm", 8.0))
    heading_size = _format_num(parsed["heading_size"])
    heading_height = _format_num(parsed["heading_height"])
    body_size = _format_num(parsed["body_size"])
    body_height = _format_num(parsed["body_height"])

    ext_name = f"{class_name}Tokens"
    class_decl = f"class {ext_name} extends ThemeExtension<{ext_name}> {{"
    if len(class_decl) > 80:
        class_decl = f"class {ext_name}\n    extends ThemeExtension<{ext_name}> {{"

    def _const_decl(field: str) -> str:
        single = f"  static const {ext_name} {field} = {ext_name}("
        if len(single) > 80:
            return f"  static const {ext_name} {field} =\n      {ext_name}("
        return single

    dark_decl = _const_decl("dark")
    light_decl = _const_decl("light")

    palette_assign = (
        f"    final palette = isDark ? {ext_name}.dark : {ext_name}.light;"
    )
    if len(palette_assign) > 80:
        palette_assign = (
            "    final palette = isDark\n"
            f"        ? {ext_name}.dark\n"
            f"        : {ext_name}.light;"
        )

    code = f"""// GENERATED FILE - DO NOT EDIT BY HAND.
// Source bundle: {parsed['source_bundle_id']}
// Generated by scripts/claude_design_to_theme_data.py (#2671).

import 'package:flutter/material.dart';

/// Claude Design トークンを保持する Flutter ThemeExtension (#2671).
@immutable
{class_decl}
  const {ext_name}({{
    required this.primary,
    required this.secondary,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.spaceSm,
    required this.spaceMd,
    required this.radiusMd,
    required this.radiusLg,
  }});

  final Color primary;
  final Color secondary;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final double spaceSm;
  final double spaceMd;
  final double radiusMd;
  final double radiusLg;

{dark_decl}
    primary: Color({primary_hex}),
    secondary: Color({secondary_hex}),
    surface0: Color({surface0_hex}),
    surface1: Color({surface1_hex}),
    surface2: Color({surface2_hex}),
    textPrimary: Color({text_hex}),
    textMuted: Color({text_muted_hex}),
    border: Color({border_hex}),
    spaceSm: {space_sm},
    spaceMd: {space_md},
    radiusMd: {radius_md},
    radiusLg: {radius_lg},
  );

{light_decl}
    primary: Color({primary_hex}),
    secondary: Color({secondary_hex}),
    surface0: Color(0xFFF8FAFC),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textMuted: Color(0xFF475569),
    border: Color(0xFFCBD5E1),
    spaceSm: {space_sm},
    spaceMd: {space_md},
    radiusMd: {radius_md},
    radiusLg: {radius_lg},
  );

  @override
  {ext_name} copyWith({{
    final Color? primary,
    final Color? secondary,
    final Color? surface0,
    final Color? surface1,
    final Color? surface2,
    final Color? textPrimary,
    final Color? textMuted,
    final Color? border,
    final double? spaceSm,
    final double? spaceMd,
    final double? radiusMd,
    final double? radiusLg,
  }}) {{
    return {ext_name}(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
    );
  }}

  @override
  {ext_name} lerp(
    final ThemeExtension<{ext_name}>? other,
    final double t,
  ) {{
    if (other is! {ext_name}) {{
      return this;
    }}
    return {ext_name}(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      surface0: Color.lerp(surface0, other.surface0, t) ?? surface0,
      surface1: Color.lerp(surface1, other.surface1, t) ?? surface1,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      spaceSm: spaceSm + (other.spaceSm - spaceSm) * t,
      spaceMd: spaceMd + (other.spaceMd - spaceMd) * t,
      radiusMd: radiusMd + (other.radiusMd - radiusMd) * t,
      radiusLg: radiusLg + (other.radiusLg - radiusLg) * t,
    );
  }}
}}

/// Claude Design トークンから決定論的に生成された Material 3 ThemeData ビルダー (#2671).
abstract final class {class_name} {{
  {class_name}._();

  static const Color primaryColor = Color({primary_hex});
  static const Color secondaryColor = Color({secondary_hex});
  static const Color errorColor = Color({error_hex});

  static ThemeData buildThemeData({{
    final Brightness brightness = Brightness.dark,
  }}) {{
    final isDark = brightness == Brightness.dark;
{palette_assign}
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: palette.surface1,
      onSurface: palette.textPrimary,
      outline: palette.border,
      error: errorColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.surface0,
      cardTheme: CardThemeData(
        color: palette.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radiusLg),
          side: BorderSide(color: palette.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(palette.radiusLg),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: {heading_size},
          fontWeight: FontWeight.w700,
          height: {heading_height},
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: {body_size},
          fontWeight: FontWeight.w400,
          height: {body_height},
          color: palette.textPrimary,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }}
}}
"""
    return normalize_flutter_web_tokens(code)


def run_self_test() -> tuple[bool, str]:
    sample = {
        "sourceBundleId": "self-test-bundle",
        "tokens": {
            "colors": {"primary": "#FF6B35", "secondary": "#3D5AFE"},
            "spacing": {"sm": 8, "md": 16},
            "radius": {"md": 12, "lg": 16},
            "typography": {
                "headlineMedium": {"fontSize": 22, "lineHeight": 1.4},
                "bodyMedium": {"fontSize": 14, "lineHeight": 1.5},
            },
        },
    }
    dart_src = generate_theme_data_dart(sample)
    if (
        "class ClaudeDesignGeneratedTheme" not in dart_src
        or "CardThemeData(" not in dart_src
        or "DialogThemeData(" not in dart_src
        or "0xFFFF6B35" not in dart_src
        or ".withOpacity(" in dart_src
    ):
        return False, "Self-test failed: generated Dart output missing expected ThemeData tokens"

    try:
        generate_theme_data_dart({"tokens": {"colors": {"primary": "red; system('rm')"}}})
        return False, "Self-test failed: invalid color accepted"
    except TokenSchemaError:
        pass

    return True, "Self-test passed: Claude Design JSON -> ThemeData converter verified."


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default=DEFAULT_INPUT_PATH, help="Input Claude Design token JSON")
    parser.add_argument("--out", default=DEFAULT_OUTPUT_PATH, help="Output Dart file path")
    parser.add_argument("--class-name", default="ClaudeDesignGeneratedTheme", help="Generated Dart class prefix")
    parser.add_argument("--check", action="store_true", help="Verify generated output matches --out without writing")
    parser.add_argument("--dry-run", action="store_true", help="Print conversion summary without writing")
    parser.add_argument("--json-out", default="", help="Optional summary JSON output path")
    parser.add_argument("--markdown-out", default="", help="Optional summary Markdown output path")
    parser.add_argument("--self-test", action="store_true", help="Run built-in converter self-tests")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.self_test:
        ok, message = run_self_test()
        print(message)
        return 0 if ok else 1

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Input token JSON not found: {input_path}", file=sys.stderr)
        return 1

    payload = json.loads(input_path.read_text(encoding="utf-8-sig"))
    generated = generate_theme_data_dart(payload, class_name=args.class_name)
    out_path = Path(args.out)

    matches = out_path.exists() and out_path.read_text(encoding="utf-8-sig").replace("\r\n", "\n") == generated
    status = "up_to_date" if matches else ("drift" if args.check else ("dry_run" if args.dry_run else "generated"))

    if args.check:
        if not matches:
            print(f"Drift detected: {out_path} does not match {input_path}", file=sys.stderr)
            return 1
        print(f"OK: {out_path} matches {input_path}")
    elif not args.dry_run:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_bytes(generated.encode("utf-8"))
        print(f"Generated: {out_path}")
    else:
        print(f"Dry-run OK: generated {len(generated)} bytes for {out_path}")

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(
                {
                    "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                    "input": str(input_path),
                    "out": str(out_path),
                    "status": status,
                    "bytes": len(generated.encode("utf-8")),
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    if args.markdown_out:
        Path(args.markdown_out).write_text(
            "\n".join(
                [
                    "## Claude Design ThemeData Conversion Summary",
                    "",
                    f"- Input: `{input_path}`",
                    f"- Output: `{out_path}`",
                    f"- Status: `{status}`",
                    f"- Bytes: {len(generated.encode('utf-8'))}",
                    "",
                ]
            ),
            encoding="utf-8",
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
