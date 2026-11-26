#!/usr/bin/env python3
"""Generic DESIGN.md & Flutter Web token fixer — pass filename as argument."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


SUBSCRIPT_SHADE: dict[tuple[str, str], str] = {
    # red
    ("red", "100"): "0xFFFEE2E2",
    ("red", "200"): "0xFFFCA5A5",
    ("red", "300"): "0xFFF87171",
    ("red", "400"): "0xFFF87171",
    ("red", "700"): "0xFFB91C1C",
    ("red", "800"): "0xFF991B1B",
    # green
    ("green", "100"): "0xFFDCFCE7",
    ("green", "200"): "0xFFA7F3D0",
    ("green", "300"): "0xFF6EE7B7",
    ("green", "400"): "0xFF34D399",
    ("green", "700"): "0xFF047857",
    ("green", "800"): "0xFF065F46",
    # amber
    ("amber", "100"): "0xFFFEF3C7",
    ("amber", "200"): "0xFFFDE68A",
    ("amber", "700"): "0xFFB45309",
    ("amber", "800"): "0xFF92400E",
    # blue
    ("blue", "100"): "0xFFDBEAFE",
    ("blue", "300"): "0xFF93C5FD",
    ("blue", "700"): "0xFF1D4ED8",
    # grey
    ("grey", "50"): "0xFFF8FAFC",
    ("grey", "100"): "0xFFF1F5F9",
    ("grey", "200"): "0xFFE2E8F0",
    ("grey", "300"): "0xFFCBD5E1",
    ("grey", "400"): "0xFF94A3B8",
    ("grey", "500"): "0xFF64748B",
    ("grey", "600"): "0xFF475569",
    ("grey", "700"): "0xFF334155",
    ("grey", "800"): "0xFF1E293B",
    ("grey", "900"): "0xFF0F172A",
}

REPLACEMENTS_EXACT: tuple[tuple[str, str], ...] = (
    # deepPurple
    ("Colors.deepPurple.shade300", "const Color(0xFF7C3AED)"),
    ("Colors.deepPurple.shade700", "const Color(0xFF5B21B6)"),
    ("Colors.deepPurple", "const Color(0xFF7C3AED)"),
    # purple
    ("Colors.purple.shade300", "const Color(0xFFA78BFA)"),
    ("Colors.purple.shade700", "const Color(0xFF6D28D9)"),
    # indigo
    ("Colors.indigo.shade900", "const Color(0xFF1E1B4B)"),
    ("Colors.indigo.shade700", "const Color(0xFF4338CA)"),
    ("Colors.indigo.shade400", "const Color(0xFF818CF8)"),
    ("Colors.indigo.shade200", "const Color(0xFFA5B4FC)"),
    ("Colors.indigo.shade50", "const Color(0xFFEEF2FF)"),
    # orange
    ("Colors.orange.shade200", "const Color(0xFFFDBA74)"),
    ("Colors.orange.shade50", "const Color(0xFFFFF7ED)"),
    # red
    ("Colors.red.shade700", "const Color(0xFFB91C1C)"),
    ("Colors.red.shade300", "const Color(0xFFF87171)"),
    ("Colors.red.shade200", "const Color(0xFFFCA5A5)"),
    # green
    ("Colors.green.shade600", "const Color(0xFF059669)"),
    ("Colors.green.shade700", "const Color(0xFF0F766E)"),
    ("Colors.green.shade50", "const Color(0xFFF0FDFA)"),
    # blue
    ("Colors.blue.shade100", "const Color(0xFFDBEAFE)"),
    ("Colors.blue.shade700", "const Color(0xFF1D4ED8)"),
    # amber
    ("Colors.amber.shade800", "const Color(0xFF92400E)"),
    ("Colors.amber.shade100", "const Color(0xFFFEF3C7)"),
    # Accents / Grey variants
    ("Colors.blueGrey", "const Color(0xFF475569)"),
    ("Colors.blueAccent", "const Color(0xFF6366F1)"),
    ("Colors.redAccent", "const Color(0xFFB91C1C)"),
    ("Colors.deepOrange", "const Color(0xFFFF6B35)"),
    ("Colors.cyan", "const Color(0xFF0D9488)"),
    ("Colors.pink", "const Color(0xFFEC4899)"),
    ("Colors.black26", "const Color(0x42000000)"),
    ("Colors.black54", "const Color(0x8A000000)"),
)

BASE_COLORS: tuple[tuple[str, str], ...] = (
    (r"Colors\.indigo(?![A-Za-z])", "const Color(0xFF6366F1)"),
    (r"Colors\.purple(?![A-Za-z])", "const Color(0xFF6366F1)"),
    (r"Colors\.orange(?![A-Za-z])", "const Color(0xFFFF6B35)"),
    (r"Colors\.green(?![A-Za-z])", "const Color(0xFF0D9488)"),
    (r"Colors\.red(?![A-Za-z])", "const Color(0xFFB91C1C)"),
    (r"Colors\.blue(?![A-Za-z])", "const Color(0xFF6366F1)"),
    (r"Colors\.teal(?![A-Za-z])", "const Color(0xFF0D9488)"),
)


def _replace_subscript(match: re.Match[str]) -> str:
    color = match.group(1).lower()
    shade = match.group(2)
    hex_val = SUBSCRIPT_SHADE.get((color, shade), "0xFF64748B")
    return f"const Color({hex_val})"


def normalize_flutter_web_tokens(source: str) -> str:
    """Upgrade deprecated color/theme APIs to Flutter Web 3.38+ Material 3 conventions."""
    updated = re.sub(
        r"\.withAlpha\((\d+)\)",
        lambda m: f".withValues(alpha: {round(int(m.group(1)) / 255, 2)})",
        source,
    )
    updated = re.sub(
        r"\.withOpacity\(([^()]+)\)",
        lambda m: f".withValues(alpha: {m.group(1).strip()})",
        updated,
    )
    updated = re.sub(r"\bMaterialStateProperty\b", "WidgetStateProperty", updated)
    updated = re.sub(r"\bMaterialState\b", "WidgetState", updated)
    updated = re.sub(r"\bCardTheme\(", "CardThemeData(", updated)
    updated = re.sub(r"\bDialogTheme\(", "DialogThemeData(", updated)
    updated = re.sub(
        r"\bconst\s+(Color\(0x[0-9A-Fa-f]{8}\))\.with",
        r"\1.with",
        updated,
    )
    updated = re.sub(r"\bconst\s+const\b", "const", updated)
    return updated


def fix_design_tokens(content: str, *, web_normalize: bool = True) -> str:
    """Replace generic Flutter Colors literals with DESIGN.md Color tokens."""
    updated = re.sub(
        r"\.withAlpha\((\d+)\)",
        lambda m: f".withValues(alpha: {round(int(m.group(1)) / 255, 2)})",
        content,
    )
    updated = re.sub(r"Colors\.(\w+)\[(\d+)\]", _replace_subscript, updated)
    for old, new in REPLACEMENTS_EXACT:
        updated = updated.replace(old, new)
    for pattern, replacement in BASE_COLORS:
        updated = re.sub(pattern, replacement, updated)
    if web_normalize:
        updated = normalize_flutter_web_tokens(updated)
    else:
        updated = re.sub(
            r"\bconst (Color\(0x[0-9A-Fa-f]{8}\))\.with",
            r"\1.with",
            updated,
        )
        updated = re.sub(r"\bconst const\b", "const", updated)
    return updated


def run_self_test() -> tuple[bool, str]:
    sample = (
        "final c = Colors.indigo.shade700.withOpacity(0.4);\n"
        "final d = Colors.grey[700];\n"
        "final t = ThemeData(cardTheme: const CardTheme(elevation: 0));\n"
    )
    out = fix_design_tokens(sample, web_normalize=True)
    if (
        "Color(0xFF4338CA).withValues(alpha: 0.4)" not in out
        or "const Color(0xFF334155)" not in out
        or "CardThemeData(" not in out
        or ".withOpacity(" in out
    ):
        return False, f"Self-test mismatch:\n{out}"
    return True, "Self-test passed: DESIGN.md tokens + Flutter Web 3.38+ normalization verified."


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filename", nargs="?", help="Target Dart file path")
    parser.add_argument("--check", action="store_true", help="Exit 1 if changes would be made")
    parser.add_argument("--dry-run", action="store_true", help="Do not modify file on disk")
    parser.add_argument("--no-web-normalize", action="store_true", help="Skip Flutter Web API upgrades")
    parser.add_argument("--self-test", action="store_true", help="Run built-in unit check")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.self_test:
        ok, message = run_self_test()
        print(message)
        return 0 if ok else 1

    if not args.filename:
        print("Error: target filename is required unless --self-test is set.", file=sys.stderr)
        return 2

    target = Path(args.filename)
    content = target.read_text(encoding="utf-8")
    updated = fix_design_tokens(content, web_normalize=not args.no_web_normalize)

    if args.check:
        if updated != content:
            print(f"Needs token normalization: {args.filename}")
            return 1
        print(f"OK: {args.filename}")
        return 0

    if not args.dry_run:
        target.write_text(updated, encoding="utf-8", newline="\n")
    print(f"Done: {args.filename}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
