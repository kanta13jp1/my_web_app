# AI Fallback Runbook — 自分株式会社

## #1787 2026-05 AI Tool Routing Update

This update folds the May 2026 AI-tool signals into the current two-instance
operating model:

- Claude Code #1 reviews adoption risk and decides adopt/defer/ignore for
  Claude Code, Codex CLI, Copilot, Gemini Code Assist, Cursor, and Devin release
  signals.
- Codex #1 owns scoped implementation, CI, merge follow-up, WBS sync
  verification, branch/worktree cleanup, and session memory/disk hygiene.
- Codex #2 and Codex #3 stay historical. Do not start dormant Codex lanes or
  PowerShell lane instances to process WBS tasks.
- Guarded subagents are allowed as child workers under Claude Code #1 or Codex
  #1 when `docs/SUBAGENT_ORCHESTRATION_POLICY.md` permits the pattern. They
  must not become new WBS owners, bypass approval gates, or leave long-running
  processes behind.
- Use `docs/ai-tool-changelog/2026-05.md` as the local source summary and verify
  any release claim against the official source before promoting it into a
  production fallback path.
- Copilot Custom Agents are design-only until explicitly activated. The current
  registry lives in `.github/agents/README.md`; agents are advisory and must not
  merge, deploy, write production data, or run side-effecting automation.

Adoption notes for this cycle:

- Claude Code v2.1.121 MCP `alwaysLoad` and `claude plugin prune` can reduce
  tool-search friction, but Claude Code #1 must approve any managed-setting or
  plugin-store change.
- Claude Code v2.1.116 `/resume` speed and MCP startup improvements support
  long-session recovery, but they do not change the top-level two-instance cap.
- Claude Code v2.1.122 Bedrock service-tier selection and v2.1.108 prompt-cache
  flags are provider-configuration candidates, not default environment changes.
- OpenAI Codex persisted goals are available to Codex #1 when the active app or
  CLI runtime exposes the goal APIs. Use them to retain the objective and
  continuation state, but keep the durable proof in the linked Issue, scoped
  branch, PR, and validation result. A goal never grants extra authority to
  merge, deploy, or change production data.
- Do not pin a task class to the historical GPT-5.5 name. Apply the configured
  adaptive model router to the models and effort levels exposed by the current
  runtime, while preserving any explicit user selection.
