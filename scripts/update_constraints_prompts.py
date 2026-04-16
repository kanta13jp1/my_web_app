#!/usr/bin/env python3
"""
update_constraints_prompts.py
docs/instance-constraints.md の各インスタンス推奨プロンプトに
セッション開始時バージョンチェック手順を追記する。
"""
import re, sys, os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONSTRAINTS_FILE = os.path.join(REPO_ROOT, "docs", "instance-constraints.md")

with open(CONSTRAINTS_FILE, "r", encoding="utf-8") as f:
    content = f.read()

# ---- VSCode版 ----
OLD_VSCODE = """\
### VSCode版

```
このインスタンスはVSCode版です。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、以下の順で実行してください:
1. docs/cross-instance-prs/ の pending タスクをすべて処理
2. Rule 16: 本番 https://my-web-app-b67f4.web.app/ をPlaywright MCP でスクリーンショット取得・表示チェック
3. Rule 19: UI改善ツールチェーン (design-skills → Figma MCP → AIDesigner MCP → 実装)
4. 新制約発見時は docs/instance-constraints.md に追記
```"""

NEW_VSCODE = """\
### VSCode版

```
このインスタンスはVSCode版です。

【セッション開始時必須】まずバージョンチェックを実行してください:
  PYTHONUTF8=1 python3 scripts/check_versions.py
バージョン更新があれば docs/tool-versions.md の制約解消チェックリストを確認し、
解消済みなら docs/instance-constraints.md から該当行を削除して役割分担を見直すこと。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、以下の順で実行してください:
1. docs/cross-instance-prs/ の pending タスクをすべて処理
2. Rule 16: 本番 https://my-web-app-b67f4.web.app/ をPlaywright MCP でスクリーンショット取得・表示チェック
3. Rule 19: UI改善ツールチェーン (design-skills → Figma MCP → AIDesigner MCP → 実装)
4. 新制約発見時は docs/instance-constraints.md に追記
```"""

# ---- Windowsアプリ版 ----
OLD_WIN = """\
### Windowsアプリ版

```
このインスタンスはWindowsアプリ版です。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、標準フローで実行してください:
1. Rule 10: docs/ 全件分析 (矛盾・鮮度切れ修正)
2. AI大学: WebSearch で新規プロバイダー候補を調査 → migration 追加
3. notebooklm Master Brain 更新 (PYTHONUTF8=1 必須)
4. 新制約発見時は docs/instance-constraints.md に追記
```"""

NEW_WIN = """\
### Windowsアプリ版

```
このインスタンスはWindowsアプリ版です。

【セッション開始時必須】まずバージョンチェックを実行してください:
  PYTHONUTF8=1 python3 scripts/check_versions.py
バージョン更新があれば docs/tool-versions.md の制約解消チェックリストを確認し、
解消済みなら docs/instance-constraints.md から該当行を削除して役割分担を見直すこと。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、標準フローで実行してください:
1. Rule 10: docs/ 全件分析 (矛盾・鮮度切れ修正)
2. AI大学: WebSearch で新規プロバイダー候補を調査 → migration 追加
3. notebooklm Master Brain 更新 (PYTHONUTF8=1 必須)
4. 新制約発見時は docs/instance-constraints.md に追記
```"""

# ---- PowerShell版 ----
OLD_PS = """\
### PowerShell版

```
このインスタンスはPowerShell版です (推奨モデル: ルーティンはclaude-haiku-4-5)。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、以下の順で実行してください:
1. Rule 17: .github/workflows/ 最適化チェック (エラーステップ削除・timeout確認)
2. quota-monitor.yml の実行結果確認 (ai_quota_usage テーブル)
3. T-1 ブログ投稿タスクのスケジュール確認
4. 新制約発見時は docs/instance-constraints.md に追記
```"""

NEW_PS = """\
### PowerShell版

```
このインスタンスはPowerShell版です (推奨モデル: ルーティンはclaude-haiku-4-5)。

【セッション開始時必須】まずバージョンチェックを実行してください:
  PYTHONUTF8=1 python3 scripts/check_versions.py
バージョン更新があれば docs/tool-versions.md の制約解消チェックリストを確認し、
解消済みなら docs/instance-constraints.md から該当行を削除して役割分担を見直すこと。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、以下の順で実行してください:
1. Rule 17: .github/workflows/ 最適化チェック (エラーステップ削除・timeout確認)
2. quota-monitor.yml の実行結果確認 (ai_quota_usage テーブル)
3. T-1 ブログ投稿タスクのスケジュール確認
4. 新制約発見時は docs/instance-constraints.md に追記
```"""

# ---- WEB版 ----
OLD_WEB = """\
### WEB版

```
このインスタンスはWEB版(claude.ai/code)です。
【制約】notebooklm CLI・flutter analyze・deno lint・ローカルCLI は実行不可。
代替: notebooklm→WebSearch / git→GitHub MCP / analyze→cross-instance-pr依頼。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、WEB版許可タスクを実行してください:
1. WebSearch で競合21社の最新情報をリサーチ → docs/competitor-reports/ に保存 (GitHub MCP)
2. Rule 11: AI大学コンテンツ更新 (WebFetch → Supabase API 経由でupsert)
3. GitHub MCP で open PR をレビュー (Code Review MCP 使用)
4. 新制約発見時は docs/instance-constraints.md に追記 (GitHub MCP 経由でファイル更新)
```"""

NEW_WEB = """\
### WEB版

```
このインスタンスはWEB版(claude.ai/code)です。
【制約】notebooklm CLI・flutter analyze・deno lint・ローカルCLI は実行不可。
代替: notebooklm→WebSearch / git→GitHub MCP / analyze→cross-instance-pr依頼。

【セッション開始時必須】WEB版はCLIが使えないためWebFetchでリリース確認してください:
  Claude Code  : https://github.com/anthropics/claude-code/releases
  Gemini       : https://marketplace.visualstudio.com/items?itemName=google.geminicodeassist
  Copilot      : https://marketplace.visualstudio.com/items?itemName=github.copilot
  OpenAI models: https://platform.openai.com/docs/models
バージョン変更があれば docs/tool-versions.md を GitHub MCP 経由で更新し、
制約解消チェックリストを確認すること。

.github/COMPRESSED_PROMPT_V3.md と docs/instance-constraints.md を確認してください。
その後、WEB版許可タスクを実行してください:
1. WebSearch で競合21社の最新情報をリサーチ → docs/competitor-reports/ に保存 (GitHub MCP)
2. Rule 11: AI大学コンテンツ更新 (WebFetch → Supabase API 経由でupsert)
3. GitHub MCP で open PR をレビュー (Code Review MCP 使用)
4. 新制約発見時は docs/instance-constraints.md に追記 (GitHub MCP 経由でファイル更新)
```"""

replacements = [
    (OLD_VSCODE, NEW_VSCODE, "VSCode版"),
    (OLD_WIN,    NEW_WIN,    "Windowsアプリ版"),
    (OLD_PS,     NEW_PS,     "PowerShell版"),
    (OLD_WEB,    NEW_WEB,    "WEB版"),
]

changed = 0
for old, new, name in replacements:
    if old in content:
        content = content.replace(old, new, 1)
        print(f"✅ {name}: updated")
        changed += 1
    else:
        print(f"⚠️  {name}: pattern not found — skipping")

if changed == 0:
    print("No changes made.")
    sys.exit(1)

with open(CONSTRAINTS_FILE, "w", encoding="utf-8") as f:
    f.write(content)

print(f"\nDone. {changed} section(s) updated in {CONSTRAINTS_FILE}")
