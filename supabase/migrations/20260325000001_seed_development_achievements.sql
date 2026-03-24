-- ============================================================
-- Seed: 2026-03-25
-- 開発実績の初期データ投入
-- ============================================================

insert into public.development_achievements (title, completed_at) values
  ('flutter analyze 216件エラー → 0件達成 (CompetitorFeatureComparisonCard の _FeatureRow.competitorName 削除・_isLoading バグ修正・bracket 不整合解消)', '2026-03-25 09:00:00+00'),
  ('ホーム画面に「GROWTH / 成長導線」セクションを新設 (インポート・成長ミッション・公開メモ一覧への直接リンク追加)', '2026-03-25 09:30:00+00'),
  ('ユーザーマニュアル全面刷新 (実際のホーム画面ナビゲーションに準拠した8セクション構成・存在しない「ホームメニュー」への言及を削除)', '2026-03-25 10:00:00+00'),
  ('development-achievements Edge Function 新規作成 (13段階の期間フィルタ対応 GET / 新規追加 ADD)', '2026-03-25 11:00:00+00'),
  ('get-growth-roadmap-progress Edge Function 新規作成 (user_profiles からユーザー数・growth_plans テーブルから計画データ取得・自動シード対応)', '2026-03-25 11:30:00+00'),
  ('deno.json に lint.rules.exclude = ["no-import-prefix"] を追加し deno 2.x でのURL import 方式エラーを全関数で解消', '2026-03-25 12:00:00+00'),
  ('deno lint 0件達成 (growth-achievement-summary・growth-referral の no-explicit-any を deno-lint-ignore で抑制)', '2026-03-25 12:30:00+00'),
  ('index.ts (get-competitor-features) の require-await エラー修正 (不要な async キーワード削除)', '2026-03-25 13:00:00+00'),
  ('DB マイグレーション作成: development_achievements・growth_plans・home_daily_status テーブルとRLS設定', '2026-03-25 14:00:00+00'),
  ('ホーム画面に GROWTH ROADMAP 進捗バー (短期/中期/長期/vs 13競合) をリアルタイム表示する GrowthRoadmapProgressCard を追加 (2026-03-24)', '2026-03-24 10:00:00+00'),
  ('競合機能比較カードを13タブ構成に拡張 (Notion/EverNote/MoneyForward/X/Animaworks/Claude Code/Codex/netkeiba/OpenClaw/Claude works/Chatwork/Slack/ジョブカン)', '2026-03-24 12:00:00+00'),
  ('DevelopmentAchievementsCard を本実装 (development-achievements Edge Function と連携・ダミーデータ完全排除)', '2026-03-24 14:00:00+00'),
  ('referral anti-abuse 実装 (1日5件レート制限・1時間未満アカウントブロック)', '2026-03-25 08:00:00+00'),
  ('growth-weekly-digest Edge Function 追加 (7日間のチャンネル別CVR集計)', '2026-03-25 08:30:00+00')
on conflict do nothing;
