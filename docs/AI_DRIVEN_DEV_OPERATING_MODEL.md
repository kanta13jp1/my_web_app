# AI 駆動開発 運用モデル v1 — 自分株式会社

> **新設**: 2026-06-03 (Win Claude part 240d / user 指示 = 3 レーン体制再定義)
> **位置づけ**: 開発の **canonical 運用モデル**。fleet roster は [`MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md)、振分は [`DEV_PROCESS_MULTI_AI.md`](DEV_PROCESS_MULTI_AI.md)、運用憲章は [`OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) を参照。
> **supersedes**: 旧 2-instance (Win Claude + Win Codex) を 3 レーンに拡張。旧 12 スロット系 docs (`MULTI_INSTANCE_COORDINATION.md` / `INSTANCE_CONFIG.md`) は本 part で削除済。

本プロジェクトは **3 つの AI レーン**で開発する。各レーンは SDLC 工程に責務を持ち、全レーン共通の **セッション儀式**（1 タスク完了 + ベストプラクティス verify + main merge）を毎回回す。

## 1. 3 レーン体制

| レーン | ツール | 主担当工程 | 主責務 | 本 Claude から駆動 |
|--------|--------|-----------|--------|:---:|
| **L1 探索** | Antigravity + Gemini | 企画 / 設計(UI探索) | 企画・要件・リサーチ・UI/UX プロトタイピング・競合/市場調査 | ❌ (user 実行) |
| **L2 実装** | VSCode + Codex | 実装 / テスト / リリース | コード実装・SQL/migration・EF(Deno)・GHA/CI・バグfix・テスト実装 | ❌ (user 実行) |
| **L3 設計** | VSCode + Claude Code | 設計 / レビュー / 運用 / 保守 | アーキ設計判断・docs・memory・PR レビュー・triage・運用設計・セキュリティ | ✅ (本インスタンス) |

> ⚠️ **正直な制約**: 本セッション (L3 = Win Claude) は L1/L2 を**駆動できない**。L1/L2 は user が各 IDE で回すレーン。L3 は設計・docs・レビューと、L2 への handoff (`docs/cross-instance-prs/`) を担う。
> 振分判定: [`DEV_PROCESS_MULTI_AI.md`](DEV_PROCESS_MULTI_AI.md) §6 の 5 質問で 1 つでも設計/横断 = L3 / 純実装 = L2。

## 2. SDLC 7 工程タクソノミ

WBS は機能カテゴリ（8 種）に加え、**工程軸 (`phase`)** を持つ（migration は part 240d で Codex handoff）。各工程に欠落タスクを作らない。

| # | phase | 工程 | 主レーン | レビュー | WBS phase 値 |
|---|-------|------|---------|---------|-------------|
| 1 | 企画 | planning / 要件定義 | L1 | L3 | `planning` |
| 2 | 設計 | design / アーキ | L3 | L1(UI) | `design` |
| 3 | 実装 | implementation | L2 | L3 | `impl` |
| 4 | テスト | test / QA | L2 | L3 | `test` |
| 5 | リリース | release / deploy | L2(CI/CD) | L3(gate) | `release` |
| 6 | 運用 | operations | L3 + routines | L2(fix) | `ops` |
| 7 | 保守 | maintenance | L3(triage) | L2(impl) | `maintenance` |

## 3. セッション儀式（全レーン毎回必須）

1. **開始**: `memory/MEMORY.md` 参照 + `notebooklm use jibun-master-brain` + `wbs.priority_for_instance` で TOP 5 取得。
2. **WBS 1 タスク完了**: 着手タスクを `wbs.update_progress` で `in_progress`→完了まで進める（**1 セッション最低 1 完了**）。tools-hub MCP 不在時は migration / cross-instance-pr で代替し、完了は handoff に明記。
3. **ベストプラクティス verify**（§4）: そのタスク領域の**公式 doc を verify-first**で確認してから実装/設計。
4. **commit → push → main merge**: worktree→PR→gate→squash merge。**1 セッション = 最低 1 merge**（auto-merge はリポジトリ無効 → CI green 確認後 手動 merge）。
5. **終了**: `/wrap-up`（memory + `GROWTH_STRATEGY_ROADMAP.md` 末尾追記 + 次回候補 3-5 件）。

## 4. ベストプラクティス取得機構（現実版）

全 24 社の公式 doc を毎セッション full-read するのは**非現実的**（トークン/時間）かつ [AI-TOOL-VERIFY] 上「読んだ」と詐称禁止。代わりに 2 層で運用:

- **層 A / per-task verify-first**: タスクに関係するベンダーのみ、`context7`（resolve-library-id → query-docs）または公式 URL `WebFetch` で最新仕様を確認してから採用。
- **層 B / weekly vendor-digest routine**: 週次 routine が 24 社をローテ巡回し changelog/blog を取得、採用候補を `docs/vendor-digests/<date>.md` + Issue 化（part 240d で新設）。

**監視 24 社**（層 B ローテ対象）:
- AI モデル: Anthropic / OpenAI / Google / Microsoft / Meta / Amazon / Apple / Grok(xAI) / Kimi(Moonshot) / MiMo(Xiaomi) / DeepSeek / BytePlus
- 開発基盤: GitHub / Unity / InsForge / FireCrawl
- コラボ/PKM: Slack / Notion / Obsidian / Discord / Reddit
- デザイン: Figma / Canva
- 決済: Stripe

## 5. 古い docs の扱い

[BRAIN-32] / [MEMORY-DECAY] に準じ、superseded / 重複 / dead-fleet 記述の docs は削除。削除前に **head を read して superseded を確認**（作成者でない file は verify-first）+ **inbound 参照を grep**して live index (`DOCS_KNOWLEDGE_HUB.md`) の dead link を同時修正。append-only 履歴 (ROADMAP / memory / cross-instance-prs) の言及は許容。

## 6. 既存正本との関係

[`OPERATIONS_CHARTER.md`](OPERATIONS_CHARTER.md) の 5 正本（Issues/PR・WBS/Notion・NotebookLM・Slack・worktree/branch）は不変。本 doc は**「誰がどの工程をどう回すか」**の運用層を定義し、5 正本の上に乗る。

## 7. follow-up（未了 flag）

- `~/.claude/hooks/inject-rules.txt` の `[INSTANCE]` は「2 instance 制」記述 → 3 レーンへ更新要（machine-local config / `/hook-rule-audit` で対応）。
- `.github/COMPRESSED_PROMPT_V3.md` も旧多インスタンス記述 = stale 候補（次 session 精査）。
- WBS `phase` 列 = 列追加済みだが backfill 3.9% (123/3,159 / 2026-06-10 監査)。handoff は [`cross-instance-prs/done/20260603_wbs_sdlc_phase.md`](cross-instance-prs/done/20260603_wbs_sdlc_phase.md) (done 移動済) + `361c10d4` (L2)。工程カバレッジの実測は [`SDLC_WBS_COVERAGE_AUDIT.md`](SDLC_WBS_COVERAGE_AUDIT.md)。
