-- PS#6 S105: prevVenueMatchScore — 前走同会場sort因子追加 (sort 19因子体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S105: 競馬予想モデル prevVenueMatchScore (前走同会場sort因子 sort 19因子体制)',
  'prevVenueMatchScore(entry, raceVenue)関数を追加。前走と今回の会場が同じ馬を優遇(score=-2)。sortのfactor 19に追加、horse_numberはfactor 20に繰り上げ。raceCtxにvenue追加でsort関数に会場情報を伝達。sort 19因子体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
