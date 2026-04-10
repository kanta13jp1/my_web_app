"""
gemini_research.py — ゼロトークンリサーチ CLI
Claude Code の /deep-research コマンドから呼ばれる。
重いドキュメント分析を Gemini に委譲し、Claude のトークンを節約する。

使い方:
  python gemini_research.py "質問テキスト"
  python gemini_research.py --files file1.txt file2.md --query "質問"
  python gemini_research.py --url "https://example.com" --query "要約して"
  python gemini_research.py --setup   # 接続テスト
"""

import os
import sys
import argparse
import json
from pathlib import Path

try:
    from google import genai
    from google.genai import types
except ImportError:
    print("ERROR: google-genai が未インストールです。")
    print("  pip install google-genai")
    sys.exit(1)

# =====================================================================
# 設定
# =====================================================================

MODEL_CASCADE = [
    "gemini-2.5-flash",
    "gemini-2.5-pro",
    "gemini-2.0-flash",
    "gemini-flash-latest",
    "gemini-pro-latest",
]

MAX_FILE_CHARS = 200_000   # 1ファイルあたり最大文字数（約50Kトークン相当）
MAX_TOTAL_CHARS = 800_000  # 全ファイル合計の上限


# =====================================================================
# Gemini 呼び出し
# =====================================================================

def get_client() -> genai.Client:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY 環境変数が設定されていません。")
        print("  set GEMINI_API_KEY=your_key  (Windows)")
        print("  export GEMINI_API_KEY=your_key  (Unix)")
        sys.exit(1)
    return genai.Client(api_key=api_key)


def call_gemini(client: genai.Client, prompt: str) -> str:
    last_error = None
    for model in MODEL_CASCADE:
        try:
            response = client.models.generate_content(
                model=model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.3,
                    max_output_tokens=8192,
                ),
            )
            return response.text
        except Exception as e:
            last_error = e
            continue
    raise RuntimeError(f"全モデルで失敗: {last_error}")


# =====================================================================
# 入力ローダー
# =====================================================================

def load_files(file_paths: list[str]) -> str:
    parts = []
    total = 0
    for path_str in file_paths:
        path = Path(path_str)
        if not path.exists():
            print(f"WARN: ファイルが見つかりません: {path_str}", file=sys.stderr)
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        if len(text) > MAX_FILE_CHARS:
            text = text[:MAX_FILE_CHARS] + f"\n\n[... 残り {len(text)-MAX_FILE_CHARS:,} 文字は省略 ...]"
        total += len(text)
        parts.append(f"=== {path.name} ===\n{text}")
        if total >= MAX_TOTAL_CHARS:
            parts.append("[合計文字数上限に達したため以降のファイルを省略]")
            break
    return "\n\n".join(parts)


def load_url(url: str) -> str:
    """WebFetch の代わりに urllib で取得（プレーンテキストのみ）"""
    import urllib.request
    import urllib.error
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8", errors="ignore")
        # 簡易 HTML タグ除去
        import re
        text = re.sub(r"<style[^>]*>.*?</style>", "", raw, flags=re.DOTALL)
        text = re.sub(r"<script[^>]*>.*?</script>", "", text, flags=re.DOTALL)
        text = re.sub(r"<[^>]+>", " ", text)
        text = re.sub(r"\s{3,}", "\n\n", text)
        return text[:MAX_FILE_CHARS]
    except urllib.error.URLError as e:
        return f"[URL取得失敗: {e}]"


# =====================================================================
# プロンプト構築
# =====================================================================

SYSTEM_PROMPT = """あなたは優秀なリサーチアナリストです。
以下のドキュメントや情報を分析し、日本語で簡潔かつ構造化されたレポートを作成してください。

レポートの形式:
1. **要約** (3〜5行)
2. **主要な発見** (箇条書き)
3. **アクションアイテム** (優先度付き)
4. **注意点・リスク** (あれば)

このプロジェクトのコンテキスト:
- Flutter Web + Supabase の AI ライフマネジメントアプリ「自分株式会社」
- 競合21社の機能を統合することがゴール
- 実ユーザー4人、本番稼働中: https://my-web-app-b67f4.web.app/
"""


def build_prompt(query: str, context: str) -> str:
    parts = [SYSTEM_PROMPT]
    if context:
        parts.append(f"## 分析対象ドキュメント\n\n{context}")
    parts.append(f"## 質問・分析指示\n\n{query}")
    return "\n\n".join(parts)


# =====================================================================
# メイン
# =====================================================================

def setup_test():
    """接続テスト"""
    print("Gemini 接続テスト中...")
    client = get_client()
    result = call_gemini(client, "「自分株式会社」を10文字で説明してください。")
    print(f"✅ 接続成功\n回答: {result}")


def main():
    parser = argparse.ArgumentParser(description="Gemini ゼロトークンリサーチ CLI")
    parser.add_argument("query", nargs="?", help="分析クエリ（位置引数）")
    parser.add_argument("--query", "-q", dest="query_opt", help="分析クエリ（オプション）")
    parser.add_argument("--files", "-f", nargs="+", help="分析するファイルパス（複数可）")
    parser.add_argument("--url", "-u", help="分析する URL")
    parser.add_argument("--output", "-o", help="結果を保存するファイルパス")
    parser.add_argument("--setup", action="store_true", help="接続テスト")
    parser.add_argument("--json", action="store_true", help="JSON形式で出力")
    args = parser.parse_args()

    if args.setup:
        setup_test()
        return

    # クエリ確定
    query = args.query or args.query_opt
    if not query:
        parser.print_help()
        sys.exit(1)

    # コンテキスト収集
    context_parts = []
    if args.files:
        file_text = load_files(args.files)
        if file_text:
            context_parts.append(file_text)
    if args.url:
        url_text = load_url(args.url)
        context_parts.append(f"=== URL: {args.url} ===\n{url_text}")

    context = "\n\n".join(context_parts)

    # Gemini 呼び出し
    client = get_client()
    prompt = build_prompt(query, context)

    print(f"🔍 Gemini で分析中... (コンテキスト: {len(context):,} 文字)", file=sys.stderr)
    result = call_gemini(client, prompt)

    # 出力
    if args.json:
        output = json.dumps({"query": query, "result": result}, ensure_ascii=False, indent=2)
    else:
        output = result

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"✅ 結果を保存: {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
