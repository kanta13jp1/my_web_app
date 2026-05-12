-- AI 大学 10 番目学部: 資格試験学部 追加 (Win版#132 part 97 / 2026-04-30)
--
-- User 要望:
--   「AI 大学に、資格試験についても学ぶことができるコンテンツも追加したいです。
--    例えば情報処理技術者試験、ベンダー資格など」
--
-- = part 93 → 94 → 95 → 96 → 97 の **24h 内 5 段階目 cascade 拡張** 到達.
-- 9 学部 46 学科 → 10 学部 53 学科. 「学習結果を validate する層」確立.
--
-- 設計判断 (sort_order):
--   - 資格試験学部 = sort_order 45 (= データ 40 と 学術 50 の間 / 学習 validation 層)
--
-- 学部間階層 (= UI 表示順 / 完成版):
--   sort  2  💻 ハードウェア              物理層
--   sort  5  💿 OS                         OS 層
--   sort 10  🤖 AI                         基盤技術
--   sort 15  📱 モバイル                   app delivery
--   sort 20  ☁️ クラウド                   infra
--   sort 30  🛠️ 開発ツール                 道具
--   sort 35  👷 ソフトウェアエンジニアリング 方法論
--   sort 40  💾 データ基盤                 データ層
--   sort 45  🎓 資格試験                   ← 新規 / validation 層
--   sort 50  📚 学術研究                   学術
--
-- = 「物理 → OS → 技術 → app → infra → 道具 → 方法論 → データ → 資格 → 学術」
--   の **10 layer 順序教育** 完成.

-- ==============================================
-- 1. 資格試験学部 (`certification`)
-- ==============================================

INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order)
VALUES
  ('certification', '資格試験学部', 'Faculty of Certifications',
   'IT 関連資格試験を網羅. 情報処理技術者試験 (IPA / 国家資格) / 主要クラウドベンダー認定 (AWS / Azure / GCP) / ネットワーク・セキュリティ (Cisco / CompTIA / CISSP) / データベース・データ (Oracle / Snowflake) / プロジェクトマネジメント (PMP / Scrum / ITIL) / 開発者資格 (CKA / Java / Python) / ビジネス・国際資格 (TOEIC / 簿記 / 統計検定). 学習成果を validate する層.',
   '🎓', 45)
ON CONFLICT (faculty_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- ==============================================
-- 2. 7 学科 seed
-- ==============================================

INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('ipa',           '情報処理技術者試験学科',       'Department of IPA Exams',
   '日本の国家資格 IT 試験 (IPA). 基本情報技術者 (FE) / 応用情報技術者 (AP) / 高度試験 (DB スペシャリスト / NW スペシャリスト / SC 情報処理安全確保支援士 / PM プロジェクトマネージャー / SM システム監査技術者 等). IT パスポート / G 検定 / E 資格.',
   '🇯🇵', 10),
  ('cloud_cert',    'クラウドベンダー資格学科',     'Department of Cloud Vendor Certifications',
   '主要クラウドベンダー認定. AWS Certified (Cloud Practitioner / Solutions Architect / DevOps Engineer / ML Specialty) / Microsoft Azure (AZ-900 / AZ-104 / AZ-204 / AZ-305) / Google Cloud (Cloud Digital Leader / Associate / Professional) / Oracle Cloud / IBM Cloud.',
   '☁️', 20),
  ('network_sec',   'ネットワーク・セキュリティ資格学科', 'Department of Network & Security Certifications',
   'ネットワーク・セキュリティ資格. Cisco (CCNA / CCNP / CCIE) / Juniper / CompTIA (Network+ / Security+ / CySA+) / (ISC)2 (CISSP / CCSP / SSCP) / EC-Council (CEH) / Offensive Security (OSCP).',
   '🛡️', 30),
  ('database_data', 'データベース・データ資格学科',  'Department of Database & Data Certifications',
   'DB・データ系資格. Oracle Master (Bronze / Silver / Gold / Platinum) / Microsoft Certified: Azure Data / Snowflake Certified / Databricks Certified / MongoDB / PostgreSQL Associate Certified.',
   '🗃️', 40),
  ('pm_cert',       'プロジェクトマネジメント資格学科', 'Department of Project Management Certifications',
   'PM・プロセス資格. PMP (PMI) / PRINCE2 / Certified ScrumMaster (CSM) / Professional Scrum Master (PSM) / SAFe Agilist (SA) / ITIL Foundation / Lean Six Sigma.',
   '📋', 50),
  ('developer',     '開発者資格学科',                'Department of Developer Certifications',
   '開発者向け資格. Microsoft Certified: Developer / Java SE/EE Programmer (Oracle) / Python Institute (PCEP/PCAP/PCPP) / Kubernetes (CKA/CKAD/CKS) / GitHub Foundations / GitHub Actions / HashiCorp (Terraform Associate).',
   '👨‍💻', 60),
  ('business_intl', 'ビジネス・国際資格学科',        'Department of Business & International Certifications',
   'ビジネス・国際資格. TOEIC / TOEFL / IELTS / 日商簿記 / 中小企業診断士 / 統計検定 / G 検定 (一般社団法人日本ディープラーニング協会) / E 資格 / 行政書士 / 司法書士 (キャリア横断学習).',
   '🌐', 70)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'certification'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- ==============================================
-- 3. development_achievements 追加
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 97: AI 大学 資格試験学部 追加 (10 学部到達)',
  'User 要望「資格試験についても学べる content / 例: 情報処理技術者試験 / ベンダー資格 等」に応えて 10 番目学部 certification を新設. 7 学科 (情報処理技術者試験 / クラウドベンダー資格 / ネットワーク・セキュリティ / データベース・データ / プロジェクトマネジメント / 開発者 / ビジネス・国際) を seed. part 96 9 学部 46 学科 → 10 学部 53 学科. sort_order 45 配置で「学習成果 validation 層」を学術 (50) の前に確立 → 10 layer 教育設計完成. 24h 内 5 段階 cascade 拡張. provider seed は cross-instance-pr で PS#3 territory に委譲.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
