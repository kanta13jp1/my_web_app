#!/usr/bin/env python3
"""
check_versions.py — セッション開始時バージョンチェック (Rule 22)
使用方法:
  PYTHONUTF8=1 python3 scripts/check_versions.py [--update] [--web] [--release-notes]
  --update        : tool-versions.md を自動更新する
  --web           : WEB版モード (CLIコマンドをスキップ、URLのみ表示)
  --release-notes : バージョン更新時にリリースノートURLを出力 (fetch は手動)

出力:
  - バージョン変更があれば警告を表示
  - 解消可能な制約があれば docs/instance-constraints.md の確認を促す
  - 新機能情報があれば devフロー組み込みを提案
  - 終了コード 0: 変更なし / 1: 更新あり / 2: エラー
"""

import subprocess, sys, re, os
from datetime import date

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSIONS_FILE = os.path.join(REPO_ROOT, "docs", "tool-versions.md")
CONSTRAINTS_FILE = os.path.join(REPO_ROOT, "docs", "INSTANCE_CONFIG.md")
TODAY = date.today().isoformat()
WEB_MODE = "--web" in sys.argv
AUTO_UPDATE = "--update" in sys.argv
SHOW_RELEASE_NOTES = "--release-notes" in sys.argv

# ──────────────────────────────────────────────
# リリースノート URL 定義
# ──────────────────────────────────────────────

RELEASE_NOTE_URLS = {
    "Claude Code CLI":        "https://github.com/anthropics/claude-code/releases",
    "Claude Code VSCode ext": "https://github.com/anthropics/claude-code/releases",
    "Gemini Code Assist":     "https://cloud.google.com/code/docs/vscode/release-notes",
    "GitHub Copilot":         "https://github.blog/changelog/",
    "OpenAI ChatGPT ext":     "https://github.com/openai/openai-vscode/releases",
    "Flutter/Dart SDK":       "https://docs.flutter.dev/release/release-notes",
    "Claude Models":          "https://www.anthropic.com/news",
}

# ──────────────────────────────────────────────
# 現在バージョン収集
# ──────────────────────────────────────────────

def run(cmd: list[str]) -> str:
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return (result.stdout + result.stderr).strip()
    except Exception:
        return ""

def get_claude_code_version() -> str:
    out = run(["claude", "--version"])
    m = re.search(r"(\d+\.\d+\.\d+)", out)
    return m.group(1) if m else "unknown"

def get_latest_claude_code_version() -> str:
    """npm registry から最新バージョンを取得"""
    out = run(["npm", "show", "@anthropic-ai/claude-code", "dist-tags.latest"])
    m = re.search(r"(\d+\.\d+\.\d+)", out)
    return m.group(1) if m else "unknown"

def get_vscode_ext_versions() -> dict[str, str]:
    out = run(["code", "--list-extensions", "--show-versions"])
    versions: dict[str, str] = {}
    for line in out.splitlines():
        m = re.match(r"^([\w.\-]+)@([\d.]+)$", line.strip())
        if m:
            versions[m.group(1).lower()] = m.group(2)
    return versions

def get_deno_version() -> str:
    out = run(["deno", "--version"])
    m = re.search(r"deno\s+(\d+\.\d+\.\d+)", out)
    return m.group(1) if m else "unknown"

def get_flutter_version() -> str:
    out = run(["flutter", "--version"])
    m = re.search(r"Flutter\s+(\d+\.\d+\.\d+)", out)
    return m.group(1) if m else "unknown"

# ──────────────────────────────────────────────
# 既知バージョン読み込み
# ──────────────────────────────────────────────

def load_known_versions() -> dict[str, str]:
    known: dict[str, str] = {}
    try:
        with open(VERSIONS_FILE, "r", encoding="utf-8") as f:
            seen_cc = False
            for line in f:
                m = re.search(r"\|\s*\*\*(.+?)\*\*.*?\|\s*`([^`]+)`\s*\|", line)
                if m:
                    name = m.group(1)
                    ver  = m.group(2)
                    key  = name.lower().replace(" ", "_").replace("/", "_")
                    # Claude Code (CLI) と (VSCode ext) を区別
                    if "claude_code" in key and "(cli)" in name.lower() and not seen_cc:
                        known["claude_code_cli"] = ver
                        seen_cc = True
                    elif "claude_code" in key and "vscode" in name.lower():
                        known["claude_code_vscode"] = ver
                    else:
                        known[key] = ver
    except FileNotFoundError:
        pass
    return known

