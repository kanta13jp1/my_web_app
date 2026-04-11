-- AI大学 達成バッジテーブル (2026-04-11)
-- クイズ完了・ストリーク・全社制覇などの達成を記録しシェア・ランキングに活用する

CREATE TABLE IF NOT EXISTS ai_university_badges (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  badge_id    text NOT NULL,   -- 'first_study' | 'quiz_master' | 'streak_7d' | 'all_providers' など
  badge_name  text NOT NULL,   -- 表示名
  icon_emoji  text NOT NULL DEFAULT '🏅',
  condition   text,            -- 達成条件の説明
  is_public   boolean NOT NULL DEFAULT true,  -- ランキング・シェアに表示するか
  awarded_at  timestamptz NOT NULL DEFAULT now(),

  UNIQUE (user_id, badge_id)   -- 同じバッジは1回のみ
);

-- インデックス
CREATE INDEX IF NOT EXISTS ai_university_badges_user_idx
  ON ai_university_badges (user_id, awarded_at DESC);

CREATE INDEX IF NOT EXISTS ai_university_badges_badge_idx
  ON ai_university_badges (badge_id, awarded_at DESC);

-- RLS: 自分のバッジは読み書き可 / is_public=true なら全員閲覧可
ALTER TABLE ai_university_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_university_badges_select_public" ON ai_university_badges
  FOR SELECT USING (is_public = true OR auth.uid() = user_id);

CREATE POLICY "ai_university_badges_insert_own" ON ai_university_badges
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- バッジ定義マスター (参照用コメント)
-- badge_id          badge_name        icon  条件
-- 'first_study'     「AI入学」         🎓   初回学習
-- 'quiz_first'      「初クイズ正解」   ✅   クイズ初正解
-- 'streak_3d'       「3日連続学習」    🔥   current_streak >= 3
-- 'streak_7d'       「週間皆勤賞」     🔥   current_streak >= 7
-- 'streak_30d'      「月間皆勤賞」     🏆   current_streak >= 30
-- 'quiz_master_3'   「クイズ3冠」      🌟   3社クイズ正解
-- 'quiz_master_all' 「全社制覇」       👑   全登録プロバイダークイズ正解
-- 'social_sharer'   「シェア先生」     📣   シェアボタン使用
-- 'early_adopter'   「アーリーアダプター」 🚀 初期ユーザー特典

-- バッジ付与ヘルパー関数 (EF から呼び出す)
CREATE OR REPLACE FUNCTION award_ai_university_badge(
  p_user_id    uuid,
  p_badge_id   text,
  p_badge_name text,
  p_icon_emoji text DEFAULT '🏅',
  p_condition  text DEFAULT NULL
)
  RETURNS boolean  -- true = 新規付与, false = 既存(スキップ)
  LANGUAGE plpgsql
  SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO ai_university_badges
    (user_id, badge_id, badge_name, icon_emoji, condition)
  VALUES
    (p_user_id, p_badge_id, p_badge_name, p_icon_emoji, p_condition)
  ON CONFLICT (user_id, badge_id) DO NOTHING;

  RETURN FOUND;
END;
$$;

-- 学習完了時に自動でバッジ付与するトリガー関数
CREATE OR REPLACE FUNCTION trg_auto_award_badges()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count int;
BEGIN
  -- first_study: スコア初挿入時
  IF (TG_OP = 'INSERT') THEN
    PERFORM award_ai_university_badge(
      NEW.user_id, 'first_study', 'AI入学', '🎓', '初回学習');
  END IF;

  -- quiz_first: クイズ初正解
  IF NEW.quiz_correct = true THEN
    SELECT COUNT(*) INTO v_count
      FROM ai_university_scores
     WHERE user_id = NEW.user_id AND quiz_correct = true;
    IF v_count = 1 THEN
      PERFORM award_ai_university_badge(
        NEW.user_id, 'quiz_first', '初クイズ正解', '✅', 'クイズ初正解');
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ai_university_auto_badge
  AFTER INSERT OR UPDATE ON ai_university_scores
  FOR EACH ROW EXECUTE FUNCTION trg_auto_award_badges();
