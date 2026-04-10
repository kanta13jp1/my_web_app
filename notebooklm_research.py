"""
notebooklm_research.py — NotebookLM リサーチ CLI
Claude Code の /deep-research コマンドから呼ばれる。
重いドキュメント分析を NotebookLM に委譲し、Claude のトークンを節約する。

使い方:
  python notebooklm_research.py "質問テキスト"
  python notebooklm_research.py --files file1.txt file2.md --query "質問"
  python notebooklm_research.py --url "https://example.com" --query "要約して"
  python notebooklm_research.py --setup   # 接続テスト

事前準備:
  pip install "notebooklm-py[browser]"
  notebooklm login   # ブラウザで Google アカウント認証
"""

import os
import sys
import asyncio
import argparse
import json
from pathlib import Path

try:
    from notebooklm import NotebookLMClient
except ImportError:
    print("ERROR: notebooklm-py が未インストールです。")
    print("  pip install \"notebooklm-py[browser]\"")
    print("  notebooklm login")
    sys.exit(1)

# =====================================================================
# 設定
# =====================================================================

NOTEBOOK_TITLE = "Claude Code Deep Research (一時ノート)"
MAX_FILE_CHARS = 200_000   # 1ファイルあたり最大文字数
MAX_TOTAL_CHARS = 800_000  # 全ファイル合計の上限

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


# =====================================================================
# 入力ローダー
# =====================================================================

def load_files(file_paths: list[str]) -> list[tuple[str, str]]:
    """(タイトル, テキスト) のリストを返す"""
    results = []
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
        results.append((path.name, text))
        if total >= MAX_TOTAL_CHARS:
            print("[合計文字数上限に達したため以降のファイルを省略]", file=sys.stderr)
            break
    return results


# =====================================================================
# NotebookLM 呼び出し
# =====================================================================

async def run_research(query: str, files: list[str] | None, url: str | None) -> str:
    try:
        client = await NotebookLMClient.from_storage()
    except Exception as e:
        print(f"ERROR: NotebookLM への接続に失敗しました: {e}", file=sys.stderr)
        print("  notebooklm login  を実行して Google 認証を完了してください。", file=sys.stderr)
        sys.exit(1)

    notebook = None
    async with client:
        try:
            # ノートブック作成
            print("📓 NotebookLM ノートブックを作成中...", file=sys.stderr)
            notebook = await client.notebooks.create(NOTEBOOK_TITLE)

            # システムプロンプトをソースとして追加
            await client.sources.add_text(
                notebook.id,
                title="分析指示・プロジェクトコンテキスト",
                content=SYSTEM_PROMPT,
            )

            # ファイルをソースとして追加
            if files:
                file_data = load_files(files)
                for title, content in file_data:
                    print(f"  📄 ソース追加: {title}", file=sys.stderr)
                    await client.sources.add_text(notebook.id, title=title, content=content)

            # URL をソースとして追加
            if url:
                print(f"  🌐 URL ソース追加: {url}", file=sys.stderr)
                await client.sources.add_url(notebook.id, url)

            # 質問を送信
            print(f"🔍 NotebookLM で分析中...", file=sys.stderr)
            result = await client.chat.ask(notebook.id, query)
            return result.answer

        finally:
            # 一時ノートブックを削除（クリーンアップ）
            if notebook is not None:
                try:
                    await client.notebooks.delete(notebook.id)
                    print("🗑️  一時ノートブックを削除しました。", file=sys.stderr)
                except Exception:
                    pass  # クリーンアップ失敗は無視


async def setup_test():
    """接続テスト"""
    print("NotebookLM 接続テスト中...")
    try:
        client = await NotebookLMClient.from_storage()
    except Exception as e:
        print(f"ERROR: 接続失敗: {e}")
        print("  notebooklm login  を実行してください。")
        sys.exit(1)

    async with client:
        nb = await client.notebooks.create("テスト (すぐ削除)")
        await client.sources.add_text(nb.id, title="テスト", content="自分株式会社はAIライフマネジメントアプリです。")
        result = await client.chat.ask(nb.id, "このアプリを10文字で説明してください。")
        await client.notebooks.delete(nb.id)
        print(f"✅ 接続成功\n回答: {result.answer}")


# =====================================================================
# メイン
# =====================================================================

def main():
    parser = argparse.ArgumentParser(description="NotebookLM ゼロトークンリサーチ CLI")
    parser.add_argument("query", nargs="?", help="分析クエリ（位置引数）")
    parser.add_argument("--query", "-q", dest="query_opt", help="分析クエリ（オプション）")
    parser.add_argument("--files", "-f", nargs="+", help="分析するファイルパス（複数可）")
    parser.add_argument("--url", "-u", help="分析する URL")
    parser.add_argument("--output", "-o", help="結果を保存するファイルパス")
    parser.add_argument("--setup", action="store_true", help="接続テスト")
    parser.add_argument("--json", action="store_true", help="JSON形式で出力")
    args = parser.parse_args()

    if args.setup:
        asyncio.run(setup_test())
        return

    query = args.query or args.query_opt
    if not query:
        parser.print_help()
        sys.exit(1)

    result = asyncio.run(run_research(query, args.files, args.url))

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
