-- VSCode版 S27: LifeGoals 月次KPI台帳UI新規実装 (#1827)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'LifeGoals 月次KPI台帳UI新規実装 (#1827)',
    'LifeGoalsKpiPage新規作成 — 今月のサマリ(平均前進pt+達成small goal件数)+4階層CSF/KPI台帳(dream/big/medium/small×KgiCsfKpiPanel再利用)+未達リスクCard(30日以内期限×progress<80%)。クライアント側集計(life_goals+life_goal_reviews月次delta)。/life-goals-kpi route登録+LifeGoalsPageにAppBar KPI台帳ボタン追加。',
    '2026-05-03'
  )
ON CONFLICT DO NOTHING;
