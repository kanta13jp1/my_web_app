-- PS#6 S65: horseracing.consensus 複勝コンセンサス追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S65 — consensus に複勝コンセンサス (place_votes) 追加',
    'horseracing.consensus EF action に place_consensus + place_distribution を追加。1着(×1.0)/2着(×0.7)/3着(×0.5) の信頼度加重合算で複数プロバイダーが推す複勝候補馬を特定。同一プロバイダーが同じ馬を複数ポジションで推す重複は seen Set で防止。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
