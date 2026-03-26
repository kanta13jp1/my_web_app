-- ============================================================
-- Migration: 2026-03-25 (between session6 and session7)
-- development_achievements テーブルに description・category・
-- achieved_at・impact_level カラムを追加
--
-- 背景: session7以降のシードが新カラムを参照しているが
-- 初期テーブル定義 (000000) にはこれらのカラムが無かったため
-- マイグレーション適用時にエラーとなっていた。
-- ============================================================

alter table public.development_achievements
  add column if not exists description  text,
  add column if not exists category     text,
  add column if not exists achieved_at  timestamptz,
  add column if not exists impact_level text;
