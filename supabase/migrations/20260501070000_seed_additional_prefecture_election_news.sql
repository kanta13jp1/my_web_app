-- Additional prefecture_election_news seeds (Win版#132 part 110 / 2026-05-01)
--
-- User 要望: 「ネット検索で国民民主党の都道府県連ごとの当選目標や擁立目標があれば反映」
--
-- 検索結果:
--   1. 広島県連 (= 中国新聞 / 2026-04-19 定期大会 / 現 2 人 → 倍増以上 / 4+ 人目標)
--   2. 沖縄県連 (= 沖縄タイムス / 2026-04-24 / 上里直司県連代表 / 9 月知事選 + 統一地方選で 10 人程度)
--   3. 全国 (= 日経 + 北日本 + 沖縄タイムス等 / 2026-04-05 党大会 / 340 → 700 倍増 / 850 擁立必須 / 玉木代表)
--
-- 4 県累計 (= 宮崎 + 北海道 + 香川 + 大阪) → 7 件 (+ 広島 + 沖縄 + 全国 = 全国レベル).
-- News driven scaffolding 第 5-7 例.

-- ==============================================
-- 1. 広島県連 (= 中国新聞 / 2026-04-19 定期大会)
-- ==============================================

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
)
SELECT
  '広島',
  '国民民主党',
  '国民民主党広島県連、広島市南区で定期大会 統一地方選の県内議員「倍増以上」目標',
  '国民民主党広島県連は 2026-04-19 に広島市南区で定期大会を開き、来春の統一地方選に向けて広島県内で現状の地方議員 2 人から倍増以上を目標とする 2026 年度の活動計画を確認した. 党幹部のキャラバンで人材発掘を進める方針.',
  'https://www.chugoku-np.co.jp/articles/-/819637',
  '中国新聞デジタル',
  '2026-04-19',
  4,
  2,
  2,
  '統一地方選',
  2027,
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM prefecture_election_news
  WHERE prefecture = '広島'
    AND party = '国民民主党'
    AND announced_at = '2026-04-19'
);

-- ==============================================
-- 2. 沖縄県連 (= 沖縄タイムス / 2026-04-24 / 知事選 + 統一地方選同日)
-- ==============================================

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
)
SELECT
  '沖縄',
  '国民民主党',
  '国民民主党沖縄県連、9 月知事選同日の統一地方選で 10 人程度擁立目標',
  '国民民主党沖縄県連の上里直司代表は 2026-04-24 に県庁で会見を開き、9 月の知事選と同日の統一地方選に向けて候補者を公募し、10 人程度の擁立を目指すと発表. 知事選では現職の玉城デニー知事を推薦することはないとしつつ、古謝玄太氏側からの推薦依頼については党本部と調整したい考えを示した. 沖縄は独自の選挙日程 (= 9 月知事選 + 統一地方選同日) を持つため、本州主要県の 2027 年春の統一地方選とは異なるタイミング.',
  'https://www.okinawatimes.co.jp/articles/-/1824894',
  '沖縄タイムス',
  '2026-04-24',
  10,
  NULL,
  NULL,
  '統一地方選 + 知事選',
  2026,
  '上里直司'
WHERE NOT EXISTS (
  SELECT 1 FROM prefecture_election_news
  WHERE prefecture = '沖縄'
    AND party = '国民民主党'
    AND announced_at = '2026-04-24'
);

-- ==============================================
-- 3. 全国 (= 国民民主党 党大会 / 日経 / 2026-04-05)
-- ==============================================

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
)
SELECT
  '全国',
  '国民民主党',
  '国民民主党、党大会で地方議員 340 → 700 人「倍増」を必達目標に',
  '国民民主党は 2026-04-05 の党大会で、現在約 340 人の地方議員を 2027 年春の統一地方選後に 700 人へ倍増させることを「必達目標」に掲げた. 玉木雄一郎代表は記者会見で「850 人は擁立しなければならない」と語り、各都道府県連ごとに擁立目標を設定し、所属議員がいない「空白区」への候補擁立を「大原則」とする方針を示した. 党幹部によるキャラバンを全国で続けて人材発掘を進める. 2026 年度活動方針原案に明記.',
  'https://www.nikkei.com/article/DGXZQOUA282KO0Y6A320C2000000/',
  '日本経済新聞',
  '2026-04-05',
  850,
  340,
  510,
  '統一地方選',
  2027,
  '玉木雄一郎'
WHERE NOT EXISTS (
  SELECT 1 FROM prefecture_election_news
  WHERE prefecture = '全国'
    AND party = '国民民主党'
    AND announced_at = '2026-04-05'
);

-- ==============================================
-- 4. development_achievements
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'Win132 part 110: prefecture_election_news 追加 3 件 seed (= 広島 / 沖縄 / 全国)',
  'User 要望「ネットで国民民主党の都道府県連ごとの目標を検索し反映」に応えて WebSearch routine 実行. 中国新聞 (広島 / 2→4+) + 沖縄タイムス (沖縄 / 10 人 / 上里直司代表 / 9 月知事選同日) + 日経 (全国 / 340 → 700 / 850 擁立必須 / 玉木代表) を seed. part 106 schema 再利用. 7 件累計 (= 宮崎 / 北海道 / 香川 / 大阪 + 広島 / 沖縄 / 全国). 「全国レベル news 初対応」(= prefecture = 全国).',
  '2026-05-01'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements
  WHERE title = 'Win132 part 110: prefecture_election_news 追加 3 件 seed (= 広島 / 沖縄 / 全国)'
);
