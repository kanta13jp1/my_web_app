-- PS#4 S437: 競合3社追加 1135→1138社 (bandcamp/nintendo-switch-online/apple-arcade)
-- SEO: "Bandcamp代替"/"Nintendo Switch Online代替"/"Apple Arcade代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S437: 競合3社追加 1135→1138社 (bandcamp/nintendo-switch-online/apple-arcade)',
  'comparison_page.dartにbandcamp(DRMフリーアーティスト直接支援ファンDB所有Bandcamp Friday/music/1DA0C3)/nintendo-switch-online(NES/SNES/N64/GBAクラシックオンライン対戦クラウドセーブ/gaming-sub/E60012)/apple-arcade(200+タイトル広告/課金なしiOS/Mac/tvOS対応/gaming-sub/555555)の3社追加(1135→1138社)。sitemap 1228 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
