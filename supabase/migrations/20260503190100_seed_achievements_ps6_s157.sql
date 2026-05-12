-- PS#6 S157: prev2FormGapBonus — 前走vs前々走着順ギャップ補正 confidence 73 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S157: 競馬予測EF confidence 73 terms — prev2FormGapBonus追加',
  '前走vs前々走着順ギャップ補正(prev2FormGapBonus)を追加。prev_finish(f1)とprev2_finish(f2)のギャップ(f2-f1)を算出。①ギャップ+3以上=+1%(直近3着以上急改善=上昇加速シグナル/巻き返し機動力の証拠)。②ギャップ-3以下=-1%(直近3着以上急悪化=下降加速シグナル/失速リスク)。prev3FormTrendBonus(S152)が3走全体のトレンド方向を見るのに対し、本補正は直近2走間のギャップの大きさ(加速度)を評価。confidence formula 73 terms体制確立。',
  '2026-05-03'
) ON CONFLICT DO NOTHING;
