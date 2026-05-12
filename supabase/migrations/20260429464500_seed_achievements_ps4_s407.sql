-- PS#4 S407: 競合3社追加 1045→1048社 (signwell/zoho-sign/duda)
-- SEO: "SignWell代替"/"Zoho Sign代替"/"Duda代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S407: 競合3社追加 1045→1048社 (signwell/zoho-sign/duda)',
  'comparison_page.dartにsignwell(シンプル電子署名無料プラン充実中小企業向け/e-signature/059669)/zoho-sign(Zohoスイート統合電子署名文書自動化/e-signature/D9232D)/duda(代理店SaaS向けホワイトラベルWebサイトビルダー/website-builder/1B8EF8)の3社追加(1045→1048社)。sitemap 1138 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
