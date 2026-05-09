-- PS#6 S166: runningStyleFieldSizeBonus — 脚質×頭数複合補正 confidence 82 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S166: 競馬予測EF confidence 82 terms — runningStyleFieldSizeBonus追加',
  '脚質×頭数複合補正(runningStyleFieldSizeBonus)を追加。running_style(逃/先/差/追)と出走頭数を組み合わせた評価。①大頭数(14+)×逃げ/先行=-1%(ペース激化で消耗戦リスク)。②大頭数(14+)×差し/追い込み=+1%(外差し展開で捌きスペース確保)。③少頭数(≤8)×逃げ/先行=+1%(ペース落ち着き脚質活きる)。runningStyleDistanceBonus(S107:脚質×距離)が距離軸を見るのに対し、本補正は頭数軸での脚質適性を評価。largeFieldPerformerBonus(S163:大頭数×前走着順)との補完関係。confidence formula 82 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
