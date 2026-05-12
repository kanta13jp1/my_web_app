-- テーマ切り替え機能 schema + 10 theme seed (Win版#132 part 100 / 2026-04-30)
--
-- User 要望:
--   「テーマ切り替え機能で複数の様々な画面デザインを選択できるような機能を追加したい」
--
-- 4 reference image (= minimal mono / saas blue / retro skeuomorphic / nature gradient)
-- + 既存 5 design system docs (= note / freee / smarthr / apple / wired)
-- + 自分株式会社 default
-- = 計 10 theme catalog seed.
--
-- 設計: docs/THEME_SWITCHER_DESIGN.md
-- Phase 1 = Win territory (= schema + seed)
-- Phase 2 = VSCode territory (= theme selector UI + ThemeData mapping)
-- Phase 3 = Codex#2 territory (= ai-hub 3 actions)

-- ==============================================
-- 1. app_themes (テーマカタログ)
-- ==============================================

CREATE TABLE IF NOT EXISTS app_themes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_code        text NOT NULL UNIQUE,
  name_ja           text NOT NULL,
  name_en           text NOT NULL,
  description       text,
  emoji             text,
  brightness        text NOT NULL DEFAULT 'dark',
  primary_color     text NOT NULL,
  accent_color      text NOT NULL,
  background_color  text NOT NULL,
  surface_color     text NOT NULL,
  text_color        text NOT NULL,
  font_family_ja    text,
  font_family_en    text,
  border_radius     int  NOT NULL DEFAULT 8,
  letter_spacing    real NOT NULL DEFAULT 0,
  line_height       real NOT NULL DEFAULT 1.7,
  preview_image_url text,
  reference_url     text,
  is_premium        boolean NOT NULL DEFAULT false,
  is_active         boolean NOT NULL DEFAULT true,
  sort_order        int NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_themes_sort_idx
  ON app_themes (sort_order, theme_code);

ALTER TABLE app_themes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_themes_select_all" ON app_themes;
CREATE POLICY "app_themes_select_all" ON app_themes
  FOR SELECT USING (is_active = true);

-- ==============================================
-- 2. user_theme_preferences (= ユーザー選択)
-- ==============================================

CREATE TABLE IF NOT EXISTS user_theme_preferences (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL,
  theme_id         uuid NOT NULL REFERENCES app_themes(id) ON DELETE CASCADE,
  custom_overrides jsonb,
  applied_at       timestamptz NOT NULL DEFAULT now(),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS user_theme_preferences_user_idx
  ON user_theme_preferences (user_id);

ALTER TABLE user_theme_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_theme_preferences_select_own" ON user_theme_preferences;
CREATE POLICY "user_theme_preferences_select_own" ON user_theme_preferences
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_theme_preferences_insert_own" ON user_theme_preferences;
CREATE POLICY "user_theme_preferences_insert_own" ON user_theme_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_theme_preferences_update_own" ON user_theme_preferences;
CREATE POLICY "user_theme_preferences_update_own" ON user_theme_preferences
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_theme_preferences_delete_own" ON user_theme_preferences;
CREATE POLICY "user_theme_preferences_delete_own" ON user_theme_preferences
  FOR DELETE USING (auth.uid() = user_id);

-- ==============================================
-- 3. updated_at triggers
-- ==============================================

CREATE OR REPLACE FUNCTION update_app_theme_updated_at()
  RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_app_themes_updated_at ON app_themes;
CREATE TRIGGER trg_app_themes_updated_at
  BEFORE UPDATE ON app_themes
  FOR EACH ROW EXECUTE FUNCTION update_app_theme_updated_at();

DROP TRIGGER IF EXISTS trg_user_theme_preferences_updated_at ON user_theme_preferences;
CREATE TRIGGER trg_user_theme_preferences_updated_at
  BEFORE UPDATE ON user_theme_preferences
  FOR EACH ROW EXECUTE FUNCTION update_app_theme_updated_at();

-- ==============================================
-- 4. 10 theme seed
-- ==============================================

INSERT INTO app_themes (
  theme_code, name_ja, name_en, description, emoji, brightness,
  primary_color, accent_color, background_color, surface_color, text_color,
  font_family_ja, font_family_en, border_radius, letter_spacing, line_height,
  reference_url, sort_order
) VALUES

-- 1. 自分株式会社 default (= dark / Orange + Indigo / docs/DESIGN.md)
('dark_ai', '自分株式会社 ダーク', 'Jibun Inc Dark',
 '自分株式会社の標準テーマ. Orange #FF6B35 + Indigo #3949AB のダークモード. 9 原則「CEO 感」を体現.',
 '🌃', 'dark',
 '#FF6B35', '#3949AB', '#0A0A0A', '#1A1A1A', '#FAFAFA',
 'Noto Sans JP', 'Inter', 8, 0, 1.7,
 'docs/DESIGN.md', 10),

-- 2. minimal mono (= image 1 / 黒白ミニマル / 円形 accent)
('minimal_mono', 'ミニマルモノ', 'Minimal Mono',
 '黒白ミニマル. 円形 accent と細い line で情報を整理. 集中作業向け.',
 '⚫️', 'light',
 '#000000', '#0066FF', '#FFFFFF', '#F5F5F5', '#111111',
 'Noto Sans JP', 'Inter', 24, 0, 1.6,
 NULL, 20),

-- 3. saas blue (= image 2 / SaaS productivity / Streamline Your Workflow)
('saas_blue', 'SaaS ブルー', 'SaaS Blue',
 '生産性向上 SaaS 風. clean blue dashboard. タスク自動化 / 時間追跡 / レポート向け.',
 '🟦', 'light',
 '#2864F0', '#FF7849', '#F8FBFF', '#FFFFFF', '#1F2937',
 'Noto Sans JP', 'Inter', 8, 0, 1.7,
 NULL, 30),

-- 4. retro skeuomorphic (= image 3 / レトロ立体感)
('retro_skeu', 'レトロ立体', 'Retro Skeuomorphic',
 'スキューモーフィズム回帰. 立体感ボタン / 影深め / 検索重視. 90s-00s の親しみやすさ.',
 '📺', 'light',
 '#3B5998', '#E8B007', '#E8E8E8', '#FFFFFF', '#1A1A2E',
 'Yu Gothic', 'Verdana', 4, 0, 1.6,
 NULL, 40),

-- 5. nature calm (= image 4 / nature gradient / 緑)
('nature_calm', 'ネイチャー カーム', 'Nature Calm',
 '自然グラデーション. 緑系 calm. ウェルビーイング / ヘルスケア / マインドフルネス向け.',
 '🌿', 'light',
 '#4CAF50', '#81C784', '#F1F8E9', '#FFFFFF', '#2E3D2A',
 'Noto Sans JP', 'Inter', 16, 0, 1.8,
 NULL, 50),

-- 6. note.com (= teal warm reading / docs/design-systems/note)
('note_warm', 'note 風', 'note.com Style',
 'note.com 風 reading theme. teal #5ac8b8 + 行間広め (line-height 2.0) + 620px 幅. 長文記事に最適.',
 '📝', 'light',
 '#5AC8B8', '#FF6F61', '#FFFFFF', '#FAFAFA', '#222222',
 'Noto Sans JP', 'Georgia', 4, 0, 2.0,
 'docs/design-systems/note/DESIGN.md', 60),

-- 7. freee (= 4px grid blue / docs/design-systems/freee)
('freee_blue', 'freee 風', 'freee Style',
 'freee 風. blue #2864F0 + 4px グリッド + システムフォント. 業務 SaaS の堅実さ.',
 '💼', 'light',
 '#2864F0', '#00A3A1', '#FFFFFF', '#F7F8FA', '#1A1A1A',
 'Noto Sans JP', 'Helvetica Neue', 4, 0, 1.7,
 'docs/design-systems/freee/DESIGN.md', 70),

-- 8. SmartHR (= Yu Gothic 8px grid / docs/design-systems/smarthr)
('smarthr_corp', 'SmartHR 風', 'SmartHR Style',
 'SmartHR 風. blue #0077C7 + Yu Gothic Medium → 400 マッピング + 8px グリッド. HR Tech 業務向け.',
 '🏢', 'light',
 '#0077C7', '#FF8C42', '#FFFFFF', '#F4F6F8', '#212121',
 'Yu Gothic', 'Inter', 8, 0, 1.7,
 'docs/design-systems/smarthr/DESIGN.md', 80),

-- 9. Apple JP (= SF Pro pill button / docs/design-systems/apple)
('apple_clean', 'Apple JP 風', 'Apple JP Style',
 'Apple JP 風. SF Pro JP + ピルボタン + #1d1d1f. プレミアム / シンプル / 高級感.',
 '🍎', 'light',
 '#0071E3', '#FF453A', '#FBFBFD', '#FFFFFF', '#1D1D1F',
 'Yu Gothic', 'SF Pro Display', 24, 0, 1.6,
 'docs/design-systems/apple/DESIGN.md', 90),

-- 10. WIRED bold (= 黒×黄 palt / docs/design-systems/wired)
('wired_bold', 'WIRED 風', 'WIRED.jp Style',
 'WIRED.jp 風. 黒×黄 / palt body 全体 / 角張りデザイン. テック誌特集の強い視認性.',
 '⚡', 'dark',
 '#FFEC00', '#FF0066', '#000000', '#1A1A1A', '#FFFFFF',
 'Yu Gothic', 'Helvetica', 0, -0.02, 1.5,
 'docs/design-systems/wired/DESIGN.md', 100)

ON CONFLICT (theme_code) DO UPDATE
  SET name_ja = EXCLUDED.name_ja,
      name_en = EXCLUDED.name_en,
      description = EXCLUDED.description,
      emoji = EXCLUDED.emoji,
      brightness = EXCLUDED.brightness,
      primary_color = EXCLUDED.primary_color,
      accent_color = EXCLUDED.accent_color,
      background_color = EXCLUDED.background_color,
      surface_color = EXCLUDED.surface_color,
      text_color = EXCLUDED.text_color,
      font_family_ja = EXCLUDED.font_family_ja,
      font_family_en = EXCLUDED.font_family_en,
      border_radius = EXCLUDED.border_radius,
      letter_spacing = EXCLUDED.letter_spacing,
      line_height = EXCLUDED.line_height,
      reference_url = EXCLUDED.reference_url,
      sort_order = EXCLUDED.sort_order;

-- ==============================================
-- 5. development_achievements 追加
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 100: テーマ切り替え機能 schema + 10 theme catalog seed (100 part milestone)',
  'User 要望「テーマ切り替え機能で複数の様々な画面デザインを選択できる機能」に応えて Phase 1 schema 完成. app_themes (catalog) + user_theme_preferences (= ユーザー選択 / RLS 自身のみ) テーブル新規 + 10 theme seed (= 自分株式会社 dark / minimal mono / saas blue / retro skeu / nature calm / note.com / freee / SmartHR / Apple JP / WIRED). 4 reference image を analyze + 既存 5 design system docs を再活用. Phase 2 (VSCode UI) + Phase 3 (Codex#2 ai-hub 3 actions) は cross-instance-pr 委譲. 100 part 連続 dogfood milestone 達成 (= Win版#132 part 1-100).',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
