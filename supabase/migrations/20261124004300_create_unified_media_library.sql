-- Batch 107 (#2714): Unified Media Library & Content-Hash Asset Reuse System.
-- Creates private Storage bucket `unified-media-library`, deduplicated parent
-- `media_library_assets`, project-reuse history `media_library_project_usages`,
-- strict owner-scoped RLS/Storage policies, immutable hash guards, and
-- SECURITY INVOKER search & reuse RPCs.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.media_library_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  asset_kind text NOT NULL CHECK (asset_kind IN ('video', 'audio', 'image')),
  mime_type text NOT NULL CHECK (
    mime_type IN (
      'video/mp4',
      'video/webm',
      'audio/mpeg',
      'audio/wav',
      'audio/aac',
      'image/png',
      'image/jpeg',
      'image/webp'
    )
  ),
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 240),
  description text NOT NULL DEFAULT '',
  content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  byte_size bigint NOT NULL CHECK (byte_size > 0 AND byte_size <= 52428800),
  duration_sec integer CHECK (duration_sec IS NULL OR (duration_sec >= 0 AND duration_sec <= 86400)),
  storage_bucket text NOT NULL DEFAULT 'unified-media-library'
    CHECK (storage_bucket = 'unified-media-library'),
  storage_object_path text NOT NULL CHECK (
    char_length(btrim(storage_object_path)) BETWEEN 10 AND 512
    AND storage_object_path LIKE owner_user_id::text || '/%'
  ),
  tags text[] NOT NULL DEFAULT '{}'::text[],
  auto_tags text[] NOT NULL DEFAULT '{}'::text[],
  tagging_model text NOT NULL DEFAULT 'deterministic-fallback' CHECK (
    tagging_model IN ('claude-sonnet-4-6', 'gemini-3.1-pro', 'deterministic-fallback')
  ),
  reuse_count integer NOT NULL DEFAULT 0 CHECK (reuse_count >= 0),
  last_reused_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  search_vector tsvector,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_media_library_assets_owner_sha256 UNIQUE (owner_user_id, content_sha256)
);

CREATE TABLE IF NOT EXISTS public.media_library_project_usages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES public.media_library_assets(id) ON DELETE CASCADE,
  owner_user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  project_key text NOT NULL CHECK (char_length(btrim(project_key)) BETWEEN 1 AND 120),
  project_title text NOT NULL DEFAULT '',
  pipeline_stage text NOT NULL DEFAULT 'video_timeline' CHECK (
    pipeline_stage IN (
      'video_timeline',
      'audio_track',
      'b_roll',
      'thumbnail',
      'voiceover',
      'ad_creative'
    )
  ),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT uq_media_library_usage_asset_project_stage UNIQUE (asset_id, project_key, pipeline_stage)
);

CREATE INDEX IF NOT EXISTS idx_media_library_assets_owner_kind_updated
  ON public.media_library_assets (owner_user_id, asset_kind, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_library_assets_tags_gin
  ON public.media_library_assets USING gin (tags);

CREATE INDEX IF NOT EXISTS idx_media_library_assets_auto_tags_gin
  ON public.media_library_assets USING gin (auto_tags);

CREATE INDEX IF NOT EXISTS idx_media_library_assets_search_vector
  ON public.media_library_assets USING gin (search_vector);

CREATE INDEX IF NOT EXISTS idx_media_library_usages_owner_project
  ON public.media_library_project_usages (owner_user_id, project_key, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_library_usages_asset
  ON public.media_library_project_usages (asset_id, created_at DESC);

ALTER TABLE public.media_library_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_library_project_usages ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.media_library_assets FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.media_library_assets TO authenticated;
GRANT ALL ON TABLE public.media_library_assets TO service_role;

REVOKE ALL ON TABLE public.media_library_project_usages FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.media_library_project_usages TO authenticated;
GRANT ALL ON TABLE public.media_library_project_usages TO service_role;

DROP POLICY IF EXISTS media_library_assets_select_own ON public.media_library_assets;
CREATE POLICY media_library_assets_select_own
  ON public.media_library_assets
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_assets_insert_own ON public.media_library_assets;
CREATE POLICY media_library_assets_insert_own
  ON public.media_library_assets
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_assets_update_own ON public.media_library_assets;
CREATE POLICY media_library_assets_update_own
  ON public.media_library_assets
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id)
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_assets_delete_own ON public.media_library_assets;
CREATE POLICY media_library_assets_delete_own
  ON public.media_library_assets
  FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_usages_select_own ON public.media_library_project_usages;
CREATE POLICY media_library_usages_select_own
  ON public.media_library_project_usages
  FOR SELECT
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_usages_insert_own ON public.media_library_project_usages;
CREATE POLICY media_library_usages_insert_own
  ON public.media_library_project_usages
  FOR INSERT
  TO authenticated
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_usages_update_own ON public.media_library_project_usages;
CREATE POLICY media_library_usages_update_own
  ON public.media_library_project_usages
  FOR UPDATE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id)
  WITH CHECK ((select auth.uid()) = owner_user_id);

