# Cross-Instance PR: CI 失敗系 6 件 batch triage

**作成**: Win版#132 part 88 / 2026-04-29
**FROM**: Win版 (User 要望「期限切迫 task を進めて」一次受領)
**TO**: PS版#1 (Rule17 WF health 専任 territory)
**優先度**: HIGH (= 6 件 CI 失敗 / 04/29-04/30 期限切迫 / production deploy ブロック懸念)
**期限**: 2026-05-06 (1 週間)
**親軸**: VIBE_CODING #5 (Minimal E2E Tests) / OPS-28 §6 (改善トリガー)

---

## 1. 背景

User 要望:
> 「期限がせまっているタスクがたくさんあります。進めて行ってください。」

screenshot: /project-gantt timeline / 606 タスク中 04/29-04/30 期限切迫が 20+ 件. うち **CI 失敗系が 6 件**:

| # | Issue | Title | 期限 | 状態 |
| --- | --- | --- | --- | --- |
| 1 | #932 | [CI失敗] Blog Publish (技術記事投稿) | 04/29 | GHA |
| 2 | #933 | [CI失敗] Horse Racing Auto Update | 04/29 | GHA |
| 3 | #938 | [CI失敗] WBS AI Review (1h cron) | 04/29 | GHA |
| 4 | #1001 | [CI失敗] CI codex/codex1-home-hopson-style | 04/30 | GHA |
| 5 | #1003 | [Schedule監視] daily-report タスク未実行を検出 | 04/30 | CX |
| 6 | #1009 | [CI失敗] CI codex/codex2-platform-memory-feature-review | 04/30 | GHA |

= 6 件の **GHA workflow / Schedule task 失敗** が同時発生中.

### 1.1 Phase 2 追加 (= Win版#132 part 89 / 2026-04-29)

User 再要望 + /project-gantt 再 audit で追加発見:

| # | Issue | Title | 期限 | 状態 |
| --- | --- | --- | --- | --- |
| 7 | #1020 | [CI失敗] CI codex/codex1-fix-migration-110000-collision | 04/29 | GHA |
| 8 | #1026 | [CI失敗] Deploy to Production (main) | 04/30 | GHA |

= 合計 **8 件**. #1051 は既に closed (= deploy success / 100% mirrored).

## 2. Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | YES | 各 CI 失敗の根本原因は異なる / 個別判断必要 |
| Q2 cross-instance 調整? | △ | 一部は Codex#1/#2 territory (= codex1/codex2 branch CI) |
| Q3 軸 docs 更新? | NO | 通常 audit 範囲 |
| Q4 docs に残す判断? | △ | 同時多発 6 件の根本原因が共通か別かで記録価値 |
| Q5 NotebookLM 連携? | NO |

