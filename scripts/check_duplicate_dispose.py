#!/usr/bin/env python3
"""Detect duplicated top-level statements in Flutter lifecycle bodies.

part 280 の本番バグ (_annualRateControllers の二重 dispose → dispose 中断 →
Timer 未解放 → defunct setState) の再発防止ゲート。lib/ 配下の全 dispose() /
initState() ボディを brace バランスで抽出し、**トップレベル文** (コールバック
内部は対象外) を `;` 区切りで再構成して同一文の重複を検出したら exit 1。
二重 dispose のほか、二重 addListener / 二重フェッチ起動も同型として捕捉する。

Usage: python scripts/check_duplicate_dispose.py [root]
"""

from __future__ import annotations

import collections
import pathlib
import re
import sys

LIFECYCLE_RE = re.compile(r"void\s+(dispose|initState)\(\)\s*\{")
LINE_COMMENT_RE = re.compile(r"(?<!:)//[^\n]*")


def lifecycle_bodies(source: str):
    for match in LIFECYCLE_RE.finditer(source):
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
        yield match.group(1), line, source[match.end() : index - 1]


def top_level_statements(body: str):
    """コールバック内部 (brace 深度>0) を除いた文を `;` 区切りで返す。"""
    statements = []
    current = []
    brace = 0
    paren = 0
    for char in body:
        if char == "{":
            brace += 1
        elif char == "}":
            brace -= 1
        elif char == "(":
            paren += 1
        elif char == ")":
            paren -= 1
        if brace == 0:
            current.append(char)
            if char == ";" and paren == 0:
                statement = re.sub(r"\s+", " ", "".join(current)).strip(" ;")
                if statement:
                    statements.append(statement)
                current = []
        elif current and brace > 0:
            # トップレベル文の途中でコールバックへ潜った (例: addListener(() {
            # ...})) — 文としては継続中なのでプレースホルダだけ残す。
            if current[-1] != "\x00":
                current.append("\x00")
    return statements


def find_duplicates(root: pathlib.Path):
    hits = []
    for path in sorted(root.glob("lib/**/*.dart")):
        source = LINE_COMMENT_RE.sub(
            "", path.read_text(encoding="utf-8", errors="replace")
        )
        for kind, line, body in lifecycle_bodies(source):
            counter = collections.Counter(top_level_statements(body))
            for statement, count in counter.items():
                if count > 1:
                    shown = statement.replace("\x00", "{...}")[:100]
                    hits.append(f"{path.as_posix()}:{line} {kind} x{count}: {shown}")
    return hits


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    hits = find_duplicates(root)
    if hits:
        print("Duplicate top-level statements found in lifecycle bodies:")
        for hit in hits:
            print(f"- {hit}")
        print(
            "二重 dispose / 二重リスナー登録は dispose 中断やコールバック"
            "多重発火を招きます (part 280 実例)。重複行を削除してください。"
        )
        return 1
    print(
        "check_duplicate_dispose: CLEAN"
        " (no duplicated top-level statements in dispose/initState)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
