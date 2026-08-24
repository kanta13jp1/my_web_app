-- Closed-loop review pipeline for explicitly exported/local AI-assisted artifacts.
--
-- This migration deliberately does not create products, Stripe Prices, Storage
-- objects, or active listings. It records preparation and review evidence. The
-- existing shop checkout/download paths remain the only buyer-facing paths.

create schema if not exists private;

create table public.artifact_candidates (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 1 and 200),
  artifact_sha256 text not null unique
    check (artifact_sha256 ~ '^[0-9a-f]{64}$'),
  mime_type text not null
    check (char_length(btrim(mime_type)) between 1 and 255),
  file_size_bytes bigint not null check (file_size_bytes > 0),
  artifact_kind text not null check (artifact_kind in (
    'image', 'audio', 'video', 'design', 'writing',
    'prompt', 'idea', 'game', 'template', 'bundle'
  )),
  stage text not null default 'intake' check (stage in (
    'intake', 'automated_checks', 'human_review', 'approved',
    'staged', 'ready', 'published', 'rejected'
  )),
  intended_price_jpy integer check (intended_price_jpy >= 50),
  product_id text references public.shop_products(id) on delete restrict,
  proposed_storage_bucket text,
  proposed_storage_path text,
  human_contribution_summary text,
  rejection_reason text,
  created_by uuid not null references auth.users(id) on delete restrict
    default auth.uid(),
  approved_by uuid references auth.users(id) on delete restrict,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint artifact_candidates_product_stage_check check (
    stage in ('intake', 'automated_checks', 'human_review', 'approved', 'rejected')
    or product_id is not null
  ),
  constraint artifact_candidates_storage_pair_check check (
    (proposed_storage_bucket is null) = (proposed_storage_path is null)
  ),
  constraint artifact_candidates_private_bucket_check check (
    proposed_storage_bucket is null
    or proposed_storage_bucket = 'product-downloads'
  ),
  constraint artifact_candidates_storage_path_check check (
    proposed_storage_path is null
    or (
      char_length(btrim(proposed_storage_path)) between 1 and 1024
      and proposed_storage_path = btrim(proposed_storage_path)
      and proposed_storage_path !~ '(^|/)\.\.(/|$)'
      and proposed_storage_path !~ '[[:cntrl:]]'
    )
  ),
  constraint artifact_candidates_human_contribution_check check (
    human_contribution_summary is null
    or char_length(btrim(human_contribution_summary)) between 20 and 4000
  ),
  constraint artifact_candidates_rejection_reason_check check (
    rejection_reason is null
    or char_length(btrim(rejection_reason)) between 10 and 2000
  ),
  constraint artifact_candidates_approval_pair_check check (
    (approved_by is null) = (approved_at is null)
  )
);

create table public.artifact_provenance (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.artifact_candidates(id)
    on delete cascade,
  source_tool text not null check (source_tool in (
    'chatgpt', 'codex', 'claude_code', 'antigravity', 'other_explicit_export'
  )),
  intake_method text not null check (intake_method in (
    'explicit_export', 'local_workspace'
  )),
  source_locator text not null
    check (char_length(btrim(source_locator)) between 1 and 1024),
  tool_version text,
  exported_at timestamptz,
  contribution_role text not null default 'intermediate_artifact'
    check (contribution_role in (
      'intermediate_artifact', 'reference', 'human_revision', 'final_assembly'
    )),
  recorded_by uuid not null references auth.users(id) on delete restrict
    default auth.uid(),
  created_at timestamptz not null default now(),
  unique (candidate_id, source_tool, source_locator),
  constraint artifact_provenance_intake_boundary_check check (
    source_tool <> 'chatgpt' or intake_method = 'explicit_export'
  )
);

