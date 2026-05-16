#!/usr/bin/env python3
"""
check_versions.py — セッション開始時バージョンチェック
使用方法:
  PYTHONUTF8=1 python3 scripts/check_versions.py [--update] [--web]
  --update : tool-versions.md を自動更新する
  --web    : WEB版モード (CLIコマンドをスキップ、URLのみ表示)

出力:
  - バージョン変更があれば警告を表示
  - 解消可能な制約があれば docs/instance-constraints.md の確認を促す
  - 終了コード 0: 変更なし / 1: 更新あり / 2: エラー
"""

import subprocess, sys, json, re, os
from datetime import date

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSIONS_FILE = os.path.join(REPO_ROOT, "docs", "tool-versions.md")
CONSTRAINTS_FILE = os.path.join(REPO_ROOT, "docs", "instance-constraints.md")
TODAY = date.today().isoformat()
WEB_MODE = "--web" in sys.argv
AUTO_UPDATE = "--update" in sys.argv
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

OFFICIAL_TOOL_SOURCES = {
    "Claude Code settings": "https://docs.anthropic.com/en/docs/claude-code/settings",
    "Claude Code memory": "https://docs.anthropic.com/en/docs/claude-code/memory",
    "Gemini Code Assist release notes": "https://developers.google.com/gemini-code-assist/resources/release-notes",
    "Gemini 3 Code Assist": "https://docs.cloud.google.com/gemini/docs/codeassist/gemini-3",
    "GitHub Copilot changelog": "https://github.blog/changelog/",
    "OpenAI Codex docs": "https://developers.openai.com/codex/cloud",
    "OpenAI Docs MCP": "https://developers.openai.com/learn/docs-mcp",
}

CODEX_MEMORY_POINTERS = [
    ("repo AGENTS.md", os.path.join(REPO_ROOT, "AGENTS.md")),
    ("home AGENTS.md", os.path.expanduser("~/.codex/AGENTS.md")),
    ("home config.toml", os.path.expanduser("~/.codex/config.toml")),
]

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

def get_codex_cli_version() -> str:
    out = run(["codex", "--version"])
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

def semver_tuple(value: str) -> tuple[int, int, int]:
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", value)
    if not m:
        return (0, 0, 0)
    return tuple(int(part) for part in m.groups())

def version_at_least(value: str, minimum: str) -> bool:
    return semver_tuple(value) >= semver_tuple(minimum)

def detect_codex_memory_pointers() -> list[str]:
    pointers: list[str] = []
    for label, path in CODEX_MEMORY_POINTERS:
        if os.path.exists(path):
            pointers.append(f"{label}: {path}")
    return pointers

# ──────────────────────────────────────────────
# 既知バージョン読み込み
# ──────────────────────────────────────────────

def normalize_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")

def load_known_versions() -> dict[str, str]:
    known: dict[str, str] = {}
    try:
        with open(VERSIONS_FILE, "r", encoding="utf-8") as f:
            for line in f:
                # Match table rows like: | **Claude Code** (CLI) | `2.1.110` | ...
                m = re.search(
                    r"\|\s*\*\*(.+?)\*\*(?:\s*\(([^)]*)\))?\s*\|\s*`([^`]+)`\s*\|",
                    line,
                )
                if m:
                    base_key = normalize_key(m.group(1))
                    qualifier_key = normalize_key(m.group(2) or "")
                    version = m.group(3)
                    if qualifier_key:
                        known[f"{base_key}_{qualifier_key}"] = version
                        if base_key.endswith(f"_{qualifier_key}"):
                            known[base_key] = version
                        else:
                            known.setdefault(base_key, version)
                    else:
                        known[base_key] = version
    except FileNotFoundError:
        pass
    return known

# ──────────────────────────────────────────────
# 比較・レポート
# ──────────────────────────────────────────────

