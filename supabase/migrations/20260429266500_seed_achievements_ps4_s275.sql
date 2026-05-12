-- PS#4 S275: 競合3社追加 696→699社 (leetcode/hackerrank/datacamp)
-- SEO: "LeetCode代替"/"HackerRank代替"/"DataCamp代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S275: 競合3社追加 696→699社 (leetcode/hackerrank/datacamp)',
  'comparison_page.dartにleetcode(コーディング面接対策アルゴリズム/coding/FFA116)/hackerrank(コーディングテスト採用評価/coding/00EA64)/datacamp(データサイエンスAI特化学習/learning/03EF62)の3社追加(696→699社)。sitemap 742 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
