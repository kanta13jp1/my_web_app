-- ============================================================
-- growth_plans に機能実装完了率カラムを追加
-- features_done: 実装済み機能数（partial は 0.5 としてカウント）
-- features_total: 競合製品の全機能数（対応機能の総数）
-- ============================================================

alter table public.growth_plans
  add column if not exists features_done integer not null default 0,
  add column if not exists features_total integer not null default 0;

-- 競合別の機能実装状況（2026-03-25 時点の推計値）
-- done=1点、partial=0.5点として算出
-- 短期/中期/長期計画は development_achievements 件数を使うため features_total=0 で管理

update public.growth_plans set features_done = 0,  features_total = 0   where label in ('短期計画','中期計画','長期計画');
update public.growth_plans set features_done = 14, features_total = 32  where label = 'vs NOTION';
update public.growth_plans set features_done = 11, features_total = 26  where label = 'vs EverNote';
update public.growth_plans set features_done = 9,  features_total = 22  where label = 'vs MoneyForward';
update public.growth_plans set features_done = 13, features_total = 24  where label = 'vs X';
update public.growth_plans set features_done = 16, features_total = 20  where label = 'vs Animaworks';
update public.growth_plans set features_done = 13, features_total = 18  where label = 'vs Claude Code';
update public.growth_plans set features_done = 11, features_total = 16  where label = 'vs Codex';
update public.growth_plans set features_done = 8,  features_total = 24  where label = 'vs netkeiba';
update public.growth_plans set features_done = 11, features_total = 18  where label = 'vs OpenClaw';
update public.growth_plans set features_done = 13, features_total = 20  where label = 'vs Claude Cowork';
update public.growth_plans set features_done = 11, features_total = 22  where label = 'vs Chatwork';
update public.growth_plans set features_done = 9,  features_total = 28  where label = 'vs Slack';
update public.growth_plans set features_done = 7,  features_total = 20  where label = 'vs ジョブカン';