def main() -> int:
    if WEB_MODE:
        print("=== WEB版モード: CLIコマンドは実行されません ===")
        print("以下のURLでリリースを手動確認してください:")
        for name, url in OFFICIAL_TOOL_SOURCES.items():
            print(f"  {name:<32}: {url}")
        print("更新があれば docs/tool-versions.md を GitHub MCP 経由で更新してください。")
        return 0

    print(f"=== バージョンチェック {TODAY} ===")
    updates: list[tuple[str, str, str]] = []  # (tool, old, new)

    # Claude Code CLI
    cc_ver = get_claude_code_version()
    known = load_known_versions()
    old_cc = known.get("claude_code_cli", known.get("claude_code", "unknown"))
    print(f"Claude Code CLI : {cc_ver} (既知: {old_cc})")
    if cc_ver != "unknown" and cc_ver != old_cc:
        updates.append(("Claude Code CLI", old_cc, cc_ver))

    # OpenAI Codex CLI + instruction/memory pointers
    codex_ver = get_codex_cli_version()
    old_codex = known.get("openai_codex_cli", known.get("codex_cli", "unknown"))
    print(f"OpenAI Codex CLI: {codex_ver} (known: {old_codex})")
    if codex_ver != "unknown" and codex_ver != old_codex:
        updates.append(("OpenAI Codex CLI", old_codex, codex_ver))
    codex_pointers = detect_codex_memory_pointers()
    if codex_pointers:
        print("Codex instruction/memory pointers:")
        for pointer in codex_pointers:
            print(f"  - {pointer}")
    else:
        print("Codex instruction/memory pointers: not found (check AGENTS.md / ~/.codex/config.toml)")

    # VSCode 拡張
    if not WEB_MODE:
        exts = get_vscode_ext_versions()
        ext_map = {
            "anthropic.claude-code": ("Claude Code VSCode ext", "claude_code_vscode_ext"),
            "google.geminicodeassist": ("Gemini Code Assist", "gemini_code_assist"),
            "github.copilot": ("GitHub Copilot", "github_copilot"),
            "openai.chatgpt": ("OpenAI ChatGPT ext", "openai_chatgpt"),
        }
        for ext_id, (name, key) in ext_map.items():
            ver = exts.get(ext_id, "not installed")
            old = known.get(key, "unknown")
            if name == "Gemini Code Assist" and ver not in ("not installed", "unknown"):
                if version_at_least(ver, "2.77.1"):
                    print("  Gemini agent-mode log attribution: OK (2.77.1+)")
                else:
                    print("  Gemini agent-mode log attribution: update to 2.77.1+")
            print(f"{name:<30}: {ver} (既知: {old})")
            if ver not in ("not installed", "unknown") and ver != old:
                updates.append((name, old, ver))
        print("Gemini 3.1 Pro / 3.0 Flash availability is license and release-channel gated; verify in Google Code Assist before routing production fallback.")

    # Flutter
    fl_ver = get_flutter_version()
    old_fl = known.get(
        "dart_flutter_sdk",
        known.get("dart_flutter", known.get("dart/flutter", "unknown")),
    )
    print(f"Flutter/Dart SDK               : {fl_ver} (既知: {old_fl})")
    if fl_ver != "unknown" and fl_ver != old_fl:
        updates.append(("Flutter/Dart SDK", old_fl, fl_ver))

    # Deno
    deno_ver = get_deno_version()
    print(f"Deno                           : {deno_ver}")

    print()

    if not updates:
        print("✅ すべて最新。バージョン変更なし。")
        return 0

    print(f"🆕 バージョン更新検出: {len(updates)} 件")
    for tool, old, new in updates:
        print(f"   {tool}: {old} → {new}")

    print()
    print("=" * 50)
    print("📋 制約解消チェック")
    print("=" * 50)

    cc_updated = any("Claude Code" in t for t, _, _ in updates)
    if cc_updated:
        print("""
Claude Code が更新されました。WEB版の制約が解消されたか確認してください:
  □ WEB版で `notebooklm --version` が動くか
  □ WEB版で `flutter analyze` が動くか
  □ WEB版で `deno lint` が動くか
  □ WEB版で `git status` が直接動くか
  □ Write ツールで絶対パスが使えるか
解消されたら: docs/instance-constraints.md の該当行を削除/更新してください。
""")

    gemini_updated = any("Gemini" in t for t, _, _ in updates)
    if gemini_updated:
        print("""
Gemini Code Assist が更新されました:
  □ Agent mode が安定稼働するか確認
  □ Flutter/Dart 補完品質に改善があるか
  □ コンテキスト上限に変更があるか (リリースノート確認)
""")

    copilot_updated = any("Copilot" in t for t, _, _ in updates)
    if copilot_updated:
        print("""
GitHub Copilot が更新/インストールされました:
  □ Copilot Edits (複数ファイル同時編集) が使えるか
  □ Copilot Workspace が使えるか
  □ `gh copilot suggest` CLI が動くか
  → docs/tool-versions.md と docs/instance-constraints.md を更新してください。
""")

    if AUTO_UPDATE:
        _update_versions_file(updates)
        print(f"✅ docs/tool-versions.md を更新しました ({TODAY})")
    else:
        print("💡 自動更新する場合: python3 scripts/check_versions.py --update")

    return 1  # 更新あり


def _update_versions_file(updates: list[tuple[str, str, str]]) -> None:
    """tool-versions.md のバージョン数値を更新する"""
    with open(VERSIONS_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    tool_to_row_key = {
        "Claude Code CLI": "Claude Code** (CLI)",
        "OpenAI Codex CLI": "OpenAI Codex CLI** (CLI)",
        "Claude Code VSCode ext": "Claude Code** (VSCode ext)",
        "Gemini Code Assist": "Gemini Code Assist** (VSCode ext)",
        "GitHub Copilot": "GitHub Copilot** (VSCode ext)",
        "OpenAI ChatGPT ext": "OpenAI ChatGPT** (VSCode ext)",
        "Flutter/Dart SDK": "Dart/Flutter** (SDK)",
    }

    for tool, old, new in updates:
        row_key = tool_to_row_key.get(tool)
        if row_key and old != "unknown":
            content = content.replace(
                f"{row_key} | `{old}`",
                f"{row_key} | `{new}`",
            )
            # Also update the 最終確認日 column (second | after version)
            # Simple approach: add history entry
        elif row_key:
            content = re.sub(
                rf"(\| \*\*{re.escape(row_key)}\s*\|.*?)\|.*?\|.*?\|",
                rf"\1| `{new}` | {TODAY} | — |",
                content,
                count=1,
            )

    # Append to history table
    history_entry = "\n".join(
        f"| {TODAY} | {tool} | `{old}` | `{new}` | 要確認 | — |"
        for tool, old, new in updates
    )
    content = content.replace(
        "| 2026-04-16 | Claude Code CLI | — | 2.1.110 | 初回記録 | — |",
        f"| 2026-04-16 | Claude Code CLI | — | 2.1.110 | 初回記録 | — |\n{history_entry}",
    )

    with open(VERSIONS_FILE, "w", encoding="utf-8") as f:
        f.write(content)


if __name__ == "__main__":
    sys.exit(main())
