# AI 大学 学部 / 学科 階層設計

> **ソース**: User 要望 (2026-04-30 / Win版#132 part 93):
> > 「AI大学に学部や学科という分類を追加して、AIに関するものだけでなくAWSやGCPやAzureなどのクラウドサービスについても学ぶことができるコンテンツも追加したいです」
>
> **目的**: AI 大学を「AI 専門校」から **「総合 IT 大学」** へ拡張. 学部/学科 hierarchy で content を整理し、クラウド/DevOps/データ基盤など隣接領域も学べる設計に進化させる.

---

## 現状

- 既存 schema: `ai_university_content (provider, category, ...)` 単一テーブル
- 既存 categorization: `provider` (= 380+ AI 社) + `category` (= models / api / pricing / news / tutorial / overview)
- 弱点:
  - **flat structure**: 380 provider が 1 軸で並ぶだけ → 学習動線が組み立てづらい
  - **AI 限定**: 競合 AI 社のみ → AWS/GCP/Azure 等クラウド系・DevOps・データ基盤を扱えない
  - **学習 path 不在**: 「初学者は何から学べば？」「LLM 学びたい人と画像生成学びたい人を分けたい」が表現できない

---

## 新設計: 学部 (Faculty) → 学科 (Department) → provider 3 階層

### 階層構造

```
学部 (Faculty)         例: AI 学部 / クラウド学部 / 開発ツール学部 / データ基盤学部 / 学術研究学部
  └─ 学科 (Department) 例: LLM 学科 / 画像生成学科 / AWS 学科 / GCP 学科 / IaC 学科
       └─ provider     例: OpenAI / Anthropic / AWS / GCP / Terraform / etc
            └─ content (= 既存 ai_university_content row)
                 └─ category: models / api / pricing / news / tutorial / overview
```

= 「物理大学の組織 (= 学部 → 学科 → 講座 → 講義回)」と相似形にして、**学習者の cognitive map** に直感的に符合させる.

### 初期 学部/学科 構成 (= 10 学部 / 53 学科 / part 97 で資格試験学部追加)

#### 1. AI 学部 (faculty_code: `ai`)

既存 380+ provider を 7 学科に再分類.

| 学科 code | 学科名 | 含む provider 例 |
| --- | --- | --- |
| `llm` | LLM 学科 | OpenAI / Anthropic / Meta / Mistral / Cohere / DeepSeek / Sakana / Aleph Alpha |
| `image` | 画像生成学科 | Stability / Midjourney / DALL-E / Adobe Firefly / Leonardo / Ideogram |
| `voice` | 音声・音楽学科 | ElevenLabs / Suno / Udio / Whisper |
| `video` | 動画生成学科 | Runway / Pika / Sora / D-ID / HeyGen |
| `agent` | エージェント・AutoML 学科 | LangChain / CrewAI / AutoGPT / DSPy / LlamaIndex |
| `embedding` | 埋め込み・検索学科 | Pinecone / Weaviate / Qdrant / Voyage |
| `framework` | フレームワーク・ツール学科 | HuggingFace / NVIDIA NeMo / DeepLearning.ai / Promptfoo |

#### 2. クラウド学部 (faculty_code: `cloud`) ← **新規**

| 学科 code | 学科名 | 含む provider 例 |
| --- | --- | --- |
| `aws` | AWS 学科 | EC2 / S3 / Lambda / SageMaker / Bedrock / RDS / DynamoDB |
| `gcp` | GCP 学科 | Compute Engine / Cloud Run / Vertex AI / BigQuery / Firebase |
| `azure` | Azure 学科 | VM / Functions / OpenAI Service / Cosmos DB / Synapse |
| `oracle` | Oracle Cloud 学科 | OCI / Autonomous DB / Oracle AI |
| `edge` | エッジ・新興クラウド学科 | Cloudflare Workers / Vercel / Fly.io / Railway / Render |

#### 3. 開発ツール学部 (faculty_code: `devtools`) ← **新規**

| 学科 code | 学科名 | 含む provider 例 |
| --- | --- | --- |
| `iac` | IaC 学科 | Terraform / Pulumi / CDK / Bicep |
| `cicd` | CI/CD 学科 | GitHub Actions / GitLab CI / CircleCI / ArgoCD |
| `container` | コンテナ・オーケストレーション学科 | Docker / Kubernetes / Helm |
| `monitoring` | 監視・観測学科 | Datadog / Grafana / Prometheus / New Relic / Honeycomb |

#### 4. データ基盤学部 (faculty_code: `data`) ← **新規**

| 学科 code | 学科名 | 含む provider 例 |
| --- | --- | --- |
| `database` | データベース学科 | PostgreSQL / MySQL / Supabase / PlanetScale |
| `warehouse` | データウェアハウス学科 | BigQuery / Snowflake / Redshift / Databricks |
| `stream` | ストリーム処理学科 | Kafka / Pulsar / Kinesis / Pub/Sub |

#### 5. 学術研究学部 (faculty_code: `research`) ← **既存 benchmark + paper を集約**

| 学科 code | 学科名 | 含む provider 例 |
| --- | --- | --- |
| `benchmark` | ベンチマーク学科 | MMLU / HumanEval / SWE-bench / WebArena / GSM8K |
| `paper` | 研究論文学科 | Transformer / RLHF / Diffusion / arxiv 主要論文 |
| `lab` | 研究機関学科 | OpenAI Research / Anthropic Research / Stanford / MIT |

#### 10. 資格試験学部 (faculty_code: `certification`) ← **新規 / part 97 追加 / sort_order 45**

User 要望「情報処理技術者試験 / ベンダー資格等の資格試験 content」を受けて新設. **学習成果を validate する層** として学術 (50) の前に配置.

| 学科 code | 学科名 | 含む 資格例 |
| --- | --- | --- |
| `ipa` | 情報処理技術者試験学科 | 基本情報技術者 (FE) / 応用情報技術者 (AP) / DB スペシャリスト / NW スペシャリスト / SC 情報処理安全確保支援士 / PM プロジェクトマネージャー / IT パスポート / G 検定 / E 資格 |
| `cloud_cert` | クラウドベンダー資格学科 | AWS Certified (CP / SAA / DevOps Pro / ML Specialty) / Azure (AZ-900 / AZ-104 / AZ-204 / AZ-305) / Google Cloud (CDL / Associate / Professional) / Oracle Cloud / IBM Cloud |
| `network_sec` | ネットワーク・セキュリティ資格学科 | Cisco (CCNA / CCNP / CCIE) / CompTIA (Network+ / Security+ / CySA+) / (ISC)2 (CISSP / CCSP) / EC-Council (CEH) / OSCP |
| `database_data` | データベース・データ資格学科 | Oracle Master (Bronze - Platinum) / Microsoft Azure Data / Snowflake Certified / Databricks / MongoDB / PostgreSQL Associate |
| `pm_cert` | プロジェクトマネジメント資格学科 | PMP / PRINCE2 / CSM / PSM / SAFe Agilist / ITIL Foundation / Lean Six Sigma |
| `developer` | 開発者資格学科 | Microsoft Certified Developer / Java SE/EE Programmer / Python Institute (PCEP/PCAP/PCPP) / Kubernetes (CKA/CKAD/CKS) / GitHub / Terraform Associate |
| `business_intl` | ビジネス・国際資格学科 | TOEIC / TOEFL / IELTS / 日商簿記 / 中小企業診断士 / 統計検定 / 行政書士 |

#### 9. ハードウェア学部 (faculty_code: `hardware`) ← **新規 / part 96 追加 / sort_order 2**

User 要望「ハードウェアについても学べる content / 例: CPU / GPU / nvidia / intel / Apple / DELL / HP 等」を受けて新設. 全 IT スタックの **物理基盤層**.

| 学科 code | 学科名 | 含む provider / topic 例 |
| --- | --- | --- |
| `cpu` | CPU 学科 | Intel Core / Xeon / AMD Ryzen / EPYC / Apple Silicon (M シリーズ) / Qualcomm Snapdragon / ARM / RISC-V |
| `gpu` | GPU・アクセラレータ学科 | NVIDIA GeForce / RTX / H100 / Blackwell / AMD Radeon / Intel Arc / Apple Neural Engine / Google TPU / AWS Trainium |
| `memory_storage` | メモリ・ストレージ学科 | DDR5 / LPDDR5X / HBM3e / NVMe SSD / Intel Optane / Samsung / Micron / SK Hynix / WD / Seagate |
| `pc_workstation` | PC・ワークステーション学科 | Apple Mac / Dell XPS / Precision / HP Spectre / ZBook / Lenovo ThinkPad / ASUS ROG / Microsoft Surface / Framework |
| `server_dc` | サーバー・データセンター学科 | Dell PowerEdge / HP ProLiant / Lenovo ThinkSystem / Supermicro / NVIDIA DGX / Cerebras / Groq |
| `network_peripheral` | ネットワーク・周辺機器学科 | Cisco / Juniper / Arista / Mellanox / Logitech / Razer / Apple Magic / displays |
| `semiconductor` | 半導体製造学科 | TSMC / Samsung Foundry / Intel Foundry / GlobalFoundries / ASML / Applied Materials / KLA |

#### 7. OS 学部 (faculty_code: `os`) ← **新規 / part 95 追加 / sort_order 5**

User 要望「Windows / macOS / Linux 等の OS も学べる content」を受けて新設.

| 学科 code | 学科名 | 含む provider / topic 例 |
| --- | --- | --- |
| `windows` | Windows 学科 | Windows 11 / Server / WSL / PowerShell / Active Directory / Hyper-V / .NET |
| `macos` | macOS 学科 | macOS Sequoia / Sonoma / iCloud / Homebrew / SwiftUI Mac / Xcode / Apple Silicon |
| `linux` | Linux 学科 | Ubuntu / Debian / Fedora / RHEL / Arch / NixOS / Alpine / kernel / systemd |
| `bsd_unix` | BSD・Unix 系学科 | FreeBSD / OpenBSD / NetBSD / Solaris / AIX / illumos / ZFS / pf |
| `rtos` | 組み込み・RTOS 学科 | FreeRTOS / Zephyr / VxWorks / TRON / Yocto / Buildroot |

#### 8. モバイル学部 (faculty_code: `mobile`) ← **新規 / part 95 追加 / sort_order 15**

User 要望「iOS / Android 等のモバイルも学べる content」を受けて新設.

| 学科 code | 学科名 | 含む provider / topic 例 |
| --- | --- | --- |
| `ios` | iOS 学科 | Swift / SwiftUI / UIKit / Xcode / TestFlight / WidgetKit / WatchKit |
| `android` | Android 学科 | Kotlin / Jetpack Compose / Android Studio / Material 3 / Google Play / KMP |
| `cross_platform` | クロスプラットフォーム学科 | Flutter / React Native / .NET MAUI / Ionic / Capacitor / Expo |
| `mobile_uiux` | モバイル UI/UX 学科 | HIG / Material Design / Touch Target / VoiceOver / TalkBack / Dark Mode |
| `mobile_devops` | モバイル DevOps 学科 | Fastlane / TestFlight / Firebase App Distribution / App Center / Codemagic |

#### 6. ソフトウェアエンジニアリング学部 (faculty_code: `swe`) ← **新規 / part 94 追加**

User 要望「アジャイル開発など Software エンジニアリング content も学べるように」を受けて新設.

| 学科 code | 学科名 | 含む provider / topic 例 |
| --- | --- | --- |
| `agile` | アジャイル・Scrum 学科 | Scrum.org / Scrum Guide / SAFe / Spotify Model / Lean / XP / Kanban |
| `architecture` | アーキテクチャ・設計学科 | Clean Architecture (Uncle Bob) / DDD (Eric Evans) / Hexagonal / Microservices / Design Patterns (GoF) |
| `testing` | テスト・品質保証学科 | TDD (Kent Beck) / BDD / Cypress / Playwright / Jest / pytest / property-based testing |
| `security` | セキュリティ・SecDevOps 学科 | OWASP Top 10 / SAST / DAST / SCA / Zero Trust / SLSA / Threat Modeling |
| `refactoring` | リファクタリング・コード品質学科 | SOLID / Clean Code / Refactoring (Fowler) / Code Review / Pair Programming |
| `pm` | プロジェクト・チームマネジメント学科 | PMBOK / PRINCE2 / OKR / Team Topologies / DORA Metrics / Engineering Ladder |
| `documentation` | ドキュメント・テクニカルライティング学科 | RFC / ADR / Diátaxis / C4 model / Mermaid / API doc 技法 |

### 合計

- **10 学部 / 53 学科** / 既存 380+ + クラウド系 30+ + SWE 系 30+ + OS 系 25+ + モバイル系 25+ + ハードウェア系 50+ + 資格試験系 50+ = **590+ provider 想定**

### 学部 sort_order 体系 (= UI 表示順 / 10 layer 順序教育設計)

| sort_order | 学部 | 位置づけ |
| --- | --- | --- |
| 2 | 💻 ハードウェア | 物理層 (= 最も foundational) |
| 5 | 💿 OS | OS 層 |
| 10 | 🤖 AI | 基盤技術 |
| 15 | 📱 モバイル | app delivery (= ユーザーに届く層) |
| 20 | ☁️ クラウド | infra |
| 30 | 🛠️ 開発ツール | 道具 |
| 35 | 👷 ソフトウェアエンジニアリング | 方法論 |
| 40 | 💾 データ基盤 | データ層 |
| **45** | 🎓 **資格試験** | **学習成果 validation 層** |
| 50 | 📚 学術研究 | 学術 |

= **「物理 → OS → 基盤 → app → infra → 道具 → 方法論 → データ → 資格 → 学術」** の **10 layer 構成的学習 path** 完成.

---

## DB schema 変更

### 新規テーブル 1: `university_faculties`

```sql
CREATE TABLE IF NOT EXISTS university_faculties (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  faculty_code  text NOT NULL UNIQUE,        -- 'ai' | 'cloud' | 'devtools' | 'data' | 'research'
  name_ja       text NOT NULL,                -- 'AI 学部' | 'クラウド学部' | etc
  name_en       text NOT NULL,                -- 'Faculty of AI' | 'Faculty of Cloud' | etc
  description   text,                          -- 学部紹介 (Markdown)
  emoji         text,                          -- '🤖' | '☁️' | '🛠️' | '💾' | '📚'
  sort_order    int  NOT NULL DEFAULT 0,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
```

### 新規テーブル 2: `university_departments`

```sql
CREATE TABLE IF NOT EXISTS university_departments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  faculty_id      uuid NOT NULL REFERENCES university_faculties(id) ON DELETE CASCADE,
  department_code text NOT NULL,                -- 'llm' | 'aws' | 'iac' | etc
  name_ja         text NOT NULL,                -- 'LLM 学科' | 'AWS 学科' | etc
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
```

### 既存テーブル拡張: `ai_university_content`

```sql
ALTER TABLE ai_university_content
  ADD COLUMN IF NOT EXISTS faculty_id    uuid REFERENCES university_faculties(id),
  ADD COLUMN IF NOT EXISTS department_id uuid REFERENCES university_departments(id);

CREATE INDEX IF NOT EXISTS ai_university_content_faculty_idx
  ON ai_university_content (faculty_id, sort_order);
CREATE INDEX IF NOT EXISTS ai_university_content_department_idx
  ON ai_university_content (department_id, sort_order);
```

= **nullable** にして既存 row を破壊しない. 後続 migration で provider→department mapping を bulk update.

### RLS ポリシー

```sql
ALTER TABLE university_faculties   ENABLE ROW LEVEL SECURITY;
ALTER TABLE university_departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "university_faculties_select_all"   ON university_faculties
  FOR SELECT USING (is_active = true);
CREATE POLICY "university_departments_select_all" ON university_departments
  FOR SELECT USING (is_active = true);
```

= 全 user 閲覧可 / 更新は service role のみ (= 既存 ai_university_content と同方針).

---

## 既存 provider → 学科 mapping 戦略

Phase 1 (= 本 migration): faculty/department を seed + nullable column 追加.

Phase 2 (= 別 migration / cross-instance-pr → PS#3): provider name keyword で **bulk UPDATE** (= 自動 mapping):

```sql
-- 例: LLM 学科への自動振り分け
UPDATE ai_university_content
SET department_id = (SELECT id FROM university_departments WHERE department_code = 'llm')
WHERE provider IN ('openai', 'anthropic', 'meta', 'mistral', 'cohere', 'deepseek', 'sakana', 'aleph_alpha');

-- 例: 画像生成学科
UPDATE ai_university_content
SET department_id = (SELECT id FROM university_departments WHERE department_code = 'image')
WHERE provider IN ('stability_ai', 'midjourney', 'dalle', 'adobe_firefly', 'leonardo_ai', 'ideogram');

-- (= 22 学科分繰り返し)
```

Phase 3 (= cross-instance-pr → PS#3): クラウド学部 5 学科 + 新規 30+ provider seed.

Phase 4 (= cross-instance-pr → VSCode): UI に学部/学科 filter / breadcrumb / hierarchy 表示.

---

## UI 設計 (= VSCode territory)

### 想定 UI

```
[ AI 大学 ]
  └─ [学部選択 chip row]
       🤖 AI 学部  ☁️ クラウド学部  🛠️ 開発ツール  💾 データ基盤  📚 学術研究

  └─ [学科選択 chip row] (= 選択学部の学科のみ表示)
       例: AI 学部選択時 → LLM / 画像生成 / 音声 / 動画 / エージェント / 埋め込み / フレームワーク

  └─ [provider grid] (= 選択学科の provider のみ表示)
       例: LLM 学科選択時 → OpenAI / Anthropic / Meta / Mistral / Cohere / ...

  └─ [content list] (= 選択 provider の content)
```

= **現行 UI**: provider grid のみ → **新 UI**: 学部 → 学科 → provider → content の 4 層 drill-down.

### Breadcrumb

```
AI 大学 > AI 学部 > LLM 学科 > Anthropic > Claude 3.5 Sonnet モデル詳細
```

### 学部 home card

各学部に「学部紹介ページ」を新規 (= /university/faculty/<code>):
- 学部紹介 markdown
- 含む 学科 list (= cards)
- 推奨学習 path (= future feature)
- 統計: provider 数 / content 数

---

## EF API 拡張 (= ai-hub action 追加)

### 新 actions

| action | 用途 |
| --- | --- |
| `university.faculty_list` | 全学部 list |
| `university.department_list` | 学部別学科 list (faculty_id filter) |
| `university.provider_by_department` | 学科別 provider list |
| `university.content_by_faculty` | 学部別 content (= 既存 content_all を学部 filter 付に拡張) |

= ai-hub の既存 university.content_all action を retain しつつ、新 4 actions 追加. EF カウントは増えない (= action level 追加のみ).

---

## 実装 phase 配分

| phase | territory | 内容 |
| --- | --- | --- |
| 1 | **Win** (本 part) | schema migration (= 2 テーブル + FK + RLS + 5 学部 / 22 学科 seed) + design doc |
| 2 | **PS#3** (= AI 大学 専任 / cross-instance-pr) | 既存 380+ provider → 学科 mapping bulk UPDATE migration |
| 3 | **PS#3** (cross-instance-pr) | クラウド学部 5 学科 / 30+ 新規 provider seed (AWS/GCP/Azure/Oracle/Cloudflare/Vercel/etc) |
| 4 | **PS#3** (cross-instance-pr) | 開発ツール / データ基盤 / 学術研究学部 provider seed |
| 5 | **VSCode** (cross-instance-pr) | UI 4 層 drill-down + breadcrumb + 学部 home card |
| 6 | **Codex#2** (cross-instance-pr) | ai-hub に university.faculty_list / department_list / provider_by_department / content_by_faculty action 追加 |

= **Phase 1 (= Win territory)** を本 part で完結. Phase 2-6 は cross-instance-pr で他 instance に委譲.

---

## INDIE_DEV_VELOCITY 原則 cross-ref

本設計は part 92 で確立した **INDIE_DEV_VELOCITY 7 原則** に整合:
- **#5 Hand-Written Code as Art**: 学部/学科 hierarchy = CEO 直筆の domain modeling 判断 (= AI 生成では出ない構造)
- **#6 Avoid Side-Project Graveyard**: 既存 380 provider で audience 確保済 → クラウド学部追加で **明確な user value 拡張** (= 機能増殖ではない)
- **#7 Community Engagement Discipline**: クラウド学部 = AWS/GCP/Azure 公式 community との接続点

---

## ROADMAP next steps

1. **本 doc commit** (= Win版#132 part 93)
2. migration `20260430020000_create_university_faculties_departments.sql` 新規 (= schema + 5 学部 / 22 学科 seed)
3. cross-instance-pr 4 件起票 (PS#3 x3 + VSCode + Codex#2)
4. baseline tracking: AI 大学 380+ → 400+ provider / 0 学部 → 5 学部 / 0 学科 → 22 学科

---

*Win版#132 part 93 / 2026-04-30 / AI 大学 学部 / 学科 階層設計 / 5 学部 22 学科 / クラウド学部新設 / 4 instance cross-instance-pr 起票候補*
