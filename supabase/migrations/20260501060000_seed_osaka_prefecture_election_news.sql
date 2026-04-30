-- Osaka prefecture_election_news seed (Win版#132 part 109 / 2026-05-01)
--
-- User 共有 News (= X / @tamakiyuichiro 2026-04-25 8:41 PM):
--   「国民民主党大阪府連の定期大会と街頭演説会に参加しました.
--    いぜん大阪では厳しい状況ですが、ご支援いただいている皆さんのおかげで、
--    少しずつ所属議員も増えてきています.
--    来春の統一選挙に向けて 30 名を超える候補者の擁立をめざして頑張ります.
--    大阪でも国民民主党を、よろしくお願いします.」
--   発表者: 玉木雄一郎 国民民主党代表
--
-- Win版#132 part 106 schema を再利用 / 「News driven scaffolding」第 4 例.
-- 4 県累計: 宮崎 + 北海道 + 香川 + 大阪.

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
)
SELECT
  '大阪',
  '国民民主党',
  '国民民主党大阪府連 定期大会 + 街頭演説会 (玉木代表) — 統一選挙で 30 名超擁立目標',
  '玉木雄一郎党代表が 2026-04-25 に大阪府連の定期大会と街頭演説会に参加. X (@tamakiyuichiro) で発信: 「いぜん大阪では厳しい状況ですが、ご支援いただいている皆さんのおかげで、少しずつ所属議員も増えてきています. 来春の統一選挙に向けて 30 名を超える候補者の擁立をめざして頑張ります. 大阪でも国民民主党を、よろしくお願いします.」64.2K Views / いいね 1.7K. 大阪は伝統的に他党 (= 維新等) の地盤で「厳しい状況」と認識しつつ拡大方針.',
  'https://x.com/tamakiyuichiro',
  'X (@tamakiyuichiro)',
  '2026-04-25',
  30,
  NULL,
  NULL,
  '統一地方選',
  2027,
  '玉木雄一郎'
WHERE NOT EXISTS (
  SELECT 1 FROM prefecture_election_news
  WHERE prefecture = '大阪'
    AND party = '国民民主党'
    AND announced_at = '2026-04-25'
);

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 109: prefecture_election_news 大阪 seed (= News driven scaffolding 第 4 例)',
  'User 共有 News (= X @tamakiyuichiro 2026-04-25 / 国民民主党大阪府連定期大会 + 街頭演説会 / 玉木代表 / 来春統一選挙で 30 名超擁立目標 / 大阪は厳しい状況だが所属議員少しずつ増) を反映. part 106 schema 再利用 = 「News driven scaffolding」pattern 第 4 例. 4 県累計 (= 宮崎 + 北海道 + 香川 + 大阪) で SNS source (= X) にも schema 汎用対応.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 109: prefecture_election_news 大阪 seed (= News driven scaffolding 第 4 例)'
);
