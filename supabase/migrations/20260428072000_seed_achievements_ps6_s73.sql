-- PS#6 S73: --force backfill対応 + AI予想プロンプト 持ち時計/馬体重変動明示
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬AI: --force backfill + プロンプト持ち時計/馬体重変動明示',
  'fetch_horse_racing.py backfill_learning_data()にforce=Falseパラメータ追加。--forceフラグでランキング算法変更後に既存ベースライン予想を強制再生成可能に。horse-racing-update.yml workflow_dispatch にforce input追加。buildHorseRacePromptを更新し持ち時計(best_time)と馬体重変動(±10kg超はリスク信号)をAIモデルへの指示に明示追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
