-- Session 2026-03-28: 全文検索安定化・ノート検索カード追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('全文検索安定化 (OpenAI フォールバック)', 'ai-search Edge Function を ILIKE ベースのテキスト検索フォールバック付きハイブリッド構成に改修。OpenAI 未設定環境でも検索が動作。searchMode フィールドで AI/text/text_fallback を返すよう拡張', '2026-03-28'),
  ('ノート検索カード (ホーム画面)', 'NoteSearchCard をホーム画面に追加。ワンタップで AiSearchPage へ遷移。キーワード・自然言語横断検索への導線を強化', '2026-03-28')
ON CONFLICT DO NOTHING;
