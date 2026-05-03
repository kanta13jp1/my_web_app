-- PS#6 S162: prev3WinRateBonus — 前3走勝率補正 confidence 78 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S162: 競馬予測EF confidence 78 terms — prev3WinRateBonus追加',
  '前3走勝率補正(prev3WinRateBonus)を追加。prev_finish/prev2_finish/prev3_finishの中で1着の回数をカウント。①前3走で2勝以上=+1%(近走圧倒的勝負強さ/連勝パターン)。②前3走で無勝利かつ全て5着以下=-1%(勝利遠く着内もなし=低実力シグナル)。winningExperienceBonus(S48:生涯勝利実績)がwinning_time有無を見るのに対し、本補正は直近3走の実際の1着頻度を評価。confidence formula 78 terms体制確立。',
  '2026-05-03'
) ON CONFLICT DO NOTHING;