create table public.artifact_checks (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.artifact_candidates(id)
    on delete cascade,
  check_key text not null check (check_key in (
    'secret_scan', 'pii_scan', 'third_party_license',
    'face_voice_consent', 'chatgpt_voice_output', 'human_contribution',
    'price_match', 'private_object', 'content_integrity'
  )),
  check_kind text not null check (check_kind in (
    'automated', 'human', 'external_evidence'
  )),
  is_hard_gate boolean not null default true check (is_hard_gate),
  status text not null default 'pending' check (status in (
    'pending', 'pass', 'fail', 'not_applicable'
  )),
  evidence_summary text,
  reviewed_by uuid references auth.users(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (candidate_id, check_key),
  constraint artifact_checks_evidence_length_check check (
    evidence_summary is null
    or char_length(btrim(evidence_summary)) between 3 and 4000
  ),
  constraint artifact_checks_review_pair_check check (
    (reviewed_by is null) = (reviewed_at is null)
  ),
  constraint artifact_checks_decision_evidence_check check (
    status = 'pending'
    or (
      evidence_summary is not null
      and reviewed_by is not null
      and reviewed_at is not null
    )
  ),
  constraint artifact_checks_contextual_na_check check (
    status <> 'not_applicable'
    or check_key in (
      'third_party_license', 'face_voice_consent', 'chatgpt_voice_output'
    )
  )
);

create table public.artifact_publication_runs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.artifact_candidates(id)
    on delete restrict,
  product_id text references public.shop_products(id) on delete restrict,
  target text not null default 'staging' check (target in ('staging', 'production')),
  dry_run boolean not null default true,
  status text not null default 'planned' check (status in (
    'planned', 'running', 'succeeded', 'failed', 'canceled', 'rolled_back'
  )),
  authorization_reference text,
  validation_summary text,
  error_summary text,
  initiated_by uuid not null references auth.users(id) on delete restrict
    default auth.uid(),
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint artifact_publication_runs_live_auth_check check (
    dry_run
    or (
      authorization_reference is not null
      and char_length(btrim(authorization_reference)) between 8 and 500
    )
  ),
  constraint artifact_publication_runs_time_check check (
    finished_at is null or started_at is not null
  )
);

create table public.artifact_publication_events (
  id bigint generated always as identity primary key,
  candidate_id uuid not null references public.artifact_candidates(id)
    on delete restrict,
  run_id uuid references public.artifact_publication_runs(id) on delete restrict,
  product_id text references public.shop_products(id) on delete restrict,
  event_type text not null check (event_type in (
    'candidate_created', 'stage_transition', 'check_updated',
    'product_activated', 'product_deactivated', 'run_status_changed'
  )),
  from_value text,
  to_value text,
  details jsonb not null default '{}'::jsonb
    check (jsonb_typeof(details) = 'object'),
  actor_id uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now()
);

comment on table public.artifact_candidates is
  'Admin-only intermediate artifacts moving through human-gated product review.';
comment on column public.artifact_candidates.artifact_sha256 is
  'Content-derived deduplication key produced by the local intake helper.';
comment on table public.artifact_provenance is
  'Admin-only source boundary records. ChatGPT accepts explicit exports only.';
comment on table public.artifact_checks is
  'Hard publication gates. not_applicable is limited to contextual checks.';
comment on table public.artifact_publication_runs is
  'Dry-run/staging/authorized publication attempt records; never a billing command.';
comment on table public.artifact_publication_events is
  'Append-only audit events emitted by database triggers.';

create index artifact_candidates_product_id_idx
  on public.artifact_candidates (product_id)
  where product_id is not null;
create index artifact_candidates_created_by_idx
  on public.artifact_candidates (created_by);
create index artifact_candidates_approved_by_idx
  on public.artifact_candidates (approved_by)
  where approved_by is not null;
create index artifact_candidates_review_queue_idx
  on public.artifact_candidates (stage, updated_at, id)
  where stage not in ('published', 'rejected');
create index artifact_provenance_candidate_id_idx
  on public.artifact_provenance (candidate_id);
create index artifact_provenance_recorded_by_idx
  on public.artifact_provenance (recorded_by);
create index artifact_checks_candidate_status_idx
  on public.artifact_checks (candidate_id, status, check_key);
create index artifact_checks_reviewed_by_idx
  on public.artifact_checks (reviewed_by)
  where reviewed_by is not null;
create index artifact_publication_runs_candidate_id_idx
  on public.artifact_publication_runs (candidate_id, created_at desc);
create index artifact_publication_runs_product_id_idx
  on public.artifact_publication_runs (product_id)
  where product_id is not null;
create index artifact_publication_runs_initiated_by_idx
  on public.artifact_publication_runs (initiated_by);
