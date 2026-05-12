#!/usr/bin/env python3
"""Guard Edge Function imports that make production deploys flaky."""

from __future__ import annotations

import argparse
from pathlib import Path


BANNED = "https://esm.sh/@supabase/supabase-js@2"
DEFAULT_ROOT = Path("supabase/functions")
DEFAULT_SUFFIXES = {".ts", ".json", ".jsonc"}


def iter_files(root: Path):
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in DEFAULT_SUFFIXES:
            continue
        yield path


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Fail if Supabase Edge Functions import supabase-js from esm.sh. "
            "Use npm:@supabase/supabase-js@2 instead."
        )
    )
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args()

    if not args.root.exists():
        print(f"Edge Function root not found: {args.root}")
        return 1

    offenders: list[tuple[Path, int, str]] = []
    for path in iter_files(args.root):
        text = path.read_text(encoding="utf-8", errors="replace")
        for number, line in enumerate(text.splitlines(), start=1):
            if BANNED in line:
                offenders.append((path, number, line.strip()))

    if offenders:
        print("Banned Supabase JS import found in Edge Functions.")
        print("Use npm:@supabase/supabase-js@2 to avoid esm.sh deploy-time 522s.")
        for path, number, line in offenders:
            print(f"- {path}:{number}: {line}")
        return 1

    print("Edge Function Supabase JS imports are deploy-resilient.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
