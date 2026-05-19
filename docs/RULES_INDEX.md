# inject-rules.txt 詳細 expand (= 39 rule full body)

> **Win版#132 part 134 (2026-05-05)**: 旧 `~/.claude/hooks/inject-rules.txt` (= 344 行) の詳細を本ファイルに移行 (= Karpathy 80 行 KPI 達成 / inject-rules.txt は ≤ 80 行 pointer hub 化).
> 詳細 body は本ファイル参照. 違反例 / 受領者 instance / 関連 docs link も保存.
> 元 inject-rules.txt は part 130 で 372 → 344 行短縮済. 本 part で 344 → 69 行に再圧縮.

---

## A. Critical (= 動作 rule / 毎ターン inject 必要)

### `[INSTANCE]`

セッション冒頭で **「Win版 (Claude Code) / Win版 (Codex CLI)」のどちらか確認必須**. 旧 instance 名 (PS#1-6 / VSCode版 / WEB版 / スマホ版 / Codex#1 / Codex#2) で作業した場合は **dormant** 状態のため fleet 体制違反 → 即 Win Claude or Win Codex に切替.

関連: `docs/MULTI_INSTANCE_FLEET.md` / `docs/FLEET_2_INSTANCE_TRANSITION.md` (= part 130 移行ログ)

### `[DART-FORMAT]`

Dart 編集後は **必ず** 以下順:
- `dart format <files> --set-exit-if-changed` → `flutter analyze 0` → `push`
- format スキップ → CI Check formatting fail → 連鎖修正 commit 数回

**pipe hang 回避 (PS#3 S26 2026-04-20 教訓)**:
- `cd <dir> && dart format <file> 2>&1 | tail -N` を background task で実行すると git-bash + cygwin 環境で buffering lock が起きて永久 hang
- **正しいテンプレ**: 絶対パス + pipe なし → `dart format C:/absolute/path/file.dart 2>&1`
- exit code だけ必要なら `--set-exit-if-changed` のみ付加 (= pipe 禁止)
- flutter analyze も同様: `flutter analyze <file.dart>` を単発で投げる

### `[REBASE]`

push 前に **必ず**:
- `git fetch origin main && git log HEAD..origin/main --oneline`
- 並行 push 検出時 → `git stash` → `git pull --rebase` → `git stash pop` → conflict 手動解決
- cwd reset で path 失敗多発 → 1 bash invoke 内で完結させる

### `[WORKDIR-ISOLATION]`

(Win版#132 part 130 / 2 instance 制 / 旧 12 instance dormant) 全 instance 別 worktree 必須:
- main repo `C:/Users/kanta/GitHub/my_web_app` は **直接編集しない** (push target only)
- **2 スロット** (canonical = `docs/MULTI_INSTANCE_FLEET.md`):
  - **Win版 (Claude Code)** → ad-hoc `.claude/worktrees/<part-name>` (part 毎自動)
  - **Win版 (Codex CLI)** → `.claude/worktrees/instance-codex` (推奨)
- 旧 12 instance は dormant (worktree 残存 / 新作業停止). reactivation 手順 = `docs/MULTI_INSTANCE_FLEET.md §再起動条件`

### `[STASH-SAFETY]`

git stash は同一 workdir の全 process に影響:
- 推奨: stash の代わりに **WIP commit** (`git commit -m "WIP" → rebase → reset HEAD~1`)
- uncommitted 変更を 10 分以上維持しない
- Edit → format → analyze → git add → commit を 1 Bash invoke で完結
- pull --rebase は必ず commit 後に実行

### `[CAVEMAN]`

通信スタイル: 記事 / filler / pleasantries / hedging 削除 fragments OK. ただし **code / commit / security の中身は normal** で書く.

### `[WBS-SYNC]`

(Win版#128 必須) 全 instance 毎セッション:
- **session-start**: `tools-hub:wbs.priority_for_instance` で TOP 5 取得
- **wrap-up**: `tools-hub:wbs.update_progress` で必須更新 (= 100% で `status=completed`)
- migration 経由の `update_wbs_progress_psNN.sql` は廃止 (= EF action で代替)
- WBS: <https://my-web-app-b67f4.web.app/project-gantt>

### `[INSTANCE-ROLES]`

(part 130 / 2 instance 制) 役割分担:
- **Win版 (Claude Code)** = architect / 設計 / docs / memory / cross-instance-pr / UI design / Rule17 / triage / AI 大学 / 競合 / mobile UAT / 動画 pipeline / blog-publish-cleanup
- **Win版 (Codex CLI)** = 実装 / 修正 PR / SQL・migration / EF Deno / GHA / EF 整理 / T-1 dispatch / 競馬予想モデル / Karpathy Compile/Lint cycle
- **Codex 振り分け 5 質問** (`docs/CODEX_WORKFLOW.md §6`):
  Q1.設計判断/trade-off ある? Q2.cross-instance 調整必要? Q3.軸 docs 更新? Q4.docs に残す判断? Q5.NotebookLM 連携要?
  → 1 つでも YES = Win Claude / 全部 NO = Win Codex
- SLA: Issue 起票 → 24h 以内 Win Claude triage → severity ≤ normal は Win Codex / 重い設計判断は Win Claude

### `[AI-TOOL-VERIFY]`

AI tool / model / agent capability claims are verify-first. Check official sources via `scripts/check_versions.py --web` before adopting fleet-wide behavior, model routing, or automation changes. The top-level operating model remains Claude Code #1 for policy/review and Codex #1 for scoped PR/CI/cleanup.

### `[SUBAGENT-GUARD]`

Guarded child subagents are allowed only under Claude Code #1 or Codex #1 as short-lived workers. Record lead owner, role, scope, validation, risk, and cleanup evidence in PR/Issue/wrap-up. Old Codex #2/#3, PS, WEB, and mobile lanes stay dormant.

### `[CONCURRENCY]`

(Win#109 修正) deploy-prod / dev / staging は `cancel-in-progress: false` 変更済. 並行 push でも全 commit が順次 deploy. 後発 push は最大 11min × 並行数 待機.

### `[AUTO-REPLY]`

任意の auto-reply (Qiita / dev.to / Slack / Discord / 任意) は **author == 自分 で必ず skip** + `MAX_REPLIES_PER_ARTICLE/RUN cap` 併設. 違反 bug 例: `scripts/blog_engagement.py` Qiita 自己連投.

---

## B. Principle docs pointer (= 13 rule)

| rule | docs | 原則数 | 閾値 | 適用 |
| --- | --- | --- | --- | --- |
| `[PHILOSOPHY-22]` | [`docs/PHILOSOPHY.md`](PHILOSOPHY.md) | 9 | 7+/9 ✅ | 新機能設計時 |
| `[AI-DEV-23]` | [`docs/AI_DEV_PRINCIPLES.md`](AI_DEV_PRINCIPLES.md) | 7 | 6+/7 ✅ | 新 AI 機能設計時 |
| `[AI-CHARACTER-24]` | [`docs/AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) | 8 | 7+/8 ✅ | AI ペルソナ機能 |
| `[IMBUE-25]` | [`docs/IMBUE_PATTERNS.md`](IMBUE_PATTERNS.md) | 7 | 6+/7 ✅ | AI / UI 機能 (CEO 感保てる体験設計) |
| `[COLLAB-26]` | [`docs/COLLAB_AI_PATTERNS.md`](COLLAB_AI_PATTERNS.md) | 7 | 6+/7 ✅ | AI システム (人間と協働進化) |
| `[MCP-AUTH-27]` | [`docs/MCP_AUTH_SECURITY_PRINCIPLES.md`](MCP_AUTH_SECURITY_PRINCIPLES.md) | 10 | **10/10 必須** | MCP server 公開時 |
| `[AI-VIDEO-29]` | [`docs/AI_VIDEO_PRINCIPLES.md`](AI_VIDEO_PRINCIPLES.md) | 6 | **6/6 必須** | 合成メディア / AI アバター |
| `[VIBE-30]` | [`docs/VIBE_CODING_PRINCIPLES.md`](VIBE_CODING_PRINCIPLES.md) | 7 | 7/7 推奨 / 4-で CEO レビュー強化 | Production AI 開発全般 |
| `[PLATFORM-31]` | [`docs/PLATFORM_EVOLUTION_PRINCIPLES.md`](PLATFORM_EVOLUTION_PRINCIPLES.md) | 7 | 7/7 推奨 | プラットフォーム進化 |
| `[BRAIN-32]` | [`docs/SECOND_BRAIN_PRINCIPLES.md`](SECOND_BRAIN_PRINCIPLES.md) | 7 | 7/7 推奨 | PKM インフラ / memory file 追加 PR |
| `[INDIE-29]` | [`docs/INDIE_DEV_VELOCITY_PRINCIPLES.md`](INDIE_DEV_VELOCITY_PRINCIPLES.md) | 7 | 5+/7 推奨 | indie 開発 shipping velocity |
| `[SYNERGY-30]` | [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](AI_FLEET_SYNERGY_PLAYBOOK.md) | 7 | 5+/7 推奨 | fleet 横断 / cross-instance-pr |
| `[OPS-28]` | [`docs/OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) | 5 正本 + 6 AI 役割 + 5 監査 | 全部遵守 | 毎セッション運用憲章 |

各 rule の詳細 (= ベースライン / gap / ソース NotebookLM ID) は対応 docs に保存.

---

## C. Behavioral 1-line (= 14 rule)

### `[ROADMAP-LOG]`

`docs/GROWTH_STRATEGY_ROADMAP.md` 毎セッション末尾追記必須 — instance + session# + 実装サマリ + commit hash + Philosophy Alignment block (9/9 採点).

### `[ISSUE-PRECHECK]`

新規 Issue 起票前に `gh issue list --search "<8文字notebook_id> in:title" --state all` で既存有無確認. 1+ open ヒット → 既存 Issue にコメント merge (新規起票しない). 違反検知: `scripts/notebooklm_issue_crosscheck.py` (= daily 04:00 JST cron).

### `[REAL-DATA]`

ダミーデータ禁止 — 必ず Supabase リアルデータ使用. `lib/pages/*` で hardcoded sample data NG (RLS 確認後 fetch). 例外: テスト用 widget catalog のみ const data 可.

### `[EF-FIRST]`

複雑ロジックは EF (Edge Function) に移動. Flutter widget は表示 + 操作のみ. 既存 hub に action 追加が最優先.

### `[EF-CAP-50]`

deploy-prod EF 数 ≤ 50 維持. hub 構成: `core / growth / ai / admin / app / schedule / tools / media / enterprise / social-commerce / lifestyle` + standalone 5 = 16 本. 新機能 = (a) 既存 hub action 追加 [最優先] (b) hub 統合 (c) 統合後 50 以下なら新規 EF 可.

### `[NO-SCOPE-CREEP]`

明示依頼されていない機能を勝手に追加禁止. 「ついでに〜」は禁止 (TODO に書いて別 session). 例外: docs 1 行修正 / 誤字訂正.

### `[UI-VERIFY]`

毎セッション 本番 UI チェック — <https://my-web-app-b67f4.web.app/> の主要ページ (home / AI 大学 / LP / ranking) を Web + モバイル両方. 自動: Playwright MCP screenshot + design-skills agent.

### `[CONSTRAINT-LOG]`

新制約 / 仕様変更を即記録 — `docs/instance-constraints.md` 制約発見ログ追記 / `docs/cross-instance-prs/YYYYMMDD_constraint.md` 周知 / `memory/feedback_correction_YYYYMMDD.md` 記録.

### `[SCHEDULE-WAKEUP]`

(PS#3 S26 2026-04-20 教訓) 深夜帯 ScheduleWakeup 抑制:
- 深夜 JST 02:00-06:00 は ScheduleWakeup call 禁止
- 3h+ 無 user input → 作業中断 + wrap-up
- 7h+ idle = 暴走 / 最長 delay 1800 (30min)
- 「user input なしで 2 回連続自動起動」= 停止サイン

### `[COMPACTION-RESUME]`

(PS#3 S26 教訓 + part 175 update v2) summary 継続セッションは短時間で終了 — 90 min 以内で commit + roadmap + memory + 終了. 新規大規模タスク詰込禁止.

**同日 part cap 履歴 (= part 175 緩和 v2 / 2026-05-07)**:

| 版 | cap | 確立 part | note |
|---|---|---|---|
| v0 | 12 part 強制終了 | part 173 (= 旧) | sustainability 重視 / part 173-174 dogfood pattern |
| v1 | 18 part 強制終了 | part 175 (= shadow) | 一時緩和 (= user revert で実質 ignore) |
| **v2 (= 現行)** | **24 part 強制終了** | **part 175** | Anthropic rate 大幅緩和 + 思い切った buffer |

**緩和根拠 (v2)**:

- Anthropic 大型 update (2026-05-07): Claude Code 5h レート 2x / Pro/Max peak 完全撤廃 / Opus API 大幅引上げ / SpaceX Colossus 1 単独取得 (= 300MW + 22 万 GPU)
- 14 part で MCP 劣化観測も session 全体は機能継続 → 24 part hard stop で 10 part buffer 残

**override pattern (現行 v2)**:

- 1-23 part = 通常 work 可 (= STOP signal log は 12+ で参考表示 / 強制終了 不要)
- 24 part = 強制終了 default (= memory + roadmap + admin merge minimum)
- 25+ part = user 明示宣言 ("override 承認") 必須 / minimum scope のみ
- 自己判断 25+ proceed 禁止 (= 「自己 cap rule strict adherence」discipline 維持)

### `[DYNAMIC-CLAIM]`

primary task no-op 時の動的タスク引き取り:
- `wbs.rebalance_suggest` → `wbs.claim_task` → 作業 → `wbs.update_progress(status=completed)`
- 引き取り可能カテゴリ: marketing / docs / seo / product-light
- 禁止: business-legal / urgent bugs / IPO tasks
- 上限: 1 session 2 件

### `[WBS-DEDUP]`

(PS#2 S29 2026-04-25 発見) WBS 重複データ — codex 451 / user 154 tasks に 9+ 件の重複. 原因: migration 20260425203000 cartesian INSERT. 修正担当: Win Claude. PR: `docs/cross-instance-prs/20260425_wbs_dedup_fix.md`.

### `[MEMORY-DECAY]`

(Win版#130 必須) memory/ 陳腐化 + 肥大化対策:
- 全 memory file 名にタイムスタンプ `YYYYMMDD` 必須
- 同主題の新ファイル = 古いファイルを **shadow** (上書きせず併存)
- 30+ 日経過 + reference 0 → `consolidate-memory` skill で merge
- **失敗パターン (`feedback_correction_*`) は absolute keep**
- `MEMORY.md` 1 ファイル 1 行サマリ
- 月 1 cleanup は Win Claude (= 旧 PS#1)

### `[FLEET-OPS]`

(運用監査) 5 正本 (Issues/PR / WBS+Notion / NotebookLM / Slack / worktree+branch). 作業開始時: 担当重複 / 同一 file・schema・EF・workflow 競合 / 5 正本不一致 / 通知形骸化 / 他 AI 活用余地を確認.

---

## 関連

- [`CLAUDE.md`](../CLAUDE.md) — pointer hub (= part 133 で 463→61 行)
- [`docs/PHILOSOPHY.md`](PHILOSOPHY.md) — 9 原則 (= 全 rule の最上位 alignment)
- [`docs/MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md) — 2 instance fleet 体制
- [`docs/OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) — 運用憲章
- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](AI_FLEET_SYNERGY_PLAYBOOK.md) — fleet 7 原則
- `~/.claude/hooks/inject-rules.txt` — 毎ターン inject される pointer hub (= part 134 で 344→69 行 / -80%)

(Win版#132 part 134 / 2026-05-05 / Karpathy KPI 横展開 第 1 例)
