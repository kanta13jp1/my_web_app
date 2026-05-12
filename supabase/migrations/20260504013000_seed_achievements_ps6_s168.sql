-- PS#6 S168: sireDistanceAffinityBonus — 父×距離適性補正 confidence 84 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S168: 競馬予測EF confidence 84 terms — sireDistanceAffinityBonus追加',
  '父×距離適性補正(sireDistanceAffinityBonus)を追加。種牡馬系統の距離特性と現在レース距離の一致/不一致を評価。スプリント血統(ロードカナロア/サクラバクシンオー/タイキシャトル/ビッグアーサー)と短距離(≤1400m)の一致=+1%。スタミナ血統(ハービンジャー/マンハッタンカフェ/ゴールドシップ/ジャングルポケット)と長距離(≥2000m)の一致=+1%。逆適性は各-1%。bloodlineCourseTypeBonus(S118:父×芝/ダート適性)が馬場種別軸を見るのに対し、本補正は距離軸での血統適性を評価。sireRankBonus(S150:トップ種牡馬産駒一律+1%)に距離文脈を追加。confidence formula 84 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
