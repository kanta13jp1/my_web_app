# Claude Code Remote Session Prefix Convention

> **ソース**: WBS Issue [#1267](https://github.com/kanta13jp1/my_web_app/issues/1267) — 「セッション名プレフィックス設定による my_web_app 専用セッションの可視化」
>
> **目的**: 複数 project / 開発者が claude.ai/code 上で remote session を並行運用する際に、自分株式会社 my_web_app セッションを **`jibun-`** prefix で即座に識別可能にする.

---

## convention

### Format

remote session を起動する全 instance は session name を以下 prefix 付で命名:

```
jibun-<instance>-<sub-id>
```

| 部分 | 意味 | 例 |
| --- | --- | --- |
| `jibun-` | 自分株式会社 project 識別子 (必須) | `jibun-` |
| `<instance>` | 11 種 instance 識別子 (= part 102 commit convention と統一) | `win`, `vscode`, `ps1`-`ps6`, `codex1`, `codex2`, `web`, `mobile` |
| `<sub-id>` | session 種別 / part 番号 / 任意 sub | `132-103`, `s145`, `audit-202604` |

### 例

```
jibun-win-132-103          # Win版 #132 part 103
jibun-vscode-s22           # VSCode S22
jibun-ps1-s22              # PS#1 S22
jibun-codex2-deploy-fix    # Codex#2 / 特定 task
jibun-mobile-ios-uat       # 📱 mobile / iOS UAT
```

---

## 自動付与 (= Claude Code v2.1+ feature)

Claude Code v2.1.119+ で `--remote-control-session-name-prefix` flag + `CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX` env var が利用可能.

### 環境変数 (= Recommended / 全 instance 推奨)

各 instance の shell 起動時に:

```bash
# Windows PowerShell (例: ~/Documents/PowerShell/profile.ps1)
$env:CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX = "jibun-win"

# bash / zsh (例: ~/.bashrc / ~/.zshrc)
export CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX="jibun-win"
```

instance 別 prefix:
- Win → `jibun-win`
- VSCode → `jibun-vscode`
- PS#N → `jibun-ps<N>`
- Codex#N → `jibun-codex<N>`

### CLI flag (= 一時 override)

```bash
claude --remote-control-session-name-prefix jibun-win-132-103
```

= 特定 part / session 用に override.

---

## .claude/settings.json サポート (= 将来対応)

将来 Claude Code がプロジェクト単位 settings をサポートするようになれば、`.claude/settings.json` に:

```json
{
  "remoteControl": {
    "sessionNamePrefix": "jibun-${instance:-win}"
  }
}
```

= 環境変数 fallback と組合せ.

---

## 検証

session 開始後 claude.ai/code で session list を見ると:

```
jibun-win-132-103       <-- 識別容易 ✅
jibun-vscode-s22        <-- 識別容易 ✅
my-other-project-foo    <-- 別 project (= 干渉なし)
```

---

## inject-rules.txt 追加候補

```
[SESSION-PREFIX-33] (Win版#132 part 103 · 2026-04-30 追加) Claude Code remote session は jibun- prefix 必須:
  format: jibun-<instance>-<sub-id>
  env: CLAUDE_REMOTE_CONTROL_SESSION_NAME_PREFIX="jibun-<instance>"
  詳細: docs/CLAUDE_CODE_SESSION_PREFIX.md
  既存軸 cross-ref: AI_FLEET_SYNERGY #1 (Strict Routing) / SECOND_BRAIN #3 (Master Index)
```

---

## 関連 Issue

- [#1267](https://github.com/kanta13jp1/my_web_app/issues/1267) — 本 doc 起源
- [docs/COMMIT_MESSAGE_CONVENTION.md](./COMMIT_MESSAGE_CONVENTION.md) — instance 識別子 (= 11 種 / 同一 convention)

---

*Win版#132 part 103 / 2026-04-30 / Issue #1267 dogfood / Claude Code v2.1.119+ feature 活用 / 12 fleet 共通*
