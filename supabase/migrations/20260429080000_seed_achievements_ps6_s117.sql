-- PS#6 S117: barrierPositionBonus (枠番補正) — confidence 33 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S117: 枠番補正 (barrierPositionBonus) confidence 33 terms',
  '競馬予測EF confidence式に枠番補正(barrierPositionBonus)を追加。内枠(1〜2枠)=+1%/外枠(7〜8枠)=-1%/中枠(3〜6枠)=0。frameForHorseNumber関数と統合。confidence式33 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
