-- AI 大学 6 番目学部: ソフトウェアエンジニアリング学部 追加 (Win版#132 part 94 / 2026-04-30)
--
-- User 要望: 「AI 大学に、Software エンジニアリングについても学ぶことができる
-- コンテンツも追加したいです。例えばアジャイル開発についてなど」
--
-- = AI 大学を「総合 IT 大学」(part 93 で 5 学部) からさらに **「ソフトウェア工学
-- まで含む総合 IT・SW 大学」** へ拡張. 6 学部目を追加.
--
-- 設計: docs/AI_UNIVERSITY_FACULTY_DEPARTMENT_DESIGN.md (part 94 で更新)
--
-- ソフトウェアエンジニアリング学部 (= software_engineering / 'swe') 7 学科:
--   1. アジャイル・Scrum 学科        (= agile)
--   2. アーキテクチャ・設計学科       (= architecture)
--   3. テスト・品質保証学科           (= testing)
--   4. セキュリティ・SecDevOps 学科   (= security)
--   5. リファクタリング・コード品質学科 (= refactoring)
--   6. プロジェクト・チームマネジメント学科 (= pm)
--   7. ドキュメント・テクニカルライティング学科 (= documentation)
--
-- 既存 5 学部 (= part 93 / ai / cloud / devtools / data / research) は保持.
-- 累計 6 学部 / 29 学科 / 含む provider 数は phase 2-4 cross-instance-pr で seed.

-- ==============================================
-- 1. ソフトウェアエンジニアリング学部 seed
-- ==============================================

INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order)
VALUES
  ('swe', 'ソフトウェアエンジニアリング学部', 'Faculty of Software Engineering',
   'ソフトウェア開発の方法論・設計・品質・運用を学ぶ. アジャイル / Scrum 開発手法から、Clean Architecture / DDD 等の設計、TDD / E2E test、SecDevOps、リファクタリング、プロジェクトマネジメント、ドキュメント技法まで網羅. AI 学部 + クラウド学部 + 開発ツール学部 と組み合わせて完全な現代エンジニアスキルセット.',
   '👷', 35)
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
  ('agile',         'アジャイル・Scrum 学科',          'Department of Agile & Scrum',
   'アジャイル開発の原則と実践. Scrum / Kanban / SAFe / XP / Lean / Spotify モデル等の方法論と、スプリント運営・Retrospective・User Story 技法.',
   '🏃', 10),
  ('architecture',  'アーキテクチャ・設計学科',         'Department of Architecture & Design',
   'ソフトウェアアーキテクチャ設計. Clean Architecture / DDD (Domain-Driven Design) / Hexagonal / Microservices / Event-Driven / CQRS / Design Patterns (GoF / Refactoring Guru) を体系学習.',
   '🏗️', 20),
  ('testing',       'テスト・品質保証学科',             'Department of Testing & QA',
   'テスト戦略と品質保証. TDD (Test-Driven Development) / BDD (Behavior-Driven) / E2E test / unit / integration / property-based / mutation testing / contract testing.',
   '🧪', 30),
  ('security',      'セキュリティ・SecDevOps 学科',     'Department of Security & SecDevOps',
   'アプリケーションセキュリティ. OWASP Top 10 / SAST / DAST / SCA / Zero Trust / Threat Modeling / Secret Management / Supply Chain Security / SLSA.',
   '🔒', 40),
  ('refactoring',   'リファクタリング・コード品質学科', 'Department of Refactoring & Code Quality',
   'コード品質と継続的改善. SOLID 原則 / Clean Code / Code Smells / Refactoring techniques (Fowler) / Code Review 文化 / Pair / Mob Programming.',
   '✨', 50),
  ('pm',            'プロジェクト・チームマネジメント学科', 'Department of Project & Team Management',
   'エンジニアリング組織運営. プロジェクトマネジメント (PMBOK / PRINCE2) / OKR / Team Topologies / Engineering Ladder / Onboarding / DORA Metrics.',
   '👥', 60),
  ('documentation', 'ドキュメント・テクニカルライティング学科', 'Department of Documentation & Technical Writing',
   'エンジニア向けドキュメント技法. Spec / RFC / ADR (Architecture Decision Record) / API ドキュメント / Diagram (C4 model / Mermaid) / Diátaxis フレームワーク.',
   '📝', 70)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'swe'
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
  'Win版#132 part 94: AI 大学 ソフトウェアエンジニアリング学部 追加',
  'User 要望「AI 大学にソフトウェアエンジニアリングについても学べる content を追加 / アジャイル開発など」に応えて 6 番目学部 swe を新設. 7 学科 (アジャイル / アーキテクチャ / テスト / セキュリティ / リファクタリング / PM / ドキュメント) を seed. part 93 の 5 学部 22 学科 → 6 学部 29 学科 へ拡張. SWE provider seed (= Scrum.org / Atlassian / Fowler / Beck 等) は cross-instance-pr で PS#3 territory に委譲.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
