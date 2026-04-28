-- PS#6 S103: venueConfidenceBonus — JRA/NAR会場別confidence調整
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S103: 競馬予想モデル venueConfidenceBonus (会場別confidence調整)',
  'venueConfidenceBonus(venue)関数を追加。JRA主要4場(東京/中山/京都/阪神)=+0.03、その他JRA=+0.01、NAR地方競馬=-0.02、ばんえい(帯広)=-0.04。confidence式に組み込み、reasoning文字列に会場補正%を明示。20 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
