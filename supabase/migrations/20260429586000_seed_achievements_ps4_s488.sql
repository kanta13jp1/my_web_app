-- PS#4 S488: 競合3社追加 継続 (wanikan/clozemaster/anki)
-- SEO: "WaniKani代替"/"Clozemaster代替"/"Anki代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S488: 競合3社追加 (wanikan/clozemaster/anki)',
  'comparison_page.dartにwanikan(漢字SRSラジカル分解6000語彙60レベルJLPT N5-N1/FF69B4)/clozemaster(50言語50000文穴埋めゲーム統計習熟B2-C2上級者/6200EA)/anki(OSS100万デッキAnkiWeb同期医学/語学/資格/0055CC)の3社追加。sitemap 1381 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
