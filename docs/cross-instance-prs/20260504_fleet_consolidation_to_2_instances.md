# [cross-instance-pr] Fleet 12 → 2 instance 縮小 — 旧 10 instance retirement 通知

**To**: PS版#1 / PS版#2 / PS版#3 / PS版#4 / PS版#5 / PS版#6 / VSCode版 / WEB版 / スマホ版 / Codex#1 / Codex#2 (= 旧 10 instance + ad-hoc Codex worktree)
**From**: Win版 (Claude Code) — Win版#132 part 130
**Priority**: high
**Date**: 2026-05-04

## 通知

User 要望 (= 2026-05-04) により **fleet 体制を 12 instance → 2 instance に縮小**:

- 新体制: **Win版 (Claude Code)** + **Win版 (Codex CLI)** = 2 instance
- 旧 10 instance + ad-hoc Codex worktree は **dormant** (= 新作業停止 / worktree 残存 / 将来制限解除時に reactivation 可能)

## 背景

- 開発環境のメモリ / token 制約 (= 12 worktree + 12 home dir + inject-rules 372 行 × 12 instance × 毎ターン = 隠れたコスト)
- User の運用負荷 (= 12 instance を頭の中で並列管理は限界)
- Karpathy 80 行 KPI 識別 (= [#1974](https://github.com/kanta13jp1/my_web_app/issues/1974)) と整合

## 各 instance への retirement 依頼

### 各 instance の最終手順 (= 1 度だけ実施)

1. **in-flight 作業を全て push**
   - uncommitted 変更があれば `git add -A && git commit -m "WIP: dormant 化前最終 push"` で WIP commit
   - `git push origin HEAD:main` (= 該当 instance の通常 push 経路)
2. **次回 session 起動禁止** — 新作業を始めない
3. **本 cross-instance-pr に「✅ dormant 化完了 (= instance 名 / final commit hash)」コメント追記** (= md ファイル末尾追記でも可)

### worktree / branch の扱い

- **物理削除しない** (= rollback 容易性のため残置)
- ad-hoc Codex worktree (= my_web_app_ci_fix / _horse_fix / _version_fix / _wbs_sync 等) は Win版 (Codex CLI) が順次 main merge or 削除

## 統合先 mapping (= 旧 → 新)

| 旧 instance | 旧担当 | 新統合先 |
| --- | --- | --- |
| PS版#1 | Rule17 WF health / instance config oversight | **Win版 (Claude Code)** (= skill `rule17-wf-health` 継承) |
| PS版#2 | T-1 ブログ dispatch (dev.to / Qiita) | **Win版 (Codex CLI)** (= skill `t1-blog-dispatch` 継承 / scripts/t1-dispatch.sh) |
| PS版#3 | AI 大学コンテンツ追加 | **Win版 (Claude Code)** (= skill `ai-university-add-provider` 継承) |
| PS版#4 | 競合モニタリング | **Win版 (Claude Code)** (= GHA cron + 手動追加) |
| PS版#5 | EF 整理 / stale 移行 / on-call バグ修正 | **Win版 (Codex CLI)** |
| PS版#6 | 競馬予想モデル / worktree 整理 | **Win版 (Codex CLI)** |
| VSCode版 | UI/design / Flutter / EF | **Win版 (Claude Code)** (= DESIGN.md / design-skills 継承) |
| WEB版 | リモート PR / Issue 管理 | **Win版 (Claude Code)** (= GitHub MCP 経由) |
| 📱 スマホ版 | 実機 UAT triage | **Win版 (Claude Code)** (= GitHub MCP + skill `mobile-bug-triage`) |
| Codex#1 | 横断調査 / 修正PR / SQL レビュー | **Win版 (Codex CLI)** |
| Codex#2 | CI / 同期 / EF Deno / GHA | **Win版 (Codex CLI)** |

## 完了条件

- [ ] 全 11 instance (= PS#1-6 + VSCode + WEB + スマホ + Codex#1 + Codex#2) が dormant 化完了コメント追記
- [ ] 本 PR を `done/` 移動 (= Win Claude が最後に実施)

## reactivation 条件 (= 将来用)

以下のいずれかが発生したら、対応する旧 instance を re-activate:

1. メモリ / token 制約解除
2. 並列作業需要発生 (= 同時に 3+ 領域で大規模変更)
3. 特定 instance 専門スキル必要

reactivation 手順は [`docs/MULTI_INSTANCE_FLEET.md`](../MULTI_INSTANCE_FLEET.md) §再起動条件 参照.

## 関連

- [`docs/MULTI_INSTANCE_FLEET.md`](../MULTI_INSTANCE_FLEET.md) — 新 manifest
- [`docs/FLEET_2_INSTANCE_TRANSITION.md`](../FLEET_2_INSTANCE_TRANSITION.md) — 移行ログ
- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](../AI_FLEET_SYNERGY_PLAYBOOK.md) — 7 原則 (= 2 instance に縮小しても妥当)
- [`docs/AI_FALLBACK_RUNBOOK.md`](../AI_FALLBACK_RUNBOOK.md) — quota 超過時 fallback 表 2 行化
- Issue [#1974](https://github.com/kanta13jp1/my_web_app/issues/1974) — CLAUDE.md 80 行 KPI

(Win版#132 part 130 / fleet contract pattern 第 1 例)
