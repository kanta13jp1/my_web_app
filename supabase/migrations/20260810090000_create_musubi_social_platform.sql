-- MUSUBI production data plane: realtime feed, private DM, search,
-- moderation audit trail, and consent-based user research.

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
SET search_path = public, extensions;

CREATE TABLE public.musubi_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 80),
  handle text NOT NULL UNIQUE CHECK (handle ~ '^[A-Za-z0-9_]{3,32}$'),
  avatar_label text NOT NULL DEFAULT '結' CHECK (char_length(avatar_label) BETWEEN 1 AND 8),
  bio text NOT NULL DEFAULT '' CHECK (char_length(bio) <= 300),
  verified_human boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.musubi_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL
    CONSTRAINT musubi_posts_author_id_fkey
    REFERENCES public.musubi_profiles(user_id) ON DELETE CASCADE,
  content text NOT NULL CHECK (char_length(btrim(content)) BETWEEN 1 AND 5000),
  audience text NOT NULL DEFAULT 'public'
    CHECK (audience IN ('public', 'circles', 'local')),
  moderation_status text NOT NULL DEFAULT 'published'
    CHECK (moderation_status IN ('published', 'review', 'hidden', 'removed')),
  ai_assisted boolean NOT NULL DEFAULT false,
  language_label text NOT NULL DEFAULT '日本語',
  source_title text,
  context_note text,
  tags text[] NOT NULL DEFAULT '{}',
  reaction_count integer NOT NULL DEFAULT 0 CHECK (reaction_count >= 0),
  reply_count integer NOT NULL DEFAULT 0 CHECK (reply_count >= 0),
  boost_count integer NOT NULL DEFAULT 0 CHECK (boost_count >= 0),
  resonance integer NOT NULL DEFAULT 80 CHECK (resonance BETWEEN 0 AND 100),
  search_vector tsvector NOT NULL DEFAULT ''::tsvector,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.musubi_refresh_post_search_vector()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.search_vector := to_tsvector(
    'simple',
    coalesce(NEW.content, '') || ' ' ||
    coalesce(NEW.source_title, '') || ' ' ||
    array_to_string(NEW.tags, ' ')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER musubi_posts_refresh_search_vector
BEFORE INSERT OR UPDATE OF content, source_title, tags ON public.musubi_posts
FOR EACH ROW EXECUTE FUNCTION public.musubi_refresh_post_search_vector();

CREATE INDEX musubi_posts_public_created_idx
  ON public.musubi_posts (created_at DESC)
  WHERE moderation_status = 'published' AND audience = 'public';
CREATE INDEX musubi_posts_author_created_idx
  ON public.musubi_posts (author_id, created_at DESC);
CREATE INDEX musubi_posts_search_idx
  ON public.musubi_posts USING gin (search_vector);
CREATE INDEX musubi_posts_content_trgm_idx
  ON public.musubi_posts USING gin (content gin_trgm_ops);

CREATE TABLE public.musubi_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id uuid NOT NULL REFERENCES public.musubi_profiles(user_id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '' CHECK (char_length(title) <= 120),
  is_group boolean NOT NULL DEFAULT false,
  direct_key text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.musubi_thread_members (
  thread_id uuid NOT NULL REFERENCES public.musubi_threads(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.musubi_profiles(user_id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'moderator', 'member')),
  last_read_at timestamptz NOT NULL DEFAULT now(),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (thread_id, user_id)
);

CREATE INDEX musubi_thread_members_user_idx
  ON public.musubi_thread_members (user_id, joined_at DESC);

CREATE TABLE public.musubi_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.musubi_threads(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.musubi_profiles(user_id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(btrim(body)) BETWEEN 1 AND 5000),
  moderation_status text NOT NULL DEFAULT 'published'
    CHECK (moderation_status IN ('published', 'review', 'hidden', 'removed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  edited_at timestamptz
);

CREATE INDEX musubi_messages_thread_created_idx
  ON public.musubi_messages (thread_id, created_at);

CREATE TABLE public.musubi_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.musubi_profiles(user_id) ON DELETE CASCADE,
  target_post_id uuid NOT NULL
    CONSTRAINT musubi_reports_target_post_id_fkey
    REFERENCES public.musubi_posts(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (
    reason IN ('harassment', 'hate', 'misinformation', 'impersonation', 'spam', 'selfHarm', 'other')
  ),
  details text NOT NULL DEFAULT '' CHECK (char_length(details) <= 2000),
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'reviewing', 'resolved', 'dismissed')),
  resolution_note text NOT NULL DEFAULT '',
  resolved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reporter_id, target_post_id, reason)
);

CREATE INDEX musubi_reports_queue_idx
  ON public.musubi_reports (status, created_at)
  WHERE status IN ('open', 'reviewing');

CREATE TABLE public.musubi_research_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  cohort text NOT NULL DEFAULT 'mvp-1' CHECK (char_length(cohort) <= 40),
  fatigue_score smallint NOT NULL CHECK (fatigue_score BETWEEN 1 AND 5),
  trust_score smallint NOT NULL CHECK (trust_score BETWEEN 1 AND 5),
  belonging_score smallint NOT NULL CHECK (belonging_score BETWEEN 1 AND 5),
  comment text NOT NULL DEFAULT '' CHECK (char_length(comment) <= 2000),
  consent_to_research boolean NOT NULL CHECK (consent_to_research),
  consented_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX musubi_research_feedback_cohort_idx
  ON public.musubi_research_feedback (cohort, created_at DESC);

CREATE TABLE public.musubi_research_events (
  id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_name text NOT NULL CHECK (event_name ~ '^[a-z0-9_.-]{2,80}$'),
  properties jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX musubi_research_events_user_created_idx
  ON public.musubi_research_events (user_id, created_at DESC);
CREATE INDEX musubi_research_events_name_created_idx
  ON public.musubi_research_events (event_name, created_at DESC);

CREATE OR REPLACE FUNCTION public.is_musubi_thread_member(
  target_thread_id uuid,
  actor_id uuid DEFAULT auth.uid()
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.musubi_thread_members member
    WHERE member.thread_id = target_thread_id
      AND member.user_id = actor_id
  );
$$;

CREATE OR REPLACE FUNCTION public.musubi_touch_thread()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  UPDATE musubi_threads
  SET updated_at = now()
  WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER musubi_messages_touch_thread
AFTER INSERT ON public.musubi_messages
FOR EACH ROW EXECUTE FUNCTION public.musubi_touch_thread();

CREATE OR REPLACE FUNCTION public.musubi_start_direct_thread(recipient_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_id uuid := auth.uid();
  normalized_key text;
  target_thread_id uuid;
BEGIN
  IF actor_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF actor_id = recipient_id THEN
    RAISE EXCEPTION 'Cannot create a direct thread with yourself';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.musubi_profiles WHERE user_id = recipient_id) THEN
    RAISE EXCEPTION 'Recipient is not available on MUSUBI';
  END IF;

  normalized_key := least(actor_id::text, recipient_id::text) || ':' ||
    greatest(actor_id::text, recipient_id::text);

  INSERT INTO public.musubi_threads (creator_id, direct_key)
  VALUES (actor_id, normalized_key)
  ON CONFLICT (direct_key) DO UPDATE SET updated_at = public.musubi_threads.updated_at
  RETURNING id INTO target_thread_id;

  INSERT INTO public.musubi_thread_members (thread_id, user_id, role)
  VALUES
    (target_thread_id, actor_id, 'owner'),
    (target_thread_id, recipient_id, 'member')
  ON CONFLICT (thread_id, user_id) DO NOTHING;

  RETURN target_thread_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.musubi_list_threads()
RETURNS TABLE (
  thread_id uuid,
  participant_id uuid,
  display_name text,
  handle text,
  avatar_label text,
  last_message text,
  unread_count bigint,
  is_online boolean,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    thread.id,
    other_member.user_id,
    profile.display_name,
    profile.handle,
    profile.avatar_label,
    coalesce(last_message.body, ''),
    (
      SELECT count(*)
      FROM public.musubi_messages unread
      WHERE unread.thread_id = thread.id
        AND unread.sender_id <> auth.uid()
        AND unread.created_at > self_member.last_read_at
    ),
    false,
    thread.updated_at
  FROM public.musubi_threads thread
  JOIN public.musubi_thread_members self_member
    ON self_member.thread_id = thread.id AND self_member.user_id = auth.uid()
  JOIN LATERAL (
    SELECT member.user_id
    FROM public.musubi_thread_members member
    WHERE member.thread_id = thread.id AND member.user_id <> auth.uid()
    ORDER BY member.joined_at
    LIMIT 1
  ) other_member ON true
  JOIN public.musubi_profiles profile ON profile.user_id = other_member.user_id
  LEFT JOIN LATERAL (
    SELECT message.body
    FROM public.musubi_messages message
    WHERE message.thread_id = thread.id
      AND message.moderation_status = 'published'
    ORDER BY message.created_at DESC
    LIMIT 1
  ) last_message ON true
  ORDER BY thread.updated_at DESC;
$$;

CREATE OR REPLACE FUNCTION public.search_musubi(
  search_query text,
  result_limit integer DEFAULT 30
) RETURNS TABLE (
  id text,
  kind text,
  title text,
  subtitle text,
  highlight text,
  author_id uuid,
  post_id uuid
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
  WITH normalized AS (
    SELECT nullif(btrim(search_query), '') AS query
  ), results AS (
    SELECT
      post.id::text AS id,
      'post'::text AS kind,
      left(post.content, 100) AS title,
      '@' || profile.handle || ' ・ ' || profile.display_name AS subtitle,
      left(post.content, 240) AS highlight,
      post.author_id,
      post.id AS post_id,
      CASE
        WHEN normalized.query IS NULL THEN 0::real
        ELSE ts_rank(post.search_vector, websearch_to_tsquery('simple', normalized.query))
      END AS rank_score,
      post.created_at
    FROM public.musubi_posts post
    JOIN public.musubi_profiles profile ON profile.user_id = post.author_id
    CROSS JOIN normalized
    WHERE post.audience = 'public'
      AND post.moderation_status = 'published'
      AND (
        normalized.query IS NULL
        OR post.search_vector @@ websearch_to_tsquery('simple', normalized.query)
        OR post.content ILIKE '%' || normalized.query || '%'
        OR profile.display_name ILIKE '%' || normalized.query || '%'
        OR profile.handle ILIKE '%' || normalized.query || '%'
      )
    UNION ALL
    SELECT
      profile.user_id::text,
      'person'::text,
      profile.display_name,
      '@' || profile.handle,
      left(profile.bio, 240),
      profile.user_id,
      NULL::uuid,
      0::real,
      profile.created_at
    FROM public.musubi_profiles profile
    CROSS JOIN normalized
    WHERE normalized.query IS NOT NULL
      AND (
        profile.display_name ILIKE '%' || normalized.query || '%'
        OR profile.handle ILIKE '%' || normalized.query || '%'
        OR profile.bio ILIKE '%' || normalized.query || '%'
      )
  )
  SELECT results.id, results.kind, results.title, results.subtitle,
    results.highlight, results.author_id, results.post_id
  FROM results
  ORDER BY results.rank_score DESC, results.created_at DESC
  LIMIT greatest(1, least(result_limit, 100));
$$;

ALTER TABLE public.musubi_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_thread_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_research_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.musubi_research_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY musubi_profiles_read ON public.musubi_profiles
  FOR SELECT TO authenticated USING (true);
CREATE POLICY musubi_profiles_insert_own ON public.musubi_profiles
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY musubi_profiles_update_own ON public.musubi_profiles
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY musubi_posts_read ON public.musubi_posts
  FOR SELECT TO authenticated USING (
    author_id = auth.uid()
    OR (audience = 'public' AND moderation_status = 'published')
  );
CREATE POLICY musubi_posts_insert_own ON public.musubi_posts
  FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());
CREATE POLICY musubi_posts_update_own ON public.musubi_posts
  FOR UPDATE TO authenticated USING (author_id = auth.uid()) WITH CHECK (author_id = auth.uid());
CREATE POLICY musubi_posts_delete_own ON public.musubi_posts
  FOR DELETE TO authenticated USING (author_id = auth.uid());

CREATE POLICY musubi_threads_read_member ON public.musubi_threads
  FOR SELECT TO authenticated USING (public.is_musubi_thread_member(id));
CREATE POLICY musubi_threads_insert_creator ON public.musubi_threads
  FOR INSERT TO authenticated WITH CHECK (creator_id = auth.uid());
CREATE POLICY musubi_threads_update_member ON public.musubi_threads
  FOR UPDATE TO authenticated USING (public.is_musubi_thread_member(id));

CREATE POLICY musubi_thread_members_read_member ON public.musubi_thread_members
  FOR SELECT TO authenticated USING (public.is_musubi_thread_member(thread_id));
CREATE POLICY musubi_thread_members_insert_creator ON public.musubi_thread_members
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.musubi_threads thread
      WHERE thread.id = thread_id AND thread.creator_id = auth.uid()
    )
  );
CREATE POLICY musubi_thread_members_update_self ON public.musubi_thread_members
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY musubi_thread_members_delete_self ON public.musubi_thread_members
  FOR DELETE TO authenticated USING (user_id = auth.uid());

CREATE POLICY musubi_messages_read_member ON public.musubi_messages
  FOR SELECT TO authenticated USING (public.is_musubi_thread_member(thread_id));
CREATE POLICY musubi_messages_insert_member ON public.musubi_messages
  FOR INSERT TO authenticated WITH CHECK (
    sender_id = auth.uid() AND public.is_musubi_thread_member(thread_id)
  );
CREATE POLICY musubi_messages_update_sender ON public.musubi_messages
  FOR UPDATE TO authenticated USING (sender_id = auth.uid()) WITH CHECK (sender_id = auth.uid());

CREATE POLICY musubi_reports_insert_own ON public.musubi_reports
  FOR INSERT TO authenticated WITH CHECK (reporter_id = auth.uid());
CREATE POLICY musubi_reports_read_own_or_admin ON public.musubi_reports
  FOR SELECT TO authenticated USING (
    reporter_id = auth.uid() OR public.is_user_admin(auth.uid())
  );
CREATE POLICY musubi_reports_update_admin ON public.musubi_reports
  FOR UPDATE TO authenticated USING (public.is_user_admin(auth.uid()))
  WITH CHECK (public.is_user_admin(auth.uid()));

CREATE POLICY musubi_feedback_insert_own ON public.musubi_research_feedback
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid() AND consent_to_research
  );
CREATE POLICY musubi_feedback_read_own_or_admin ON public.musubi_research_feedback
  FOR SELECT TO authenticated USING (
    user_id = auth.uid() OR public.is_user_admin(auth.uid())
  );
CREATE POLICY musubi_feedback_delete_own ON public.musubi_research_feedback
  FOR DELETE TO authenticated USING (user_id = auth.uid());

CREATE POLICY musubi_events_insert_own ON public.musubi_research_events
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY musubi_events_read_own_or_admin ON public.musubi_research_events
  FOR SELECT TO authenticated USING (
    user_id = auth.uid() OR public.is_user_admin(auth.uid())
  );

GRANT EXECUTE ON FUNCTION public.search_musubi(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.musubi_start_direct_thread(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.musubi_list_threads() TO authenticated;

ALTER TABLE public.musubi_posts REPLICA IDENTITY FULL;
ALTER TABLE public.musubi_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.musubi_posts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.musubi_messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON TABLE public.musubi_reports IS
  'MUSUBI moderation audit trail. Resolution is restricted to existing app admins.';
COMMENT ON TABLE public.musubi_research_feedback IS
  'Consent-gated UX validation responses. Users may delete their own responses.';

RESET search_path;
