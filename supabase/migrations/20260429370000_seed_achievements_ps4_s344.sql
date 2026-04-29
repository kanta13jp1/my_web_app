-- PS#4 S344: 競合3社追加 903→906社 (boomy/aiva/loudly)
-- SEO: "Boomy代替"/"AIVA代替"/"Loudly代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S344: 競合3社追加 903→906社 (boomy/aiva/loudly)',
  'comparison_page.dartにboomy(AI音楽生成1クリック楽曲収益化/music-gen/F59E0B)/aiva(AI作曲映画ゲーム向けサウンドトラック/music-gen/4338CA)/loudly(AIテキストto音楽ロイヤリティフリー/music-gen/059669)の3社追加(903→906社)。sitemap 949 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
