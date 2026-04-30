-- Kagawa prefecture_election_news seed (Win版#132 part 108 / 2026-05-01)
--
-- User 共有 News (= KSB 瀬戸内海放送 / Yahoo!ニュース 2026-04-26 / 国民民主党香川県連大会):
--   「玉木雄一郎党代表が登壇 / 党の勢力拡大 / 自治体議員数を 26 → 56 名 (= +30) /
--    来春の統一地方選までに / 原田秀一参議院議員 (2025-07 当選) も国政活動報告」
--   発表者: 玉木雄一郎 国民民主党代表 (= 党大会で発言 / 県連代表ではなく党代表)
--
-- Win版#132 part 106 で確立した prefecture_election_news schema を再利用.
-- 「News driven scaffolding」pattern 第 3 例 (= 宮崎 / 北海道 / 香川 = 3 県目).

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
)
SELECT
  '香川',
  '国民民主党',
  '国民民主党香川県連大会 玉木代表「香川の自治体議員を 26 名から 56 名に」 (高松市)',
  '国民民主党の香川県総支部連合会の大会が 2026-04-26 高松市で開かれ、玉木雄一郎党代表が登壇. 衆議院選挙を振り返り、今後は党の勢力を拡大していきたいと意欲. 玉木代表「地力をちゃんと全国でつけていかなければいけないということが一番の反省. そのためには自治体議員の数を増やす. 香川県連は現在 26 名だが (来春の統一地方選までに) これを 56 名にする」. = 現職 26 → 目標 56 (= +30 名). 党大会では 2025-07 参議院選挙で当選した原田秀一議員が国政活動成果と今後の方針を報告.',
  'https://news.yahoo.co.jp/articles/28c97c114219f791a16c614faf317fd807bce7c6',
  'KSB瀬戸内海放送',
  '2026-04-26',
  56,
  26,
  30,
  '統一地方選',
  2027,
  '玉木雄一郎'
WHERE NOT EXISTS (
  SELECT 1 FROM prefecture_election_news
  WHERE prefecture = '香川'
    AND party = '国民民主党'
    AND announced_at = '2026-04-26'
);

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 108: prefecture_election_news 香川 seed (= News driven scaffolding 第 3 例)',
  'User 共有 News (= KSB瀬戸内海放送 / Yahoo!ニュース 2026-04-26 / 国民民主党香川県連大会 / 玉木雄一郎党代表登壇 / 自治体議員 26 → 56 名 / +30 名 / 来春統一地方選までに / 原田秀一参議院議員も国政活動報告) を反映. part 106 schema 再利用 = 「News driven scaffolding」pattern 第 3 例. 3 県累計 (宮崎 + 北海道 + 香川) で schema 汎用性さらに validate.',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 108: prefecture_election_news 香川 seed (= News driven scaffolding 第 3 例)'
);
