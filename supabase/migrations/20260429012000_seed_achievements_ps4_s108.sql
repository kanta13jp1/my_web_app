-- PS#4 S107/S108: 競合追加修正 + webflow/framer/copy-ai新規追加 195→198社
-- S107は runway/heygen/elevenlabs が既存エントリと重複 → 重複除去後 195社維持
-- S108: webflow/framer/copy-ai 3社新規追加 (195→198社)
-- SEO: "Webflow代替"/"Framer代替"/"Copy.ai代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S108: 競合3社追加 195→198社 (webflow/framer/copy-ai)',
  'comparison_page.dartにwebflow(ノーコードWebサイト構築/月額14USD~/no-code)/framer(AI駆動Webデザイン/月額15USD~/no-code)/copy-ai(AIコピーライティング/月額49USD~/ai-writing)の3社追加(195→198社)。新カテゴリno-code/ai-writing追加。competitorMeta/sitemap(+3URL priority=0.8)/_categoryOf更新。全ファイル社数表記195→198統一。S107 runway/heygen/elevenlabs重複除去済み。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