- Thread Automations (#1837) and persisted goals solve different problems:
  automations provide an explicit schedule, while a goal preserves the state of
  one approved body of work. Neither is a reason to create an unattended
  dependency-update-to-merge pipeline.
- Cursor context-usage breakdown, Gemini Code Assist release notes, and Devin
  CI-aware auto-fix are advisory signals unless a local verified workflow is
  explicitly routed.

## 2026-05-07 Official AI Tool Update Gate (#1706)

This runbook now treats AI-tool release claims as "verify before routing". Use
these official sources before promoting a tool into the production fallback
path:

- Claude Code: official settings and memory docs confirm managed settings,
  notification channels, hooks, and CLAUDE.md memory hierarchy. Do not require
  unverified slash commands such as `/tui` or `/resume <PR URL>` unless a
  current Claude Code release note confirms them.
- OpenAI Codex: use the official Codex docs and OpenAI Docs MCP. Codex work is
  routed through the Windows Codex #1 worktree and must keep AGENTS.md /
  `~/.codex/config.toml` as pointer-based instruction memory, not a giant prompt.
- Google coding agents: Gemini Code Assist agent mode remains preview-gated.
  Since 2026-06-18, the IDE extension and Gemini CLI no longer serve requests
  for Individuals, Google AI Pro, or Google AI Ultra; those users route through
  Antigravity instead. Gemini Code Assist Standard/Enterprise remains a
  candidate only after its license and local availability are verified.
- GitHub Copilot: official changelog confirms Copilot coding agent startup
  improvements and Claude/Codex partner-agent availability. Treat performance
  claims as changelog-scoped; this runbook records the official 50% startup
  improvement, not the older unverified 20% figure.

Official source pointers:

- https://docs.anthropic.com/en/docs/claude-code/settings
- https://docs.anthropic.com/en/docs/claude-code/memory
- https://code.claude.com/docs/en/changelog
- https://code.claude.com/docs/en/tools-reference#powershell-tool
- https://code.claude.com/docs/en/llm-gateway
- https://code.claude.com/docs/en/mcp
- https://developers.openai.com/codex/cloud
- https://developers.openai.com/learn/docs-mcp
- https://developers.google.com/gemini-code-assist/resources/release-notes
- https://docs.cloud.google.com/gemini/docs/codeassist/gemini-3
- https://docs.flutter.dev/ai/mcp-server
- https://docs.cloud.google.com/gemini/docs/codeassist/overview
- https://github.blog/changelog/2026-02-26-claude-and-codex-now-available-for-copilot-business-pro-users/
- https://github.blog/changelog/2026-03-19-copilot-coding-agent-now-starts-work-50-faster/

Related ai-tool-update Issues: #1644, #1645, #1646, #1647, #1706.

#1646 UI/browser QA and generated-image provenance are defined in
`docs/CODEX_UI_QA_PLAYBOOK.md`. For UI PRs, Codex #1 must record route,
viewport, screenshot/Playwright evidence, console/page/request review, and
generated-image rights/provenance before marking the work review-ready.

#1644 dynamic context injection is defined in
`docs/DYNAMIC_CONTEXT_INJECTION.md` and `config/context-injection-map.json`.
At session start, Codex #1 should run `python scripts/context_injection_check.py`
or `python scripts/codex_session_check.py` to see keyword-matched docs, skills,
NotebookLM query candidates, target Issue links, and unapplied NotebookLM intake
counts before implementation begins.

> 作成: 2026-04-24 (PS#6 S26)  
> 目的: Claude Code quota 制限時に開発・自動化が完全停止しないための手順書

---

## クイックリファレンス: 今何が使えないか確認

```bash
# Claude Code 残量確認 (claude.ai/settings → Usage)
# GHA quota-monitor.yml の最新ラン確認
gh run list --workflow=quota-monitor.yml --limit 1
```

---

## シナリオ 1: Claude Code CLI quota 超過

**症状**: `claude` コマンドが "rate limit" / "quota exceeded" を返す

### 開発作業のフォールバック順位

| 作業種別 | Primary | Fallback 1 | Fallback 2 |
|---------|---------|-----------|-----------|
| コード補完・小修正 (5分以内) | GitHub Copilot (VS Code) | Copilot Chat | 手動 |
| Dart/Flutter ファイル編集 | GitHub Copilot + Dart/Flutter MCP | Antigravity + Dart/Flutter MCP | Gemini Code Assist Standard/Enterprise + Dart/Flutter MCP |
| 大規模リファクタリング (500行+) | Codex | Antigravity + Dart/Flutter MCP | 手動分割 |
| SQL / アルゴリズム最適化 | Codex CLI | Antigravity | 手動 |
| 設計・戦略・ルール判断 | claude.ai (WEBブラウザ版) | NotebookLM | ドキュメント参照 |
| EF cleanup / hub migration | claude.ai (WEB版) | Codex | 手動 |
| Dart format チェック | `dart format .` (CLI直接) | CI確認 | — |

### Codex CLI セットアップ (未設定の場合)

```bash
# インストール (OpenAI API Key 必要)
npm install -g @openai/codex
export OPENAI_API_KEY="sk-..."

# 使用例
codex "lib/pages/home_page.dart の fetchData() にエラーハンドリングを追加して"
codex "supabase/functions/tools-hub/index.ts に action=habit.list を追加"
```

### Dart/Flutter MCP + Google coding agent セットアップ

```text
1. Dart 3.9+ を確認する: dart --version
2. project の .gemini/settings.json が SDK 内蔵 `dart mcp-server` を起動する
3. Antigravity では MCP store の Dart を選ぶか、同じ command を手動登録する
4. Gemini Code Assist Standard/Enterprise の VS Code Agent Mode では `/mcp` で接続確認する
5. VS Code Dart extension v3.116+ では workspace の `dart.mcpServer: true` も有効にする
```

`dart pub global run dart_mcp_server` は使用しない。Individuals / Google AI
Pro / Google AI Ultra は 2026-06-18 以降 Gemini Code Assist IDE / Gemini CLI
の対象外なので、Antigravity へ route する。

### インスタンス別フォールバック割当

| インスタンス | Claude quota 超過時の代替 |
|------------|------------------------|
| **Win版 (Claude Code)** | Codex CLI + Copilot + Antigravity + NotebookLM + claude.ai WEB版 |
| **Win版 (Codex CLI)** | Codex CLI (主担当) + Copilot + Antigravity; Gemini Code Assist は Standard/Enterprise license 確認時のみ |

> 旧 12 instance (PS版#1-6 / VSCode版 / WEB版 / スマホ版 / Codex#1 / Codex#2) は 2026-05-04 dormant 化 (= [`docs/MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md)). reactivation 時のみ各 fallback 適用.

---

## シナリオ 2: GitHub Actions での Anthropic API quota 超過

**影響ワークフロー**: `claude-agent-review.yml` のみ

**対応済み** (2026-04-24 PS#6 S26): Gemini 1.5 Flash への自動フォールバック実装済み。

| 状態 | 挙動 |
|-----|------|
| Anthropic OK | Claude sonnet-4-6 でレビュー |
| Anthropic quota 超過 → Gemini OK | Gemini 1.5 Flash でレビュー |
| 両方 quota 超過 | スキップ (PR ブロックなし) |

**GEMINI_API_KEY 設定手順** (未設定の場合):

```text
1. aistudio.google.com → API Keys → Create API Key
2. GitHub → Settings → Secrets → GEMINI_API_KEY に追加
3. 無料枠: 1分15リクエスト / 1日1500リクエスト (個人開発には十分)
```

---

## シナリオ 3: Schedule タスクの quota 対応

### 現状の GHA ワークフロー — Claude 依存度

| ワークフロー | Claude 依存 | quota 超過時の挙動 |
|------------|------------|-----------------|
| `cs-check.yml` | **なし** | 影響なし ✅ |
| `daily-report.yml` | **なし** | 影響なし ✅ |
| `ai-university-update.yml` | **なし** (RSS only) | 影響なし ✅ |
| `quota-monitor.yml` | **なし** (監視のみ) | 影響なし ✅ |
| `claude-agent-review.yml` | あり → Gemini fallback | Gemini でカバー ✅ |
| `blog-engagement.yml` | Claude → Gemini → template | Gemini またはテンプレ返信で継続 ✅ |
| `horse-racing-update.yml` | **なし** | 影響なし ✅ |
| `wbs-staleness-audit.yml` | **なし** | 影響なし ✅ |

**結論**: スケジュールタスクの大半はすでに Claude 非依存。`blog-engagement.yml` のコメント返信も Gemini / template fallback で継続する。

### Claude Code CLI ベースのタスク (手動代替手順)

以下のタスクは元々 Claude Code CLI を前提としているが、フォールバック可能:

**daily-report AI 分析セクション**:
```bash
# Claude unavailable → 手動でコメントを追記するだけでOK
# または quota-monitor.yml の出力を参照して手動 commit
git add docs/daily-reports/$(date +%Y-%m-%d).md
git commit -m "自動: 日次レポート $(date +%Y-%m-%d) [manual]"
```

**EF cleanup / hub migration** (PS#6 担当):
```bash
# Codex で代替
codex "supabase/functions/ の DEAD_LIST 削除対象ディレクトリを特定して削除スクリプトを生成"
# または claude.ai WEBブラウザ版を使う (同じAPIキーだが別枠)
```

---

## シナリオ 4: 複数 AI ツールの同時quota超過 (最悪ケース)

**対応手順**:

1. **GitHub Copilot は独立課金** → Claude/Gemini 停止中も使える
2. **NotebookLM** → Google アカウントで無料、Claude と独立
3. **Notion AI** → Notion プランに含まれる、Claude と独立
4. **手動開発** → 以下を参照

```bash
# 最小限の手動開発ループ
dart format lib/             # フォーマット
flutter analyze              # 静的解析
git add -p                   # 差分確認
git commit -m "..."
git push origin ps-main:main
```

---

## Slack / Notion へのアラート設定 (推奨)

### quota-monitor.yml でのアラート強化

現在の `quota-monitor.yml` は Supabase に記録するのみ。Slack webhook でプッシュ通知を追加推奨:

```yaml
# quota-monitor.yml に追加するステップ
- name: Slack Alert on High Usage
  if: steps.anthropic.outputs.usage_pct > 80
  run: |
    curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
      -H 'Content-type: application/json' \
      -d '{"text": "⚠️ Claude quota 80% 超過 — Gemini/Codex に切り替えてください"}'
```

### Notion での quota トラッキング (オプション)

```text
Notion Database: "AI Quota Log"
- Date: 日付
- Claude Usage %: quota 使用率
- Status: Normal / Warning / Critical
- Fallback: Active AI ツール
毎日 quota-monitor.yml の結果を手動または自動でここに記録
```

---

## 開発プロセス — 平常時 vs quota 超過時

### 平常時 (Claude Code 利用可能)

```text
Claude Code CLI (設計・編集) 
  + GitHub Copilot (補完)
  + NotebookLM (リサーチ)
  + GHA (自動化 — Claude 非依存)
```

### Claude quota 超過時

```text
Codex CLI / Antigravity (編集メイン)
  + Gemini Code Assist Agent Mode (Standard/Enterprise license 確認時のみ)
  + claude.ai WEB版 (設計判断・限定的)
  + GitHub Copilot (補完)
  + NotebookLM (リサーチ)
  + GHA (変わらず全自動) ← 影響なし
```

### 全 AI quota 超過時 (最悪ケース)

```text
GitHub Copilot (補完のみ)
  + 手動 dart format / flutter analyze
  + NotebookLM (Google 無料枠)
  + GHA (変わらず全自動) ← 影響なし
```

---

## GEMINI_API_KEY 取得手順

1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. 「Get API key」→「Create API key in new project」
3. キーをコピー
4. GitHub repo → Settings → Secrets and variables → Actions → New secret
   - Name: `GEMINI_API_KEY`
   - Value: `AIza...`
5. `claude-agent-review.yml` が自動的に使用開始

---

## チェックリスト — Quota 超過発生時

- [ ] `quota-monitor.yml` の最新ランで使用率確認
- [ ] `GEMINI_API_KEY` が GitHub Secrets に設定済みか確認
- [ ] Antigravity、または契約済み Gemini Code Assist Standard/Enterprise が利用可能か確認
- [ ] Dart/Flutter 作業では `dart --version` が 3.9+ か、`/mcp` が接続済みか確認
- [ ] Codex CLI が使える状態か確認 (`codex --version`)
- [ ] GHA 自動ワークフローは継続稼働中か確認 (影響なし)
- [ ] claude.ai WEB版の残量を確認 (CLI と別枠の可能性あり)

---

## 2026-05 Update: AI tool fleet 進化を反映 (Win版#132 part 115)

> 詳細 Issue: [#1706 fleet 全 instance 反映](https://github.com/kanta13jp1/my_web_app/issues/1706) / [#1707 Cloud Agent CI 統合](https://github.com/kanta13jp1/my_web_app/issues/1707)

### Codex CLI Memory (= 2026-05 GA)

Codex CLI が **Memory** を持つようになり、past task の preference / project convention / corrections を future thread に持続できる. fleet 視点での影響:

- **Codex#1 / #2 が CLAUDE.md を毎回 re-load 不要** — Memory に project convention を一度書けば多 session で活用
- 自分株式会社の **migration 命名則 / EF deny-by-default / Rule [WORKDIR-ISOLATION]** を Codex Memory に登録推奨
- ただし **Memory が古くなった場合の reset コマンド** を運用フローに組み込む必要あり (= claude-mem decay と同種の問題)

### Gemini Code Assist Agent Mode / Antigravity

- Agent Mode は VS Code / IntelliJ で Preview。Standard/Enterprise license と
  local availability を確認してから利用する。
- Individuals / Google AI Pro / Google AI Ultra は 2026-06-18 に IDE extension
  と Gemini CLI の request 提供が終了したため、Antigravity / Antigravity CLI
  へ移行する。
- Dart/Flutter 作業は SDK 内蔵 `dart mcp-server` (Dart 3.9+) を使用する。
  Project 設定は `.gemini/settings.json`、接続確認は Agent Mode の `/mcp`。

### GitHub Copilot Cloud Agent +20% startup + Claude/Codex model selection

- Cloud agent **+20% startup** (Actions custom image) — `ci-auto-fix.yml` 高速化候補
- **Model selection for Claude / Codex agents on github.com** — Copilot から Claude / Codex 直接呼出 (= fleet 連携の bridge)
- Copilot **code review が Actions minutes 消費開始** (2026-06-01〜) — quota 影響を `quota-monitor.yml` に反映必要

### Claude Code 2026-05 (`/tui` + push notification + project purge + /resume PR URL)

- `/tui fullscreen` — optional flicker-free interactive rendering. It is a
  display preference, not a fleet concurrency control.
- **Push notification tool** — Remote Control + "Push when Claude decides" でスマホ通知 (= スマホ版 instance 連携)
- `claude project purge [path]` — Claude project state (transcripts, tasks,
  file history, and the config entry) を削除する。Git worktree、branch、または
  untracked file は削除しないため、worktree cleanup の代替にしない。
- `/resume <PR URL>` — PR を作成した session に復帰 (= context 連続性向上)

### Claude Code v2.1.113–v2.1.126 追加機能 (PS#5 S118 2026-05-03)

**セキュリティ / 権限**
- `sandbox.network.deniedDomains` — 特定ドメインのネットワークアクセスをブロック (= WEB版 sandbox でのリクエスト制御)
- `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` が正しく機能するよう修正 (= Issue #1751 の権限ロックダウン基盤強化)

**Hook 進化 (v2.1.118) → Issue #1765**
- Hooks が MCP ツールを直接呼べるように: `type: "mcp_tool"` — inject-rules.txt フックから Supabase/GitHub MCP を呼べる (= PostToolUse で自動コミットや Slack 通知が可能)

**開発体験 (v2.1.118-v2.1.119)**
- Vim visual mode (`v` / `V`) — TUI 操作効率向上
- `/cost` + `/stats` → `/usage` 統合
- `/theme` command + `~/.claude/themes/*.json` — カスタムテーマ作成 (= テーマ切り替えUIとの連携)
- `--from-pr` が GitLab / Bitbucket / GitHub Enterprise URL を受け付け

**CI / 認証 (v2.1.126-v2.1.129) → Issue #1767**
- `claude auth login` — WSL2/SSH/コンテナ環境で OAuth code をターミナルにペースト可能
- `/model` picker の gateway discovery は v2.1.129+ かつ
  `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` の opt-in。対象は
  `ANTHROPIC_BASE_URL` で指定した Anthropic-compatible Messages API gateway
  の `/v1/models` であり、Azure OpenAI / Bedrock の一般的な fallback ではない。
- `claude ultrareview [target]` — CI/スクリプトから非インタラクティブに `/ultrareview` 実行 (= GHA に組み込み可能)
- `/recap` — セッション再開時に前回の context をサマリー提示し、Issue/PR
  に残した恒久証跡からの引き継ぎを補助する。

**MCP 安定性改善 (v2.1.126) → Issue #1831**
- 初期接続の transient 5xx / connection refused / timeout は最大3回 retry。
- HTTP/SSE transport は切断時に指数 backoff で最大5回再接続するが、
  stdio server は自動再起動しない。認証失敗と404もretry対象外。
- SSE/HTTP transport で mid-response に connection drop した場合の hang 修正
- 429 (rate limit) retry: exponential backoff を最低値として適用 (= 13秒で全試行消費するバグ修正)
- API retry countdown が正確に表示されるよう修正
- **fleet適用**: `MCP_TIMEOUT=60000` (S119で設定済み) は接続待ち時間を
  延長する設定であり、全transportの自動復旧を保証しない。

**session /recap (v2.1.126)**
- `CLAUDE_CODE_ENABLE_AWAY_SUMMARY=0` または `/config` でオプトアウト可能
- **運用**: 現行の2-owner構成で session を再開するときに使う。Issue/PR/WBSを
  source of truth とし、recapだけに未保存の判断を残さない。

**project purge (v2.1.126)**
- `claude project purge [path]` — project の Claude state を削除する破壊的操作。
- **運用**: 対象path、`git status`、push済みbranch/PRを確認し、最初に
  `claude project purge --dry-run [path]`、次にinteractive確認を使う。
  `--all` / `--yes` をcleanup automationへ組み込まず、Git worktree cleanupと
  分離する。

**Windows (v2.1.126)**
- PowerShell tool が有効、または Git Bash が利用できない場合は PowerShell を
  primary shell として使用できる。全Windows環境で無条件に Bash より優先する
  仕様ではない。project hooks は既存どおり明示的な `powershell` command を使う。

### GitHub Copilot 2026-05: GPT-5.3-Codex 昇格

- GPT-5.3-Codex が Copilot Business / Enterprise の base model に (2026-05-17〜) — agentic coding +25% 高速化
- Copilot CLI: streaming 改善 / MCP + OAuth サポート強化 / session 管理改善

### 平常時 fallback 順序 (改訂)

```text
1. Claude Code CLI (= 設計 / 編集 main) ← 不変
2. Codex CLI  ← 実装 main
3. Antigravity / Antigravity CLI  ← Google 個人 tier の fallback
4. Kimi K2.7 Code (OpenAI 互換 API)  ← 新規追加 (2026-07-12)
5. GitHub Copilot (補完 + Cloud Agent)  ← 不変
6. NotebookLM (リサーチ / Master Brain)  ← 不変
7. Gemini Code Assist Agent Mode  ← Standard/Enterprise license 確認時のみ
8. GHA (= Claude 非依存)  ← 不変
```

### Kimi K2.7 Code (Moonshot AI) — 2026-07-12 追加

**追加背景**: Claude Code / Codex quota 超過時のコーディング特化 fallback として採用
(参照: `docs/vendor-digests/2026-07-12.md`, Issue #3993)

| 項目 | 値 |
|------|-----|
| ベース URL | `https://api.moonshot.cn/v1` |
| モデル名 | `kimi-k2-code` (要 Moonshot API ドキュメント確認) |
| コンテキスト | 256K tokens |
| 互換性 | OpenAI ChatCompletions API 互換 |
| 思考トークン | K2.6 比 -30% (forced thinking mode) |
| ライセンス | OSS 公開 (MoonshotAI/kimi-code) |

**セットアップ**:
```bash
export MOONSHOT_API_KEY="sk-..."
# Codex CLI / LiteLLM 経由で使用する場合
# base_url=https://api.moonshot.cn/v1 model=kimi-k2-code
```

**適用場面**:
- Claude Code quota 超過かつ Gemini/Codex も不可の場合
- 200 ステップ超の長時間 agentic コーディングタスク
- コスト制約が厳しい場合 (思考トークン節約)

**注意**: 本番採用前に公式 API ドキュメント (https://platform.kimi.ai) で最新モデル名を確認すること。

### 関連 ai-tool-update Issue

- [#1644](https://github.com/kanta13jp1/my_web_app/issues/1644) Skill Activation Hook + NotebookLM Master Brain
- [#1645](https://github.com/kanta13jp1/my_web_app/issues/1645) Docker MCP Toolkit
- [#1646](https://github.com/kanta13jp1/my_web_app/issues/1646) Codex 内蔵ブラウザ + 画像生成
- [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) Codex Memory + Thread Automations

---

## Copilot Code Review 課金変更 (2026-06-01〜) 対応

### 変更内容
- **2026-06-01** から GitHub Copilot Code Review が **Actions minutes を消費**開始
- 従来: Copilot Code Review は無料 (Copilot Business/Enterprise プランで無制限)
- 変更後: PR ごとに Actions minutes が加算される (精確な単価は GitHub 公式要確認)

### fleet への影響
- `claude-agent-review.yml` (Claude/Gemini PR review) + Copilot Code Review が**同時に動く**と Actions 二重消費
- `ci-auto-fix.yml` も自動 Copilot review がトリガーされると minutes 増大

### 対処方針
1. **Copilot Code Review** は `on.pull_request` でデフォルト有効化しない (手動 `/review` コマンドのみ)
2. `claude-agent-review.yml` で Claude/Gemini レビューを主軸として継続 (Actions minutes 内で完結)
3. `quota-monitor.yml` に Copilot review minutes gauge 追加 (Issue #1707 フォローアップ)
4. 月次 Actions budget チェック: Settings → Billing → Actions で実費確認

### ci-auto-fix.yml 高速化
- GitHub Copilot Cloud Agent の **Actions custom image** 採用で +20% 高速化可能
  - `container: ghcr.io/...` で pre-warmed image 指定
  - 参考: [GitHub Changelog 2026-04-27](https://github.blog/changelog/2026-04-27-copilot-cloud-agent-starts-20-faster-with-actions-custom-images/)
  - 適用タイミング: Copilot Integration 本格採用時 (現在は Claude/Gemini 主軸のため延期)

### 参照
- Issue [#1707](https://github.com/kanta13jp1/my_web_app/issues/1707): Copilot Cloud Agent CI/PR フロー統合
- `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` 原則 6 (Deterministic Guardrails) — Budget cap rule 追記済
