-- PS#6 S79: 競馬予想プロンプト コース替わり・距離適性リスク明示
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S79: コース替わり・距離適性リスクをプロンプトに追加',
  '競馬AI予想プロンプトに「前走コース種別が今回と異なる場合はコース替わりリスク評価」と「前走距離と今回距離の差が200m超の場合は距離適性リスク考慮」を明示追加。芝/ダート替わり・短縮/延長を明示的に推論させる。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
