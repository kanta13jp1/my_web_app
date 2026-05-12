# [Codex CLI 宛] Overdue WBS task batch 3 — batch 1+2 漏れ 2 件 5-question 振分

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 143)
**to**: Win Codex CLI
**priority**: high (= 全件 2 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` 2 件 cap respect

## Summary

batch 1 (= 8 件 / `20260505_codex_overdue_wbs_handoff.md`) + batch 2 (= 10 件 / `_batch2.md`)
で計 18 件を triage 済。本 batch 3 で WBS UI 上位の **未 triage 残 2 件** を補完。
Win Claude territory 1 件 (#1292 SOP) は part 143 [DYNAMIC-CLAIM] 2 件 cap (= #1316 + #1345 既消費) に
respect して **part 144 deferred** とし、本 session では triage + scope outline のみ。

## 振分結果 (= 2 件)

| # | issue | judge | 既存 skill / hand off |
|---|---|---|---|
| 1 | [#1286](https://github.com/kanta13jp1/my_web_app/issues/1286) 管理者バイパス無効化 + 署名済み commit + linear history | **Codex** (実装 / GitHub API + branch protection) | `gh api PATCH /repos/.../branches/main/protection` + ruleset JSON |
| 2 | [#1292](https://github.com/kanta13jp1/my_web_app/issues/1292) Restart/Pause 時の SOP 策定 | **Win Claude** (docs / SOP) | **part 144 primary** = `docs/MAINTENANCE_SOP.md` 新規 |

## 5-question matrix 適用

質問 (docs/CODEX_WORKFLOW.md §6 抜粋):
1. Q1 設計 / architect 要素を含むか
2. Q2 docs / memory 更新が主か
3. Q3 UI design / mockup を含むか
4. Q4 triage / 競合 / AI 大学 / mobile UAT / 動画 task か
5. Q5 部署横断 / 抽象化レビューが必要か

| # | Q1 | Q2 | Q3 | Q4 | Q5 | judge |
|---|---|---|---|---|---|---|
| 1286 | N | N | N | N | N | Codex |
| 1292 | N | **Y** | N | N | N | Win Claude |

## #1286 hand off 詳細

### 受入条件 (= Issue 抜粋)
1. Admin/bypass role でも保護ルール skip 不可
2. GPG/SSH 検証済 signed commit のみ merge 可
3. merge commit 作成不可 / linear history 強制

### Codex 実装 hint
- GitHub API `PATCH /repos/{owner}/{repo}/branches/{branch}/protection` で:
  - `enforce_admins: true` (= admin bypass 無効化)
  - `required_signatures: { enabled: true }` (= signed commit 強制)
  - `required_linear_history: true` (= merge commit 禁止)
  - `required_pull_request_reviews.bypass_pull_request_allowances: { users: [], teams: [] }` (= bypass 全削除)
- ruleset JSON テンプレ: `.github/branch-protection.json` 新規 + apply script
- 工数推定: ~3h (= API call + JSON template + GHA workflow で apply 自動化)

## #1292 (Win Claude part 144 deferred) — scope outline

### 想定 doc 構成 (= part 144 ship 候補)
`docs/MAINTENANCE_SOP.md`:

1. **対象操作**: Supabase Restart / Pause / migration apply / EF deploy / DB role 変更
2. **事前承認フロー**: 操作担当 → CEO 承認 → Slack #ops-approval log
3. **告知テンプレート**: ja + en (= banner / Twitter / dev.to / Discord 4 channel)
4. **timing 規約**: 平日 02:00-04:00 JST 推奨 (= [SCHEDULE-WAKEUP] respect)
5. **復旧確認 checklist**: API health / Auth login / EF smoke / DB connection / RLS effective / Cron 起動
6. **incident escalation**: Sentry trigger + Slack #incident + 24h review

### 関連既存 spec
- [docs/MAINTENANCE_MODE_SPEC.md](docs/MAINTENANCE_MODE_SPEC.md) (= part 142 / UI/EF spec)
  - 本 SOP は **process spec** / MAINTENANCE_MODE_SPEC は **system spec** / 補完関係
  - SOP 策定後、MAINTENANCE_MODE_SPEC.md `## 6. SOP 連携` section から cross-link

### part 144 工数推定
~2h (= 6 section 草案 + 既存 spec cross-link + commit)

## 期限 + SLA

- #1286: 既に 2 日 overdue → Codex 即時 triage 推奨
- #1292: part 144 (= 次 Win Claude session) で SOP doc ship

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix **20 件累計適用** (= batch 1 + 2 + 3)
- `[DYNAMIC-CLAIM]` 1 session 2 件 cap **3 batch 連続厳守** (= part 143 で #1316 + #1345 ship 後の追加 Win Claude work は part 144 deferred)
- `[WBS-SYNC]` overdue triage の **3 batch 化** (= 1 session 内で 20 件 triage 達成 = 過去最大)
- `[SYNERGY-30]` cross-instance-pr 累計 = fleet 横断 hand off 第 1 例 → **3 batch 連続 = pattern 確立**
