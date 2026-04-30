-- VSCode版 S24: 宮崎県連 news badge UI
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '宮崎県連 news badge UI (ElectionNewsBadge widget)',
  'ElectionNewsBadge StatefulWidget — prefecture_election_news Supabase fetch / 公式発表値 (計/確定/公募 chips) + 出典リンク / election_victory_page _buildPrefectureCard 統合 / 全 prefecture 対応 (将来 News seed で自動表示)',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
