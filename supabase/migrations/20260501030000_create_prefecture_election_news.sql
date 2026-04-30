-- Prefecture Election News schema + 宮崎県連 25 人擁立目標 seed (Win版#132 part 106 / 2026-05-01)
--
-- User 要望:
--   「下記のニュースがあります。これを反映することはできますか？」
--   国民民主党宮崎県連が 2027 統一地方選等で計 25 人擁立目標発表 (= 20 確定 + 公募 5 人追加方針)
--
-- 設計判断:
--   - 既存 lib/services/local_election_plan_service.dart は tier-based formula で動的算出
--   - News 由来の **公式発表値** (= 25 人 / 公募 5) は override データとして DB に格納
--   - UI 側 (VSCode territory) は本テーブルを fetch して dashboard 上に news badge / override 表示
--   - 「news event」として時系列保存 (= 将来追加 prefecture も同 schema で蓄積可)

-- ==============================================
-- 1. prefecture_election_news (= 公式発表 news event)
-- ==============================================

CREATE TABLE IF NOT EXISTS prefecture_election_news (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prefecture                  text NOT NULL,                      -- '宮崎' | '東京' | etc
  party                       text NOT NULL DEFAULT '国民民主党',  -- '国民民主党' | '立憲民主党' | etc
  news_title                  text NOT NULL,
  news_summary                text,
  news_source_url             text NOT NULL,
  news_source_label           text,                                -- '読売新聞' | etc
  announced_at                date NOT NULL,
  -- 公式発表値 (= override 候補)
  total_candidate_target      int,                                 -- 計擁立目標 (= 25 for 宮崎)
  confirmed_candidate_count   int,                                 -- 立候補予定者確定数 (= 20 for 宮崎)
  public_recruitment_count    int,                                 -- 公募追加目標 (= 5 for 宮崎)
  -- 対象選挙
  target_election_kind        text,                                -- '統一地方選' | '地方議員選' | 'mixed'
  target_election_year        int,                                 -- 2027 等
  -- メタ情報
  representative_name         text,                                -- 発表者 (= 長友慎治 等)
  raw_payload                 jsonb,                                -- future 拡張用
  is_active                   boolean NOT NULL DEFAULT true,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS prefecture_election_news_prefecture_idx
  ON prefecture_election_news (prefecture, announced_at DESC);
CREATE INDEX IF NOT EXISTS prefecture_election_news_party_idx
  ON prefecture_election_news (party, announced_at DESC);

ALTER TABLE prefecture_election_news ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "prefecture_election_news_select_all" ON prefecture_election_news;
CREATE POLICY "prefecture_election_news_select_all" ON prefecture_election_news
  FOR SELECT USING (is_active = true);

-- ==============================================
-- 2. updated_at trigger
-- ==============================================

CREATE OR REPLACE FUNCTION update_prefecture_election_news_updated_at()
  RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prefecture_election_news_updated_at ON prefecture_election_news;
CREATE TRIGGER trg_prefecture_election_news_updated_at
  BEFORE UPDATE ON prefecture_election_news
  FOR EACH ROW EXECUTE FUNCTION update_prefecture_election_news_updated_at();

-- ==============================================
-- 3. 宮崎県連 2026-04-29 発表 seed
-- ==============================================

INSERT INTO prefecture_election_news (
  prefecture, party, news_title, news_summary, news_source_url, news_source_label,
  announced_at, total_candidate_target, confirmed_candidate_count, public_recruitment_count,
  target_election_kind, target_election_year, representative_name
) VALUES (
  '宮崎',
  '国民民主党',
  '宮崎県連が地方選で計25人擁立目標、20人決定済+公募5人追加方針',
  '国民民主党宮崎県連は 2026-04-29、来年 (2027) の統一地方選やその他の地方議員選挙について、党公認候補として県内で計25人を擁立する目標を発表. 県議選や宮崎市議選、延岡市議選などで既に計20人の立候補予定者を決めており、今後公募で5人を追加する方針. 代表の長友慎治衆院議員 (宮崎2区) らが記者会見で説明. 既決定: 県議選 (宮崎市/延岡市/児湯郡)、宮崎市/延岡市/日向市/日之影町など. 擁立目標数は党本部からの指示.',
  'https://www.yomiuri.co.jp/',
  '読売新聞',
  '2026-04-29',
  25,
  20,
  5,
  'mixed',
  2027,
  '長友慎治'
)
ON CONFLICT DO NOTHING;

-- ==============================================
-- 4. development_achievements
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 106: prefecture_election_news schema + 宮崎県連 25 人擁立 News 反映',
  'User 共有 News (= 国民民主党宮崎県連 2026-04-29 発表 / 統一地方選 + 地方議員選で計 25 人擁立目標 / 20 人決定 + 公募 5 人追加) を反映するため prefecture_election_news テーブル新規 (= party / news_title / news_source_url / total_candidate_target / confirmed_candidate_count / public_recruitment_count / target_election_year 等). 宮崎 entry seed. 既存 LocalElectionPlanService は tier 3 で formula 動的算出だが、本 news 由来の override 値を UI に表示 (= VSCode territory) で dashboard 上に news badge 反映可能に.',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
