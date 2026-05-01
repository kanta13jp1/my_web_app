-- PS#6 S154: prevPopularityBounceBonus — 前走人気リバウンド補正 confidence 70 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S154: 競馬予測EF confidence 70 terms — prevPopularityBounceBonus追加',
  '前走人気リバウンド補正(prevPopularityBounceBonus)を追加。①前走1-2番人気→4着以下敗退=+1%(人気馬が負けた後の巻き返し期待シグナル)。②前走6番人気以下→3着以内好走=+1%(人気薄好走実績=陣営が本番に向けた仕上げの証拠)。prev_popularityとprev_finishフィールドを使用。confidence formula 70 terms体制確立。',
  '2026-05-02'
) ON CONFLICT DO NOTHING;