create index artifact_publication_runs_active_idx
  on public.artifact_publication_runs (created_at, id)
  where status in ('planned', 'running');
create index artifact_publication_events_candidate_id_idx
  on public.artifact_publication_events (candidate_id, occurred_at desc, id desc);
create index artifact_publication_events_run_id_idx
  on public.artifact_publication_events (run_id)
  where run_id is not null;
create index artifact_publication_events_product_id_idx
  on public.artifact_publication_events (product_id)
  where product_id is not null;
create index artifact_publication_events_actor_id_idx
  on public.artifact_publication_events (actor_id)
  where actor_id is not null;

-- Atomic metadata-only intake. It stores no file body or matched secret/PII
-- value and cannot move the candidate beyond intake. SECURITY INVOKER keeps
-- the admin RLS checks in force.
create or replace function public.intake_artifact_candidate(
  intake_title text,
  intake_sha256 text,
  intake_mime_type text,
  intake_file_size_bytes bigint,
  intake_artifact_kind text,
  intake_source_tool text,
  intake_source_method text,
  intake_source_locator text,
  intake_human_contribution_summary text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  candidate_id uuid;
begin
  if actor is null or not public.is_user_admin(actor) then
    raise exception 'artifact_intake_admin_required' using errcode = '42501';
  end if;

  insert into public.artifact_candidates (
    title, artifact_sha256, mime_type, file_size_bytes, artifact_kind,
    human_contribution_summary, created_by
  ) values (
    intake_title, intake_sha256, intake_mime_type, intake_file_size_bytes,
    intake_artifact_kind, intake_human_contribution_summary, actor
  )
  on conflict (artifact_sha256) do update
    set updated_at = public.artifact_candidates.updated_at
  returning id into candidate_id;

  insert into public.artifact_provenance (
    candidate_id, source_tool, intake_method, source_locator, recorded_by
  ) values (
    candidate_id, intake_source_tool, intake_source_method,
    intake_source_locator, actor
  )
  on conflict (candidate_id, source_tool, source_locator) do nothing;

  return candidate_id;
end;
$$;

create or replace function private.artifact_trigger_actor_authorized()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select
    (
      auth.uid() is not null
      and public.is_user_admin(auth.uid())
    )
    or coalesce(auth.jwt() ->> 'role', '') = 'service_role'
    or session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
$$;

-- Storage metadata is private by design, so this trigger-only helper is the
-- narrow privileged lookup used to prove that the referenced object exists.
create or replace function private.artifact_private_object_exists(
  check_bucket text,
  check_path text,
  check_size_bytes bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    private.artifact_trigger_actor_authorized()
    and exists (
      select 1
      from storage.objects as object
      where object.bucket_id = check_bucket
        and object.name = check_path
        and object.metadata ->> 'size' ~ '^[0-9]+$'
        and (object.metadata ->> 'size')::bigint = check_size_bytes
    )
$$;

-- This helper is not exposed through the Data API. It is used by trigger code
-- to evaluate the full set of hard gates under the caller's privileges.
create or replace function private.artifact_candidate_hard_gates_pass(
  check_candidate_id uuid
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select
    count(*) = 9
    and bool_and(
      case
        when checks.check_key in (
          'third_party_license', 'face_voice_consent', 'chatgpt_voice_output'
        ) then checks.status in ('pass', 'not_applicable')
        else checks.status = 'pass'
      end
    )
  from public.artifact_checks as checks
  where checks.candidate_id = check_candidate_id
    and checks.is_hard_gate
$$;

create or replace function private.artifact_candidate_matches_product(
  check_candidate_id uuid,
  check_product_id text,
  allowed_stages text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.artifact_trigger_actor_authorized() and exists (
    select 1
    from public.artifact_candidates as candidate
    join public.shop_products as product on product.id = candidate.product_id
    join storage.buckets as bucket on bucket.id = product.storage_bucket
    where candidate.id = check_candidate_id
      and candidate.product_id = check_product_id
      and candidate.stage = any (allowed_stages)
      and candidate.approved_by is not null
      and candidate.approved_at is not null
      and candidate.intended_price_jpy = product.price_jpy
      and product.stripe_price_id is not null
      and btrim(product.stripe_price_id) <> ''
      and candidate.proposed_storage_bucket = product.storage_bucket
      and candidate.proposed_storage_path = product.storage_path
      and product.storage_bucket = 'product-downloads'
      and not bucket.public
      and private.artifact_private_object_exists(
        product.storage_bucket, product.storage_path, candidate.file_size_bytes
      )
      and product.sha256 = candidate.artifact_sha256
      and product.file_size_bytes = candidate.file_size_bytes
      and private.artifact_candidate_hard_gates_pass(candidate.id)
  )
$$;

-- Direct table updates remain RLS-controlled. This trigger is the state
-- machine: it prevents skipped stages and derives approval identity from the
-- authenticated caller rather than accepting a client-supplied reviewer.
create or replace function private.guard_artifact_candidate_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  allowed boolean := false;
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'artifact_transition_actor_not_authorized'
      using errcode = '42501';
  end if;
  new.updated_at := now();

  if tg_op = 'INSERT' then
    if new.stage <> 'intake' then
      raise exception 'artifact_candidate_must_start_at_intake'
        using errcode = '23514';
    end if;
    return new;
  end if;

  if new.artifact_sha256 is distinct from old.artifact_sha256
    or new.mime_type is distinct from old.mime_type
    or new.file_size_bytes is distinct from old.file_size_bytes
    or new.artifact_kind is distinct from old.artifact_kind
    or new.created_by is distinct from old.created_by
  then
    raise exception 'artifact_identity_is_immutable'
      using errcode = '23514';
  end if;

  if new.approved_by is distinct from old.approved_by
     or new.approved_at is distinct from old.approved_at then
    raise exception 'artifact_approval_is_derived_from_stage_transition'
      using errcode = '23514';
  end if;

  if old.stage in ('staged', 'ready', 'published') and (
    new.intended_price_jpy is distinct from old.intended_price_jpy
    or new.proposed_storage_bucket is distinct from old.proposed_storage_bucket
    or new.proposed_storage_path is distinct from old.proposed_storage_path
    or new.human_contribution_summary is distinct from old.human_contribution_summary
  ) then
    raise exception 'approved_publication_evidence_is_immutable'
      using errcode = '23514';
  end if;

  if old.stage in ('staged', 'ready', 'published')
     and new.product_id is distinct from old.product_id then
    raise exception 'artifact_product_link_locked_after_staging'
      using errcode = '23514';
  end if;

  if new.stage = old.stage then
    return new;
  end if;

  allowed :=
    (old.stage = 'intake' and new.stage = 'automated_checks')
    or (old.stage = 'automated_checks' and new.stage in ('human_review', 'intake'))
    or (old.stage = 'human_review' and new.stage in ('approved', 'automated_checks'))
    or (old.stage = 'approved' and new.stage in ('staged', 'human_review'))
    or (old.stage = 'staged' and new.stage in ('ready', 'human_review'))
    or (old.stage = 'ready' and new.stage = 'staged')
    or (old.stage = 'ready' and new.stage = 'published')
    or (old.stage = 'published' and new.stage = 'ready')
    or (old.stage = 'rejected' and new.stage = 'intake')
    or (old.stage not in ('published', 'rejected') and new.stage = 'rejected');

  if not allowed then
    raise exception 'invalid_artifact_stage_transition:%->%', old.stage, new.stage
      using errcode = '23514';
  end if;

  if new.stage = 'human_review' and old.stage = 'automated_checks' then
    if exists (
      select 1
      from public.artifact_checks as checks
      where checks.candidate_id = old.id
        and checks.check_key in ('secret_scan', 'pii_scan')
        and checks.status <> 'pass'
    ) then
      raise exception 'automated_risk_checks_not_passed'
        using errcode = '23514';
    end if;
  end if;

  if new.stage = 'approved' then
    if actor is null or not public.is_user_admin(actor) then
      raise exception 'human_admin_approval_required' using errcode = '42501';
    end if;
    if new.human_contribution_summary is null then
      raise exception 'human_contribution_summary_required'
        using errcode = '23514';
    end if;
    if exists (
      select 1
      from public.artifact_checks as checks
      where checks.candidate_id = old.id
        and checks.check_key in (
          'third_party_license', 'face_voice_consent',
          'chatgpt_voice_output', 'human_contribution'
        )
        and (
          (checks.check_key = 'human_contribution' and checks.status <> 'pass')
          or (
            checks.check_key <> 'human_contribution'
            and checks.status not in ('pass', 'not_applicable')
          )
        )
    ) then
      raise exception 'human_rights_checks_not_passed'
        using errcode = '23514';
    end if;
    new.approved_by := actor;
    new.approved_at := now();
  elsif new.stage in ('intake', 'automated_checks', 'human_review') then
    new.approved_by := null;
    new.approved_at := null;
  end if;

  if new.stage = 'staged' and old.stage = 'approved' then
    if new.product_id is null then
      raise exception 'inactive_product_link_required' using errcode = '23514';
    end if;
    if not exists (
      select 1 from public.shop_products as product
      where product.id = new.product_id and not product.is_active
    ) then
      raise exception 'linked_product_must_be_inactive' using errcode = '23514';
    end if;
  end if;

  if new.stage = 'ready' and old.stage = 'staged' then
    if not private.artifact_candidate_matches_product(
      old.id, new.product_id, array['staged']::text[]
    ) then
      raise exception 'publication_hard_gates_not_satisfied'
        using errcode = '23514';
    end if;
    if exists (
      select 1 from public.shop_products as product
      where product.id = new.product_id and product.is_active
    ) then
      raise exception 'ready_product_must_remain_inactive'
        using errcode = '23514';
    end if;
  end if;

  if new.stage = 'published' then
    if not exists (
      select 1 from public.shop_products as product
      where product.id = new.product_id and product.is_active
    ) then
      raise exception 'explicit_product_activation_required'
        using errcode = '23514';
    end if;
    if not private.artifact_candidate_matches_product(
      old.id, new.product_id, array['ready']::text[]
    ) then
      raise exception 'published_product_no_longer_matches_evidence'
        using errcode = '23514';
    end if;
  end if;

  if old.stage = 'published' and new.stage = 'ready' and exists (
    select 1 from public.shop_products as product
    where product.id = old.product_id and product.is_active
  ) then
    raise exception 'deactivate_product_before_rollback'
      using errcode = '23514';
  end if;

  if new.stage = 'rejected' then
    if new.rejection_reason is null then
      raise exception 'rejection_reason_required' using errcode = '23514';
    end if;
  elsif old.stage = 'rejected' then
    new.rejection_reason := null;
  end if;

  return new;
end;
$$;

create or replace function private.prepare_artifact_check_decision()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if new.candidate_id is distinct from old.candidate_id
     or new.check_key is distinct from old.check_key
     or new.check_kind is distinct from old.check_kind
     or new.is_hard_gate is distinct from old.is_hard_gate
     or new.reviewed_by is distinct from old.reviewed_by
     or new.reviewed_at is distinct from old.reviewed_at then
    raise exception 'artifact_check_identity_is_immutable' using errcode = '23514';
  end if;

  new.updated_at := now();
  if not (
    (new.check_key in ('secret_scan', 'pii_scan')
      and exists (
        select 1 from public.artifact_candidates as candidate
        where candidate.id = new.candidate_id
          and candidate.stage = 'automated_checks'
      ))
    or (new.check_key in (
          'third_party_license', 'face_voice_consent',
          'chatgpt_voice_output', 'human_contribution'
        )
      and exists (
        select 1 from public.artifact_candidates as candidate
        where candidate.id = new.candidate_id
          and candidate.stage = 'human_review'
      ))
    or (new.check_key in ('price_match', 'private_object', 'content_integrity')
      and exists (
        select 1 from public.artifact_candidates as candidate
        where candidate.id = new.candidate_id
          and candidate.stage = 'staged'
      ))
  ) then
    raise exception 'artifact_check_wrong_stage' using errcode = '23514';
  end if;
  if new.check_key = 'chatgpt_voice_output'
     and new.status in ('pass', 'not_applicable')
     and exists (
       select 1
       from public.artifact_candidates as candidate
       join public.artifact_provenance as provenance
         on provenance.candidate_id = candidate.id
       where candidate.id = new.candidate_id
         and candidate.mime_type like 'audio/%'
         and provenance.source_tool = 'chatgpt'
     ) then
    raise exception 'chatgpt_voice_output_standalone_audio_blocked'
      using errcode = '23514';
  end if;
  if new.status is distinct from old.status
     or new.evidence_summary is distinct from old.evidence_summary then
    if actor is null or not public.is_user_admin(actor) then
      raise exception 'admin_check_review_required' using errcode = '42501';
    end if;
    if new.status = 'pending' then
      new.reviewed_by := null;
      new.reviewed_at := null;
      new.evidence_summary := null;
    else
      new.reviewed_by := actor;
      new.reviewed_at := now();
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.guard_artifact_publication_run()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed boolean := false;
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'publication_run_actor_not_authorized'
      using errcode = '42501';
  end if;
  new.updated_at := now();
  if tg_op = 'INSERT' then
    if new.status <> 'planned' then
      raise exception 'publication_run_must_start_planned' using errcode = '23514';
    end if;
    if not new.dry_run and (
      new.product_id is null
      or not private.artifact_candidate_matches_product(
        new.candidate_id, new.product_id, array['ready']::text[]
      )
    ) then
      raise exception 'live_run_requires_ready_candidate' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.candidate_id is distinct from old.candidate_id
     or new.product_id is distinct from old.product_id
     or new.target is distinct from old.target
     or new.dry_run is distinct from old.dry_run
     or new.authorization_reference is distinct from old.authorization_reference
     or new.initiated_by is distinct from old.initiated_by
     or new.created_at is distinct from old.created_at then
    raise exception 'publication_run_identity_is_immutable' using errcode = '23514';
  end if;

  if new.status = old.status then
    return new;
  end if;
  allowed :=
    (old.status = 'planned' and new.status in ('running', 'canceled'))
    or (old.status = 'running' and new.status in ('succeeded', 'failed', 'canceled'))
    or (old.status = 'succeeded' and new.status = 'rolled_back');
  if not allowed then
    raise exception 'invalid_publication_run_transition:%->%', old.status, new.status
      using errcode = '23514';
  end if;

  if new.status = 'running' then
    new.started_at := coalesce(old.started_at, now());
  elsif new.status in ('succeeded', 'failed', 'canceled', 'rolled_back') then
    new.started_at := coalesce(old.started_at, now());
    new.finished_at := now();
  end if;
  if new.status = 'succeeded' and (
    new.validation_summary is null
    or char_length(btrim(new.validation_summary)) < 8
  ) then
    raise exception 'successful_run_requires_validation_summary'
      using errcode = '23514';
  end if;
  if new.status = 'failed' and (
    new.error_summary is null or char_length(btrim(new.error_summary)) < 3
  ) then
    raise exception 'failed_run_requires_error_summary'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

-- The trigger-only audit writers need to insert into append-only tables even
-- though authenticated admins intentionally have no INSERT grant on events.
create or replace function private.seed_and_audit_artifact_candidate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'artifact_audit_actor_not_authorized' using errcode = '42501';
  end if;
  insert into public.artifact_checks (candidate_id, check_key, check_kind)
  values
    (new.id, 'secret_scan', 'automated'),
    (new.id, 'pii_scan', 'automated'),
    (new.id, 'third_party_license', 'human'),
    (new.id, 'face_voice_consent', 'human'),
    (new.id, 'chatgpt_voice_output', 'human'),
    (new.id, 'human_contribution', 'human'),
    (new.id, 'price_match', 'external_evidence'),
    (new.id, 'private_object', 'external_evidence'),
    (new.id, 'content_integrity', 'external_evidence')
  on conflict (candidate_id, check_key) do nothing;

  insert into public.artifact_publication_events (
    candidate_id, product_id, event_type, to_value, actor_id
  ) values (
    new.id, new.product_id, 'candidate_created', new.stage, auth.uid()
  );
  return new;
end;
$$;

create or replace function private.audit_artifact_candidate_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'artifact_audit_actor_not_authorized' using errcode = '42501';
  end if;
  if new.stage is distinct from old.stage then
    insert into public.artifact_publication_events (
      candidate_id, product_id, event_type, from_value, to_value, actor_id
    ) values (
      new.id, new.product_id, 'stage_transition', old.stage, new.stage, auth.uid()
    );
  end if;
  return new;
end;
$$;

create or replace function private.audit_artifact_check_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'artifact_audit_actor_not_authorized' using errcode = '42501';
  end if;
  if new.status is distinct from old.status
     or new.evidence_summary is distinct from old.evidence_summary then
    insert into public.artifact_publication_events (
      candidate_id, event_type, from_value, to_value, details, actor_id
    ) values (
      new.candidate_id,
      'check_updated',
      old.status,
      new.status,
      jsonb_build_object(
        'check_key', new.check_key,
        'evidence_changed', new.evidence_summary is distinct from old.evidence_summary
      ),
      auth.uid()
    );
  end if;
  return new;
end;
$$;

create or replace function private.audit_artifact_publication_run()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'artifact_audit_actor_not_authorized' using errcode = '42501';
  end if;
  if new.status is distinct from old.status then
    insert into public.artifact_publication_events (
      candidate_id, run_id, product_id, event_type,
      from_value, to_value, actor_id
    ) values (
      new.candidate_id, new.id, new.product_id, 'run_status_changed',
      old.status, new.status, auth.uid()
    );
  end if;
  return new;
end;
$$;

create or replace function private.guard_linked_shop_product_activation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'product_activation_actor_not_authorized'
      using errcode = '42501';
  end if;
  if new.is_active and exists (
    select 1 from public.artifact_candidates as candidate
    where candidate.product_id = new.id
  ) and not exists (
    select 1
    from public.artifact_candidates as candidate
    where candidate.product_id = new.id
      and private.artifact_candidate_matches_product(
        candidate.id, new.id, array['ready', 'published']::text[]
      )
  ) then
    raise exception 'linked_artifact_product_not_publication_ready'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.audit_linked_shop_product_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.artifact_trigger_actor_authorized() then
    raise exception 'artifact_audit_actor_not_authorized' using errcode = '42501';
  end if;
  if new.is_active is distinct from old.is_active then
    insert into public.artifact_publication_events (
      candidate_id, product_id, event_type, from_value, to_value, actor_id
    )
    select
      candidate.id,
      new.id,
      case when new.is_active then 'product_activated' else 'product_deactivated' end,
      old.is_active::text,
      new.is_active::text,
      auth.uid()
    from public.artifact_candidates as candidate
    where candidate.product_id = new.id;
  end if;
  return new;
end;
$$;

create trigger artifact_candidates_guard
  before insert or update on public.artifact_candidates
  for each row execute function private.guard_artifact_candidate_transition();
create trigger artifact_candidates_seed_audit
  after insert on public.artifact_candidates
  for each row execute function private.seed_and_audit_artifact_candidate();
create trigger artifact_candidates_transition_audit
  after update on public.artifact_candidates
  for each row execute function private.audit_artifact_candidate_transition();
create trigger artifact_checks_prepare_decision
  before update on public.artifact_checks
  for each row execute function private.prepare_artifact_check_decision();
create trigger artifact_checks_update_audit
  after update on public.artifact_checks
  for each row execute function private.audit_artifact_check_update();
create trigger artifact_publication_runs_guard
  before insert or update on public.artifact_publication_runs
  for each row execute function private.guard_artifact_publication_run();
create trigger artifact_publication_runs_audit
  after update on public.artifact_publication_runs
  for each row execute function private.audit_artifact_publication_run();
create trigger shop_products_artifact_activation_guard
  before update on public.shop_products
  for each row execute function private.guard_linked_shop_product_activation();
create trigger shop_products_artifact_state_audit
  after update on public.shop_products
  for each row execute function private.audit_linked_shop_product_state();

alter table public.artifact_candidates enable row level security;
alter table public.artifact_provenance enable row level security;
alter table public.artifact_checks enable row level security;
alter table public.artifact_publication_runs enable row level security;
alter table public.artifact_publication_events enable row level security;

create policy artifact_candidates_admin_select on public.artifact_candidates
  for select to authenticated
  using ((select public.is_user_admin((select auth.uid()))));
create policy artifact_candidates_admin_insert on public.artifact_candidates
  for insert to authenticated
  with check (
    (select public.is_user_admin((select auth.uid())))
    and created_by = (select auth.uid())
  );
create policy artifact_candidates_admin_update on public.artifact_candidates
  for update to authenticated
  using ((select public.is_user_admin((select auth.uid()))))
  with check ((select public.is_user_admin((select auth.uid()))));

create policy artifact_provenance_admin_select on public.artifact_provenance
  for select to authenticated
  using ((select public.is_user_admin((select auth.uid()))));
create policy artifact_provenance_admin_insert on public.artifact_provenance
  for insert to authenticated
  with check (
    (select public.is_user_admin((select auth.uid())))
    and recorded_by = (select auth.uid())
  );
create policy artifact_checks_admin_select on public.artifact_checks
  for select to authenticated
  using ((select public.is_user_admin((select auth.uid()))));
create policy artifact_checks_admin_update on public.artifact_checks
  for update to authenticated
  using ((select public.is_user_admin((select auth.uid()))))
  with check ((select public.is_user_admin((select auth.uid()))));

create policy artifact_publication_runs_admin_select
  on public.artifact_publication_runs
  for select to authenticated
  using ((select public.is_user_admin((select auth.uid()))));
create policy artifact_publication_runs_admin_insert
  on public.artifact_publication_runs
  for insert to authenticated
  with check (
    (select public.is_user_admin((select auth.uid())))
    and initiated_by = (select auth.uid())
  );
create policy artifact_publication_runs_admin_update
  on public.artifact_publication_runs
  for update to authenticated
  using ((select public.is_user_admin((select auth.uid()))))
  with check ((select public.is_user_admin((select auth.uid()))));

create policy artifact_publication_events_admin_select
  on public.artifact_publication_events
  for select to authenticated
  using ((select public.is_user_admin((select auth.uid()))));

-- Inactive linked products must be visible to admins for readiness review, but
-- no authenticated shop-product write policy is added here.
create policy shop_products_admin_read on public.shop_products
  for select to authenticated
  using ((select public.is_user_admin((select auth.uid()))));

revoke all on table public.artifact_candidates from anon, authenticated;
revoke all on table public.artifact_provenance from anon, authenticated;
revoke all on table public.artifact_checks from anon, authenticated;
revoke all on table public.artifact_publication_runs from anon, authenticated;
revoke all on table public.artifact_publication_events from anon, authenticated;
revoke all on sequence public.artifact_publication_events_id_seq
  from anon, authenticated;

grant select, insert, update on table public.artifact_candidates to authenticated;
grant select, insert on table public.artifact_provenance to authenticated;
grant select, update on table public.artifact_checks to authenticated;
grant select, insert, update on table public.artifact_publication_runs
  to authenticated;
grant select on table public.artifact_publication_events to authenticated;

revoke execute on function public.intake_artifact_candidate(
  text, text, text, bigint, text, text, text, text, text
) from public, anon, service_role;
grant execute on function public.intake_artifact_candidate(
  text, text, text, bigint, text, text, text, text, text
) to authenticated;

revoke execute on function private.artifact_candidate_hard_gates_pass(uuid)
  from public, anon, authenticated, service_role;
revoke execute on function private.artifact_private_object_exists(text, text, bigint)
  from public, anon, authenticated, service_role;
revoke execute on function private.artifact_candidate_matches_product(uuid, text, text[])
  from public, anon, authenticated, service_role;
revoke execute on function private.guard_artifact_candidate_transition()
  from public, anon, authenticated, service_role;
revoke execute on function private.prepare_artifact_check_decision()
  from public, anon, authenticated, service_role;
revoke execute on function private.seed_and_audit_artifact_candidate()
  from public, anon, authenticated, service_role;
revoke execute on function private.audit_artifact_candidate_transition()
  from public, anon, authenticated, service_role;
revoke execute on function private.audit_artifact_check_update()
  from public, anon, authenticated, service_role;
revoke execute on function private.guard_artifact_publication_run()
  from public, anon, authenticated, service_role;
revoke execute on function private.artifact_trigger_actor_authorized()
  from public, anon, authenticated, service_role;
revoke execute on function private.audit_artifact_publication_run()
  from public, anon, authenticated, service_role;
revoke execute on function private.guard_linked_shop_product_activation()
  from public, anon, authenticated, service_role;
revoke execute on function private.audit_linked_shop_product_state()
  from public, anon, authenticated, service_role;
