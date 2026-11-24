-- Batch 61 (#2631): 段階的アーリーアクセス機能とフィードバック収集の構築
-- 非課金（招待・オプトイン限定）のフィーチャーフラグティア（standard / insider / supporter / vip）を管理し、
-- 厳格な RLS と BEFORE INSERT OR UPDATE トリガーによりクライアント側の権限昇格や証跡改ざんを防止する。

CREATE TABLE IF NOT EXISTS public.early_access_feature_flags (
  flag_key text PRIMARY KEY CHECK (
    char_length(trim(flag_key)) BETWEEN 2 AND 80
    AND flag_key ~ '^[a-z][a-z0-9_]*$'
  ),
  title text NOT NULL CHECK (char_length(trim(title)) BETWEEN 1 AND 120),
  description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 500),
  min_tier text NOT NULL DEFAULT 'insider' CHECK (
    min_tier IN ('standard', 'insider', 'supporter', 'vip')
  ),
  is_active boolean NOT NULL DEFAULT true,
  feedback_label text NOT NULL DEFAULT 'early-access' CHECK (
    char_length(trim(feedback_label)) BETWEEN 1 AND 50
  ),
  -- 将来の有料層導入時は別マイグレーション・法的審査を必須とするため DB レベルで非課金を固定する
  monetization_enabled boolean NOT NULL DEFAULT false CHECK (
    monetization_enabled = false
  ),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.early_access_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  access_tier text NOT NULL DEFAULT 'standard' CHECK (
    access_tier IN ('standard', 'insider', 'supporter', 'vip')
  ),
  opted_in_flags text[] NOT NULL DEFAULT ARRAY[]::text[] CHECK (
    coalesce(array_length(opted_in_flags, 1), 0) <= 50
  ),
  notes text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 500),
  granted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  granted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.early_access_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  flag_key text NOT NULL REFERENCES public.early_access_feature_flags(flag_key) ON DELETE RESTRICT,
  access_tier_snapshot text NOT NULL DEFAULT 'standard' CHECK (
    access_tier_snapshot IN ('standard', 'insider', 'supporter', 'vip')
  ),
  category text NOT NULL DEFAULT 'feedback' CHECK (
    category IN ('bug', 'enhancement', 'ux', 'feedback')
  ),
  title text NOT NULL CHECK (char_length(trim(title)) BETWEEN 4 AND 120),
  body text NOT NULL CHECK (char_length(trim(body)) BETWEEN 10 AND 4000),
  status text NOT NULL DEFAULT 'submitted' CHECK (
    status IN ('submitted', 'triaged', 'linked_to_github', 'closed')
  ),
  github_issue_number integer CHECK (
    github_issue_number IS NULL OR github_issue_number > 0
  ),
  github_issue_url text CHECK (
    github_issue_url IS NULL
    OR github_issue_url ~ '^https://github\.com/[^/]+/[^/]+/issues/[0-9]+$'
  ),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_early_access_flags_tier_active
  ON public.early_access_feature_flags (min_tier, is_active);

