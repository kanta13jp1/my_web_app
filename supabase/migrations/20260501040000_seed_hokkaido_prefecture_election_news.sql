-- Hokkaido prefecture_election_news seed (Win版#132 part 107 / 2026-05-01)
--
-- User 共有 News (= 朝日新聞 2026-04-12 / 国民民主党北海道連 道連定期大会):
--   「来春の統一地方選で公認・推薦の道議、市町村議を合わせて 20〜30 人の当選を
--    めざす方針 / 現市議 4 人から 5 倍以上を目標 / 札幌中心に旭川・函館・苫小牧・
--    釧路など都市部 / 公募で新顔擁立 / 現時点で 15 人ほどのめど」
--   発表者: 臼木秀剛 道連代表 (衆院議員)
--
-- Win版#132 part 106 で確立した prefecture_election_news schema を再利用.
-- 「News driven scaffolding」pattern 第 2 例. 1 県 → 2 県への拡張で schema 汎用性検証.

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
)
SELECT
  '北海道',
  '国民民主党',
  '国民民主党道連、統一地方選で 20〜30 人の地方議員目標 札幌など',
  '国民民主党北海道連は 2026-04-12 の道連定期大会に合わせて、来春 (2027) の統一地方選で公認・推薦の道議・市町村議を合わせて 20〜30 人の当選をめざす方針を発表. 現市議 4 人から 5 倍以上を目標. 札幌を中心に旭川・函館・苫小牧・釧路など都市部の市議選を中心に公募で新顔擁立 + 現職の公認・推薦も進める. 臼木秀剛 道連代表 (衆院議員) が記者会見で説明: 「人口 10 万人前後のところには立てていきたい. 札幌市内とそういった都市部、さらに町村を含めて手を挙げてくれば、ハードルは高いが、見えてくる数字」. 現時点で 15 人ほどのめど. 知事選については民主連絡調整会議 (立憲民主道連 / 国民民主道連 / 連合北海道) で別の候補を応援していたが、立憲・公明などの検討を見守る考え.',
  'https://www.asahi.com/',
  '朝日新聞',
  '2026-04-12',
  30,
  15,
  NULL,
  '統一地方選',
  2027,
  '臼木秀剛'
WHERE NOT EXISTS (
  SELECT 1 FROM prefecture_election_news
  WHERE prefecture = '北海道'
    AND party = '国民民主党'
    AND announced_at = '2026-04-12'
);

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 107: prefecture_election_news 北海道 seed (= News driven scaffolding 第 2 例)',
  'User 共有 News (= 朝日新聞 2026-04-12 / 国民民主党北海道連定期大会 / 統一地方選で 20〜30 人擁立目標 / 現市議 4 人から 5 倍以上 / 札幌中心に旭川・函館・苫小牧・釧路 / 15 人めど / 臼木秀剛代表) を反映. part 106 で確立した schema を再利用 = 「1 県 → 2 県への拡張で schema 汎用性検証」. 「News driven scaffolding」pattern 第 2 例. WBS migration `20260501040000`.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 107: prefecture_election_news 北海道 seed (= News driven scaffolding 第 2 例)'
);
