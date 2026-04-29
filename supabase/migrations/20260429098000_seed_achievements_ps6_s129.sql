-- PS#6 S129: winningExperienceBonus (勝利実績補正) — confidence 45 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S129: 勝利実績補正 (winningExperienceBonus) confidence 45 terms',
  '競馬予測EF confidence式に勝利実績補正(winningExperienceBonus)を追加。winning_timeフィールドが存在する場合=+1%(過去勝利実績あり/勝ち方を知っている/精神的優位)。winning_timeは過去に勝利した際のタイムデータ。best_timeのみ(入着止まり)との差別化で勝利経験を評価。45 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
