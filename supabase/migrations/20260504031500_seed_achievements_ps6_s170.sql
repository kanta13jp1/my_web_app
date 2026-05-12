-- PS#6 S170: jockeyGradeCompatibilityBonus — 騎手勝率×グレード難易度適性補正 confidence 86 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S170: 競馬予測EF confidence 86 terms — jockeyGradeCompatibilityBonus追加',
  '騎手勝率×グレード難易度適性補正(jockeyGradeCompatibilityBonus)を追加。G1/G2(top-tier grade)レース限定で騎手の通算勝率(jockey_win_rate)を評価。①jockey_win_rate≥18%(超トップジョッキー) × G1/G2=+1%(大舞台経験豊富なエースが最高峰で真価発揮)。②jockey_win_rate<7%(低勝率騎手) × G1/G2=-1%(重賞レースでの力量不足リスク)。平場・G3では発動しない(グレード限定)。jockeyWinRateBonus(S26:全レース通算勝率汎用評価)とjockeyTopCourseBonus(S155:騎手得意コース)がそれぞれ単独評価するのに対し、本補正はG1/G2という難易度フィルタを追加した精密評価。confidence formula 86 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
