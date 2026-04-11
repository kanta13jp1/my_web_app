#!/usr/bin/env python3
"""
notebooklm_research.py — ゼロトークンリサーチ ヘルパー
Claude Code の /deep-research コマンドから呼び出される。

使い方:
  python notebooklm_research.py "競合21社の最新動向"
  python notebooklm_research.py --files doc1.md doc2.md --query "APIとUIの整合性"
  python notebooklm_research.py --url https://example.com --query "要約して"
  python notebooklm_research.py --setup   # セットアップ確認

  # Master Brain に保存 (セッション記録の蓄積)
  python notebooklm_research.py --add-to-master-brain memory/project_20260411.md
  python notebooklm_research.py --add-to-master-brain memory/feedback_success_20260411.md memory/project_20260411.md

  # 成果物を生成
  python notebooklm_research.py --generate slide-deck
  python notebooklm_research.py --generate audio --generate-prompt "engaging deep dive"

  # リサーチ後に成果物生成 + Master Brain 追加を一括実行
  python notebooklm_research.py "Flutter performance" --generate flashcards --add-to-master-brain ./memory/project_today.md
"""

import asyncio
import argparse
import sys
import os
import json
from pathlib import Path
from datetime import datetime

# PYTHONUTF8 を強制（Windows CP932 エンコードエラー回避）
os.environ.setdefault("PYTHONUTF8", "1")

STORAGE_PATH = Path.home() / ".notebooklm" / "storage_state.json"
NOTEBOOK_PREFIX = "jibun-research"


def check_auth() -> bool:
    """認証状態を確認する"""
    return STORAGE_PATH.exists()


def setup_guide():
    """セットアップ手順を表示する"""
    print("""
NotebookLM セットアップ手順:

  Step 1: notebooklm-py のインストール
    pip install "notebooklm-py[browser]"
    playwright install chromium

  Step 2: Google アカウントでログイン
    notebooklm login
    -> ブラウザが開くので Google アカウントでログイン

  Step 3: 動作確認
    python notebooklm_research.py --setup
""")


async def research_topic(query: str, notebook_name: str = None) -> dict:
    """トピックを NotebookLM でリサーチする"""
    try:
        from notebooklm import NotebookLMClient  # noqa: PLC0415
    except ImportError:
        return {"error": "notebooklm-py がインストールされていません。`pip install notebooklm-py[browser]` を実行してください。"}

    if not check_auth():
        return {"error": "未認証です。`notebooklm login` を実行してください。"}

    name = notebook_name or f"{NOTEBOOK_PREFIX}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    async with await NotebookLMClient.from_storage() as client:
        nb = await client.notebooks.create(name)
        print(f"[NotebookLM] ノートブック作成: {name} (id: {nb.id[:8]}...)", file=sys.stderr)

        print(f"[NotebookLM] テキストソース追加中: {query[:50]}...", file=sys.stderr)
        await client.sources.add_text(nb.id, f"Research: {name}", query, wait=True)

        print("[NotebookLM] 質問送信中...", file=sys.stderr)
        result = await client.chat.ask(nb.id, query)

        try:
            summary_result = await client.chat.ask(
                nb.id,
                "このノートブックの内容を300字以内で日本語で要約してください",
            )
            summary = summary_result.answer if hasattr(summary_result, "answer") else str(summary_result)
        except Exception:
            summary = ""

        return {
            "notebook_id": nb.id,
            "notebook_name": name,
            "query": query,
            "answer": result.answer if hasattr(result, "answer") else str(result),
            "summary": summary,
            "citations": getattr(result, "citations", []),
        }


