-- PS#6 S163: largeFieldPerformerBonus — 大頭数実績補正 confidence 79 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S163: 競馬予測EF confidence 79 terms — largeFieldPerformerBonus追加',
  '大頭数実績補正(largeFieldPerformerBonus)を追加。14頭以上の大頭数レースでの前走成績を評価。①14頭以上かつ前走3着以内=+1%(大競争環境での実力証明/混戦適性の証)。②14頭以上かつ前走10着以下=-1%(大頭数での不振=混戦不向きシグナル)。fieldWeightRankBonus(S163:出走頭数での斤量相対評価)と異なり、本補正は頭数そのものを競争環境変数として使用。小頭数レース(14頭未満)は±0%(別評価軸)。confidence formula 79 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
