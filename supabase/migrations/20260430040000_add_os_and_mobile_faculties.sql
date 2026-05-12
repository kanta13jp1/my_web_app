-- AI 大学 7・8 番目学部: OS 学部 + モバイル学部 追加 (Win版#132 part 95 / 2026-04-30)
--
-- User 要望:
--   「AI 大学に、OS についても学ぶことができるコンテンツも追加したいです。
--    例えば Windows、MacOS、Linux についてなど。
--    またモバイルについても学ぶことができるコンテンツも追加したいです。
--    例えば iOS、Android など」
--
-- = part 93 (5 学部) + part 94 (6 学部目 SWE) に続く 3 段階目 domain 拡張.
-- 8 学部 / 39 学科の総合 IT 大学体系完成.
--
-- 設計判断 (sort_order):
--   - OS 学部 = sort_order 5 (= AI 10 の前 / 最も foundational なので最上位)
--   - モバイル学部 = sort_order 15 (= AI 10 と クラウド 20 の間 / app delivery 層)
--
-- 学部間階層 (= UI 表示順):
--   1. 💿 OS 学部 (5)        ← foundational
--   2. 🤖 AI 学部 (10)
--   3. 📱 モバイル学部 (15)  ← new
--   4. ☁️ クラウド学部 (20)
--   5. 💿 OS 学部 ← 再掲
--   ...

-- ==============================================
-- 1. OS 学部 (`os`)
-- ==============================================

INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order)
VALUES
  ('os', 'OS 学部', 'Faculty of Operating Systems',
   'オペレーティングシステムを学ぶ. Windows / macOS / Linux 等の主要 OS、BSD / Unix 系、組み込み RTOS まで網羅. カーネル / システムプログラミング / シェル / 仮想化 / ファイルシステム の基礎理解を提供.',
   '💿', 5)
ON CONFLICT (faculty_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- 5 学科 seed
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('windows',   'Windows 学科',         'Department of Windows',
   'Microsoft Windows 系 OS. Windows 11 / Windows Server / WSL (Linux 連携) / PowerShell / Active Directory / Hyper-V / .NET 開発環境.',
   '🪟', 10),
  ('macos',     'macOS 学科',           'Department of macOS',
   'Apple macOS. macOS Sequoia / Sonoma 等の最新版 / iCloud 連携 / Homebrew / SwiftUI for Mac / Xcode / Apple Silicon (M1/M2/M3) 最適化.',
   '🍎', 20),
  ('linux',     'Linux 学科',           'Department of Linux',
   'Linux ディストリビューション全般. Ubuntu / Debian / Fedora / RHEL / Arch / NixOS / Alpine. カーネル基礎 / systemd / シェル (bash/zsh/fish) / パッケージマネージャ.',
   '🐧', 30),
  ('bsd_unix',  'BSD・Unix 系学科',     'Department of BSD & Unix',
   'BSD 系 (FreeBSD / OpenBSD / NetBSD) と商用 Unix (Solaris / AIX / HP-UX / illumos). サーバー OS / セキュリティ重視設計 / ZFS / pf ファイアウォール.',
   '🛡️', 40),
  ('rtos',      '組み込み・RTOS 学科',  'Department of Embedded & RTOS',
   '組み込み OS / リアルタイム OS. FreeRTOS / Zephyr / VxWorks / TRON / Yocto Project / Buildroot / RT-Linux. IoT デバイス開発の基盤.',
   '🔧', 50)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'os'
ON CONFLICT (faculty_id, department_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- ==============================================
-- 2. モバイル学部 (`mobile`)
-- ==============================================

INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order)
VALUES
  ('mobile', 'モバイル学部', 'Faculty of Mobile',
   'モバイルアプリ開発. iOS (Swift / SwiftUI) / Android (Kotlin / Jetpack Compose) ネイティブ開発、Flutter / React Native 等のクロスプラットフォーム、モバイル UI/UX、Fastlane / TestFlight 等のモバイル DevOps を網羅.',
   '📱', 15)
ON CONFLICT (faculty_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      sort_order = EXCLUDED.sort_order;

-- 5 学科 seed
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order)
SELECT f.id, dept.code, dept.name_ja, dept.name_en, dept.description, dept.emoji, dept.sort_order
FROM university_faculties f
CROSS JOIN (VALUES
  ('ios',            'iOS 学科',                       'Department of iOS',
   'Apple iOS / iPadOS 開発. Swift 言語 / SwiftUI / UIKit / Xcode IDE / TestFlight 配布 / App Store 公開 / WidgetKit / WatchKit. App Store Review Guidelines.',
   '📲', 10),
  ('android',        'Android 学科',                   'Department of Android',
   'Google Android 開発. Kotlin (推奨) / Jetpack Compose (UI 宣言型) / Android Studio / Material Design 3 / Google Play Console / KMP (Kotlin Multiplatform).',
   '🤖', 20),
  ('cross_platform', 'クロスプラットフォーム学科',     'Department of Cross-Platform',
   'クロスプラットフォーム mobile framework. Flutter (Dart) / React Native (JS/TS) / .NET MAUI (C#) / Ionic / Capacitor / Expo. 1 codebase で iOS+Android 両対応.',
   '🌐', 30),
  ('mobile_uiux',    'モバイル UI/UX 学科',            'Department of Mobile UI/UX',
   'モバイル特有の UI/UX デザイン. Apple Human Interface Guidelines / Google Material Design / Touch Target / Gesture / Accessibility (VoiceOver / TalkBack) / Dark Mode / Adaptive Layout.',
   '🎨', 40),
  ('mobile_devops',  'モバイル DevOps 学科',           'Department of Mobile DevOps',
   'モバイル CI/CD と配布. Fastlane / TestFlight / Google Play Internal Testing / Firebase App Distribution / App Center (Microsoft) / Codemagic / Bitrise / Crashlytics クラッシュ解析.',
   '🚀', 50)
) AS dept(code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'mobile'
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
  'Win版#132 part 95: AI 大学 OS 学部 + モバイル学部 追加 (8 学部到達)',
  'User 要望「OS について (Windows/macOS/Linux 等) / モバイルについて (iOS/Android 等) も学べる content を追加」に応えて 7 + 8 番目学部を新設. OS 学部 5 学科 (Windows / macOS / Linux / BSD・Unix / 組み込み RTOS) + モバイル学部 5 学科 (iOS / Android / クロスプラットフォーム / Mobile UI/UX / Mobile DevOps) seed. part 94 6 学部 29 学科 → 8 学部 39 学科. 連続 domain 拡張 第 3 段階. provider seed は cross-instance-pr で PS#3 territory に委譲.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