async def research_files(files: list, query: str, notebook_name: str = None) -> dict:
    """ファイルを読み込んで NotebookLM に質問する"""
    try:
        from notebooklm import NotebookLMClient  # noqa: PLC0415
    except ImportError:
        return {"error": "notebooklm-py がインストールされていません。"}

    if not check_auth():
        return {"error": "未認証です。`notebooklm login` を実行してください。"}

    name = notebook_name or f"{NOTEBOOK_PREFIX}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    async with await NotebookLMClient.from_storage() as client:
        nb = await client.notebooks.create(name)
        print(f"[NotebookLM] ノートブック作成: {name} (id: {nb.id[:8]}...)", file=sys.stderr)

        all_content = []
        for f in files:
            path = Path(f)
            if not path.exists():
                print(f"[NotebookLM] ファイルが見つかりません: {f}", file=sys.stderr)
                continue
            print(f"[NotebookLM] ファイル読込: {path.name}", file=sys.stderr)
            if path.suffix.lower() == ".pdf":
                await client.sources.add_file(nb.id, str(path), wait=True)
            else:
                content = path.read_text(encoding="utf-8", errors="ignore")
                all_content.append(f"# {path.name}\n\n{content[:4000]}")

        if all_content:
            combined = "\n\n---\n\n".join(all_content)
            full_query = f"以下のファイル内容を分析してください:\n\n{combined[:6000]}\n\n質問: {query}"
            print("[NotebookLM] 質問送信中...", file=sys.stderr)
            result = await client.chat.ask(nb.id, full_query)
        else:
            print("[NotebookLM] 質問送信中...", file=sys.stderr)
            result = await client.chat.ask(nb.id, query)

        return {
            "notebook_id": nb.id,
            "notebook_name": name,
            "query": query,
            "answer": result.answer if hasattr(result, "answer") else str(result),
            "citations": getattr(result, "citations", []),
            "files": files,
        }


async def research_url(url: str, query: str, notebook_name: str = None) -> dict:
    """URL を NotebookLM に追加してリサーチする"""
    try:
        from notebooklm import NotebookLMClient  # noqa: PLC0415
    except ImportError:
        return {"error": "notebooklm-py がインストールされていません。"}

    if not check_auth():
        return {"error": "未認証です。`notebooklm login` を実行してください。"}

    name = notebook_name or f"{NOTEBOOK_PREFIX}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    async with await NotebookLMClient.from_storage() as client:
        nb = await client.notebooks.create(name)
        print(f"[NotebookLM] ノートブック作成: {name} (id: {nb.id[:8]}...)", file=sys.stderr)

        print(f"[NotebookLM] URL 追加中: {url}", file=sys.stderr)
        await client.sources.add_url(nb.id, url, wait=True)

        print(f"[NotebookLM] 質問送信中: {query}", file=sys.stderr)
        result = await client.chat.ask(nb.id, query)

        return {
            "notebook_id": nb.id,
            "notebook_name": name,
            "query": query,
            "answer": result.answer if hasattr(result, "answer") else str(result),
            "citations": getattr(result, "citations", []),
            "url": url,
        }


def print_result(result: dict):
    """結果を整形して表示する"""
    if "error" in result:
        print(f"\n[ERROR] {result['error']}", file=sys.stderr)
        setup_guide()
        sys.exit(1)

    print("\n" + "=" * 60)
    print(f"Notebook: {result.get('notebook_name', '')}")
    print(f"Query   : {result.get('query', '')}")
    print("=" * 60)
    print("\n## NotebookLM の回答\n")
    print(result.get("answer", ""))

    if result.get("summary"):
        print("\n## サマリー\n")
        print(result["summary"])

    citations = result.get("citations", [])
    if citations:
        print(f"\n## 引用 ({len(citations)}件)\n")
        for i, c in enumerate(citations[:5], 1):
            print(f"{i}. {c}")

    print("\n" + "=" * 60)
    print(f"NotebookLM ID: {result.get('notebook_id', '')[:16]}...")
    print("=" * 60)


MASTER_BRAIN_NOTEBOOK = "jibun-master-brain"