CREATE INDEX IF NOT EXISTS idx_early_access_enrollments_tier
  ON public.early_access_enrollments (access_tier, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_early_access_feedback_user_created
  ON public.early_access_feedback (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_early_access_feedback_status
  ON public.early_access_feedback (status, created_at DESC);

ALTER TABLE public.early_access_feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.early_access_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.early_access_feedback ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.early_access_feature_flags FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.early_access_feature_flags TO authenticated;
GRANT ALL ON TABLE public.early_access_feature_flags TO service_role;

REVOKE ALL ON TABLE public.early_access_enrollments FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON TABLE public.early_access_enrollments TO authenticated;
GRANT ALL ON TABLE public.early_access_enrollments TO service_role;

REVOKE ALL ON TABLE public.early_access_feedback FROM PUBLIC, anon;
GRANT SELECT, INSERT ON TABLE public.early_access_feedback TO authenticated;
GRANT ALL ON TABLE public.early_access_feedback TO service_role;

-- feature flags policies
DROP POLICY IF EXISTS early_access_flags_authenticated_select
  ON public.early_access_feature_flags;
CREATE POLICY early_access_flags_authenticated_select
  ON public.early_access_feature_flags
  FOR SELECT
  TO authenticated
  USING (
    is_active = true
    OR EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS early_access_flags_admin_insert
  ON public.early_access_feature_flags;
CREATE POLICY early_access_flags_admin_insert
  ON public.early_access_feature_flags
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS early_access_flags_admin_update
  ON public.early_access_feature_flags;
CREATE POLICY early_access_flags_admin_update
  ON public.early_access_feature_flags
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS early_access_flags_admin_delete
  ON public.early_access_feature_flags;
CREATE POLICY early_access_flags_admin_delete
  ON public.early_access_feature_flags
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

-- enrollments policies
DROP POLICY IF EXISTS early_access_enrollments_owner_select
  ON public.early_access_enrollments;
CREATE POLICY early_access_enrollments_owner_select
  ON public.early_access_enrollments
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS early_access_enrollments_admin_select
  ON public.early_access_enrollments;
CREATE POLICY early_access_enrollments_admin_select
  ON public.early_access_enrollments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS early_access_enrollments_owner_insert
  ON public.early_access_enrollments;
CREATE POLICY early_access_enrollments_owner_insert
  ON public.early_access_enrollments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND access_tier = 'standard'
    AND granted_by IS NULL
    AND granted_at IS NULL
  );

DROP POLICY IF EXISTS early_access_enrollments_owner_update
  ON public.early_access_enrollments;
CREATE POLICY early_access_enrollments_owner_update
  ON public.early_access_enrollments
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (access_tier = 'standard' OR granted_at IS NOT NULL)
  );

DROP POLICY IF EXISTS early_access_enrollments_admin_insert
  ON public.early_access_enrollments;
CREATE POLICY early_access_enrollments_admin_insert
  ON public.early_access_enrollments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS early_access_enrollments_admin_update
  ON public.early_access_enrollments;
CREATE POLICY early_access_enrollments_admin_update
  ON public.early_access_enrollments
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

-- feedback policies
DROP POLICY IF EXISTS early_access_feedback_owner_select
  ON public.early_access_feedback;
CREATE POLICY early_access_feedback_owner_select
  ON public.early_access_feedback
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS early_access_feedback_admin_select
  ON public.early_access_feedback;
CREATE POLICY early_access_feedback_admin_select
  ON public.early_access_feedback
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

DROP POLICY IF EXISTS early_access_feedback_owner_insert
  ON public.early_access_feedback;
CREATE POLICY early_access_feedback_owner_insert
  ON public.early_access_feedback
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'submitted'
    AND reviewed_by IS NULL
    AND github_issue_number IS NULL
    AND github_issue_url IS NULL
  );

DROP POLICY IF EXISTS early_access_feedback_admin_update
  ON public.early_access_feedback;
CREATE POLICY early_access_feedback_admin_update
  ON public.early_access_feedback
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );

CREATE OR REPLACE FUNCTION public.guard_early_access_enrollment_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $guard$
DECLARE
  v_jwt_role text;
  v_is_privileged boolean;
  v_is_admin boolean;
  v_existing_tier text;
  v_app_tier text;
  v_effective_rank integer;
  v_flag_key text;
  v_flag_min_tier text;
  v_flag_active boolean;
  v_flag_monetized boolean;
  v_flag_rank integer;