# ──────────────────────────────────────────────
# 比較・レポート
# ──────────────────────────────────────────────

def print_release_note_reminder(tool: str, old: str, new: str) -> None:
    url = RELEASE_NOTE_URLS.get(tool) or RELEASE_NOTE_URLS.get("Claude Code CLI")
    print(f"\n📖 リリースノート確認 ({tool}: {old} → {new}):")
    print(f"   URL: {url}")
    print(f"   確認項目:")
    print(f"     □ 新機能追加 → docs/INSTANCE_CONFIG.md に記録 → CLAUDE.md/devフローへ組み込み")
    print(f"     □ WEB版制約の解消 → docs/INSTANCE_CONFIG.md の制約カタログを更新")
    print(f"     □ モデル追加 → docs/tool-versions.md + INSTANCE_CONFIG.md を更新")
    print(f"     □ Breaking Changes → 影響受けるEF/ワークフローを修正")


def main() -> int:
    if WEB_MODE:
        print("=== WEB版モード: CLIコマンドは実行されません ===")
        print("以下のURLでリリースを手動確認してください:")
        for tool, url in RELEASE_NOTE_URLS.items():
            print(f"  {tool:<25}: {url}")
        print()
        print("Claude Opusモデル最新版 (2026-04-17): claude-opus-4-7")
        print("  ⚠️ Opus 4.7 は Extended Thinking 非対応 → ultrathink は Sonnet 4.6 で実行")
        print("更新があれば docs/tool-versions.md を GitHub MCP 経由で更新してください。")
        return 0

    print(f"=== バージョンチェック {TODAY} (Rule 22) ===")
    updates: list[tuple[str, str, str]] = []  # (tool, old, new)
    known = load_known_versions()

    # ── Claude Code CLI ──
    cc_ver = get_claude_code_version()
    cc_latest = get_latest_claude_code_version()
    old_cc = known.get("claude_code_cli", "unknown")
    print(f"Claude Code CLI  : 現在={cc_ver} / npm最新={cc_latest} (台帳={old_cc})")
    if cc_latest != "unknown" and cc_ver != "unknown" and cc_latest != cc_ver:
        print(f"  🆕 更新利用可能! → `npm update -g @anthropic-ai/claude-code` で更新")
    if cc_ver != "unknown" and cc_ver != old_cc:
        updates.append(("Claude Code CLI", old_cc, cc_ver))

    # ── VSCode 拡張 ──
    exts = get_vscode_ext_versions()
    ext_map = {
        "anthropic.claude-code":  ("Claude Code VSCode ext", "claude_code_vscode"),
        "google.geminicodeassist": ("Gemini Code Assist",     "gemini_code_assist"),
        "github.copilot":          ("GitHub Copilot",          "github_copilot"),
        "openai.chatgpt":          ("OpenAI ChatGPT ext",      "openai_chatgpt"),
    }
    for ext_id, (name, key) in ext_map.items():
        ver = exts.get(ext_id, "not installed")
        old = known.get(key, "unknown")
        print(f"{name:<30}: {ver} (台帳: {old})")
        if ver not in ("not installed", "unknown") and ver != old:
            updates.append((name, old, ver))

    # ── Flutter ──
    fl_ver = get_flutter_version()
    old_fl = known.get("dart_flutter__sdk_", "unknown")
    print(f"Flutter/Dart SDK               : {fl_ver} (台帳: {old_fl})")
    if fl_ver != "unknown" and fl_ver != old_fl:
        updates.append(("Flutter/Dart SDK", old_fl, fl_ver))

    # ── Deno ──
    deno_ver = get_deno_version()
    print(f"Deno                           : {deno_ver}")

    # ── Claude モデル確認リマインダー ──
    print()
    print("📌 Claude API モデル確認 (台帳値):")
    print(f"   Sonnet: {known.get('claude_sonnet__api_model_', 'claude-sonnet-4-6')}")
    print(f"   Haiku : {known.get('claude_haiku__api_model_', 'claude-haiku-4-5')}")
    print(f"   Opus  : {known.get('claude_opus__api_model_', 'claude-opus-4-7')}")
    print("   ⚠️ Opus 4.7 は Extended Thinking 非対応 → ultrathink には Sonnet 4.6 を使用")
    print()

    if not updates:
        print("✅ すべて最新。バージョン変更なし。")
        print("💡 新しい Claude モデルがリリースされた場合はユーザーが手動で教えてください。")
        return 0

    print(f"🆕 バージョン更新検出: {len(updates)} 件")
    for tool, old, new in updates:
        print(f"   {tool}: {old} → {new}")

    print()
    print("=" * 55)
    print("📋 制約解消チェック + リリースノート確認 (Rule 22 Step 3-4)")
    print("=" * 55)

    cc_updated = any("Claude Code" in t for t, _, _ in updates)
    if cc_updated:
        print("""
Claude Code が更新されました:
  □ WEB版で `notebooklm --version` が動くか → 解消なら INSTANCE_CONFIG.md 更新
  □ WEB版で `flutter analyze` が動くか
  □ WEB版で `deno lint` が動くか
  □ WEB版で `git status` が直接動くか
  □ Write ツールで絶対パスが使えるか
""")

    gemini_updated = any("Gemini" in t for t, _, _ in updates)
    if gemini_updated:
        print("""
Gemini Code Assist が更新されました:
  □ Agent mode の安定稼働を確認
  □ Flutter/Dart 補完品質を確認
  □ コンテキスト上限の変化を確認
""")

    # リリースノート表示
    if SHOW_RELEASE_NOTES or cc_updated or gemini_updated:
        for tool, old, new in updates:
            print_release_note_reminder(tool, old, new)

    print()
    print("📝 devフロー組み込みチェック (Rule 22 Step 4):")
    print("   □ docs/INSTANCE_CONFIG.md の変更ログに追記")
    print("   □ CLAUDE.md の該当 Rule に新機能を追記")
    print("   □ docs/tool-versions.md のバージョン更新履歴を追記")
    print("   □ 影響を受ける EF のモデルパラメータを更新")

    if AUTO_UPDATE:
        _update_versions_file(updates)
        print(f"\n✅ docs/tool-versions.md を更新しました ({TODAY})")
    else:
        print("\n💡 自動更新: python3 scripts/check_versions.py --update")
        print("💡 リリースノートも確認: python3 scripts/check_versions.py --release-notes")

    return 1  # 更新あり


