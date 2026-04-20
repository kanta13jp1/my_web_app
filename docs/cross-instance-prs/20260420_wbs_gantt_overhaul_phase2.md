# WBS / Gantt 大改修 Phase 2 — マスタータスク一覧 + enforcement 強制化

**起票**: PS版#4 S30 (2026-04-20 夜)
**起票元**: ユーザー directive 「WBS ガントチャートが更新されない + enforcement Phase 2 実施」
**ステータス**: backlog 分配

---

## 🔗 関連 handoff (rebase 後発見 — 2026-04-20 夜時点)

PS#4 rebase 後、本 PR と並行して以下が既起票されていた。役割分担を明確化:

| 関連 PR | 起票 | カバー範囲 | 本 PR との関係 |
|---|---|---|---|
| `20260420_wbs_enforcement_option_a_win.md` | PS#2 S17 | T8-A (Win SessionStart hook auto-curl) | 本 PR T8-A の tactical 実装詳細 |
| `20260420_wbs_enforcement_option_b_ps1.md` | PS#2 S17 | T8-B (PS#1 wrap-up skill error-block) | 本 PR T8-B の tactical 実装詳細 |
| `20260420_wbs_gantt_ui_filter_vscode.md` | PS#2 S17 | T5 (未完了 filter UI) + T9 一部 | 本 PR T5 の tactical 実装詳細 |
| `fix(ps6-s22): wbs.* actions unreachable` (232b2783) | PS#6 S22 | **CRITICAL 前提修復** — tools-hub wbs.* 2 週間潜伏 bug | ✅ **merged** — 本 PR 全タスクの前提条件 |

