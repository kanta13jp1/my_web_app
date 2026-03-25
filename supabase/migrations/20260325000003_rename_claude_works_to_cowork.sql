-- ============================================================
-- Migration: 2026-03-25 session3
-- growth_plans テーブルの "vs Claude works" を "vs Claude Cowork" に更新
-- ============================================================

update public.growth_plans
  set label = 'vs Claude Cowork'
  where label = 'vs Claude works';