→ Q1+Q2 YES + WORKDIR-ISOLATION (= GHA workflow / CI = PS#1 Rule17 WF health 専任) = **PS#1 territory 確定**.

## 3. 期待する PS#1 audit

### 3.1 各 Issue の status 確認

各 6 Issue を PS#1 が `gh issue view` + 関連 GHA run log を audit:

```bash
gh issue view 932 --json title,body,labels
gh run list --workflow=blog-publish.yml --limit 5
# (= 各 Issue 6 件分)
```

### 3.2 根本原因分類

PS#1 が分類:
- **GHA workflow 失敗 (= 4 件)**: #932 / #933 / #938 / #1001 / #1009
  - 環境変数欠如?
  - Secret 期限切れ?
  - Action 依存パッケージ更新?
  - Schedule cron timing 競合?
- **Schedule task 未実行 (= 1 件)**: #1003 daily-report
  - cron 起動失敗?
  - Anthropic API quota 超過?
- **codex1/codex2 branch CI (= 2 件)**: #1001 / #1009
  - 各 Codex worktree の作業 branch CI
  - 当該 worktree が長期 stale?

### 3.3 fix 配分 / cross-instance-pr 再委譲

PS#1 が分類後:
- **PS#1 で直接 fix 可能** (= GHA yml 修正 / secret 更新): 即実施
- **VSCode territory** (= Flutter test 失敗等): VSCode 再委譲
- **Codex#1/#2 territory** (= 各 branch の作業残り): Codex 再委譲
- **User territory** (= secret 期限切れ等): Issue comment で User notification

### 3.4 close cycle

- 個別 fix → PR merge → Issue auto-close (= issue-to-wbs.yml 経由 WBS task も auto-completed)
- 全 6 件 close 後、本 cross-instance-pr を `done/` 移動

## 4. 受入基準

- [ ] **8 Issue** 個別 audit 完了 + 根本原因分類 (= part 88 の 6 件 + part 89 追加 2 件)
- [ ] PS#1 直接 fix 可能なものは即実施 (= 想定 8 件中 4-5 件)
- [ ] 残り (= 3-4 件) は再委譲 cross-instance-pr 起票 (VSCode / Codex#1 / Codex#2 / User)
- [ ] 8 Issue 全 close で `done/` 移動
- [ ] WBS update:
  - migration `20260429170000_update_wbs_progress_win132_part88.sql` (= part 88 / 6 件 status)
  - migration `20260429180000_update_wbs_progress_win132_part89.sql` (= part 89 / +2 件追加 + #1051 既 closed 反映)
  - 100% は Issue close 後 issue-to-wbs.yml で auto 反映

## 5. 連携 docs

- `docs/cs-notes/2026-04-29-*.md` (= 既存 cs-check.yml 自動生成 / 同 Issue 群が含まれる可能性)
- `.github/workflows/cs-check.yml` (= CS automation / 関連 GHA run history)
- `docs/SCHEDULE_TASKS.md` Task: cs-check (= 既存 Schedule task / hour cron / FAQ 返信 + バグ修正 + escalation)

## 6. 既存 cross-instance-pr との関連

| 関連 PR | 状態 | 関連 Issue |
| --- | --- | --- |
| `20260428_codex_merge_backlog_monitor_ps1.md` | done | (= Codex backlog 監視 / 関連 / 過去) |
| `20260429_blog_publish_missing_draft_ps2.md` | pending | #932 関連? (= Blog Publish 系) |
| `20260429_migration_collision_prevention_ps1.md` | pending | (= migration collision audit / 関連) |

= **本 PR は 6 件 CI 失敗の **横断 audit** / 個別 fix は他 PR で対応**.

## 7. 期限切迫 task 全体 audit (= part 88 で実施)

本 cross-instance-pr とは別に、Win版#132 part 88 で WBS update migration `20260429170000_update_wbs_progress_win132_part88.sql` を作成. 11 件の期限切迫 task の状態を実状況に正規化:

- ✅ #911 / #912: 既 fix 済 (= e87e3fd1d) → 100% completed
- 🔄 #793-795: PLATFORM_EVOLUTION #1 / #5 / #6 で対応中 → 50-70%
- 🔄 #931: AI 分割→登録 cross-instance-pr (part 87) → 30%
- ⏳ #932-1009: 本 PR で PS#1 audit → 20%
- 👤 #696: User 手動操作 (= Slack + Notion セットアップ) → pending

## 8. OPS-28 charter §6 受領 lane (= Win → PS#1 lane 5 件目)

| part | 内容 | 状態 |
| --- | --- | --- |
| 47 | Migration timestamp collision detector | ✅ |
| 51 | deploy-prod concurrency truth | ✅ |
| 56 | migration time-relative CHECK detector | ✅ |
| 69 | consolidate-memory --lint | ✅ (PS#1 S5) |
| **88 (本)** | **CI 失敗系 6 件 batch triage** | **⏳ 起票** |

= Win → PS#1 lane の **継続実証**. PS#1 は Rule17 WF health 専任で実装速度高 (= 過去 4 件全 ✅).

---

*Win版#132 part 88 / 2026-04-29 起票 / User 要望「期限切迫 task を進めて」/ CI 失敗系 6 件 batch triage / PS#1 territory / 個別 fix は他 PR 経由 / Win → PS#1 lane 5 件目*