DROP POLICY IF EXISTS media_library_usages_delete_own ON public.media_library_project_usages;
CREATE POLICY media_library_usages_delete_own
  ON public.media_library_project_usages
  FOR DELETE
  TO authenticated
  USING ((select auth.uid()) = owner_user_id);

CREATE OR REPLACE FUNCTION public.guard_media_library_asset()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $guard$
DECLARE
  v_claims_raw text := current_setting('request.jwt.claims', true);
  v_claims jsonb := '{}'::jsonb;
  v_jwt_role text;
  v_is_service boolean;
BEGIN
  IF v_claims_raw IS NOT NULL AND length(trim(v_claims_raw)) > 0 THEN
    BEGIN
      v_claims := v_claims_raw::jsonb;
    EXCEPTION
      WHEN OTHERS THEN
        v_claims := '{}'::jsonb;
    END;
  END IF;

  v_jwt_role := coalesce(
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Authentication required for media_library_assets'
        USING ERRCODE = '42501';
    END IF;
    IF TG_OP = 'INSERT' AND NEW.owner_user_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'owner_user_id must match authenticated caller'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' AND (
    NEW.id IS DISTINCT FROM OLD.id
    OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
    OR NEW.content_sha256 IS DISTINCT FROM OLD.content_sha256
    OR NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
    OR NEW.storage_object_path IS DISTINCT FROM OLD.storage_object_path
    OR NEW.byte_size IS DISTINCT FROM OLD.byte_size
    OR NEW.created_at IS DISTINCT FROM OLD.created_at
  ) THEN
    RAISE EXCEPTION 'Immutable media library identity/hash columns cannot be modified'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.created_at := coalesce(NEW.created_at, timezone('utc', now()));
  END IF;
  NEW.updated_at := timezone('utc', now());
  NEW.search_vector :=
    setweight(to_tsvector('simple', coalesce(NEW.title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(NEW.description, '')), 'B') ||
    setweight(
      to_tsvector(
        'simple',
        coalesce(array_to_string(coalesce(NEW.tags, '{}'::text[]) || coalesce(NEW.auto_tags, '{}'::text[]), ' '), '')
      ),
      'C'
    );
  RETURN NEW;
END;
$guard$;

REVOKE ALL ON FUNCTION public.guard_media_library_asset() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_media_library_asset ON public.media_library_assets;
CREATE TRIGGER trg_guard_media_library_asset
  BEFORE INSERT OR UPDATE ON public.media_library_assets
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_media_library_asset();

CREATE OR REPLACE FUNCTION public.guard_media_library_project_usage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $usage_guard$
DECLARE
  v_asset_owner uuid;
  v_claims_raw text := current_setting('request.jwt.claims', true);
  v_claims jsonb := '{}'::jsonb;
  v_jwt_role text;
  v_is_service boolean;
BEGIN
  IF v_claims_raw IS NOT NULL AND length(trim(v_claims_raw)) > 0 THEN
    BEGIN
      v_claims := v_claims_raw::jsonb;
    EXCEPTION
      WHEN OTHERS THEN
        v_claims := '{}'::jsonb;
    END;
  END IF;

  v_jwt_role := coalesce(
    nullif(v_claims ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service := (v_jwt_role = 'service_role')
    OR (
      v_jwt_role = ''
      AND session_user IN ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );

  IF NOT v_is_service AND auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required for media_library_project_usages'
      USING ERRCODE = '42501';
  END IF;

  SELECT owner_user_id INTO v_asset_owner
  FROM public.media_library_assets
  WHERE id = NEW.asset_id;

  IF v_asset_owner IS NULL OR v_asset_owner IS DISTINCT FROM NEW.owner_user_id THEN
    RAISE EXCEPTION 'Media asset ownership mismatch on project reuse record'
      USING ERRCODE = '42501';
  END IF;

  IF NOT v_is_service AND NEW.owner_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Usage owner_user_id must match authenticated caller'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'UPDATE' AND (
    NEW.id IS DISTINCT FROM OLD.id
    OR NEW.asset_id IS DISTINCT FROM OLD.asset_id
    OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id
    OR NEW.created_at IS DISTINCT FROM OLD.created_at
  ) THEN
    RAISE EXCEPTION 'Immutable usage columns cannot be modified'
      USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.created_at := coalesce(NEW.created_at, timezone('utc', now()));
  END IF;
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$usage_guard$;

REVOKE ALL ON FUNCTION public.guard_media_library_project_usage() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_guard_media_library_project_usage ON public.media_library_project_usages;
CREATE TRIGGER trg_guard_media_library_project_usage
  BEFORE INSERT OR UPDATE ON public.media_library_project_usages
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_media_library_project_usage();

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'unified-media-library',
  'unified-media-library',
  false,
  52428800,
  array[
    'video/mp4',
    'video/webm',
    'audio/mpeg',
    'audio/wav',
    'audio/aac',
    'image/png',
    'image/jpeg',
    'image/webp'
  ]::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

DROP POLICY IF EXISTS unified_media_library_select_own ON storage.objects;
CREATE POLICY unified_media_library_select_own
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'unified-media-library'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

DROP POLICY IF EXISTS unified_media_library_insert_own ON storage.objects;
CREATE POLICY unified_media_library_insert_own
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'unified-media-library'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

DROP POLICY IF EXISTS unified_media_library_delete_own ON storage.objects;
CREATE POLICY unified_media_library_delete_own
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'unified-media-library'
    AND (storage.foldername(name))[1] = (select auth.uid())::text
  );

CREATE OR REPLACE FUNCTION public.record_media_asset_reuse(
  p_asset_id uuid,
  p_project_key text,
  p_project_title text DEFAULT '',
  p_pipeline_stage text DEFAULT 'video_timeline',
  p_notes text DEFAULT ''
)
RETURNS public.media_library_project_usages
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, pg_catalog, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_asset_owner uuid;
  v_usage public.media_library_project_usages%rowtype;
  v_total_reuses integer;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required for record_media_asset_reuse'
      USING ERRCODE = '42501';
  END IF;

  SELECT owner_user_id INTO v_asset_owner
  FROM public.media_library_assets
  WHERE id = p_asset_id;

  IF v_asset_owner IS NULL OR v_asset_owner IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'Media asset not found or owned by another user'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.media_library_project_usages (
    asset_id,
    owner_user_id,
    project_key,
    project_title,
    pipeline_stage,
    notes
  )
  VALUES (
    p_asset_id,
    v_caller,
    trim(p_project_key),
    trim(coalesce(p_project_title, '')),
    coalesce(nullif(trim(p_pipeline_stage), ''), 'video_timeline'),
    coalesce(p_notes, '')
  )
  ON CONFLICT (asset_id, project_key, pipeline_stage) DO UPDATE SET
    project_title = CASE
      WHEN length(trim(excluded.project_title)) > 0 THEN excluded.project_title
      ELSE public.media_library_project_usages.project_title
    END,
    notes = CASE
      WHEN length(trim(excluded.notes)) > 0 THEN excluded.notes
      ELSE public.media_library_project_usages.notes
    END,
    updated_at = timezone('utc', now())
  RETURNING * INTO v_usage;

  SELECT count(*)::integer INTO v_total_reuses
  FROM public.media_library_project_usages
  WHERE asset_id = p_asset_id
    AND owner_user_id = v_caller;

  UPDATE public.media_library_assets
  SET
    reuse_count = greatest(reuse_count, v_total_reuses),
    last_reused_at = timezone('utc', now())
  WHERE id = p_asset_id
    AND owner_user_id = v_caller;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Failed to update reuse counter for asset %', p_asset_id
      USING ERRCODE = 'P0002';
  END IF;

  RETURN v_usage;
END;
$$;

REVOKE ALL ON FUNCTION public.record_media_asset_reuse(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_media_asset_reuse(uuid, text, text, text, text) TO authenticated;

COMMENT ON TABLE public.media_library_assets IS
  'Owner-scoped deduplicated unified media assets keyed by (owner_user_id, content_sha256) (#2714).';
COMMENT ON TABLE public.media_library_project_usages IS
  'Multi-project asset reuse lineage for the unified media library (#2714).';
COMMENT ON FUNCTION public.record_media_asset_reuse(uuid, text, text, text, text) IS
  'SECURITY INVOKER idempotent project reuse linker verifying asset ownership (#2714).';
