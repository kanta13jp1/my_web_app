-- AI大学 civics 学部 (政治・選挙リテラシー) + 4 学科 + 教育コンテンツ seed
-- 設計: Win Claude part 240e / docs/AI_UNIVERSITY_CIVICS_MODULE.md / 適用: Win Codex (L2)
-- 中立性: 全政党等価・出典必須・議員評点なし ([AI-CHARACTER-24])
--
-- Note: ai_university_content has UNIQUE(provider, category), so each civics
-- lesson uses its department_code as category while keeping provider stable
-- for clean rollback: provider='civics_literacy'.

-- 1) civics 学部
INSERT INTO university_faculties (
  faculty_code,
  name_ja,
  name_en,
  description,
  emoji,
  sort_order,
  is_active
)
VALUES (
  'civics',
  '政治・選挙リテラシー学部',
  'Faculty of Civics & Electoral Literacy',
  '国会の仕組み・議員・政策・選挙制度を中立的に学ぶ (kokkaimap.jp モデルの教育版)',
  '🏛️',
  55,
  true
)
ON CONFLICT (faculty_code) DO NOTHING;

-- 2) 4 学科
INSERT INTO university_departments (
  faculty_id,
  department_code,
  name_ja,
  name_en,
  description,
  emoji,
  sort_order,
  is_active
)
SELECT
  f.id,
  d.department_code,
  d.name_ja,
  d.name_en,
  d.description,
  d.emoji,
  d.sort_order,
  true
FROM university_faculties f
JOIN (VALUES
  ('diet_structure', '国会の仕組み学科', 'Diet Structure',  '二院制・法案成立過程・委員会の役割', '🏛️', 10),
  ('diet_members',   '国会議員学科',     'Diet Members',     '衆参議員・会派・選挙区の調べ方',     '👥', 20),
  ('policy_themes',  '政策テーマ学科',   'Policy Themes',    '物価・教育・環境などテーマ別の論点', '📋', 30),
  ('election',       '選挙制度学科',     'Electoral System', '選挙の仕組み・投票・一票の価値',     '🗳️', 40)
) AS d(department_code, name_ja, name_en, description, emoji, sort_order) ON true
WHERE f.faculty_code = 'civics'
ON CONFLICT (faculty_id, department_code) DO NOTHING;

-- 3) 教育コンテンツ seed (出典付き・中立 / provider='civics_literacy')
INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active,
  faculty_id,
  department_id
)
SELECT
  'civics_literacy',
  lesson.dept_code,
  lesson.title,
  lesson.content,
  lesson.source_url,
  now()::date,
  lesson.sort_order,
  true,
  fac.id,
  dept.id
FROM university_faculties fac
JOIN university_departments dept ON dept.faculty_id = fac.id
JOIN (VALUES
  (
    'diet_structure',
    '国会の二院制と法案成立の流れ',
    '日本の国会は衆議院と参議院からなる二院制です。法律案は委員会審査→本会議議決を経て、両院で可決されると成立します。衆議院の優越などの仕組みを公式サイトで確認しましょう。出典: 衆議院・参議院 公式。',
    'https://www.shugiin.go.jp/',
    10
  ),
  (
    'diet_members',
    '国会議員の調べ方 (公式データの読み方)',
    '議員の所属会派・選挙区・任期は衆参の公式議員一覧で確認できます。発言は国会会議録検索システムで検索可能です。特定議員の評価ではなく、一次情報の確認方法を身につけましょう。出典: 国会会議録検索システム。',
    'https://kokkai.ndl.go.jp/',
    20
  ),
  (
    'policy_themes',
    '政策テーマから国会を読む',
    '物価・教育・環境など関心テーマで会議録を横断検索すると、各党の論点を中立に比較できます。賛否どちらも一次情報で確認することが重要です。出典: 国会会議録検索システム。',
    'https://kokkai.ndl.go.jp/',
    30
  ),
  (
    'election',
    '選挙制度の基礎 (小選挙区比例代表並立制)',
    '衆議院は小選挙区比例代表並立制、参議院は選挙区+比例代表です。一票の価値や投票方法の基礎を総務省の解説で学べます。出典: 総務省 選挙。',
    'https://www.soumu.go.jp/senkyo/senkyo_s/',
    40
  )
) AS lesson(dept_code, title, content, source_url, sort_order)
  ON lesson.dept_code = dept.department_code
WHERE fac.faculty_code = 'civics'
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      sort_order = EXCLUDED.sort_order,
      is_active = true,
      faculty_id = EXCLUDED.faculty_id,
      department_id = EXCLUDED.department_id,
      updated_at = now();
