-- VSCode版 S25: CFO Office コスト・予算管理接続 + 自己接触トラッカーページ新規実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'CFO オフィスにコスト・予算管理を接続 (#1669 UI)',
    'CfoOfficePage に BudgetFinancialPlannerPage を追加。月次予算設定・カテゴリ別支出入力・AI節約アドバイス・将来シミュレーションが CFO オフィスから直接アクセス可能になった。',
    '2026-05-03'
  ),
  (
    '自己接触トラッカーページ新規実装 (#1272)',
    'SelfTouchTrackerPage を新規作成。AbstinenceGuardStore を再利用して touch_hair アイテムの 1 タップ記録・過去7日間バーチャート・警戒閾値超え時の代替アクション底シート表示を実装。/self-touch-tracker route 追加。',
    '2026-05-03'
  ),
  (
    'GitHub Issues 10 件登録 (VSCode S25 + bc58b50b + AI-Tool-Watch)',
    'NotebookLM bc58b50b の VSCode 領域への展開 (Issues #1739-#1740)、WBS 未着手 UI タスク (Issues #1741-#1746)、AI_FLEET_SYNERGY KPI (Issue #1748)、AI-Tool-Watch skill 化 (Issue #1747) を登録。後続セッション引き継ぎ完了。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
