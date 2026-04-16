# ツールバージョン管理台帳

> **更新ルール**: セッション開始時に `scripts/check_versions.py` を実行し、
> バージョンが上がっていれば①この台帳を更新②制約解消チェック③**リリースノート確認 → 新機能をdevフローへ組み込み**④役割分担見直しを行う。
> WEB版は `check_versions.py` 実行不可 → WebFetch でリリースページを確認し手動更新。

---

## 現在のバージョン (2026-04-17 時点)

| ツール | 現在バージョン | 最終確認日 | 確認インスタンス |
| --- | --- | --- | --- |
| **Claude Code** (CLI) | `2.1.110` | 2026-04-16 | Windowsアプリ版 |
| **Claude Code** (VSCode ext) | `2.1.109` | 2026-04-16 | VSCode版 |
| **Gemini Code Assist** (VSCode ext) | `2.78.0` | 2026-04-16 | VSCode版 |
| **OpenAI ChatGPT** (VSCode ext) | `26.409.20454` | 2026-04-16 | VSCode版 |
| **GitHub Copilot** (VSCode ext) | 未インストール | 2026-04-16 | VSCode版 |
| **Dart/Flutter** (SDK) | `3.132.0` | 2026-04-16 | VSCode版 |
| **Deno** | `2.6.5` | 2026-04-16 | Windowsアプリ版 |
| **Claude Sonnet** (API model) | `claude-sonnet-4-6` | 2026-04-16 | 全インスタンス |
| **Claude Haiku** (API model) | `claude-haiku-4-5` | 2026-04-16 | PowerShell版 |
| **Claude Opus** (API model) | `claude-opus-4-7` | 2026-04-17 | 全インスタンス |

---

## バージョンアップ履歴

| 日付 | ツール | 旧バージョン | 新バージョン | 制約解消確認 | リリースノート新機能 | 対応 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-04-16 | Claude Code CLI | — | 2.1.110 | 初回記録 | — | — |
| 2026-04-17 | Claude Opus API | `claude-opus-4` | `claude-opus-4-7` | 制約なし (APIモデル更新) | 要確認: https://www.anthropic.com/news | Extended Thinking タスクのモデルをopus-4-7に更新 |

---

## バージョン更新時 制約解消チェックリスト

バージョンが上がったら以下を確認し、解消済みなら `docs/instance-constraints.md` を更新する。

### Claude Code (CLI / VSCode ext)

| チェック項目 | 制約インスタンス | 解消確認方法 |
| --- | --- | --- |
| WEB版での `notebooklm` CLI 実行 | WEB版 | `notebooklm --version` が動くか |
| WEB版での `flutter analyze` 実行 | WEB版 | `flutter --version` が動くか |
| WEB版での `deno lint` 実行 | WEB版 | `deno --version` が動くか |
| WEB版での直接 `git` 操作 | WEB版 | `git status` が動くか |
| Write ツールの絶対パス対応 | VSCode版 | `C:/Users/...` で Write 成功するか |
| Edit ツールの Read 省略対応 | 全インスタンス | Read 前 Edit でエラーが出ないか |

### Claude API モデル更新時

| チェック項目 | 対応内容 |
| --- | --- |
| 新モデルのリリースノートを確認 | https://www.anthropic.com/news でFeatures/Capabilities変化を確認 |
| EFのDEFAULT_SYNTHESIS_MODEL更新 | `supabase/functions/ai-assistant/index.ts` の定数を更新 |
| Extended Thinking推奨モデルを更新 | COMPRESSED_PROMPT_V3.md・CLAUDE.md・instance-constraints.md を更新 |
| 新機能をdevフローへ組み込み | 例: 新ツール使用API / 新モード / コンテキスト上限変化 → CLAUDE.mdに反映 |

### Gemini Code Assist

