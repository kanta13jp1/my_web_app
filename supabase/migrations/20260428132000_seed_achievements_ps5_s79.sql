-- PS#5 S79: PR #860 test ブロッカー残り2件解消
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PR #860 test fix 残り2件 (PS#5 S79)',
  'memory_drill_page.dart: _loadCustomPacks の Supabase.instance.client を try/catch で囲み VM test での未初期化クラッシュを解消。ai_status_page_test.dart: S74 anon guard が mock で unstubbed → _FakeGoTrueClient/_FakeUser 追加 + auth stub を setUp に追加して MissingStubError を解消。PR #860 の CI ブロッカー 3件全完了。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
