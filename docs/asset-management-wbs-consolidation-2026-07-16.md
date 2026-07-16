# 資産管理 WBS 集約クローズ候補リスト (2026-07-16)

> 策定: Win Claude (L3)。契機: ユーザー要請「資産管理クラスタ(~15 件の近重複)の実装状況を
> 棚卸しして集約クローズ候補リストを作る」。
> 手法: 3 つの read-only エージェントで `asset_liability_planning_service.dart` /
> `asset_management_insight_service.dart` / `asset_liability_workbook.dart` /
> `asset_management_page.dart` (29k 行) / 関連 service を横断監査し、各 Issue の受け入れ条件を
> 実コード (`file:line`) と突き合わせて検証。GitHub の open/closed 状態も全件確認。

## エグゼクティブサマリ

資産管理の追加要望 ~17 件は、実は **4 つの capability に集約**され、その **中核は既に実装済み**でした:

- **A. ショート検知 → 口座移動提案 (from/to/金額)** … 実装済 (2 機構 + UI パネル)
- **B. 提案 → transfer_task 作成・管理 (ワンタップ/完了/取消/繰越)** … 実装済
- **C. 支払原資口座 未設定の一括レビュー + 推奨口座** … 実装済
- **D. transfer_task ステータス → 見込み残高 即時再計算** … 実装済

