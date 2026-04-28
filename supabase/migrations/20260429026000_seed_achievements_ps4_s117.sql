-- PS#4 S117: vsMatch修正+競合3社追加 222→225社 (hubspot/miro/linear)
-- バグ修正: S115-S116でcategoryOfのみ追加されたmailerlite/hotjar/amplitude/mixpanel/brevo/beehiivのvsMatchエントリを補完
-- SEO: "HubSpot代替"/"Miro代替"/"Linear代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S117: vsMatch修正+競合3社追加 222→225社 (hubspot/miro/linear)',
  'S115-S116でcategoryOf/sitemapのみ追加されていたmailerlite/hotjar/amplitude/mixpanel/brevo/beehiivの6社にvsMatchエントリを補完(バグ修正)。さらにhubspot(CRM+マーケティングオートメーション/crm/FF7A59)/miro(オンラインホワイトボード/whiteboard/FFD02F)/linear(開発チームイシュー管理/project/5E6AD2)の3社をvsMatch+categoryOf+sitemap(274URLs)に追加(222→225社)。全ファイル社数表記222→231(S117-S119合計)統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
