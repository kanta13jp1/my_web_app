-- PS#4 S432: 競合3社追加 1120→1123社 (steam/gog/mastodon)
-- SEO: "Steam代替"/"GOG代替"/"Mastodon代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S432: 競合3社追加 1120→1123社 (steam/gog/mastodon)',
  'comparison_page.dartにsteam(Valve PCゲームプラットフォーム50000+タイトルSteam Deck/gaming/1B2838)/gog(CD Projekt DRMフリーPCゲームGalaxy クライアント/gaming/6440B2)/mastodon(分散型SNS ActivityPub広告なし自己ホスト/social/6364FF)の3社追加(1120→1123社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