| チェック項目 | 現状 | 解消確認方法 |
| --- | --- | --- |
| Agent mode の安定稼働 | 実験的 | 設定で有効化し動作確認 |
| Flutter/Dart 補完品質 | — | Dart ファイルでの補完精度確認 |
| 2Mコンテキスト上限 | 2M tokens | リリースノートで上限変更確認 |

### GitHub Copilot

| チェック項目 | 現状 | 解消確認方法 |
| --- | --- | --- |
| インストール状況 | **未インストール** | `code --list-extensions \| grep copilot` |
| Copilot Workspace 利用可否 | 未確認 | github.com/features/copilot-workspace |
| ターミナル `gh copilot suggest` | 未確認 | `gh extension list \| grep copilot` |

### OpenAI / CODEX

| チェック項目 | 現状 | 解消確認方法 |
| --- | --- | --- |
| o3 API 一般公開 | 限定公開 | OpenAI API `/v1/models` で確認 |
| Codex CLI 一般公開 | ベータ | `codex --version` |
| o4-mini API 利用可否 | 要確認 | OpenAI API `/v1/models` |

---

## バージョンアップ → リリースノート確認 → devフロー組み込みマッピング

```text
【Claude API モデル更新時】
  Step 1: リリースノート確認 (https://www.anthropic.com/news)
    → 新機能例: 新ツール使用API / Extended Thinking強化 / コンテキスト上限変化 /
                新モード (Interleaved Thinking等) / 価格変化
  Step 2: 新機能をこのプロジェクトのdevフローへ組み込む
    → 新モデル名を docs/tool-versions.md に記録
    → ai-assistant/index.ts の DEFAULT_SYNTHESIS_MODEL (または Extended Thinking呼び出し) を更新
    → COMPRESSED_PROMPT_V3.md の「Claude最新機能」テーブルを更新
    → CLAUDE.md のインスタンス別モデル表を更新
    → instance-constraints.md のモデル列を更新
  Step 3: 制約解消チェック
    → 新モデルで過去の制約 (コンテキスト不足・推論精度不足等) が解消されるか確認
    → 解消済みなら instance-constraints.md から削除

【Claude Code CLI/VSCode ext 更新時】
  → WEB版制約チェックリストを全確認
  → 解消された制約を docs/instance-constraints.md から削除
  → COMPRESSED_PROMPT_V3.md の制約列を更新
  → CLAUDE.md の代替パターン記述を削除/更新

【GitHub Copilot がインストール/更新】
  → Copilot Edits / Workspace の利用可否を確認
  → AI選択フローの「Copilot Edits → Flutter多ファイル編集」を有効化
  → VSCode版の推奨ツールに追記

【Gemini Code Assist が更新】
  → Agent mode が安定したらEF全体分析タスクをGeminiに移管検討
  → コンテキスト上限が増えた場合は大規模リファクタタスクへ活用
  → リリースノート: https://marketplace.visualstudio.com/items?itemName=google.geminicodeassist

【新しい Claude モデルリリース (例: claude-sonnet-4-7, claude-opus-4-7) 】
  → ai-assistant EF の DEFAULT_SYNTHESIS_MODEL を更新
  → daily-judgment / gemini-election-analysis のモデルパラメータを更新
  → Extended Thinking推奨モデルを更新
  → この台帳の「現在のバージョン」テーブルを更新
```

---

## リリース確認先 URL

| ツール | リリースページ | 確認頻度 |
| --- | --- | --- |
| Claude Code | https://github.com/anthropics/claude-code/releases | 毎セッション (`claude --version`) |
| Claude モデル | https://www.anthropic.com/news | 毎セッション (WEB版はWebFetch) |
| Gemini Code Assist | https://marketplace.visualstudio.com/items?itemName=google.geminicodeassist | 週1回 |
| GitHub Copilot | https://marketplace.visualstudio.com/items?itemName=github.copilot | 週1回 |
| OpenAI API モデル | https://platform.openai.com/docs/models | 週1回 |
| Flutter/Dart SDK | https://docs.flutter.dev/release/release-notes | 月1回 |
