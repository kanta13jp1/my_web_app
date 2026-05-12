-- PS#6 S109: consensusBonus — 3指標合意confidenceボーナス (25 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S109: 競馬予想モデル consensusBonus (3指標合意confidenceボーナス)',
  'consensusBonus(topEntry)関数を追加。1番人気(popularity==1)+低オッズ(≤3.0)+前走好走(≤3着)の3指標全一致=+0.04/2指標一致=+0.02/それ以外=0。人気・オッズ・実績の3軸が揃う「真の本命」を confidence 最大+4% でブースト。confidence式に組み込み25 terms体制確立。reasoning文字列に「合意補正:+X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
