-- PS#4 S420: 競合3社追加 1084→1087社 (busuu/memrise/preply)
-- SEO: "Busuu代替"/"Memrise代替"/"Preply代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S420: 競合3社追加 1084→1087社 (busuu/memrise/preply)',
  'comparison_page.dartにbusuu(AI言語学習ネイティブ練習修了証書/language/3DB549)/memrise(スペースドリピテーション動画語学AIロールプレイ/language/56B366)/preply(オンライン語学チューター1対1ビジネス英語/language/6A5ACD)の3社追加(1084→1087社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
