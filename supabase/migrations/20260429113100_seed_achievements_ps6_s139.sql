-- PS#6 S139: sireRankBonus (現役トップ種牡馬産駒補正) — confidence 55 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S139: 現役トップ種牡馬産駒補正 (sireRankBonus) confidence 55 terms',
  '競馬予測EF confidence式に現役トップ種牡馬産駒補正(sireRankBonus)を追加。ロードカナロア/キタサンブラック/エピファネイア/ハービンジャー/モーリス/ルーラーシップ/オルフェーヴル/キズナ/ドゥラメンテ/リアルスティールの10頭トップ種牡馬産駒=+1%(高連対率/市場信頼高/ファンデータ充実)。bloodlineTopHorseBonusが血統データ充足を評価するのに対し本補正は種牡馬の市場ブランド力と産駒実績の強さを評価する。55 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
