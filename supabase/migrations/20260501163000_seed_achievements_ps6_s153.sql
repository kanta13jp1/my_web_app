-- PS#6 S153: jockeyChangeBonus — 騎乗交代補正 confidence 69 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S153: 競馬予測EF confidence 69 terms — jockeyChangeBonus追加',
  '騎乗交代補正(jockeyChangeBonus)を追加。prev_jockeyvs jockey_nameで交代検出。交代あり+高勝率騎手(jockey_win_rate≥15%)=+1%(陣営強化シグナル)。交代あり+低勝率騎手(win_rate<5%)=-1%(陣営弱化シグナル)。日本競馬では騎手交代は重要情報源。主戦騎手継続時は0(ニュートラル)。confidence formula 69 terms体制確立。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
