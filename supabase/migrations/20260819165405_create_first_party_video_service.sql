-- First-party paid video generation ledger and GPU-worker queue.
-- All mutations are service-role-only RPCs so browsers cannot mint credits,
-- bypass reservations, or settle their own jobs.
-- nocheck: time-relative -- UPDATE statements target only new video_* tables;
-- the repository detector otherwise parses the schema name "public" as a table.

create table public.video_credit_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  available_credits bigint not null default 0 check (available_credits >= 0),
  reserved_credits bigint not null default 0 check (reserved_credits >= 0),
  credit_debt bigint not null default 0 check (credit_debt >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.video_generation_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null check (
    char_length(idempotency_key) between 8 and 128
  ),
  model_key text not null check (model_key = 'studio-video-v1'),
  inference_engine text not null check (
    inference_engine = 'omocha_works_gpu'
  ),
  model_revision text not null check (
    model_revision = 'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e'
  ),
  prompt text not null check (char_length(prompt) between 1 and 1000),
  duration_seconds smallint not null check (duration_seconds = 5),
  aspect_ratio text not null check (aspect_ratio in ('16:9', '9:16')),
  resolution text not null check (resolution = '720p'),
  status text not null default 'queued' check (
    status in (
      'queued',
      'in_progress',
      'succeeded',
      'failed',
      'cancelled'
    )
  ),
  quoted_credits bigint not null check (quoted_credits = 300),
  reserved_credits bigint not null check (reserved_credits >= 0),
  charged_credits bigint not null default 0 check (charged_credits >= 0),
  output_storage_path text,
  error_code text,
  worker_id text,
  worker_lease_token text,
  lease_expires_at timestamptz,
  attempt_count smallint not null default 0 check (
    attempt_count between 0 and 3
  ),
  started_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (user_id, idempotency_key),
  check (charged_credits <= quoted_credits),
  check (
    (status = 'succeeded' and output_storage_path is not null) or
    status <> 'succeeded'
  )
);

