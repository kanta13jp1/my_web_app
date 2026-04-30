# Cross-Instance PR: AI 大学 学部/学科 mapping + クラウド/DevOps/データ provider seed

**作成**: Win版#132 part 93 / 2026-04-30
**FROM**: Win版 (User 要望 + schema 設計)
**TO**: PS版#3 (AI 大学 専任 territory)
**優先度**: HIGH (= User 直接要望 / phase 2-4 連続 task)
**期限**: 2026-05-07 (1 週間)
**親軸**: AI 大学拡張 + INDIE_DEV_VELOCITY (#6 Avoid Side-Project Graveyard / #7 Community)

---

## 1. 背景

User 要望:
> 「AI 大学に学部や学科という分類を追加して、AI に関するものだけでなく AWS や GCP や Azure などのクラウドサービスについても学ぶことができるコンテンツも追加したいです」

Win territory done (= phase 1 / 本 part):
- 設計 doc: `docs/AI_UNIVERSITY_FACULTY_DEPARTMENT_DESIGN.md`
- migration: `supabase/migrations/20260430020000_create_university_faculties_departments.sql`
  - `university_faculties` + `university_departments` テーブル新規
  - `ai_university_content` に `faculty_id` + `department_id` columns 追加 (nullable)
  - 5 学部 (ai / cloud / devtools / data / research) seed
  - 22 学科 seed (AI 7 + クラウド 5 + 開発ツール 4 + データ 3 + 学術 3)

PS#3 territory (= 本 cross-instance-pr / phase 2-4):
- Phase 2: 既存 380+ provider → 学科 mapping bulk UPDATE
- Phase 3: クラウド学部 5 学科に 30+ provider seed (AWS / GCP / Azure / Oracle / Cloudflare 等)
- Phase 4: 開発ツール / データ基盤 / 学術研究学部 provider seed

## 2. Phase 2: 既存 provider → 学科 mapping (= migration 1 件)

`supabase/migrations/<timestamp>_map_existing_providers_to_departments.sql` 新規:

```sql
-- LLM 学科
UPDATE ai_university_content
SET faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = 'ai'),
    department_id = (SELECT id FROM university_departments
                     WHERE department_code = 'llm'
                       AND faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = 'ai'))
WHERE provider IN (
  'openai', 'anthropic', 'meta', 'mistral', 'cohere', 'deepseek', 'sakana',
  'aleph_alpha', 'reka', 'baidu', 'ibm', 'oracle', 'perplexity', 'groq',
  'amazon', 'huggingface', 'nvidia', 'google', 'microsoft', 'x'
);

-- 画像生成学科
UPDATE ai_university_content
SET faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = 'ai'),
    department_id = (SELECT id FROM university_departments
                     WHERE department_code = 'image'
                       AND faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = 'ai'))
WHERE provider IN (
  'stability_ai', 'midjourney', 'dalle', 'adobe_firefly', 'leonardo_ai',
  'ideogram'
);

-- (= 残 5 学科分繰り返し / voice / video / agent / embedding / framework)

-- 学術研究学部 → benchmark 学科
UPDATE ai_university_content
SET faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = 'research'),
    department_id = (SELECT id FROM university_departments
                     WHERE department_code = 'benchmark'
                       AND faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = 'research'))
WHERE provider IN ('mmlu', 'humaneval', 'swe_bench', 'webarena', 'gsm8k', 'hellaswag', 'truthfulqa', 'arc_challenge', 'big_bench', 'agentbench');

-- 完了確認 query (= comment / dev だけ実行)
-- SELECT count(*) FROM ai_university_content WHERE faculty_id IS NULL;
```

= 既存 380+ row を 1 migration で全 mapping. `provider` 名 → 学科 の対応表を migration 内に明示.

## 3. Phase 3: クラウド学部 5 学科 / 30+ provider seed

5 migration file (= 各学科 6 provider 想定):

```text
20260430030000_seed_aws_university.sql       (= AWS 学科 / 6+ services)
20260430030500_seed_gcp_university.sql       (= GCP 学科 / 6+ services)
20260430031000_seed_azure_university.sql     (= Azure 学科 / 6+ services)
20260430031500_seed_oracle_cloud_university.sql (= Oracle 学科 / 4+ services)
20260430032000_seed_edge_cloud_university.sql   (= エッジ・新興 / 6+ providers)
```

各 file の構造 (= AWS 例):

```sql
-- AWS 学科 seed (cloud / aws)
DO $$
DECLARE
  v_faculty_id    uuid;
  v_department_id uuid;
BEGIN
  SELECT id INTO v_faculty_id FROM university_faculties WHERE faculty_code = 'cloud';
  SELECT id INTO v_department_id FROM university_departments
    WHERE department_code = 'aws' AND faculty_id = v_faculty_id;

  INSERT INTO ai_university_content (provider, category, title, content, source_url, faculty_id, department_id, sort_order)
  VALUES
    ('aws_ec2',     'overview', 'AWS EC2 概要', '...', 'https://aws.amazon.com/ec2/', v_faculty_id, v_department_id, 10),
    ('aws_s3',      'overview', 'AWS S3 概要', '...', 'https://aws.amazon.com/s3/', v_faculty_id, v_department_id, 20),
    ('aws_lambda',  'overview', 'AWS Lambda 概要', '...', 'https://aws.amazon.com/lambda/', v_faculty_id, v_department_id, 30),
    ('aws_sagemaker', 'overview', 'AWS SageMaker 概要', '...', '...', v_faculty_id, v_department_id, 40),
    ('aws_bedrock', 'overview', 'AWS Bedrock 概要', '...', '...', v_faculty_id, v_department_id, 50),
    ('aws_rds',     'overview', 'AWS RDS 概要', '...', '...', v_faculty_id, v_department_id, 60),
    ('aws_dynamodb', 'overview', 'AWS DynamoDB 概要', '...', '...', v_faculty_id, v_department_id, 70)
  ON CONFLICT DO NOTHING;
END $$;
```

= **既存 AI 大学 seed pattern と同型** (= 既存 PS#3 routine の延長).

## 4. Phase 4: 開発ツール / データ基盤 / 学術研究学部

PS#3 が既存 seed pattern に沿って migration 作成:
- 開発ツール 4 学科 (= IaC / CI/CD / Container / Monitoring) / 各 5 provider 想定 = 20+ provider
- データ基盤 3 学科 (= Database / Warehouse / Stream) / 各 5 provider = 15+ provider
- 学術研究 3 学科 (= Benchmark / Paper / Lab) / 既存 benchmark 集約 + 新規 paper/lab seed = 20+ provider

## 4.1 Phase 4.5: ソフトウェアエンジニアリング学部 (= part 94 追加 / 6 学部目)

Win版 part 94 で `20260430030000_add_software_engineering_faculty.sql` 適用済 (= 学部 + 7 学科 seed 完了).

PS#3 territory: SWE 学部 7 学科に **30+ provider seed** (= migration `20260430040000_seed_swe_university.sql` 想定):

| 学科 | 想定 provider 例 |
| --- | --- |
| `agile` | Scrum.org / SAFe / Atlassian / Mountain Goat (Mike Cohn) / Spotify / GitHub / GitLab |
| `architecture` | Uncle Bob (Clean Architecture) / Eric Evans (DDD) / Martin Fowler (Refactoring Guru) / GoF / Microservices.io |
| `testing` | Kent Beck (TDD) / Cucumber (BDD) / Playwright / Cypress / Jest / pytest / Hypothesis |
| `security` | OWASP / Snyk / Aqua / Hashicorp Vault / Auth0 / Okta |
| `refactoring` | Refactoring (Fowler 著) / Clean Code (Uncle Bob) / Code Climate / SonarQube |
| `pm` | PMI / Atlassian Jira / Linear / OKR Software / DORA / DevOps Research |
| `documentation` | Diátaxis / Stripe Doc Style / Stoplight / ReadMe / Mintlify |

各 provider に overview / tutorial / pricing 等 category content を seed.

合計 phase 2-4.5 で **100+ provider 追加** + **既存 380+ mapping** = 480+ provider に拡大.

## 4.2 Phase 4.6: OS 学部 + モバイル学部 (= part 95 追加 / 7・8 学部目)

Win版 part 95 で `20260430040000_add_os_and_mobile_faculties.sql` 適用済 (= 学部 + 10 学科 seed 完了).

### OS 学部 5 学科に 25+ provider seed (= migration `20260430050000_seed_os_university.sql` 想定)

| 学科 | 想定 provider 例 |
| --- | --- |
| `windows` | Windows 11 / Windows Server / WSL2 / PowerShell / Active Directory / Hyper-V |
| `macos` | macOS Sequoia / Homebrew / Xcode / SwiftUI / Apple Silicon (M1/M2/M3) |
| `linux` | Ubuntu / Debian / Fedora / Arch / NixOS / Alpine / Linux Kernel |
| `bsd_unix` | FreeBSD / OpenBSD / Solaris / illumos |
| `rtos` | FreeRTOS / Zephyr / VxWorks / TRON / Yocto |

### モバイル学部 5 学科に 25+ provider seed (= migration `20260430060000_seed_mobile_university.sql` 想定)

| 学科 | 想定 provider 例 |
| --- | --- |
| `ios` | Swift / SwiftUI / UIKit / Xcode / TestFlight / WidgetKit |
| `android` | Kotlin / Jetpack Compose / Android Studio / Material Design 3 / Google Play |
| `cross_platform` | Flutter / React Native / .NET MAUI / Ionic / Capacitor / Expo |
| `mobile_uiux` | Apple HIG / Material Design / Mobile Patterns |
| `mobile_devops` | Fastlane / Firebase App Distribution / App Center / Codemagic / Bitrise |

合計 phase 2-4.6 で **150+ provider 追加** + **既存 380+ mapping** = **530+ provider** に拡大.

## 4.3 Phase 4.7: ハードウェア学部 (= part 96 追加 / 9 学部目)

Win版 part 96 で `20260430050000_add_hardware_faculty.sql` 適用済 (= 学部 + 7 学科 seed 完了).

### ハードウェア学部 7 学科に 50+ provider seed (= migration `20260430070000_seed_hardware_university.sql` 想定)

| 学科 | 想定 provider 例 |
| --- | --- |
| `cpu` | Intel Core / Xeon / AMD Ryzen / EPYC / Apple Silicon M3/M4 / Qualcomm Snapdragon X / ARM Cortex / RISC-V |
| `gpu` | NVIDIA RTX 5090 / H100 / Blackwell B200 / AMD Radeon RX / Instinct MI300 / Intel Arc / Apple Neural Engine / Google TPU v5p / AWS Trainium |
| `memory_storage` | DDR5 / LPDDR5X / HBM3e / NVMe SSD / Samsung 990 Pro / Micron / SK Hynix / WD Black / Seagate IronWolf |
| `pc_workstation` | Mac Studio / MacBook Pro M4 / Dell XPS / Precision / HP Spectre / ZBook / Lenovo ThinkPad X1 / ASUS ROG / Microsoft Surface / Framework Laptop |
| `server_dc` | Dell PowerEdge / HP ProLiant / Lenovo ThinkSystem / Supermicro / NVIDIA DGX H200 / Cerebras WSE-3 / Groq LPU |
| `network_peripheral` | Cisco Catalyst / Juniper MX / Arista 7800 / Mellanox ConnectX / Logitech MX Master / Razer / Apple Studio Display |
| `semiconductor` | TSMC 3nm/2nm / Samsung Foundry / Intel 18A / GlobalFoundries / ASML EUV / Applied Materials / Tokyo Electron |

合計 phase 2-4.7 で **200+ provider 追加** + **既存 380+ mapping** = **580+ provider** に拡大.

## 4.4 Phase 4.8: 資格試験学部 (= part 97 追加 / 10 学部目)

Win版 part 97 で `20260430060000_add_certification_faculty.sql` 適用済 (= 学部 + 7 学科 seed 完了).

### 資格試験学部 7 学科に 50+ provider seed (= migration `20260430080000_seed_certification_university.sql` 想定)

| 学科 | 想定 provider 例 |
| --- | --- |
| `ipa` | 基本情報技術者 (FE) / 応用情報技術者 (AP) / DB スペシャリスト / NW スペシャリスト / SC 安全確保支援士 / PM / IT パスポート / G 検定 / E 資格 |
| `cloud_cert` | AWS Certified (CP/SAA/DOP/MLS) / Azure (AZ-900/104/204/305) / Google Cloud (CDL/Associate/PCA/PDE) / Oracle Cloud Infrastructure |
| `network_sec` | Cisco CCNA/CCNP/CCIE / CompTIA Network+/Security+/CySA+ / CISSP / CCSP / CEH / OSCP |
| `database_data` | Oracle Master (Bronze/Silver/Gold/Platinum) / Snowflake Certified / Databricks / MongoDB / PostgreSQL Associate |
| `pm_cert` | PMP / PRINCE2 / CSM / PSM I/II/III / SAFe / ITIL 4 Foundation / Lean Six Sigma |
| `developer` | Microsoft Certified Developer / Oracle Java SE/EE / Python PCEP/PCAP/PCPP / CKA/CKAD/CKS / GitHub Foundations / HashiCorp Terraform |
| `business_intl` | TOEIC / TOEFL / IELTS / 日商簿記 1-3 級 / 中小企業診断士 / 統計検定 / 行政書士 |

合計 phase 2-4.8 で **250+ provider 追加** + **既存 380+ mapping** = **630+ provider** に拡大.

## 5. 受入基準

- [ ] Phase 2 mapping migration 完了 → `SELECT count(*) FROM ai_university_content WHERE faculty_id IS NULL` = 0
- [ ] Phase 3 クラウド学部 5 学科分 seed migration 完了 (= 5 file)
- [ ] Phase 4 開発ツール 4 / データ 3 / 学術 3 = 10 学科分 seed migration 完了 (= 10 file)
- [ ] **Phase 4.5 SWE 学部 7 学科分 seed migration 完了 (= 7 file)** ← part 94 追加
- [ ] **Phase 4.6 OS 学部 5 学科分 seed migration 完了 (= 5 file)** ← part 95 追加
- [ ] **Phase 4.6 モバイル学部 5 学科分 seed migration 完了 (= 5 file)** ← part 95 追加
- [ ] **Phase 4.7 ハードウェア学部 7 学科分 seed migration 完了 (= 7 file)** ← part 96 追加
- [ ] **Phase 4.8 資格試験学部 7 学科分 seed migration 完了 (= 7 file)** ← part 97 追加
- [ ] 各 migration `python scripts/check_migration_timestamps.py` PASS
- [ ] development_achievements に各 phase の seed entry 追加
- [ ] cross-instance-pr 完了時 `done/` 移動

## 6. PS#3 既存 routine との整合

PS#3 は既に AI 大学 380+ provider seed routine を実証済 (= part 87-S145 累計). 本 PR は同 routine に **学部/学科 column** を加えるのみ. 1 provider 追加につき 5-10 行の DO block 追加で完結.

= PS#3 territory への低摩擦委譲.

---

*Win版#132 part 93 / 2026-04-30 起票 / AI 大学 学部/学科 階層 phase 2-4 / Win → PS#3 lane*
