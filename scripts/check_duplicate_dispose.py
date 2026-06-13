#!/usr/bin/env python3
"""Detect duplicated risky top-level statements in Flutter method bodies.

part 280 の本番バグ (_annualRateControllers の二重 dispose → dispose 中断 →
Timer 未解放 → defunct setState) の再発防止ゲート。part 285 で対象を
dispose()/initState() から **全メソッドボディ** へ拡張した。

検出方針 (2 ティア):
- **ライフサイクル** (dispose / initState): トップレベル文の重複を**すべて**検出。
  これらのボディでは同一文の繰り返しはほぼ確実にバグ。
- **一般メソッド**: トップレベル文のうち `await` / `setState(` / `.dispose(` /
  `.addListener(` 等の**副作用を伴う危険パターン**の重複のみ検出
  (二重 await = 二重フェッチ、二重 setState = 二重再描画 等)。一般メソッドは
  正当な同一文の繰り返しもあるため、危険パターンに限定して誤検出を抑える。

メソッド検出は `){`(本体開始)を起点に対応する `(` まで後方走査し、その直前の
語を名前として取る方式。制御構文 (if/for/...) と無名クロージャは名前条件で除外。
巨大ファイル (= 80 万字の page) でも線形時間で走るよう、貪欲な前方マッチを避ける。

トップレベル文は brace/paren 深度で `;` 区切りに分割し、コールバック本体も
そのまま保持する (本体が異なる呼び出しを別物として扱い、完全一致だけ捕捉)。

Usage: python scripts/check_duplicate_dispose.py [root]
"""

from __future__ import annotations

import collections
import pathlib
import re
import sys

# 本体開始 `) [async] {`。`)` と `{` の間は空白/改行のみ許容 (多行シグネチャ可)。
HEADER_RE = re.compile(r"\)[ \t\n]*(?:async\*?|sync\*?)?[ \t\n]*\{")
NAME_RE = re.compile(r"(\w+)\s*$")
CONTROL_KEYWORDS = {
    "if",
    "for",
    "while",
    "switch",
    "catch",
    "else",
    "do",
    "return",
}
LIFECYCLE_NAMES = {"dispose", "initState"}
LINE_COMMENT_RE = re.compile(r"(?<!:)//[^\n]*")
# 副作用を伴う危険な呼び出し (重複すると二重実行になりやすい)。
RISKY_RE = re.compile(
    r"\bawait\b"
    r"|\bsetState\s*\("
    r"|\.dispose\s*\("
    r"|\.cancel\s*\("
    r"|\.addListener\s*\("
    r"|\.removeListener\s*\("
)


def _matching_open_paren(source: str, close_index: int) -> int:
    """`close_index` の `)` に対応する `(` の位置を返す (無ければ -1)。"""
    depth = 0
    index = close_index
    while index >= 0:
        char = source[index]
        if char == ")":
            depth += 1
        elif char == "(":
            depth -= 1
            if depth == 0:
                return index
        index -= 1
    return -1


def method_bodies(source: str):
    """全メソッド/関数ボディを (name, start_index, body) で返す。"""
    for match in HEADER_RE.finditer(source):
        open_paren = _matching_open_paren(source, match.start())
        if open_paren < 0:
            continue
        window = source[max(0, open_paren - 64):open_paren].rstrip()
        name_match = NAME_RE.search(window)
        if name_match is None:
            continue
        name = name_match.group(1)
        if name in CONTROL_KEYWORDS:
            continue
        index = match.end()
        depth = 1
        while index < len(source) and depth > 0:
            char = source[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
            index += 1
        yield name, match.start(), source[match.end() : index - 1]


def top_level_statements(body: str):
    """brace/paren 深度 0 の `;` で区切ったトップレベル文を返す。

    コールバック本体も保持するため、本体の異なる呼び出しは別文として扱う。
    """
    statements = []
    current = []
    brace = 0
    paren = 0
    for char in body:
        current.append(char)
        if char == "{":
            brace += 1
        elif char == "}":
            brace -= 1
        elif char == "(":
            paren += 1
        elif char == ")":
            paren -= 1
        elif char == ";" and brace == 0 and paren == 0:
            statement = re.sub(r"\s+", " ", "".join(current)).strip(" ;")
            if statement:
                statements.append(statement)
            current = []
    return statements


def find_duplicates(root: pathlib.Path):
    hits = []
    for path in sorted(root.glob("lib/**/*.dart")):
        source = LINE_COMMENT_RE.sub(
            "", path.read_text(encoding="utf-8", errors="replace")
        )
        for name, start_index, body in method_bodies(source):
            counter = collections.Counter(top_level_statements(body))
            lifecycle = name in LIFECYCLE_NAMES
            for statement, count in counter.items():
                if count <= 1:
                    continue
                if not lifecycle and not RISKY_RE.search(statement):
                    continue
                line = source.count("\n", 0, start_index) + 1
                shown = statement[:100]
                hits.append(f"{path.as_posix()}:{line} {name}() x{count}: {shown}")
    return hits


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    hits = find_duplicates(root)
    if hits:
        print("Duplicate risky top-level statements found in method bodies:")
        for hit in hits:
            print(f"- {hit}")
        print(
            "二重 dispose / 二重 await / 二重 setState は dispose 中断・"
            "二重フェッチ・二重再描画を招きます (part 280 実例)。重複行を削除してください。"
        )
        return 1
    print(
        "check_duplicate_dispose: CLEAN"
        " (no duplicated risky top-level statements in method bodies)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
