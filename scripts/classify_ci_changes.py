#!/usr/bin/env python3
"""Classify changed paths so CI runs only the relevant expensive toolchains."""

from __future__ import annotations

import argparse
import fnmatch
from pathlib import Path


GROUPS: dict[str, tuple[str, ...]] = {
    "flutter": (
        "lib/**",
        "test/**",
        "integration_test/**",
        "web/**",
        "assets/**",
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        "l10n.yaml",
        "firebase.json",
    ),
    "web": (
        "lib/**",
        "integration_test/**",
        "web/**",
        "assets/**",
        "pubspec.yaml",
        "pubspec.lock",
        "analysis_options.yaml",
        "l10n.yaml",
        "firebase.json",
    ),
    "edge": (
        "supabase/functions/**",
        "supabase/config.toml",
    ),
    "caption": ("services/caption-transcoder/**",),
    "migration": ("supabase/migrations/**",),
}

IGNORED_PATTERNS: dict[str, tuple[str, ...]] = {
    "flutter": ("assets/data/tiger_*",),
    "web": ("assets/data/tiger_*",),
}


def classify(paths: list[str], force_all: bool = False) -> dict[str, bool]:
    normalized = [path.strip().replace("\\", "/") for path in paths if path.strip()]
    result = {
        group: force_all
        or any(
            fnmatch.fnmatchcase(path, pattern)
            and not any(
                fnmatch.fnmatchcase(path, ignored)
                for ignored in IGNORED_PATTERNS.get(group, ())
            )
            for path in normalized
            for pattern in patterns
        )
        for group, patterns in GROUPS.items()
    }
    result["deployable"] = result["web"] or result["edge"] or result["migration"]
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--changed-files", type=Path, required=True)
    parser.add_argument("--github-output", type=Path)
    parser.add_argument("--all", action="store_true", dest="force_all")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    paths = (
        args.changed_files.read_text(encoding="utf-8").splitlines()
        if args.changed_files.exists()
        else []
    )
    result = classify(paths, force_all=args.force_all)
    lines = [f"{name}={str(enabled).lower()}" for name, enabled in result.items()]
    print("\n".join(lines))
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as output:
            output.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