BEGIN
  v_jwt_role := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(auth.role(), ''),
    ''
  );
  v_is_privileged := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  SELECT COALESCE(up.is_admin, false)
    INTO v_is_admin
  FROM public.user_profiles up
  WHERE up.user_id = auth.uid()
  LIMIT 1;
  v_is_admin := COALESCE(v_is_admin, false);

  IF NOT (v_is_privileged OR v_is_admin) THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for early_access_enrollments';
    END IF;

    IF TG_OP = 'INSERT' THEN
      IF NEW.user_id IS DISTINCT FROM auth.uid()
        OR NEW.access_tier <> 'standard'
        OR NEW.granted_by IS NOT NULL
        OR NEW.granted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Only administrators or service_role may assign elevated early_access_enrollments';
      END IF;
    ELSE
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at
        OR NEW.access_tier IS DISTINCT FROM OLD.access_tier
        OR NEW.granted_by IS DISTINCT FROM OLD.granted_by
        OR NEW.granted_at IS DISTINCT FROM OLD.granted_at THEN
        RAISE EXCEPTION 'Only administrators or service_role may alter access_tier or grant metadata';
      END IF;
    END IF;

    -- 認可は常に管理された app_metadata または DB enrollment に限定し、user_metadata は参照しない
    SELECT e.access_tier
      INTO v_existing_tier
    FROM public.early_access_enrollments e
    WHERE e.user_id = auth.uid()
    LIMIT 1;

    v_app_tier := NULLIF(auth.jwt() -> 'app_metadata' ->> 'early_access_tier', '');
    v_effective_rank := GREATEST(
      CASE NEW.access_tier
        WHEN 'vip' THEN 3
        WHEN 'supporter' THEN 2
        WHEN 'insider' THEN 1
        ELSE 0
      END,
      CASE COALESCE(v_existing_tier, 'standard')
        WHEN 'vip' THEN 3
        WHEN 'supporter' THEN 2
        WHEN 'insider' THEN 1
        ELSE 0
      END,
      CASE COALESCE(v_app_tier, 'standard')
        WHEN 'vip' THEN 3
        WHEN 'supporter' THEN 2
        WHEN 'insider' THEN 1
        ELSE 0
      END
    );

    FOREACH v_flag_key IN ARRAY COALESCE(NEW.opted_in_flags, ARRAY[]::text[]) LOOP
      SELECT f.min_tier, f.is_active, f.monetization_enabled
        INTO v_flag_min_tier, v_flag_active, v_flag_monetized
      FROM public.early_access_feature_flags f
      WHERE f.flag_key = v_flag_key;

      IF NOT FOUND OR v_flag_active IS NOT TRUE OR v_flag_monetized IS TRUE THEN
        RAISE EXCEPTION 'Feature flag % is inactive or unavailable for opt-in', v_flag_key;
      END IF;

      v_flag_rank := CASE v_flag_min_tier
        WHEN 'vip' THEN 3
        WHEN 'supporter' THEN 2
        WHEN 'insider' THEN 1
        ELSE 0
      END;
      IF v_effective_rank < v_flag_rank THEN
        RAISE EXCEPTION 'Feature flag % requires higher early access tier %', v_flag_key, v_flag_min_tier;
      END IF;
    END LOOP;
  ELSE
    IF TG_OP = 'UPDATE' THEN
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Immutable columns id, user_id, created_at cannot be modified';
      END IF;
    END IF;

    IF NEW.access_tier <> 'standard' AND NEW.granted_at IS NULL THEN
      NEW.granted_at := now();
    END IF;
    IF v_is_admin AND NEW.access_tier <> 'standard' AND NEW.granted_by IS NULL THEN
      NEW.granted_by := auth.uid();
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_early_access_enrollment_fields
  ON public.early_access_enrollments;
CREATE TRIGGER trg_guard_early_access_enrollment_fields
  BEFORE INSERT OR UPDATE
  ON public.early_access_enrollments
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_early_access_enrollment_fields();

CREATE OR REPLACE FUNCTION public.guard_early_access_feedback_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $guard$
DECLARE
  v_jwt_role text;
  v_is_privileged boolean;
  v_is_admin boolean;
  v_enrollment_tier text;
  v_app_tier text;
  v_verified_rank integer;
  v_snapshot_rank integer;
