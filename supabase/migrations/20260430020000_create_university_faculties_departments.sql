-- AI 大学 学部 / 学科 階層導入 (Win版#132 part 93 / 2026-04-30)
--
-- User 要望: AI 大学に学部や学科という分類を追加して、AI に関するものだけでなく
-- AWS や GCP や Azure などのクラウドサービスについても学べる content を追加したい.
--
-- 設計: docs/AI_UNIVERSITY_FACULTY_DEPARTMENT_DESIGN.md
--
-- 階層: 学部 (Faculty) → 学科 (Department) → provider → content
--
-- 5 学部 / 22 学科 を seed:
--   1. AI 学部           (既存 380+ provider 収容 / 7 学科)
--   2. クラウド学部       (AWS / GCP / Azure 等 / 5 学科) ← 新規
--   3. 開発ツール学部     (IaC / CI/CD / Container / Monitoring / 4 学科) ← 新規
--   4. データ基盤学部     (Database / Warehouse / Stream / 3 学科) ← 新規
--   5. 学術研究学部       (Benchmark / Paper / Lab / 3 学科) ← 既存集約
--
-- 既存 ai_university_content には faculty_id / department_id を nullable で追加.
-- 既存 row への mapping は phase 2 (PS#3 cross-instance-pr) で bulk UPDATE.

-- ==============================================
-- 1. university_faculties (学部)
-- ==============================================

CREATE TABLE IF NOT EXISTS university_faculties (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  faculty_code  text NOT NULL UNIQUE,
  name_ja       text NOT NULL,
  name_en       text NOT NULL,
  description   text,
  emoji         text,
  sort_order    int  NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS university_faculties_sort_idx
  ON university_faculties (sort_order, faculty_code);

ALTER TABLE university_faculties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "university_faculties_select_all" ON university_faculties;
CREATE POLICY "university_faculties_select_all" ON university_faculties
  FOR SELECT USING (is_active = true);

-- ==============================================
-- 2. university_departments (学科)
-- ==============================================

CREATE TABLE IF NOT EXISTS university_departments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  faculty_id      uuid NOT NULL REFERENCES university_faculties(id) ON DELETE CASCADE,
  department_code text NOT NULL,
  name_ja         text NOT NULL,
  name_en         text NOT NULL,
  description     text,
  emoji           text,
  sort_order      int  NOT NULL DEFAULT 0,
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (faculty_id, department_code)
);

CREATE INDEX IF NOT EXISTS university_departments_faculty_idx
  ON university_departments (faculty_id, sort_order);

ALTER TABLE university_departments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "university_departments_select_all" ON university_departments;
CREATE POLICY "university_departments_select_all" ON university_departments
  FOR SELECT USING (is_active = true);

-- ==============================================
-- 3. ai_university_content extension
-- ==============================================

ALTER TABLE ai_university_content
  ADD COLUMN IF NOT EXISTS faculty_id    uuid REFERENCES university_faculties(id),
  ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES university_departments(id);

CREATE INDEX IF NOT EXISTS ai_university_content_faculty_idx
  ON ai_university_content (faculty_id, sort_order);
CREATE INDEX IF NOT EXISTS ai_university_content_department_idx
  ON ai_university_content (department_id, sort_order);

-- ==============================================
-- 4. updated_at triggers
-- ==============================================

CREATE OR REPLACE FUNCTION update_university_faculty_updated_at()
  RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_university_faculty_updated_at ON university_faculties;
CREATE TRIGGER trg_university_faculty_updated_at
  BEFORE UPDATE ON university_faculties
  FOR EACH ROW EXECUTE FUNCTION update_university_faculty_updated_at();

DROP TRIGGER IF EXISTS trg_university_department_updated_at ON university_departments;
CREATE TRIGGER trg_university_department_updated_at
  BEFORE UPDATE ON university_departments
  FOR EACH ROW EXECUTE FUNCTION update_university_faculty_updated_at();

-- ==============================================
-- 5. Seed: 5 学部
-- ==============================================

INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order)
VALUES
  ('ai',       'AI 学部',           'Faculty of AI',
   'AI モデル・サービス・エージェントを学ぶ. LLM / 画像生成 / 音声 / 動画 / エージェント / 埋め込み / フレームワークの 7 学科で 380+ AI provider を整理.',
   '🤖', 10),
  ('cloud',    'クラウド学部',     'Faculty of Cloud',
   'クラウドサービス全般 (AWS / GCP / Azure / Oracle / 新興エッジ) を学ぶ. インフラ・PaaS・IaaS・SaaS の基礎から AI 統合活用までカバー.',
   '☁️', 20),
  ('devtools', '開発ツール学部',   'Faculty of DevTools',
   'IaC / CI/CD / コンテナ / 監視 など現代的開発インフラを学ぶ. クラウド学部と組み合わせると DevOps エンジニア相当のスキルセットになる.',
   '🛠️', 30),
  ('data',     'データ基盤学部',   'Faculty of Data Infrastructure',
   'データベース / データウェアハウス / ストリーム処理を学ぶ. AI 学部の RAG / embedding と連携して Data + AI 統合スキルを養う.',
   '💾', 40),
  ('research', '学術研究学部',     'Faculty of Research',
   '研究論文 / ベンチマーク / 研究機関を学ぶ. 産業応用 (= 他 4 学部) を理解した上で、最新研究動向を追える学術視点を確立.',
   '📚', 50)
ON CONFLICT (faculty_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- ==============================================
-- 6. Seed: 22 学科 (= 7 + 5 + 4 + 3 + 3)
-- ==============================================

-- 6.1 AI 学部 (7 学科)
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('llm',       'LLM 学科',                'Department of LLM',
   '大規模言語モデルを学ぶ. OpenAI / Anthropic / Meta / Mistral 等 LLM プロバイダーを横断比較.',
   '💬', 10),
  ('image',     '画像生成学科',           'Department of Image Generation',
   'AI 画像生成. Stability / Midjourney / DALL-E / Adobe Firefly 等の比較と用途別選択.',
   '🎨', 20),
  ('voice',     '音声・音楽学科',         'Department of Voice & Music',
   'AI 音声合成・音楽生成. ElevenLabs / Suno / Udio / Whisper を学ぶ.',
   '🎵', 30),
  ('video',     '動画生成学科',           'Department of Video Generation',
   'AI 動画生成. Runway / Pika / Sora / D-ID / HeyGen のテクニックと比較.',
   '🎬', 40),
  ('agent',     'エージェント・AutoML 学科', 'Department of Agents & AutoML',
   'AI エージェント / 自律ワークフロー. LangChain / CrewAI / AutoGPT / DSPy / LlamaIndex.',
   '🤝', 50),
  ('embedding', '埋め込み・検索学科',     'Department of Embedding & Search',
   '埋め込みベクトル / ベクトル検索. Pinecone / Weaviate / Qdrant / Voyage / pgvector.',
   '🔍', 60),
  ('framework', 'フレームワーク・ツール学科', 'Department of Frameworks & Tools',
   'AI 開発フレームワーク / 評価ツール. HuggingFace / NVIDIA NeMo / Promptfoo / DeepLearning.ai.',
   '🧰', 70)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'ai'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- 6.2 クラウド学部 (5 学科)
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('aws',    'AWS 学科',           'Department of AWS',
   'Amazon Web Services の主要サービス (EC2 / S3 / Lambda / SageMaker / Bedrock / RDS / DynamoDB) を体系学習.',
   '🟠', 10),
  ('gcp',    'GCP 学科',           'Department of GCP',
   'Google Cloud Platform の主要サービス (Compute Engine / Cloud Run / Vertex AI / BigQuery / Firebase) を体系学習.',
   '🔵', 20),
  ('azure',  'Azure 学科',         'Department of Azure',
   'Microsoft Azure の主要サービス (VM / Functions / OpenAI Service / Cosmos DB / Synapse) を体系学習.',
   '🟦', 30),
  ('oracle', 'Oracle Cloud 学科',  'Department of Oracle Cloud',
   'Oracle Cloud Infrastructure (OCI) / Autonomous Database / Oracle AI を学習.',
   '🔴', 40),
  ('edge',   'エッジ・新興クラウド学科', 'Department of Edge & Emerging Cloud',
   'Cloudflare Workers / Vercel / Fly.io / Railway / Render など最新エッジ・サーバーレスを学習.',
   '⚡', 50)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'cloud'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- 6.3 開発ツール学部 (4 学科)
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('iac',        'IaC 学科',                       'Department of Infrastructure as Code',
   'Terraform / Pulumi / AWS CDK / Azure Bicep でインフラをコード化する手法.',
   '📜', 10),
  ('cicd',       'CI/CD 学科',                     'Department of CI/CD',
   'GitHub Actions / GitLab CI / CircleCI / ArgoCD で継続的統合・継続的デプロイを学ぶ.',
   '🔁', 20),
  ('container',  'コンテナ・オーケストレーション学科', 'Department of Containers & Orchestration',
   'Docker / Kubernetes / Helm / コンテナオーケストレーション基礎.',
   '📦', 30),
  ('monitoring', '監視・観測学科',                  'Department of Monitoring & Observability',
   'Datadog / Grafana / Prometheus / New Relic / Honeycomb で運用観測.',
   '📊', 40)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'devtools'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- 6.4 データ基盤学部 (3 学科)
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('database',  'データベース学科',         'Department of Databases',
   'PostgreSQL / MySQL / Supabase / PlanetScale など RDB / NewSQL の選定と運用.',
   '🗃️', 10),
  ('warehouse', 'データウェアハウス学科',   'Department of Data Warehouses',
   'BigQuery / Snowflake / Redshift / Databricks で大規模分析基盤.',
   '🏛️', 20),
  ('stream',    'ストリーム処理学科',       'Department of Stream Processing',
   'Kafka / Pulsar / Kinesis / Pub/Sub でリアルタイムデータ処理.',
   '🌊', 30)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'data'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- 6.5 学術研究学部 (3 学科)
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('benchmark', 'ベンチマーク学科', 'Department of Benchmarks',
   'MMLU / HumanEval / SWE-bench / WebArena / GSM8K 等 LLM 評価ベンチマーク.',
   '📐', 10),
  ('paper',     '研究論文学科',     'Department of Research Papers',
   'Transformer / RLHF / Diffusion 等の主要 arxiv 論文.',
   '📄', 20),
  ('lab',       '研究機関学科',     'Department of Research Labs',
   'OpenAI Research / Anthropic Research / Stanford / MIT 等の研究動向.',
   '🔬', 30)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'research'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- ==============================================
-- 7. development_achievements 追加
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 93: AI 大学 学部 / 学科 階層導入',
  'User 要望「AI に関するものだけでなく AWS や GCP や Azure などのクラウドサービスについても学べる content を追加したい」に応えて、学部 (Faculty) → 学科 (Department) → provider → content の 4 階層を導入. 5 学部 (AI / クラウド / 開発ツール / データ基盤 / 学術研究) / 22 学科 を seed. ai_university_content に faculty_id / department_id columns 追加 (nullable). 既存 380+ provider mapping + AWS/GCP/Azure provider seed + UI 4 層 drill-down + ai-hub action 追加 は phase 2-6 で他 instance に cross-instance-pr 委譲.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