def add_to_master_brain(files: list):
    """ファイルを Master Brain ノートブックにソースとして追加する"""
    import subprocess  # noqa: PLC0415

    if not check_auth():
        print("[ERROR] 未認証です。`notebooklm login` を実行してください。", file=sys.stderr)
        sys.exit(1)

    print(f"[Master Brain] ノートブック切り替え: {MASTER_BRAIN_NOTEBOOK}", file=sys.stderr)
    subprocess.run(["notebooklm", "use", MASTER_BRAIN_NOTEBOOK], check=False)

    for f in files:
        path = Path(f)
        if not path.exists():
            print(f"[Master Brain] ファイルが見つかりません: {f}", file=sys.stderr)
            continue
        print(f"[Master Brain] ソース追加: {path.name}", file=sys.stderr)
        result = subprocess.run(
            ["notebooklm", "source", "add", str(path)],
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            print(f"[Master Brain] ✅ 追加完了: {path.name}", file=sys.stderr)
        else:
            print(f"[Master Brain] ❌ 追加失敗: {path.name} — {result.stderr.strip()}", file=sys.stderr)


def generate_artifact(artifact_type: str, prompt: str = ""):
    """NotebookLM でリサーチ成果物を生成する"""
    import subprocess  # noqa: PLC0415

    valid_types = ["slide-deck", "flashcards", "mind-map", "data-table", "audio", "quiz", "infographic", "video"]
    if artifact_type not in valid_types:
        print(f"[ERROR] 無効な成果物タイプ: {artifact_type}", file=sys.stderr)
        print(f"       有効なタイプ: {', '.join(valid_types)}", file=sys.stderr)
        sys.exit(1)

    cmd = ["notebooklm", "generate", artifact_type]
    if prompt:
        cmd.append(prompt)
    if artifact_type == "audio":
        cmd.append("--wait")

    print(f"[NotebookLM] 成果物生成中: {artifact_type}", file=sys.stderr)
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"[NotebookLM] ✅ 生成完了: {artifact_type}")
        if result.stdout:
            print(result.stdout)
    else:
        print(f"[NotebookLM] ❌ 生成失敗: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="NotebookLM zero-token research helper for Claude Code /deep-research",
    )
    parser.add_argument("query", nargs="?", help="リサーチするトピックや質問")
    parser.add_argument("--files", nargs="+", metavar="FILE", help="分析するファイルパス (複数可)")
    parser.add_argument("--url", help="分析するURL")
    parser.add_argument("--notebook", help="ノートブック名 (省略時は自動生成)")
    parser.add_argument("--setup", action="store_true", help="セットアップ状況を確認する")
    parser.add_argument("--json", dest="output_json", action="store_true", help="結果を JSON で出力する")
    parser.add_argument(
        "--add-to-master-brain",
        nargs="+",
        metavar="FILE",
        help=f"指定ファイルを {MASTER_BRAIN_NOTEBOOK} ノートブックにソース追加する",
    )
    parser.add_argument(
        "--generate",
        metavar="TYPE",
        help="成果物を生成する (slide-deck/flashcards/mind-map/data-table/audio/quiz/infographic/video)",
    )
    parser.add_argument(
        "--generate-prompt",
        metavar="PROMPT",
        default="",
        help="--generate に渡す追加プロンプト",
    )

    args = parser.parse_args()

    if args.setup:
        print("[Check] NotebookLM セットアップ確認中...")
        try:
            import notebooklm as nlm_module  # noqa: PLC0415
            version = getattr(nlm_module, "__version__", "unknown")
            print(f"[OK] notebooklm-py: {version}")
        except ImportError:
            print("[NG] notebooklm-py: 未インストール")
            setup_guide()
            sys.exit(1)

        if check_auth():
            print(f"[OK] 認証: {STORAGE_PATH}")
            print("\n[OK] セットアップ完了！ /deep-research コマンドを使用できます。")
        else:
            print("[NG] 認証: 未ログイン")
            print("     run: notebooklm login")
            setup_guide()
            sys.exit(1)
        return

    # Master Brain へのソース追加（単独モード）
    if args.add_to_master_brain and not args.query and not args.files and not args.url:
        add_to_master_brain(args.add_to_master_brain)
        return

    # 成果物生成（単独モード）
    if args.generate and not args.query and not args.files and not args.url:
        generate_artifact(args.generate, args.generate_prompt)
        return

    if not args.query and not args.files and not args.url:
        parser.print_help()
        sys.exit(1)

    query = args.query or "このドキュメントを分析して主要なポイントを教えてください"

    if args.files:
        result = asyncio.run(research_files(args.files, query, args.notebook))
    elif args.url:
        result = asyncio.run(research_url(args.url, query, args.notebook))
    else:
        result = asyncio.run(research_topic(query, args.notebook))

    if args.output_json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print_result(result)

    # リサーチ後に成果物生成（オプション）
    if args.generate:
        generate_artifact(args.generate, args.generate_prompt)

    # リサーチ後に Master Brain へ追加（オプション）
    if args.add_to_master_brain:
        add_to_master_brain(args.add_to_master_brain)


if __name__ == "__main__":
    main()
