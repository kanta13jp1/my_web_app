-- PS#6 S77: 競馬予想モデル 休み明けペナルティ (prev_days_ago 10因子目)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S77: 休み明けペナルティ追加 (prev_days_ago 10因子目)',
  '競馬AIランキングに休み明けペナルティ (freshnessPenaltyScore) を10因子目として追加。prev_days_ago 90日超=休み明けリスク/180日+=超長期。データ品質スコアも prev_days_ago を含め16→17項目化。プロンプトに「90日超は休み明けリスク」を明示。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
