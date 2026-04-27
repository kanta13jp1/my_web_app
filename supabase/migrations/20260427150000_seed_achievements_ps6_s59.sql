-- PS#6 S59: horse racing stats mode + GHA learning stats step
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S59 — 競馬AI 学習統計 stats mode',
  'fetch_horse_racing.py に --mode stats 追加: horse_learning_daily_accuracy 直近7日トレンド + horse_bet_type_accuracy TOP5 を標準出力 & GITHUB_STEP_SUMMARY Markdown 表書き込み。all モード末尾で自動 stats 出力。horse-racing-update.yml に学習統計レポートステップ追加 (JST 0時台 or stats/all)。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
