# Cross-Instance PR: WBS PS#2 カテゴリ誤割当修正

**作成**: PS版#2 S24 / 2026-04-25
**宛先**: Win版
**優先度**: low

## 問題

wbs.priority_for_instance("ps2") が business-legal タスクを返す。
正規マッピング (Win#132 part 16): business-legal → win / business-marketing → ps2

## 根本原因 (推定)

20260425203000 が all tasks x all instances の cartesian INSERT を実行。
ps2 に business-legal コピーが残存。

## 修正方法 (Win版が判断)

Option A: DELETE FROM wbs_tasks WHERE instance='ps2' AND category='business-legal'
Option B: UPDATE instance='win' WHERE instance='ps2' AND category='business-legal'
Option C: 無視 (T-1 dispatch 業務には影響なし)
