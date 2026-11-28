#!/usr/bin/env python3
"""Verify feature-based Container/Presentation layer boundaries under lib/features (#2603).

Checks that Dart files inside `lib/features/<feature>/presentation/` do not
directly import backend/network clients (`package:supabase_flutter`,
`package:supabase`, `package:http`, `package:dio`, `dart:io`, `dart:html`).
"""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys

DEFAULT_FEATURES_ROOT = Path("lib/features")
DISALLOWED_PRESENTATION_PREFIXES: tuple[str, ...] = (
    "package:supabase_flutter/",
    "package:supabase/",
    "package:http/",
    "package:dio/",
    "dart:io",
    "dart:html",
)
_DIRECTIVE_PATTERN = re.compile(
    r"""^\s*(?:import|export)\s+(['"])([^'"]+)\1""",
    re.MULTILINE,
)


@dataclass(frozen=True)
class ArchitectureViolation:
    file_path: str
    line: int
    import_uri: str
    reason: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def _strip_dart_comments(source: str) -> str:
    """Remove // line comments and /* ... */ block comments while preserving newlines."""
    out: list[str] = []
    i = 0
    n = len(source)
    in_sq = False
    in_dq = False
    while i < n:
        ch = source[i]
        nxt = source[i + 1] if i + 1 < n else ""
        if not in_sq and not in_dq and ch == "/" and nxt == "/":
            while i < n and source[i] != "\n":
                i += 1
            continue
        if not in_sq and not in_dq and ch == "/" and nxt == "*":
            i += 2
            while i + 1 < n and not (source[i] == "*" and source[i + 1] == "/"):
                if source[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        if ch == "\\" and (in_sq or in_dq) and i + 1 < n:
            out.append(ch)
            out.append(source[i + 1])
            i += 2
            continue
        if ch == "'" and not in_dq:
            in_sq = not in_sq
        elif ch == '"' and not in_sq:
            in_dq = not in_dq
        out.append(ch)
        i += 1
    return "".join(out)


def find_presentation_files(features_root: Path) -> list[Path]:
    """Return sorted Dart files inside `lib/features/<feature>/presentation/`."""
    if not features_root.exists():
        return []
    files: list[Path] = []
    for feature_dir in sorted(features_root.iterdir()):
        if not feature_dir.is_dir():
            continue
        pres_dir = feature_dir / "presentation"
        if pres_dir.is_dir():
            files.extend(sorted(pres_dir.rglob("*.dart")))
    return files


def check_features_directory(features_root: Path) -> list[ArchitectureViolation]:
    """Scan presentation files under features_root and return boundary violations."""
    violations: list[ArchitectureViolation] = []
    for path in find_presentation_files(features_root):
        text = path.read_text(encoding="utf-8")
        cleaned = _strip_dart_comments(text)
        for match in _DIRECTIVE_PATTERN.finditer(cleaned):
            uri = match.group(2).strip()
            for disallowed in DISALLOWED_PRESENTATION_PREFIXES:
                if uri == disallowed or uri.startswith(disallowed):
                    line_no = cleaned.count("\n", 0, match.start()) + 1
                    violations.append(
                        ArchitectureViolation(
                            file_path=path.as_posix(),
                            line=line_no,
                            import_uri=uri,
                            reason=(
                                "Presentation layer must not import network/backend "
                                f"dependency '{uri}'; inject state/callbacks via Container."
                            ),
                        )
                    )
                    break
    return violations


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify feature Container/Presentation boundaries under lib/features.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_FEATURES_ROOT,
        help="Path to lib/features directory (default: lib/features)",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON report")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    files = find_presentation_files(args.root)
    violations = check_features_directory(args.root)

    if args.json:
        print(
            json.dumps(
                {
                    "root": args.root.as_posix(),
                    "presentation_files_checked": len(files),
                    "violation_count": len(violations),
                    "violations": [v.to_dict() for v in violations],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    else:
        if violations:
            for v in violations:
                print(f"{v.file_path}:{v.line}: {v.reason}", file=sys.stderr)
        else:
            print(
                f"OK: checked {len(files)} presentation Dart file(s) under "
                f"{args.root.as_posix()} — 0 layer violations"
            )

    return 1 if violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