**棲み分け**: 本 PR (PS#4 S30) = 戦略的 T1-T9 master plan / PS#2 S17 = 3 tactical handoffs (T5/T8-A/T8-B の subset)。T1 (イナズマ線) / T2 (recovery_plan 列) / T3 (planned vs actual) / T4 (ALL explode) / T6 (Schedule/GHA UI 反映) / T7 (リソース警告) / T8-C (cron audit) / T9 (全体 UI 改善) は本 PR でのみ扱う。

---

## 現状確認 (PS#4 が audit 済)

2026-04-20 時点で prod https://my-web-app-b67f4.web.app/project-gantt の状態:

| 項目 | 現状 | 対応要否 |
|---|---|---|
| instance 値に PS#1~#6 / WEB / 📱 / schedule / gha 含まれているか | ✅ **含まれている** (Win版#131 part 13 `20260420140000` で 13 値に拡張済) | UI で可視化 OK ✅ |
| Gantt UI の instance filter タブ | ✅ 全て / VSCode / Win / PS#1~#6 / WEB / 📱 tab 表示確認済 | **追加対応なし** |
| GitHub Actions タスク seed | ✅ 4 件 seed 済 (deploy-prod / ci.yml / wbs-staleness-audit / cron-batch) | **追加対応なし** |
| Claude Schedule タスク seed | ✅ 10 件 seed 済 (daily-report / cs-check / competitor-monitoring 等) | **追加対応なし** |
| recovery_plan 列 | ✅ part 10 (`20260420090000`) で追加済 + delayed_tasks_view で recovery_status 判定済 | **UI に列表示が必要** |
| estimated_hours + wbs_milestone_risk_view | ✅ part 13 で追加 (over_capacity / tight / critical_overdue 判定) | **UI で警告表示が必要** |
| start_date / end_date | ✅ 存在 | ⚠ **planned vs actual 分離が必要** |
| 今日の赤縦線 (今日線) | ✅ `DateTime.now()` で描画 (正しい論理) | ⚠ **ユーザーが指す「イナズマ線」は別** (下記参照) |
| 未完了 filter | ✅ `_hideCompleted` 実装済 (line 203 `project_gantt_page.dart`) | **UI ボタンの discoverability 要改善** |
| `instance='all'` 残存タスク | ⚠ **ユーザー数達成 (50/500/5000) 3 件のみ残存** (part 13 で意図的に共同責任として残置) | **3 件を 10 instance 分複製する? 方針判断要** |

**結論**: 既存機能の可視化 + 「真の意味でのイナズマ線 (進捗線)」 + enforcement 3 案の未実装分が残作業。

---

## ユーザー要望 9 項目 → 担当割当

### ✅ 既に実装済 (追加作業なし)

1. ~~担当に PS#1~#6 / WEB / 📱 含める~~ → **完了** (Win版#131 part 13)
2. ~~Claude Schedule / GitHub Actions タスクを WBS に反映~~ → **完了** (part 13 で 14 件 seed)
3. ~~リソース不足警告の仕組み~~ → **`wbs_milestone_risk_view` 実装済** (UI で未表示のみ)

### 🔴 要実装 (担当別割当)

#### T1. 「真の意味でのイナズマ線 (進捗線 / S-curve overlay)」実装 → **VSCode版**

**優先度**: High
**工数見積**: 4-6h
**担当**: VSCode版 (UI 専任)

**内容**:
- 現行 = 今日の日付に赤い**縦線** (_todayColor = 0xFFFF6B35)
- 要望 = classic PM ガント の **progress line / status line**
  - 今日の位置から各タスク行の「進捗% に対応する x 位置」に折れ線を引く
  - 折れ線が今日線より左 → そのタスク遅れ / 右 → 先行
  - 視覚的に遅延タスクが即座に分かる
- **実装箇所**: `lib/pages/project_gantt_page.dart` の `_GanttGridPainter` (line 2514 付近)
- **アルゴリズム**:
  ```
  各タスク t について:
    planned_x = lerp(t.start_date, t.end_date, t.progress/100)
    今日_x = dateToX(DateTime.now())
    折れ線の点 = (planned_x, t.y_center)
  全点を Path で折れ線接続 → `Paint()..color=amber..strokeWidth=2` で描画
  遅延タスク (planned_x < 今日_x) は行の background に赤 tint
  ```

---

#### T2. 「開始予定日 / 完了予定日」列 + 「遅延リカバリー案」列追加 → **Win版 + VSCode版**

**優先度**: High
**工数見積**: Win 3h + VSCode 4h

**Win版担当分 (migration)**:
- `planned_start_date date` / `planned_end_date date` 列を新規追加
- 既存 `start_date` / `end_date` を **actual** として維持 (null 許容)
- migration `20260421020000_wbs_planned_vs_actual.sql`:
  ```sql
  ALTER TABLE wbs_tasks
    ADD COLUMN planned_start_date date,
    ADD COLUMN planned_end_date date;
  -- 初期値 = 既存 start_date / end_date (後で運用で更新)
  UPDATE wbs_tasks SET planned_start_date = start_date, planned_end_date = end_date;
  ```
- `wbs_delayed_tasks_view` を `planned_end_date < CURRENT_DATE AND status != 'completed'` に書換

**VSCode版担当分 (UI)**:
- Gantt 行に「予定開始 / 予定完了 / 実績開始 / 実績完了 / リカバリー案」5 列を追加
- 遅延中 (planned_end_date < today AND status != completed) 行に:
  - 行 background 薄赤
  - `recovery_plan` 列が空なら **必須入力** プレースホルダ赤字表示
  - 編集 → `wbs.update_progress` call (既存 action・既に recovery_plan param 受入可)

---

#### T3. 未完了タスクフィルター discoverability 改善 → **VSCode版**

**優先度**: Medium
**工数見積**: 1h
**担当**: VSCode版

- 現状 `_hideCompleted` あり (line 203 `project_gantt_page.dart`) だが UI で見つけにくい
- Instance filter tab 行の右に **「未完了のみ」toggle chip** を常時表示
- 初期値 = ON (ユーザー期待値 = 未完了が default)

---

#### T4. 「instance=all」残存タスクの扱い方針判断 → **Win版 (判断 + migration)**

**優先度**: Medium
**工数見積**: 2h
**担当**: Win版

- 残存 3 件: ユーザー数達成 50 / 500 / 5000
- 2 択:
  - **(A) 共同責任のまま残置** + UI で「全インスタンス共有」warning chip 表示 (現方針)
  - **(B) 10 instance 分に完全複製** = 10 × 3 = 30 タスクに explode (user 要望直接対応)
- Win版推奨: **(A) + UI warning 強化**。理由 = 本質的に共同目標 (KPI) であり、進捗追跡も 1 本で十分 + 10 倍に膨らむ副作用大きい
- migration `20260421030000_wbs_all_task_ui_hint.sql` で `owner_instance` 必須化 CHECK 追加
- UI 側は T2 と併せて VSCode版が warning chip 実装

---

#### T5. enforcement Phase 2 — Option A (SessionStart hook で wbs.priority_for_instance 自動 curl) → **PS版#1**

**優先度**: High
**工数見積**: 3h
**担当**: PS版#1 (hook/skill 管理)

- `~/.claude/hooks/inject-rules.txt` に **実行 hook** を追記 (rule text でなく実際の bash call)
  ```bash
  # SessionStart hook (新規)
  INSTANCE=$(detect_instance)  # vscode|win|ps1|ps2..|ps6|web|mobile
  curl -s -X POST "$SUPABASE_URL/functions/v1/tools-hub" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -d "{\"action\":\"wbs.priority_for_instance\",\"instance\":\"$INSTANCE\"}" \
    | jq -r '.tasks[] | "- \(.title) (\(.progress)%)"' \
    > /tmp/wbs_priority.txt
  # system-reminder 注入 (Claude Code が読む)
  cat /tmp/wbs_priority.txt
  ```
- 実行位置: `~/.claude/settings.json` の `hooks.SessionStart` command
- **[WBS-SYNC] rule テキスト → hook 実行に昇格** = 強制化

---

#### T6. enforcement Phase 2 — Option B (wrap-up skill 内で wbs.update_progress 必須化) → **PS版#1**

**優先度**: High
**工数見積**: 2h
**担当**: PS版#1

- `.claude/commands/wrap-up.md` Step N (現行 line 131 付近) を書換:
  - 進捗更新を **事前 prompt** (user 確認) → **mandatory call** に変更
  - 完了タスク 0 件時もダミー update (`{"note":"no progress this session"}`) を curl で記録
- skill 終了前に `wbs.update_progress` response status 200 を検証 → 失敗なら skill abort + エラー表示

---

#### T7. enforcement Phase 2 — Option C (毎日 cron で WBS 未更新 instance audit) → **PS版#1**

**優先度**: High
**工数見積**: 4h
**担当**: PS版#1

- 新規 GHA workflow `.github/workflows/wbs-staleness-daily.yml`:
  - schedule: `0 21 * * *` UTC (毎日 06:00 JST)
  - step: 各 instance (10 個) について `wbs.last_updated_for_instance` を check
  - 48h+ 未更新 = stale → `docs/cross-instance-prs/YYYYMMDD_<instance>_wbs_overdue.md` 自動作成
- Win版#131 part 12 で `wbs-staleness-audit.yml` 既存 = **ベース利用** (ただし PR 作成ロジックのみ追加)

---

#### T8. 「イナズマ線のズレ」検証 → **VSCode版 (軽量調査)**

**優先度**: Low (先に T1 の解釈確認が必要)
**工数見積**: 0.5h
**担当**: VSCode版

- 仮に user の指す「イナズマ線」 = 現行の今日の赤縦線の場合:
  - `DateTime.now()` = ブラウザ locale依存。ユーザーが JST 外 timezone なら UTC 扱いでズレる可能性
  - 対策: `DateTime.now().toLocal()` 明示 OR `.toUtc().add(Duration(hours:9))` で JST 固定
- 実装 = `_dateToX(DateTime.now())` 呼出箇所 (line 1545) 1 行修正
- ただし T1 (真のイナズマ線実装) 優先 → T1 完了後に副作用として解消見込み

---

#### T9. リソース不足警告 UI 表示 → **VSCode版**

**優先度**: Medium
**工数見積**: 2h
**担当**: VSCode版

- `wbs_milestone_risk_view` 既存 (`remaining_hours > days_left * 40` で over_capacity 判定)
- 現 Gantt UI のマイルストーンカード (α版 / β版 / 最終版) に risk_status badge 追加:
  - on_track = 緑 ✅
  - tight = 黄 ⚠️
  - over_capacity = 橙 🔥
  - critical_overdue = 赤 🚨
- EF action: `wbs.milestone_risk` を `tools-hub` に追加 (1 SELECT from view) → Win版 30 min
- Flutter 側 Card widget に Badge 1 つ追加 = VSCode版 1.5h

---

## 割当サマリ + 順序

| T# | タイトル | 担当 | 工数 | 依存 |
|---|---|---|---|---|
| T2-Win | planned_* 列 migration | **Win版** | 3h | なし |
| T9-Win | `wbs.milestone_risk` action | **Win版** | 0.5h | なし |
| T4 | all タスク方針 + CHECK 追加 | **Win版** | 2h | なし |
| T5 | SessionStart hook 実装 | **PS#1** | 3h | なし |
| T6 | wrap-up skill update 強制化 | **PS#1** | 2h | なし |
| T7 | 毎日 cron staleness audit | **PS#1** | 4h | (T5/T6 非依存) |
| T1 | 真のイナズマ線 (progress line) | **VSCode版** | 5h | T2-Win 先行推奨 |
| T2-VSCode | Gantt UI 5 列 + recovery 編集 | **VSCode版** | 4h | T2-Win 先行必須 |
| T3 | 未完了 filter chip discoverable | **VSCode版** | 1h | なし |
| T8 | 今日線 timezone 検証 | **VSCode版** | 0.5h | T1 完了後 |
| T9-VSCode | マイルストーン risk badge | **VSCode版** | 1.5h | T9-Win 先行必須 |

**合計**: Win版 5.5h / PS#1 9h / VSCode版 12h = **計 26.5h** (各インスタンス稼働 4h/日 前提で約 2 日で完遂可能)

---

## Philosophy Alignment (Rule 22) — 本 overhaul 全体

- 原則 1 (CEO 感): リソース不足を可視化 = 経営判断材料 ✅
- 原則 2 (ミッション駆動): 10 instance 体制の可視化 = 共同ミッション明示 ✅
- 原則 3 (優しい mentor): 遅延タスクに「リカバリー案必須」 = 失敗ではなく改善の仕組化 ✅
- 原則 4 (6 部署バランス): 人事 (各 instance) の負荷可視化 ✅
- 原則 5 (商品=ユーザー価値): プロジェクト管理 UX 向上 = 自分株式会社の "commercial" 化ステップ ✅
- 原則 6 (資本=時間): enforcement 強制化 = 毎 session の WBS 同期時間ロスゼロ ✅
- 原則 7 (BS 原則): 遅延 = 負債可視化 / リカバリー = 資産転換 ✅
- 原則 8 (KPI=昨日の自分): progress line で「昨日より進んだか」即判定 ✅
- 原則 9 (ウェルビーイング / IPO): 過負荷警告で burnout 予防 ✅

→ **9/9 ✅** (全原則クリア)

## AI-DEV Alignment (Rule 23)

- 原則 1 (Auth): enforcement hook で `SERVICE_ROLE_KEY` source of truth ✅
- 原則 2 (Deny-by-default): wrap-up skill で update 失敗ならセッション abort ✅
- 原則 3 (trace_id): T5 curl call に `X-Trace-Id: ${SESSION_ID}` 必須化 推奨
- 原則 4 (CB): 現 WBS EF は軽量で CB 不要
- 原則 5 (team memory): 本 cross-instance-pr が team memory そのもの ✅
- 原則 6 (retry/DLQ): T7 cron audit 失敗時 `DLQ = issue auto-create` ✅
- 原則 7 (QG): T6 wrap-up で response status 200 検証 ✅

→ **6/7 ✅** (trace_id 追加で 7/7 到達可能)

---

## 各担当インスタンスへ

- **Win版**: T2-Win / T4 / T9-Win を 1 セッションで消化可 (migration 3 本 + EF 1 action)
- **PS版#1**: T5 / T6 / T7 を 1 セッションで消化可 (hook + skill + GHA workflow)
- **VSCode版**: T1 / T2-VSCode / T3 / T9-VSCode を 2 セッションで消化 (UI 改修重め)

完了時は各々 `docs/cross-instance-prs/done/` に移動し、本 PR の先頭 status ステッカーを更新してください。

## 未決定事項 (user 決裁 要)

1. T4 の方針 (A) (B) — 「ユーザー数タスクを 10 倍に explode するか?」 (Win版推奨は (A))
2. T2 の「遅延でリカバリー案 empty = エラー?」 severity — 強制 error or warning?
3. T1 の「イナズマ線 = classic progress line」解釈合ってますか? (縦 S-curve で合ってる前提で設計)

← これらは各担当が着手前に user 確認推奨。

---

**PS#4 本件に関する追加対応**: なし (競合モニタリング専任のため・本 PR 起票で handoff 完了)