def _update_versions_file(updates: list[tuple[str, str, str]]) -> None:
    """tool-versions.md のバージョン数値を更新する"""
    try:
        with open(VERSIONS_FILE, "r", encoding="utf-8") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"⚠️  {VERSIONS_FILE} が見つかりません。先に作成してください。")
        return

    tool_to_row_key = {
        "Claude Code CLI":        "Claude Code** (CLI)",
        "Claude Code VSCode ext": "Claude Code** (VSCode ext)",
        "Gemini Code Assist":     "Gemini Code Assist** (VSCode ext)",
        "GitHub Copilot":         "GitHub Copilot** (VSCode ext)",
        "OpenAI ChatGPT ext":     "OpenAI ChatGPT** (VSCode ext)",
        "Flutter/Dart SDK":       "Dart/Flutter** (SDK)",
    }

    for tool, old, new in updates:
        row_key = tool_to_row_key.get(tool)
        if row_key and old not in ("unknown", "—"):
            content = content.replace(
                f"| `{old}` |",
                f"| `{new}` |",
                1,
            )

    # 履歴エントリを追加 (既存の最後の履歴行の後に挿入)
    history_entries = "\n".join(
        f"| {TODAY} | {tool} | `{old}` | `{new}` | 要確認: {RELEASE_NOTE_URLS.get(tool, '')} | 要組み込み | — |"
        for tool, old, new in updates
    )
    # 最後の履歴行を探して挿入
    last_history_line = re.search(r"(\| 20\d{2}-\d{2}-\d{2} \|[^\n]+\n)(?!\| 20)", content)
    if last_history_line:
        insert_pos = last_history_line.end()
        content = content[:insert_pos] + history_entries + "\n" + content[insert_pos:]

    with open(VERSIONS_FILE, "w", encoding="utf-8") as f:
        f.write(content)


if __name__ == "__main__":
    sys.exit(main())
