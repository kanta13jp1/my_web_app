-- Extend user_profiles with private lifestyle/context fields used by
-- AI asset management advice.

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS gender text,
  ADD COLUMN IF NOT EXISTS occupation text,
  ADD COLUMN IF NOT EXISTS annual_income numeric,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS education text,
  ADD COLUMN IF NOT EXISTS career_history text,
  ADD COLUMN IF NOT EXISTS hobbies text,
  ADD COLUMN IF NOT EXISTS alcohol_use text,
  ADD COLUMN IF NOT EXISTS smoking_use text,
  ADD COLUMN IF NOT EXISTS favorite_foods text;

COMMENT ON COLUMN user_profiles.gender IS '性別。AI資産管理アシスタントの個別事情分析に使用。';
COMMENT ON COLUMN user_profiles.occupation IS '職業。収入安定性や働き方の助言に使用。';
COMMENT ON COLUMN user_profiles.annual_income IS '年収。返済余力や生活設計の助言に使用。';
COMMENT ON COLUMN user_profiles.address IS '住所・居住地域。生活費や地域事情の助言に使用。';
COMMENT ON COLUMN user_profiles.education IS '学歴。仕事・収入改善の助言に使用。';
COMMENT ON COLUMN user_profiles.career_history IS '職歴。仕事・収入改善の助言に使用。';
COMMENT ON COLUMN user_profiles.hobbies IS '趣味。浪費傾向や生活満足度の助言に使用。';
COMMENT ON COLUMN user_profiles.alcohol_use IS '飲酒の有無・頻度。生活費と健康支出の助言に使用。';
COMMENT ON COLUMN user_profiles.smoking_use IS '喫煙の有無・頻度。生活費と健康支出の助言に使用。';
COMMENT ON COLUMN user_profiles.favorite_foods IS '好きな食べ物。食費節約と満足度の助言に使用。';

CREATE OR REPLACE FUNCTION calculate_profile_completeness(p user_profiles)
RETURNS INT AS $$
DECLARE
  score INT := 0;
BEGIN
  IF p.display_name IS NOT NULL AND length(p.display_name) > 0 THEN score := score + 10; END IF;
  IF p.bio IS NOT NULL AND length(p.bio) > 0 THEN score := score + 8; END IF;
  IF p.avatar_url IS NOT NULL AND length(p.avatar_url) > 0 THEN score := score + 8; END IF;
  IF p.birth_date IS NOT NULL THEN score := score + 8; END IF;
  IF p.gender IS NOT NULL AND length(p.gender) > 0 THEN score := score + 6; END IF;
  IF p.occupation IS NOT NULL AND length(p.occupation) > 0 THEN score := score + 10; END IF;
  IF p.annual_income IS NOT NULL THEN score := score + 10; END IF;
  IF p.address IS NOT NULL AND length(p.address) > 0 THEN score := score + 6; END IF;
  IF p.education IS NOT NULL AND length(p.education) > 0 THEN score := score + 6; END IF;
  IF p.career_history IS NOT NULL AND length(p.career_history) > 0 THEN score := score + 10; END IF;
  IF p.hobbies IS NOT NULL AND length(p.hobbies) > 0 THEN score := score + 6; END IF;
  IF p.alcohol_use IS NOT NULL AND length(p.alcohol_use) > 0 THEN score := score + 4; END IF;
  IF p.smoking_use IS NOT NULL AND length(p.smoking_use) > 0 THEN score := score + 4; END IF;
  IF p.favorite_foods IS NOT NULL AND length(p.favorite_foods) > 0 THEN score := score + 4; END IF;
  RETURN LEAST(score, 100);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
