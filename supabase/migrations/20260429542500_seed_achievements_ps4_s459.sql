-- PS#4 S459: 競合3社追加 1198→1201社 (plex/jellyfin/monzo)
-- SEO: "Plex代替"/"Jellyfin代替"/"Monzo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S459: 競合3社追加 1198→1201社 (plex/jellyfin/monzo)',
  'comparison_page.dartにplex(個人メディアサーバーPlex Pass無料映画TV/E5A00D)/jellyfin(OSSメディアサーバー完全無料自己ホスティング/00A4DC)/monzo(UKネオバンクPots家計分析海外手数料ゼロ/FF4A6D)の3社追加(1198→1201社)。sitemap 1300 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