create table public.video_credit_purchases (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  pack_key text not null check (pack_key in ('starter', 'creator', 'studio')),
  credits bigint not null check (credits > 0),
  amount_jpy integer not null check (amount_jpy > 0),
  stripe_checkout_session_id text not null unique,
  stripe_payment_intent_id text unique,
  status text not null default 'paid' check (status in ('paid', 'refunded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  refunded_at timestamptz
);

create table public.video_credit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.video_generation_jobs(id) on delete set null,
  purchase_id bigint references public.video_credit_purchases(id) on delete set null,
  delta_available bigint not null default 0,
  delta_reserved bigint not null default 0,
  delta_debt bigint not null default 0,
  reason text not null check (
    reason in (
      'pack_purchase',
      'generation_reserved',
      'generation_settled',
      'generation_refunded',
      'payment_refunded',
      'admin_adjustment'
    )
  ),
  reference text not null unique check (char_length(reference) between 1 and 255),
  created_at timestamptz not null default now(),
  check (delta_available <> 0 or delta_reserved <> 0 or delta_debt <> 0)
);

create index video_generation_jobs_user_created_idx
  on public.video_generation_jobs (user_id, created_at desc);
create index video_generation_jobs_queue_idx
  on public.video_generation_jobs (status, lease_expires_at, created_at)
  where status in ('queued', 'in_progress');
create index video_credit_purchases_user_created_idx
  on public.video_credit_purchases (user_id, created_at desc);
create index video_credit_ledger_user_created_idx
  on public.video_credit_ledger (user_id, created_at desc);
create index video_credit_ledger_job_idx
  on public.video_credit_ledger (job_id)
  where job_id is not null;
create index video_credit_ledger_purchase_idx
  on public.video_credit_ledger (purchase_id)
  where purchase_id is not null;

alter table public.video_credit_accounts enable row level security;
alter table public.video_generation_jobs enable row level security;
alter table public.video_credit_purchases enable row level security;
alter table public.video_credit_ledger enable row level security;

create policy "video credit account select own"
  on public.video_credit_accounts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "video generation jobs select own"
  on public.video_generation_jobs
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "video credit purchases select own"
  on public.video_credit_purchases
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "video credit ledger select own"
  on public.video_credit_ledger
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.video_credit_accounts from anon, authenticated;
revoke all on table public.video_generation_jobs from anon, authenticated;
revoke all on table public.video_credit_purchases from anon, authenticated;
revoke all on table public.video_credit_ledger from anon, authenticated;
grant select on table public.video_credit_accounts to authenticated;
grant select (
  id,
  user_id,
  model_key,
  prompt,
  duration_seconds,
  aspect_ratio,
  resolution,
  status,
  quoted_credits,
  charged_credits,
  output_storage_path,
  error_code,
  created_at,
  updated_at,
  completed_at
) on table public.video_generation_jobs to authenticated;
grant select on table public.video_credit_purchases to authenticated;
grant select on table public.video_credit_ledger to authenticated;
grant all on table public.video_credit_accounts to service_role;
grant all on table public.video_generation_jobs to service_role;
grant all on table public.video_credit_purchases to service_role;
grant all on table public.video_credit_ledger to service_role;
grant usage, select on sequence public.video_credit_purchases_id_seq to service_role;
grant usage, select on sequence public.video_credit_ledger_id_seq to service_role;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'video-generations',
  'video-generations',
  false,
  52428800,
  array['video/mp4']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.video_reserve_generation(
  p_user_id uuid,
  p_idempotency_key text,
  p_model_key text,
  p_inference_engine text,
  p_model_revision text,
  p_prompt text,
  p_duration_seconds smallint,
  p_aspect_ratio text,
  p_resolution text,
  p_required_credits bigint
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_account public.video_credit_accounts%rowtype;
  v_job public.video_generation_jobs%rowtype;
begin
  if p_user_id is null then
    raise exception 'user_id_required' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'invalid_idempotency_key' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_prompt, ''))) not between 1 and 1000 then
    raise exception 'invalid_prompt' using errcode = '22023';
  end if;
  if p_duration_seconds <> 5
    or p_aspect_ratio not in ('16:9', '9:16')
    or p_resolution <> '720p'
    or p_required_credits <> 300
    or p_model_key <> 'studio-video-v1'
    or p_inference_engine <> 'omocha_works_gpu'
    or p_model_revision <> 'wan2.2-ti2v-5b@921dbaf3f1674a56f47e83fb80a34bac8a8f203e' then
    raise exception 'invalid_video_quote' using errcode = '22023';
  end if;

  insert into public.video_credit_accounts (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select *
  into v_account
  from public.video_credit_accounts
  where user_id = p_user_id
  for update;

  select *
  into v_job
  from public.video_generation_jobs
  where user_id = p_user_id
    and idempotency_key = trim(p_idempotency_key);

  if found then
    return jsonb_build_object(
      'job_id', v_job.id,
      'status', v_job.status,
      'idempotent_replay', true,
      'available_credits', v_account.available_credits,
      'reserved_credits', v_account.reserved_credits,
      'credit_debt', v_account.credit_debt
    );
  end if;

  if exists (
    select 1
    from public.video_generation_jobs
    where user_id = p_user_id
      and status in ('queued', 'in_progress')
  ) then
    raise exception 'video_generation_already_active' using errcode = 'P0001';
  end if;

  if v_account.available_credits < p_required_credits then
    raise exception 'insufficient_video_credits' using errcode = 'P0001';
  end if;

  update public.video_credit_accounts
  set available_credits = available_credits - p_required_credits,
      reserved_credits = reserved_credits + p_required_credits,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_account;

  insert into public.video_generation_jobs (
    user_id,
    idempotency_key,
    model_key,
    inference_engine,
    model_revision,
    prompt,
    duration_seconds,
    aspect_ratio,
    resolution,
    quoted_credits,
    reserved_credits
  ) values (
    p_user_id,
    trim(p_idempotency_key),
    trim(p_model_key),
    trim(p_inference_engine),
    trim(p_model_revision),
    trim(p_prompt),
    p_duration_seconds,
    p_aspect_ratio,
    p_resolution,
    p_required_credits,
    p_required_credits
  )
  returning * into v_job;

  insert into public.video_credit_ledger (
    user_id,
    job_id,
    delta_available,
    delta_reserved,
    reason,
    reference
  ) values (
    p_user_id,
    v_job.id,
    -p_required_credits,
    p_required_credits,
    'generation_reserved',
    'video-job:' || v_job.id::text || ':reserve'
  );

  return jsonb_build_object(
    'job_id', v_job.id,
    'status', v_job.status,
    'idempotent_replay', false,
    'available_credits', v_account.available_credits,
    'reserved_credits', v_account.reserved_credits,
    'credit_debt', v_account.credit_debt
  );
end;
$$;

create or replace function public.video_finalize_generation(
  p_user_id uuid,
  p_job_id uuid,
  p_status text,
  p_output_storage_path text default null,
  p_error_code text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_account public.video_credit_accounts%rowtype;
  v_job public.video_generation_jobs%rowtype;
  v_success boolean;
  v_debt_paid bigint;
  v_available_refund bigint;
begin
  if p_status not in ('succeeded', 'failed', 'cancelled') then
    raise exception 'invalid_final_status' using errcode = '22023';
  end if;
  v_success := p_status = 'succeeded';
  if v_success and nullif(trim(coalesce(p_output_storage_path, '')), '') is null then
    raise exception 'output_storage_path_required' using errcode = '22023';
  end if;

  select *
  into v_job
  from public.video_generation_jobs
  where id = p_job_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'video_job_not_found' using errcode = 'P0002';
  end if;
  if v_job.status in ('succeeded', 'failed', 'cancelled') then
    return jsonb_build_object(
      'job_id', v_job.id,
      'status', v_job.status,
      'idempotent_replay', true
    );
  end if;

  select *
  into v_account
  from public.video_credit_accounts
  where user_id = p_user_id
  for update;

  if v_account.reserved_credits < v_job.reserved_credits then
    raise exception 'video_credit_reservation_corrupt' using errcode = 'P0001';
  end if;

  if v_success then
    update public.video_credit_accounts
    set reserved_credits = reserved_credits - v_job.reserved_credits,
        updated_at = now()
    where user_id = p_user_id;

    insert into public.video_credit_ledger (
      user_id, job_id, delta_reserved, reason, reference
    ) values (
      p_user_id,
      v_job.id,
      -v_job.reserved_credits,
      'generation_settled',
      'video-job:' || v_job.id::text || ':settle'
    );
  else
    -- A Stripe refund may arrive while this job still holds credits in
    -- reserved_credits. If the job later fails, repay that refund debt before
    -- making any credits spendable again; otherwise webhook/job ordering could
    -- temporarily recreate already-refunded value.
    v_debt_paid := least(v_account.credit_debt, v_job.reserved_credits);
    v_available_refund := v_job.reserved_credits - v_debt_paid;

    update public.video_credit_accounts
    set available_credits = available_credits + v_available_refund,
        reserved_credits = reserved_credits - v_job.reserved_credits,
        credit_debt = credit_debt - v_debt_paid,
        updated_at = now()
    where user_id = p_user_id;

    insert into public.video_credit_ledger (
      user_id,
      job_id,
      delta_available,
      delta_reserved,
      delta_debt,
      reason,
      reference
    ) values (
      p_user_id,
      v_job.id,
      v_available_refund,
      -v_job.reserved_credits,
      -v_debt_paid,
      'generation_refunded',
      'video-job:' || v_job.id::text || ':refund'
    );
  end if;

  update public.video_generation_jobs
  set status = p_status,
      reserved_credits = 0,
      charged_credits = case when v_success then v_job.reserved_credits else 0 end,
      output_storage_path = case
        when v_success then trim(p_output_storage_path)
        else null
      end,
      error_code = case
        when v_success then null
        else left(nullif(trim(coalesce(p_error_code, '')), ''), 120)
      end,
      worker_lease_token = null,
      lease_expires_at = null,
      completed_at = now(),
      updated_at = now()
  where id = v_job.id
  returning * into v_job;

  return jsonb_build_object(
    'job_id', v_job.id,
    'status', v_job.status,
    'charged_credits', v_job.charged_credits,
    'idempotent_replay', false
  );
end;
$$;

create or replace function public.video_cancel_queued_generation(
  p_user_id uuid,
  p_job_id uuid,
  p_error_code text default 'generation_queue_unavailable'
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_job public.video_generation_jobs%rowtype;
  v_error_code text;
begin
  select *
  into v_job
  from public.video_generation_jobs
  where id = p_job_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'video_job_not_found' using errcode = 'P0002';
  end if;
  if v_job.status <> 'queued' or v_job.attempt_count <> 0 then
    return jsonb_build_object(
      'job_id', v_job.id,
      'status', v_job.status,
      'cancelled', false
    );
  end if;

  v_error_code := left(
    regexp_replace(
      lower(coalesce(p_error_code, 'generation_queue_unavailable')),
      '[^a-z0-9_]+',
      '',
      'g'
    ),
    120
  );
  if v_error_code = '' then
    v_error_code := 'generation_queue_unavailable';
  end if;

  return public.video_finalize_generation(
    v_job.user_id,
    v_job.id,
    'failed',
    null,
    v_error_code
  );
end;
$$;

create or replace function public.video_grant_credit_pack(
  p_user_id uuid,
  p_pack_key text,
  p_credits bigint,
  p_amount_jpy integer,
  p_stripe_checkout_session_id text,
  p_stripe_payment_intent_id text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_expected_credits bigint;
  v_expected_amount integer;
  v_account public.video_credit_accounts%rowtype;
  v_purchase public.video_credit_purchases%rowtype;
  v_debt_paid bigint;
  v_available_grant bigint;
begin
  select expected_credits, expected_amount
  into v_expected_credits, v_expected_amount
  from (values
    ('starter'::text, 500::bigint, 500::integer),
    ('creator'::text, 1200::bigint, 1000::integer),
    ('studio'::text, 3000::bigint, 2400::integer)
  ) as packs(pack_key, expected_credits, expected_amount)
  where pack_key = p_pack_key;

  if v_expected_credits is null
    or p_credits <> v_expected_credits
    or p_amount_jpy <> v_expected_amount
    or nullif(trim(coalesce(p_stripe_checkout_session_id, '')), '') is null then
    raise exception 'invalid_video_credit_pack' using errcode = '22023';
  end if;

  insert into public.video_credit_accounts (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select *
  into v_account
  from public.video_credit_accounts
  where user_id = p_user_id
  for update;

  select *
  into v_purchase
  from public.video_credit_purchases
  where stripe_checkout_session_id = trim(p_stripe_checkout_session_id);

  if found then
    return jsonb_build_object(
      'purchase_id', v_purchase.id,
      'status', v_purchase.status,
      'idempotent_replay', true,
      'available_credits', v_account.available_credits,
      'credit_debt', v_account.credit_debt
    );
  end if;

  v_debt_paid := least(v_account.credit_debt, p_credits);
  v_available_grant := p_credits - v_debt_paid;

  insert into public.video_credit_purchases (
    user_id,
    pack_key,
    credits,
    amount_jpy,
    stripe_checkout_session_id,
    stripe_payment_intent_id
  ) values (
    p_user_id,
    p_pack_key,
    p_credits,
    p_amount_jpy,
    trim(p_stripe_checkout_session_id),
    nullif(trim(coalesce(p_stripe_payment_intent_id, '')), '')
  )
  returning * into v_purchase;

  update public.video_credit_accounts
  set available_credits = available_credits + v_available_grant,
      credit_debt = credit_debt - v_debt_paid,
      updated_at = now()
  where user_id = p_user_id
  returning * into v_account;

  insert into public.video_credit_ledger (
    user_id,
    purchase_id,
    delta_available,
    delta_debt,
    reason,
    reference
  ) values (
    p_user_id,
    v_purchase.id,
    v_available_grant,
    -v_debt_paid,
    'pack_purchase',
    'stripe-checkout:' || trim(p_stripe_checkout_session_id)
  );

  return jsonb_build_object(
    'purchase_id', v_purchase.id,
    'status', v_purchase.status,
    'idempotent_replay', false,
    'available_credits', v_account.available_credits,
    'credit_debt', v_account.credit_debt
  );
end;
$$;

create or replace function public.video_revoke_refunded_pack(
  p_stripe_payment_intent_id text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_account public.video_credit_accounts%rowtype;
  v_purchase public.video_credit_purchases%rowtype;
  v_available_revoke bigint;
  v_debt_add bigint;
begin
  select *
  into v_purchase
  from public.video_credit_purchases
  where stripe_payment_intent_id = trim(p_stripe_payment_intent_id)
  for update;

  if not found then
    return jsonb_build_object('matched', false, 'idempotent_replay', false);
  end if;
  if v_purchase.status = 'refunded' then
    return jsonb_build_object(
      'matched', true,
      'purchase_id', v_purchase.id,
      'idempotent_replay', true
    );
  end if;

  select *
  into v_account
  from public.video_credit_accounts
  where user_id = v_purchase.user_id
  for update;

  v_available_revoke := least(v_account.available_credits, v_purchase.credits);
  v_debt_add := v_purchase.credits - v_available_revoke;

  update public.video_credit_accounts
  set available_credits = available_credits - v_available_revoke,
      credit_debt = credit_debt + v_debt_add,
      updated_at = now()
  where user_id = v_purchase.user_id;

  update public.video_credit_purchases
  set status = 'refunded',
      refunded_at = now(),
      updated_at = now()
  where id = v_purchase.id;

  insert into public.video_credit_ledger (
    user_id,
    purchase_id,
    delta_available,
    delta_debt,
    reason,
    reference
  ) values (
    v_purchase.user_id,
    v_purchase.id,
    -v_available_revoke,
    v_debt_add,
    'payment_refunded',
    'stripe-refund:' || v_purchase.stripe_payment_intent_id
  );

  return jsonb_build_object(
    'matched', true,
    'purchase_id', v_purchase.id,
    'idempotent_replay', false,
    'revoked_available_credits', v_available_revoke,
    'added_credit_debt', v_debt_add
  );
end;
$$;

create or replace function public.video_claim_generation(
  p_worker_id text,
  p_lease_seconds integer default 1800
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_exhausted public.video_generation_jobs%rowtype;
  v_job public.video_generation_jobs%rowtype;
  v_lease_token text;
  v_cleanup_storage_paths text[] := array[]::text[];
begin
  if coalesce(p_worker_id, '') !~ '^[A-Za-z0-9._-]{3,80}$' then
    raise exception 'invalid_worker_id' using errcode = '22023';
  end if;
  if p_lease_seconds not between 300 and 3600 then
    raise exception 'invalid_lease_seconds' using errcode = '22023';
  end if;

  -- A worker that disappears must not hold customer credits forever. On each
  -- claim, settle one exhausted job before looking for more work.
  select *
  into v_exhausted
  from public.video_generation_jobs
  where status = 'in_progress'
    and lease_expires_at < now()
    and attempt_count >= 3
  order by lease_expires_at, created_at
  for update skip locked
  limit 1;

  if found then
    v_cleanup_storage_paths := array_append(
      v_cleanup_storage_paths,
      v_exhausted.user_id::text || '/' || v_exhausted.id::text ||
        '-attempt-' || v_exhausted.attempt_count::text || '.mp4'
    );
    perform public.video_finalize_generation(
      v_exhausted.user_id,
      v_exhausted.id,
      'failed',
      null,
      'worker_attempts_exhausted'
    );
  end if;

  select *
  into v_job
  from public.video_generation_jobs
  where attempt_count < 3
    and (
      status = 'queued'
      or (status = 'in_progress' and lease_expires_at < now())
    )
  order by created_at
  for update skip locked
  limit 1;

  if not found then
    if cardinality(v_cleanup_storage_paths) > 0 then
      return jsonb_build_object(
        'cleanup_storage_paths', to_jsonb(v_cleanup_storage_paths)
      );
    end if;
    return null;
  end if;

  if v_job.status = 'in_progress' then
    v_cleanup_storage_paths := array_append(
      v_cleanup_storage_paths,
      v_job.user_id::text || '/' || v_job.id::text ||
        '-attempt-' || v_job.attempt_count::text || '.mp4'
    );
  end if;

  v_lease_token := replace(gen_random_uuid()::text, '-', '') ||
    replace(gen_random_uuid()::text, '-', '');

  update public.video_generation_jobs
  set status = 'in_progress',
      worker_id = p_worker_id,
      worker_lease_token = v_lease_token,
      lease_expires_at = now() + make_interval(secs => p_lease_seconds),
      attempt_count = attempt_count + 1,
      started_at = coalesce(started_at, now()),
      updated_at = now()
  where id = v_job.id
  returning * into v_job;

  return jsonb_build_object(
    'job_id', v_job.id,
    'lease_token', v_lease_token,
    'model_key', v_job.model_key,
    'prompt', v_job.prompt,
    'duration_seconds', v_job.duration_seconds,
    'aspect_ratio', v_job.aspect_ratio,
    'resolution', v_job.resolution,
    'attempt', v_job.attempt_count,
    'lease_expires_at', v_job.lease_expires_at,
    'cleanup_storage_paths', to_jsonb(v_cleanup_storage_paths)
  );
end;
$$;

create or replace function public.video_heartbeat_generation(
  p_job_id uuid,
  p_worker_id text,
  p_lease_token text,
  p_lease_seconds integer default 1800
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if p_lease_seconds not between 300 and 3600 then
    raise exception 'invalid_lease_seconds' using errcode = '22023';
  end if;

  update public.video_generation_jobs
  set lease_expires_at = now() + make_interval(secs => p_lease_seconds),
      updated_at = now()
  where id = p_job_id
    and status = 'in_progress'
    and worker_id = p_worker_id
    and worker_lease_token = p_lease_token
    and lease_expires_at >= now();

  return found;
end;
$$;

create or replace function public.video_validate_generation_lease(
  p_job_id uuid,
  p_worker_id text,
  p_lease_token text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_job public.video_generation_jobs%rowtype;
begin
  select *
  into v_job
  from public.video_generation_jobs
  where id = p_job_id
    and status = 'in_progress'
    and worker_id = p_worker_id
    and worker_lease_token = p_lease_token
    and lease_expires_at >= now();

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'job_id', v_job.id,
    'user_id', v_job.user_id,
    'storage_path', v_job.user_id::text || '/' || v_job.id::text ||
      '-attempt-' || v_job.attempt_count::text || '.mp4',
    'attempt', v_job.attempt_count
  );
end;
$$;

create or replace function public.video_complete_claimed_generation(
  p_job_id uuid,
  p_worker_id text,
  p_lease_token text,
  p_output_storage_path text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_job public.video_generation_jobs%rowtype;
  v_expected_path text;
begin
  select *
  into v_job
  from public.video_generation_jobs
  where id = p_job_id
    and status = 'in_progress'
    and worker_id = p_worker_id
    and worker_lease_token = p_lease_token
    and lease_expires_at >= now()
  for update;

  if not found then
    raise exception 'invalid_worker_lease' using errcode = 'P0001';
  end if;

  v_expected_path := v_job.user_id::text || '/' || v_job.id::text ||
    '-attempt-' || v_job.attempt_count::text || '.mp4';
  if p_output_storage_path <> v_expected_path then
    raise exception 'invalid_output_storage_path' using errcode = '22023';
  end if;

  return public.video_finalize_generation(
    v_job.user_id,
    v_job.id,
    'succeeded',
    v_expected_path,
    null
  );
end;
$$;

create or replace function public.video_fail_claimed_generation(
  p_job_id uuid,
  p_worker_id text,
  p_lease_token text,
  p_error_code text,
  p_retryable boolean default true
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_job public.video_generation_jobs%rowtype;
  v_error_code text;
begin
  select *
  into v_job
  from public.video_generation_jobs
  where id = p_job_id
    and status = 'in_progress'
    and worker_id = p_worker_id
    and worker_lease_token = p_lease_token
    and lease_expires_at >= now()
  for update;

  if not found then
    raise exception 'invalid_worker_lease' using errcode = 'P0001';
  end if;

  v_error_code := left(
    regexp_replace(lower(coalesce(p_error_code, 'worker_failed')), '[^a-z0-9_]+', '', 'g'),
    120
  );
  if v_error_code = '' then
    v_error_code := 'worker_failed';
  end if;

  if p_retryable and v_job.attempt_count < 3 then
    update public.video_generation_jobs
    set status = 'queued',
        worker_id = null,
        worker_lease_token = null,
        lease_expires_at = null,
        error_code = v_error_code,
        updated_at = now()
    where id = v_job.id;

    return jsonb_build_object(
      'job_id', v_job.id,
      'status', 'queued',
      'retry_scheduled', true
    );
  end if;

  return public.video_finalize_generation(
    v_job.user_id,
    v_job.id,
    'failed',
    null,
    v_error_code
  );
end;
$$;

revoke all on function public.video_reserve_generation(
  uuid, text, text, text, text, text, smallint, text, text, bigint
) from public, anon, authenticated;
revoke all on function public.video_finalize_generation(
  uuid, uuid, text, text, text
) from public, anon, authenticated;
revoke all on function public.video_cancel_queued_generation(
  uuid, uuid, text
) from public, anon, authenticated;
revoke all on function public.video_grant_credit_pack(
  uuid, text, bigint, integer, text, text
) from public, anon, authenticated;
revoke all on function public.video_revoke_refunded_pack(text)
  from public, anon, authenticated;
revoke all on function public.video_claim_generation(text, integer)
  from public, anon, authenticated;
revoke all on function public.video_heartbeat_generation(
  uuid, text, text, integer
) from public, anon, authenticated;
revoke all on function public.video_validate_generation_lease(
  uuid, text, text
) from public, anon, authenticated;
revoke all on function public.video_complete_claimed_generation(
  uuid, text, text, text
) from public, anon, authenticated;
revoke all on function public.video_fail_claimed_generation(
  uuid, text, text, text, boolean
) from public, anon, authenticated;

grant execute on function public.video_reserve_generation(
  uuid, text, text, text, text, text, smallint, text, text, bigint
) to service_role;
grant execute on function public.video_finalize_generation(
  uuid, uuid, text, text, text
) to service_role;
grant execute on function public.video_cancel_queued_generation(
  uuid, uuid, text
) to service_role;
grant execute on function public.video_grant_credit_pack(
  uuid, text, bigint, integer, text, text
) to service_role;
grant execute on function public.video_revoke_refunded_pack(text)
  to service_role;
grant execute on function public.video_claim_generation(text, integer)
  to service_role;
grant execute on function public.video_heartbeat_generation(
  uuid, text, text, integer
) to service_role;
grant execute on function public.video_validate_generation_lease(
  uuid, text, text
) to service_role;
grant execute on function public.video_complete_claimed_generation(
  uuid, text, text, text
) to service_role;
grant execute on function public.video_fail_claimed_generation(
  uuid, text, text, text, boolean
) to service_role;

comment on table public.video_credit_accounts is
  'Service-role-managed balances for first-party paid video generation.';
comment on table public.video_generation_jobs is
  'First-party GPU video jobs with bounded leases and retry accounting.';
comment on table public.video_credit_ledger is
  'Immutable accounting entries for video credits, reservations, settlements, and refunds.';
