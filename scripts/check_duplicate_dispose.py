#!/usr/bin/env python3
"""Detect duplicated cleanup statements inside Flutter dispose() bodies.

part 280 の本番バグ (_annualRateControllers の二重 dispose → dispose 中断 →
Timer 未解放 → defunct setState) の再発防止ゲート。lib/ 配下の全 dispose()
ボディを brace バランスで抽出し、同一文の重複を検出したら exit 1。

Usage: python scripts/check_duplicate_dispose.py [root]
"""

from __future__ import annotations

import collections
import pathlib
import re
import sys

DISPOSE_RE = re.compile(r"void\s+dispose\(\)\s*\{")


def dispose_bodies(source: str):
    for match in DISPOSE_RE.finditer(source):
        index = match.end()
        depth = 1
        while index < len(source) and depth > 0:
            char = source[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
            index += 1
        line = source[: match.start()].count("\n") + 1
        yield line, source[match.end() : index - 1]


def find_duplicates(root: pathlib.Path):
    hits = []
    for path in sorted(root.glob("lib/**/*.dart")):
        source = path.read_text(encoding="utf-8", errors="replace")
        for line, body in dispose_bodies(source):
            statements = [
                stripped
                for raw in body.splitlines()
                if (stripped := raw.strip()).endswith(";")
                and not stripped.startswith("//")
            ]
            for statement, count in collections.Counter(statements).items():
                if count > 1:
                    hits.append(
                        f"{path.as_posix()}:{line} x{count}: {statement[:100]}"
                    )
    return hits


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    hits = find_duplicates(root)
    if hits:
        print("Duplicate statements found in dispose() bodies:")
        for hit in hits:
            print(f"- {hit}")
        print(
            "二重 dispose は dispose 中断→リソース未解放を招きます"
            " (part 280 実例)。重複行を削除してください。"
        )
        return 1
    print("check_duplicate_dispose: CLEAN (no duplicated dispose statements)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
