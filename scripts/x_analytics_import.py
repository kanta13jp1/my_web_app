#!/usr/bin/env python3
"""X Analytics のコンテンツ CSV を growth-hub の学習母集団へ取り込む runner.

R24 (2026-07-28). `growth-hub` に着地した `x.analytics_import` action を実際に
叩くための唯一の入口。EF 側だけ実装しても実行手段が無ければ取り込みは永久に
走らないため、ここを補う。

なぜ取り込むのか
----------------
`x.performance_context` がこれまで見ていたのは `x_post_log` =「アプリの AI
シェア経由で投稿したもの」だけだった。実測 (2026-04-27〜07-25 / 350 投稿) では
サイトへの URL クリック 304 件のうち 302 件がアプリ外の手動投稿から出ており、
学習ループはアカウント最大の勝ち筋を一度も見ていなかった。

取り込んだ行は `learning_cohort='historical_benchmark'` になる (CSV は投稿から
の経過時間がバラバラな lifetime cumulative なので、投稿年齢を揃えた勝ち
exemplar のランキングには入れない)。

認証について
------------
`x.analytics_import` は X operator ロールを要求する。**このスクリプトは
パスワードを一切扱わない。** 呼び出し側が自分のブラウザセッションから
アクセストークンを取り出して環境変数で渡す。

  1. 本番サイト <https://my-web-app-b67f4.web.app/> に自分のアカウントでログイン
  2. DevTools > Application > Local Storage > `sb-<ref>-auth-token` を開く
  3. JSON の `access_token` の値をコピー
  4. `$env:X_OPERATOR_TOKEN = '<access_token>'` (PowerShell)

使い方
------
    # まず dry-run (既定)。何件が新規/更新になるかだけ見る
    python scripts/x_analytics_import.py path/to/account_analytics_content.csv

    # 実際に取り込む
    python scripts/x_analytics_import.py path/to/file.csv --commit

トークンは短命 (既定 1 時間) なので、401 が返ったら取り直す。
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
FUNCTION_PATH = "/functions/v1/growth-hub"

# CSV のファイル名に含まれる期間 (X の export 既定の命名)。
# 例: account_analytics_content_2026-04-27_2026-07-25.csv
RANGE_PATTERN = re.compile(r"(\d{4}-\d{2}-\d{2})_(\d{4}-\d{2}-\d{2})")


def export_range_from_name(path: pathlib.Path) -> str:
    """ファイル名から `YYYY-MM-DD..YYYY-MM-DD` を推定する (取れなければ空)。"""
    match = RANGE_PATTERN.search(path.name)
    return f"{match.group(1)}..{match.group(2)}" if match else ""


def post(url: str, token: str, anon_key: str, payload: dict) -> dict:
    body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
    request = urllib.request.Request(url, data=body, method="POST")
    request.add_header("Content-Type", "application/json")
    request.add_header("Authorization", f"Bearer {token}")
    if anon_key:
        request.add_header("apikey", anon_key)
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:400]
        if error.code == 401:
            raise SystemExit(
                "401 Unauthorized — X_OPERATOR_TOKEN が空か期限切れです。"
                "ログイン中のブラウザから access_token を取り直してください。"
            ) from error
        if error.code == 403:
            raise SystemExit(
                "403 Forbidden — このユーザーに X operator ロールがありません。"
                f" 応答: {detail}"
            ) from error
        raise SystemExit(f"HTTP {error.code}: {detail}") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=pathlib.Path, help="X Analytics の CSV パス")
    parser.add_argument(
        "--commit",
        action="store_true",
        help="実際に書き込む (既定は dry-run で件数だけ返す)",
    )
    parser.add_argument(
        "--export-range",
        default="",
        help="期間ラベル。省略時はファイル名から推定する",
    )
    args = parser.parse_args()

    if not args.csv.is_file():
        raise SystemExit(f"CSV が見つかりません: {args.csv}")

    token = os.environ.get("X_OPERATOR_TOKEN", "").strip()
    if not token:
        raise SystemExit(
            "X_OPERATOR_TOKEN が未設定です。docstring の手順で "
            "access_token を環境変数に入れてから再実行してください。"
        )

    supabase_url = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
    anon_key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    csv_text = args.csv.read_text(encoding="utf-8")
    export_range = args.export_range or export_range_from_name(args.csv)

    print(f"CSV: {args.csv} ({len(csv_text):,} bytes)")
    print(f"期間: {export_range or '(不明)'}")
    print(f"モード: {'COMMIT (書き込み)' if args.commit else 'DRY-RUN (既定)'}")

    result = post(
        f"{supabase_url}{FUNCTION_PATH}",
        token,
        anon_key,
        {
            "action": "x.analytics_import",
            "csv": csv_text,
            "exportRange": export_range,
            "dryRun": not args.commit,
        },
    )

    print(json.dumps(result, ensure_ascii=False, indent=2)[:2000])
    if result.get("success") is not True:
        return 1
    if not args.commit:
        print("\ndry-run で終了しました。実際に取り込むには --commit を付けてください。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
