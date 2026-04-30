-- AI 大学 9 番目学部: ハードウェア学部 追加 (Win版#132 part 96 / 2026-04-30)
--
-- User 要望:
--   「AI 大学に、ハードウェアについても学ぶことができるコンテンツも追加したいです。
--    例えば CPU、GPU、nvidia、intel、Apple、DELL、HP、など」
--
-- = part 93 (5 学部) → part 94 (+SWE) → part 95 (+OS+Mobile) に続く
-- 24h 内 4 段階目 cascade 拡張. 8 学部 → 9 学部 / 39 学科 → 46 学科.
--
-- 設計判断 (sort_order):
--   - ハードウェア学部 = sort_order 2 (= OS 5 よりさらに下 / 物理層 / 最も foundational)
--
-- 学部間階層 (= UI 表示順):
--   sort 2  💻 ハードウェア      ← 新規 / 物理層
--   sort 5  💿 OS                foundational
--   sort 10 🤖 AI                基盤技術
--   sort 15 📱 モバイル          app delivery
--   sort 20 ☁️ クラウド          infra
--   sort 30 🛠️ 開発ツール        道具
--   sort 35 👷 ソフトウェアエンジニアリング 方法論
--   sort 40 💾 データ基盤        データ層
--   sort 50 📚 学術研究          学術
--
-- = 「物理層 → OS → 基盤 → app → infra → 道具 → 方法論 → データ → 学術」
--   の **9 layer 順序教育設計** 完成.

-- ==============================================
-- 1. ハードウェア学部 (`hardware`)
-- ==============================================

INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order)
VALUES
  ('hardware', 'ハードウェア学部', 'Faculty of Hardware',
   'コンピューティングハードウェア全般. CPU (Intel / AMD / Apple Silicon / ARM) / GPU・アクセラレータ (NVIDIA / Apple Neural / Google TPU) / メモリ・ストレージ / PC・ワークステーション (Apple / Dell / HP / Lenovo) / サーバー・データセンター / ネットワーク機器 / 半導体製造 (TSMC / Samsung / ASML) を網羅. 全 IT スタックの物理基盤.',
   '💻', 2)
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
  ('cpu',         'CPU 学科',                          'Department of CPU',
   'CPU アーキテクチャと製品. Intel Core / Xeon / AMD Ryzen / EPYC / Apple Silicon (M シリーズ) / Qualcomm Snapdragon / ARM Cortex / RISC-V. ISA・命令セット・マイクロアーキテクチャ.',
   '⚙️', 10),
  ('gpu',         'GPU・アクセラレータ学科',           'Department of GPU & Accelerators',
   'GPU・AI アクセラレータ. NVIDIA GeForce / RTX / H100 / Blackwell / AMD Radeon / Instinct / Intel Arc / Apple Neural Engine / Google TPU / AWS Trainium / Inferentia. CUDA / ROCm / Metal.',
   '🎮', 20),
  ('memory_storage', 'メモリ・ストレージ学科',          'Department of Memory & Storage',
   'メモリ・ストレージ製品. DDR5 / LPDDR5X / HBM3e / NVMe SSD / Intel Optane / Samsung / Micron / SK Hynix / WD / Seagate. 性能特性 / 寿命 / TCO.',
   '💾', 30),
  ('pc_workstation', 'PC・ワークステーション学科',     'Department of PC & Workstation',
   'コンシューマー・プロシューマー機器. Apple Mac / iMac / Mac Studio / Dell XPS / Precision / HP Spectre / ZBook / Lenovo ThinkPad / ASUS ROG / Microsoft Surface / Framework Laptop.',
   '🖥️', 40),
  ('server_dc',   'サーバー・データセンター学科',      'Department of Servers & Datacenters',
   'エンタープライズサーバー・DC 基盤. Dell PowerEdge / HP ProLiant / Lenovo ThinkSystem / Supermicro / NVIDIA DGX / Cerebras / Groq / hyperscale (AWS/GCP/Azure 自社設計).',
   '🏢', 50),
  ('network_peripheral', 'ネットワーク・周辺機器学科', 'Department of Network & Peripherals',
   'ネットワーク機器 / 周辺機器. Cisco / Juniper / Arista / Mellanox / Logitech / Razer / Apple Magic / 4K/8K ディスプレイ / Webカメラ / オーディオ.',
   '🔌', 60),
  ('semiconductor', '半導体製造学科',                  'Department of Semiconductor Manufacturing',
   '半導体製造業界. TSMC / Samsung Foundry / Intel Foundry Services / GlobalFoundries / ASML (露光装置) / Applied Materials / KLA / Tokyo Electron. 微細化プロセス (3nm/2nm).',
   '🔬', 70)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'hardware'
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
  'Win版#132 part 96: AI 大学 ハードウェア学部 追加 (9 学部到達)',
  'User 要望「ハードウェアについても学べる content / 例: CPU / GPU / nvidia / intel / Apple / DELL / HP 等」に応えて 9 番目学部 hardware を新設. 7 学科 (CPU / GPU・アクセラレータ / メモリ・ストレージ / PC・ワークステーション / サーバー・データセンター / ネットワーク・周辺機器 / 半導体製造) を seed. part 95 8 学部 39 学科 → 9 学部 46 学科. sort_order 2 配置で物理層を最下層に確立 → 9 layer 教育設計完成. 24h 内 4 段階 cascade 拡張. provider seed は cross-instance-pr で PS#3 territory に委譲.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