そのため、多くの Issue は「実装済の親」に対する **重複** か、**1 点だけ差分が残る partial** です。真に未実装なのは
**仮内訳(#3349)** と **自動実行(#3443)**、および 3 つの guided wizard / gate だけでした。

### バーンダウン内訳

| 区分 | 件数 | 承認要否 | 状態 |
|---|---:|---|---|
| ① Stale 行 (GitHub で既に close 済) | 5 | 不要 | ✅ **本セッションで repair 済** (migration `20260716130000`) |
| ② 実装済 → close 候補 | 2 | **要承認** | 提案 |
| ③ 重複/enhancement → 重複 close + 差分 re-file 候補 | 5 | **要承認** | 提案 |
| ④ 中核は実装済・固有機能が未実装 → open 継続 (scope 縮小) | 3 | — | Codex へ |
| ⑤ 完全未実装 → open 継続 | 2 | — | Codex へ |

① は完了済。②③ を承認いただければ **最大 7 Issue** を追加で閉じられます (各 Issue は WBS 行が 2 本ずつあるため WBS 行ベースではさらに大きく減少)。

---

## ① Stale 行 (GitHub で既に close 済) — ✅ repair 済 / 承認不要

GitHub では既に close 済なのに 2026-07-15 WBS スナップショットで pending/in_progress のまま残っていた行。
sync ドリフト修復として migration `20260716130000_wbs_repair_stale_closed_asset_issues.sql` で completed 化済。

| Issue | 題名 | GitHub close 理由 | 実装エビデンス |
|---|---|---|---|
| #2941 | 口座間移動タスク管理 | completed (06-08) | `_createTransferTaskFromSuggestion` page:3534 / active・completed・canceled section page:24791-24966 |
| #2939 | 支払原資口座の未設定レビュー | completed (06-08) | `借金減少ラインの確認導線` page:22396 / `原資未設定 N件` chip page:22541 / 全 missing 行 list page:22598 |
| #3357 | 枯渇ウォッチ自動移動提案 | duplicate (06-15) | `_buildMovementSuggestions` insight:598-663 (of #3343) |
| #3318 | 安全割れ差替え移動提案 | duplicate (06-13) | 同上 (of #3343/#2941) |
| #3325 | ショート予兆ワンクリック作成 | duplicate (06-13) | 同上 (of #3343) |

---

## ② 実装済 → close 候補 (要承認)

受け入れ条件が実コードで満たされている Issue。close すると sync で WBS 行も completed 化。

### #3343 — 支払原資口座の見込み残高ショートからの自動口座移動提案生成 — **IMPLEMENTED**
- **エビデンス**: `_buildTransferSuggestions` `asset_liability_planning_service.dart:1729` (donor=`projectedBalance>30000` :1734 / shortage=`isShort` :1737 / `amount=min(shortfall, donorSurplus)` :1761) / モデル `AssetLiabilityTransferSuggestion` `asset_liability_workbook.dart:740` / UI パネル `_buildTransferSuggestionSection` `asset_management_page.dart:24785` + 「Create task」ボタン :24979 → `_createTransferTaskFromSuggestion` :3534。
- **AC 判定**: 「不足検出で具体案が出る」「ボタン一つで transfer_tasks へ」「再表示で反映」= すべて充足。
- **推奨**: **close (completed)**。これがクラスタ A の canonical 親。
- **唯一の nuance**: 発火が `projected<0`(safety 閾値ではない)。厳密な閾値運用が欲しければ差分を re-file。

### #3384 — 口座間移動タスクのステータスと残高見込みのリアルタイム連動 — **IMPLEMENTED**
- **エビデンス**: ステータス mutator `_toggleTransferTaskCompleted` page:3583 / cancel page:3686 / restore page:24874 が各々 `setState`+保存。`_buildAccountCashflowSummaries` が completed・canceled を除外して pending transfer を畳み込み `projectedBalance` を再計算 `asset_liability_planning_service.dart:1693-1722`。表示 workbook は毎 build 再構築 `page:8181` → 同一フレームで即時反映。
- **推奨**: **close (completed)**。
- **nuance**: 「遅延」ステータスは未モデル化 / 「リアルタイム」は Supabase live 購読ではなく in-app 即時再計算。この 2 点が必須なら小さな差分 Issue に再定義。

---

## ③ 重複 / enhancement → 重複 close + 差分 re-file 候補 (要承認)

実装済の親に対する重複。各 Issue は「1 点の差分」だけが残る。**重複 close + 差分だけ小 Issue に再登録**を推奨。

| Issue | 題名 | 親 | 残差分 (未実装の 1 点) | エビデンス |
|---|---|---|---|---|
| #3595 | 資金ショート予測口座への提案精度向上 | #3343 | **全額補填保証 + 5000 円バッファ** (現状 `amount=min(shortfall,donorSurplus)` で donor 上限にキャップ / buffer 無し) | planning:1761 / `+5000` grep=0 |
| #3585 | 利用可能額不足時の提案の根拠と優先度明確化 | #3343 | **対象支払の明示** (reason は不足額・期日のみ / `対象支払` grep=0) | insight:656,705,720 |
| #3328 | 安全残高を下回る際の赤帯アラートと即時振替起票 | #2941/#3343 | **`<safety_balance` 発火** (現状 `<0`) + 赤帯内インライン `振替起票` ボタン (現状ボタンは別カード・英語 `Create task:`) | 赤帯 page:23747 / ボタン page:24985 |
| #3354 | 支払原資口座の優先順位ルールと自動起票 | #2941 | **`PaymentFundingRule` モデル** (優先配列/最低残高/除外/自動割当) + **keyed `dedupe_key`** (現状は値比較 dedupe) | `PaymentFundingRule` grep=0 / dedupe page:3544 |
| #3383 | 支払原資口座未設定アラートの重要度とアクション具体化 | #2939 | **重要度バッジ (期日優先/要確認) + tooltip/modal** (検知と推奨口座 chip は実装済 / severity 表示のみ欠落) | 検知 workbook:1274 / 推奨 page:22860 / `_priorityLabel` は別セクション planning:2043 |

> ③ は「親は close、残差分だけを 1-2 行の小 Issue に再登録」すると、重複の山が畳まれつつ本当に欲しい改善だけが残ります。

---

## ④ 中核は実装済・固有機能が未実装 → open 継続 (scope 縮小 / Codex へ)

engine は実装済だが、Issue 固有の guided UI が未実装。**close せず、残スコープを明記して Codex 実装レーンへ。**

| Issue | 題名 | 実装済 | 真の残作業 |
|---|---|---|---|
| #3326 | カード明細取り込み失敗時の手動明細入力ウィザード | configured vs billed 検証 + diff≈0 で自動解消 `planning:1187` / 未取込検知 `planning:1180` | **手動明細行入力 wizard** (現状 CSV/TSV paste のみ page:22173) |
| #3329 | カード明細未取り込みの専用バナー + 3 ステップ手動照合ウィザード | needs_review バナー + jump link `page:18866,22113` | **3 ステップ wizard (請求額確認→差分入力→保存)** (現状は read-only DataTable) |
| #3291 | 入金予定ウィザードと必須チェック | 登録 dialog + 保存後 cashflow 再計算 `page:3896,8202` | **未登録時の支払確定ブロック gate** (現状は advisory card のみ insight:732) + 多段 wizard |

---

## ⑤ 完全未実装 → open 継続 (Codex へ)

| Issue | 題名 | 監査結果 |
|---|---|---|
| #3349 | カード明細照合差分の『仮内訳』即時登録 | **NOT_BUILT**。`provisional`/`仮内訳` は lib 全体で grep=0。モデル・service・UI すべて不在。 |
| #3443 | 支払原資不足時の『自動的』口座間移動提案と実行 | **NOT_BUILT (auto 部分)**。auto 作成なし / `user_settings_service.dart` 不在 / `AssetLiabilityUserSettingsPayload` に auto-exec toggle 無し / 自動実行履歴無し。手動部分は #2941 と重複。 |

---

## 付随: WBS 行の重複 (別軸の cleanup)

open Issue の多くは WBS 行が **2 本ずつ**存在 (スナップショットの「GitHub Issue / Feature Request」行 +
「ユーザー要望」行、同一 Issue 番号で別 UUID)。runbook の「同一 Issue の重複 WBS 行は 1 本を canonical に
残し他を duplicate」に該当。dedup migration `wbs_dedup_v2_active_issue_unique` の対象のはず。②③ の close 時に
canonical/duplicate を揃えると WBS 行数がさらに縮む。

---

## 推奨アクション (ユーザー承認事項)

1. **②を close**: #3343, #3384 (実装済 / 受け入れ条件充足) → completed。
2. **③を重複 close + 差分 re-file**: #3595, #3585, #3328, #3354, #3383 を「親の重複」として close し、
   上表「残差分」だけを 1-2 行の小 Issue に再登録。
3. **④⑤は open 維持**: #3326, #3329, #3291, #3349, #3443 を Codex 実装レーンへ。残スコープは本書の通り縮小済。

> 承認いただければ、②③ の GitHub Issue close + WBS 反映 migration + 差分 re-file を実行します
> (close は reversible / 実装済のエビデンスは本書 `file:line` で追跡可能)。

---

## 実行ログ (2026-07-16 / ②③ 承認済み実行)

- **③ 残差分の集約 Issue を新設**: **#4059**「集約後の残差分 5 点」— 5 項目のチェックリスト + `file:line`。
- **② close (completed)**: #3343, #3384 — 実装エビデンス付きコメント + `state_reason=completed`。
- **③ close (duplicate)**: #3595→dup #3343 / #3585→dup #3343 / #3328→dup #3343 / #3354→dup #2941 /
  #3383→dup #2939 — 各コメントで親と残差分 (#4059) を明示。
- **WBS 反映**: migration `20260716140000_wbs_complete_asset_consolidation_closures.sql` で
  7 Issue × 2 行 = **14 WBS 行**を completed 化 (`github_issue_state=CLOSED` + `ai_review_status=manual_override`)。
- ① の stale 5 行 (`20260716130000`) と合わせ、資産管理クラスタで **19 WBS 行**を completed 化。
- ④⑤ の 5 件 (#3326 #3329 #3291 #3349 #3443) は open 継続 → Codex 実装レーン (残スコープは本書の通り)。
