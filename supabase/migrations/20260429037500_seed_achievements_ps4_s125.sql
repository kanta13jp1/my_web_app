-- PS#4 S125: 競合3社追加 246→249社 (invision/zeplin/helpscout)
-- SEO: "InVision代替"/"Zeplin代替"/"Help Scout代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S125: 競合3社追加 246→249社 (invision/zeplin/helpscout)',
  'comparison_page.dartにinvision(UIプロトタイピング/design/FF3366)/zeplin(デザインハンドオフ/design/FFBD00)/helpscout(カスタマーサポート/support/1292EE)の3社追加(246→249社)。sitemap292URLs/全ファイル社数表記249統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