BEGIN
  v_jwt_role := COALESCE(
    NULLIF(auth.jwt() ->> 'role', ''),
    NULLIF(auth.role(), ''),
    ''
  );
  v_is_privileged := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  SELECT COALESCE(up.is_admin, false)
    INTO v_is_admin
  FROM public.user_profiles up
  WHERE up.user_id = auth.uid()
  LIMIT 1;
  v_is_admin := COALESCE(v_is_admin, false);

  IF NOT (v_is_privileged OR v_is_admin) THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for early_access_feedback';
    END IF;

    IF TG_OP = 'UPDATE' THEN
      RAISE EXCEPTION 'Only administrators or service_role may triage early_access_feedback';
    END IF;

    IF NEW.user_id IS DISTINCT FROM auth.uid()
      OR NEW.status <> 'submitted'
      OR NEW.reviewed_by IS NOT NULL
      OR NEW.github_issue_number IS NOT NULL
      OR NEW.github_issue_url IS NOT NULL THEN
      RAISE EXCEPTION 'Unprivileged users cannot modify triage or GitHub linkage fields';
    END IF;

    SELECT e.access_tier
      INTO v_enrollment_tier
    FROM public.early_access_enrollments e
    WHERE e.user_id = auth.uid()
    LIMIT 1;

    v_app_tier := NULLIF(auth.jwt() -> 'app_metadata' ->> 'early_access_tier', '');
    v_verified_rank := GREATEST(
      CASE COALESCE(v_enrollment_tier, 'standard')
        WHEN 'vip' THEN 3
        WHEN 'supporter' THEN 2
        WHEN 'insider' THEN 1
        ELSE 0
      END,
      CASE COALESCE(v_app_tier, 'standard')
        WHEN 'vip' THEN 3
        WHEN 'supporter' THEN 2
        WHEN 'insider' THEN 1
        ELSE 0
      END
    );
    v_snapshot_rank := CASE NEW.access_tier_snapshot
      WHEN 'vip' THEN 3
      WHEN 'supporter' THEN 2
      WHEN 'insider' THEN 1
      ELSE 0
    END;
    IF v_snapshot_rank > v_verified_rank THEN
      RAISE EXCEPTION 'access_tier_snapshot exceeds verified early access tier';
    END IF;
  ELSE
    IF TG_OP = 'UPDATE' THEN
      IF NEW.id IS DISTINCT FROM OLD.id
        OR NEW.user_id IS DISTINCT FROM OLD.user_id
        OR NEW.flag_key IS DISTINCT FROM OLD.flag_key
        OR NEW.access_tier_snapshot IS DISTINCT FROM OLD.access_tier_snapshot
        OR NEW.category IS DISTINCT FROM OLD.category
        OR NEW.title IS DISTINCT FROM OLD.title
        OR NEW.body IS DISTINCT FROM OLD.body
        OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Feedback submission payload and author are immutable during triage';
      END IF;

      IF v_is_admin AND NEW.reviewed_by IS NULL AND NEW.status <> OLD.status THEN
        NEW.reviewed_by := auth.uid();
      END IF;
      NEW.updated_at := now();
    END IF;
  END IF;

  RETURN NEW;
END;
$guard$;

DROP TRIGGER IF EXISTS trg_guard_early_access_feedback_fields
  ON public.early_access_feedback;
CREATE TRIGGER trg_guard_early_access_feedback_fields
  BEFORE INSERT OR UPDATE
  ON public.early_access_feedback
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_early_access_feedback_fields();

INSERT INTO public.early_access_feature_flags (
  flag_key,
  title,
  description,
  min_tier,
  is_active,
  feedback_label,
  monetization_enabled
)
VALUES
  (
    'offline_vault_prefetch',
    'オフライン要約キャッシュ (一般先行)',
    '直近閲覧したノートの要約インデックスを端末内キャッシュへプリフェッチする標準先行フラグです。',
    'standard',
    true,
    'early-access-standard',
    false
  ),
  (
    'ai_voice_macro_v2',
    '音声コマンド・マクロ v2 (Insider)',
    '音声メモ入力から日次タスク候補と要約を連続生成する Insider 向け先行実験機能です。',
    'insider',
    true,
    'early-access-insider',
    false
  ),
  (
    'knowledge_graph_3d_preview',
    'ナレッジグラフ空間プレビュー (Supporter)',
    'ノートの関連性とタグクラスタを立体的に俯瞰する Supporter 向けプレビュー機能です。',
    'supporter',
    true,
    'early-access-supporter',
    false
  ),
  (
    'multi_agent_sprint_board',
    '自律エージェント進捗ライブボード (VIP)',
    '複数エージェントの並列タスク進捗とボトルネックをリアルタイム監視する VIP 向け先行画面です。',
    'vip',
    true,
    'early-access-vip',
    false
  )
ON CONFLICT (flag_key) DO NOTHING;
