-- Migration for Issue #2664: AI Generated Asset Commercial License & Copyright Compliance

create table if not exists public.ai_compliance_checklist_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null unique check (rule_key ~ '^[a-z0-9_]{3,80}$'),
  ai_provider text not null default 'general' check (
    ai_provider in ('elevenlabs', 'leonardo_ai', 'general', 'd_id')
  ),
  title text not null check (char_length(trim(title)) between 1 and 200),
  disclaimer_body text not null check (
    char_length(trim(disclaimer_body)) between 1 and 2000
  ),
  is_required boolean not null default true,
  is_active boolean not null default true,
  sort_order integer not null default 100 check (sort_order between 0 and 10000),
  terms_version text not null default '2026-11' check (
    char_length(trim(terms_version)) between 1 and 40
  ),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_compliance_rules_active_sort
  on public.ai_compliance_checklist_rules (is_active, sort_order, rule_key);

insert into public.ai_compliance_checklist_rules (
  rule_key,
  ai_provider,
  title,
  disclaimer_body,
  is_required,
  is_active,
  sort_order,
  terms_version
) values
  (
    'elevenlabs_paid_at_generation',
    'elevenlabs',
    'ElevenLabs 生成時点の有料プラン契約確認',
    'ElevenLabs Free プランおよび Beta 機能による生成物は商用・本番利用不可です（クレジット表記や生成後の有料プラン加入による遡及適用も不可）。素材生成時点で有効な Paid プランを契約していたことを確認してください。',
    true,
    true,
    10,
    '2026-11'
  ),
  (
    'leonardo_paid_private_ownership',
    'leonardo_ai',
    'Leonardo.Ai プラン区分・知的財産帰属確認',
    'Leonardo.Ai Free プランの生成物は公開ギャラリー対象となりプラットフォーム側への広範な利用許諾・学習利用が伴います。商用ブランドや非公開案件では有料プランおよび権利帰属条件を満たしていることを確認してください。',
    true,
    true,
    20,
    '2026-11'
  ),
  (
    'copyright_non_similarity_no_reliance',
    'general',
    '著作権侵害（依拠性・類似性）非該当の確認',
    '既存の保護された著作物を参照・入力して実質的に類似した出力を作成していないこと（依拠性・類似性の排除）を確認してください。',
    true,
    true,
    30,
    '2026-11'
  ),
  (
    'third_party_likeness_trademark_clear',
    'general',
    '第三者の肖像権・パブリシティ権・商標権の確認',
    '実在人物の肖像・声質や第三者の登録商標・キャラクターを許諾なく模倣・含有していないことを確認してください。',
    true,
    true,
    40,
    '2026-11'
  )
on conflict (rule_key) do nothing;

create table if not exists public.ai_commercial_asset_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  asset_title text not null check (char_length(trim(asset_title)) between 1 and 200),
  ai_provider text not null check (
    ai_provider in ('elevenlabs', 'leonardo_ai', 'general', 'd_id')
  ),
  plan_tier_at_generation text not null check (
    plan_tier_at_generation in ('free', 'paid', 'enterprise')
  ),
  commercial_license_verified boolean not null default false,
  copyright_non_similarity_confirmed boolean not null default false,
  accepted_rule_ids jsonb not null default '[]'::jsonb check (
    jsonb_typeof(accepted_rule_ids) = 'array'
  ),
  publish_status text not null default 'draft' check (
    publish_status in ('draft', 'cleared', 'blocked')
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    publish_status <> 'cleared'
    or (
      plan_tier_at_generation <> 'free'
      and commercial_license_verified = true
      and copyright_non_similarity_confirmed = true
    )
  )
);

create index if not exists idx_ai_commercial_submissions_user_created
  on public.ai_commercial_asset_submissions (user_id, created_at desc);

create table if not exists public.ai_compliance_consent_audit_logs (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.ai_commercial_asset_submissions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  accepted_rule_keys jsonb not null default '[]'::jsonb check (
    jsonb_typeof(accepted_rule_keys) = 'array'
  ),
  disclaimer_snapshot jsonb not null default '[]'::jsonb check (
    jsonb_typeof(disclaimer_snapshot) = 'array'
  ),
  consented_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_compliance_audit_logs_user_consented
  on public.ai_compliance_consent_audit_logs (user_id, consented_at desc);

alter table public.ai_compliance_checklist_rules enable row level security;
alter table public.ai_commercial_asset_submissions enable row level security;
alter table public.ai_compliance_consent_audit_logs enable row level security;

revoke all on table public.ai_compliance_checklist_rules from public, anon, authenticated;
grant select on table public.ai_compliance_checklist_rules to authenticated;
grant all on table public.ai_compliance_checklist_rules to service_role;

revoke all on table public.ai_commercial_asset_submissions from public, anon, authenticated;
grant select on table public.ai_commercial_asset_submissions to authenticated;
grant all on table public.ai_commercial_asset_submissions to service_role;

revoke all on table public.ai_compliance_consent_audit_logs from public, anon, authenticated;
grant select on table public.ai_compliance_consent_audit_logs to authenticated;
grant all on table public.ai_compliance_consent_audit_logs to service_role;

drop policy if exists "ai_compliance_checklist_rules_select_authenticated"
  on public.ai_compliance_checklist_rules;
create policy "ai_compliance_checklist_rules_select_authenticated"
  on public.ai_compliance_checklist_rules
  for select
  to authenticated
  using (true);

drop policy if exists "ai_commercial_asset_submissions_select_owner_or_admin"
  on public.ai_commercial_asset_submissions;
create policy "ai_commercial_asset_submissions_select_owner_or_admin"
  on public.ai_commercial_asset_submissions
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_compliance_consent_audit_logs_select_owner_or_admin"
  on public.ai_compliance_consent_audit_logs;
create policy "ai_compliance_consent_audit_logs_select_owner_or_admin"
  on public.ai_compliance_consent_audit_logs
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.user_profiles up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_ai_compliance_checklist_rules()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_jwt_role text := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service boolean := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_rule_rpc boolean :=
    coalesce(current_setting('app.ai_compliance_rule_rpc_active', true), '') = 'on';
begin
  if TG_OP = 'DELETE' then
    if not v_is_service then
      raise exception 'ai_compliance_checklist_rules cannot be deleted directly'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if not v_is_service and not v_rule_rpc then
    raise exception 'ai_compliance_checklist_rules mutations require admin RPC or service_role'
      using errcode = '42501';
  end if;

  if TG_OP = 'UPDATE' and new.id is distinct from old.id then
    raise exception 'id is immutable on ai_compliance_checklist_rules'
      using errcode = '42501';
  end if;

  new.updated_at := timezone('utc', now());
  return new;
end;
$guard$;

drop trigger if exists guard_ai_compliance_checklist_rules
  on public.ai_compliance_checklist_rules;
create trigger guard_ai_compliance_checklist_rules
  before insert or update or delete on public.ai_compliance_checklist_rules
  for each row
  execute function public.guard_ai_compliance_checklist_rules();

create or replace function public.guard_ai_commercial_asset_submissions()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_jwt_role text := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service boolean := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_rpc_active boolean :=
    coalesce(current_setting('app.ai_compliance_rpc_active', true), '') = 'on';
begin
  if TG_OP = 'DELETE' then
    if not v_is_service then
      raise exception 'ai_commercial_asset_submissions cannot be deleted directly'
        using errcode = '42501';
    end if;
    return old;
  end if;

  if not v_is_service and not v_rpc_active then
    raise exception 'ai_commercial_asset_submissions must go through submit_ai_commercial_compliance'
      using errcode = '42501';
  end if;

  if TG_OP = 'INSERT' then
    new.created_at := coalesce(new.created_at, timezone('utc', now()));
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if new.id is distinct from old.id
    or new.user_id is distinct from old.user_id
    or new.created_at is distinct from old.created_at then
    raise exception 'id, user_id, and created_at are immutable'
      using errcode = '42501';
  end if;

  new.updated_at := timezone('utc', now());
  return new;
end;
$guard$;

drop trigger if exists guard_ai_commercial_asset_submissions
  on public.ai_commercial_asset_submissions;
create trigger guard_ai_commercial_asset_submissions
  before insert or update or delete on public.ai_commercial_asset_submissions
  for each row
  execute function public.guard_ai_commercial_asset_submissions();

create or replace function public.guard_ai_compliance_consent_audit_logs_immutable()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_jwt_role text := coalesce(
    nullif(auth.jwt() ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    ''
  );
  v_is_service boolean := (v_jwt_role = 'service_role')
    or (
      v_jwt_role = ''
      and session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
    );
  v_rpc_active boolean :=
    coalesce(current_setting('app.ai_compliance_rpc_active', true), '') = 'on';
begin
  if TG_OP in ('UPDATE', 'DELETE') then
    raise exception 'ai_compliance_consent_audit_logs is append-only; UPDATE and DELETE are forbidden'
      using errcode = '42501';
  end if;

  if not v_is_service and not v_rpc_active then
    raise exception 'ai_compliance_consent_audit_logs inserts require submit_ai_commercial_compliance'
      using errcode = '42501';
  end if;

  new.consented_at := coalesce(new.consented_at, timezone('utc', now()));
  return new;
end;
$guard$;

drop trigger if exists guard_ai_compliance_consent_audit_logs_immutable
  on public.ai_compliance_consent_audit_logs;
create trigger guard_ai_compliance_consent_audit_logs_immutable
  before insert or update or delete on public.ai_compliance_consent_audit_logs
  for each row
  execute function public.guard_ai_compliance_consent_audit_logs_immutable();

create or replace function public.submit_ai_commercial_compliance(
  p_asset_title text,
  p_ai_provider text,
  p_plan_tier_at_generation text,
  p_commercial_license_verified boolean,
  p_copyright_non_similarity_confirmed boolean,
  p_accepted_rule_ids jsonb default '[]'::jsonb
)
returns public.ai_commercial_asset_submissions
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_provider text := lower(trim(coalesce(p_ai_provider, '')));
  v_tier text := lower(trim(coalesce(p_plan_tier_at_generation, '')));
  v_title text := trim(coalesce(p_asset_title, ''));
  v_accepted_ids jsonb := coalesce(p_accepted_rule_ids, '[]'::jsonb);
  v_missing_count integer := 0;
  v_accepted_keys jsonb := '[]'::jsonb;
  v_disclaimer_snapshot jsonb := '[]'::jsonb;
  v_created public.ai_commercial_asset_submissions;
begin
  if v_uid is null then
    raise exception 'Authentication required to submit commercial compliance'
      using errcode = '42501';
  end if;

  if char_length(v_title) = 0 then
    raise exception 'Asset title is required'
      using errcode = '22023';
  end if;

  if v_tier = 'free' then
    raise exception 'Free plan AI assets cannot be cleared for commercial publication'
      using errcode = '42501';
  end if;

  if coalesce(p_commercial_license_verified, false) = false
    or coalesce(p_copyright_non_similarity_confirmed, false) = false then
    raise exception 'Both commercial license verification and copyright clearance are required'
      using errcode = '42501';
  end if;

  if jsonb_typeof(v_accepted_ids) <> 'array' then
    raise exception 'accepted_rule_ids must be a JSON array'
      using errcode = '22023';
  end if;

  select count(*)
  into v_missing_count
  from public.ai_compliance_checklist_rules r
  where r.is_active = true
    and r.is_required = true
    and r.ai_provider in ('general', v_provider)
    and not exists (
      select 1
      from jsonb_array_elements_text(v_accepted_ids) elem
      where elem = r.id::text
    );

  if v_missing_count > 0 then
    raise exception 'All active required compliance checklist rules must be accepted (missing: %)', v_missing_count
      using errcode = '42501';
  end if;

  select
    coalesce(jsonb_agg(r.rule_key order by r.sort_order, r.rule_key), '[]'::jsonb),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'rule_id', r.id,
          'rule_key', r.rule_key,
          'title', r.title,
          'terms_version', r.terms_version,
          'disclaimer_body', r.disclaimer_body
        )
        order by r.sort_order, r.rule_key
      ),
      '[]'::jsonb
    )
  into v_accepted_keys, v_disclaimer_snapshot
  from public.ai_compliance_checklist_rules r
  where r.is_active = true
    and r.id::text in (
      select elem
      from jsonb_array_elements_text(v_accepted_ids) elem
    );

  perform set_config('app.ai_compliance_rpc_active', 'on', true);

  insert into public.ai_commercial_asset_submissions (
    user_id,
    asset_title,
    ai_provider,
    plan_tier_at_generation,
    commercial_license_verified,
    copyright_non_similarity_confirmed,
    accepted_rule_ids,
    publish_status
  ) values (
    v_uid,
    v_title,
    v_provider,
    v_tier,
    true,
    true,
    v_accepted_ids,
    'cleared'
  )
  returning * into v_created;

  insert into public.ai_compliance_consent_audit_logs (
    submission_id,
    user_id,
    accepted_rule_keys,
    disclaimer_snapshot
  ) values (
    v_created.id,
    v_uid,
    v_accepted_keys,
    v_disclaimer_snapshot
  );

  perform set_config('app.ai_compliance_rpc_active', 'off', true);
  return v_created;
exception
  when others then
    perform set_config('app.ai_compliance_rpc_active', 'off', true);
    raise;
end;
$fn$;

revoke all on function public.submit_ai_commercial_compliance(
  text, text, text, boolean, boolean, jsonb
) from public, anon;
grant execute on function public.submit_ai_commercial_compliance(
  text, text, text, boolean, boolean, jsonb
) to authenticated, service_role;

create or replace function public.upsert_ai_compliance_checklist_rule(
  p_rule_key text,
  p_ai_provider text,
  p_title text,
  p_disclaimer_body text,
  p_is_required boolean default true,
  p_is_active boolean default true,
  p_sort_order integer default 100,
  p_terms_version text default '2026-11'
)
returns public.ai_compliance_checklist_rules
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_is_admin boolean := false;
  v_saved public.ai_compliance_checklist_rules;
begin
  if v_uid is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select exists (
    select 1
    from public.user_profiles up
    where up.user_id = v_uid
      and up.is_admin = true
  )
  into v_is_admin;

  if not v_is_admin then
    raise exception 'Admin role required to update compliance checklist rules'
      using errcode = '42501';
  end if;

  perform set_config('app.ai_compliance_rule_rpc_active', 'on', true);

  insert into public.ai_compliance_checklist_rules (
    rule_key,
    ai_provider,
    title,
    disclaimer_body,
    is_required,
    is_active,
    sort_order,
    terms_version
  ) values (
    lower(trim(p_rule_key)),
    lower(trim(p_ai_provider)),
    trim(p_title),
    trim(p_disclaimer_body),
    coalesce(p_is_required, true),
    coalesce(p_is_active, true),
    coalesce(p_sort_order, 100),
    coalesce(nullif(trim(p_terms_version), ''), '2026-11')
  )
  on conflict (rule_key) do update set
    ai_provider = excluded.ai_provider,
    title = excluded.title,
    disclaimer_body = excluded.disclaimer_body,
    is_required = excluded.is_required,
    is_active = excluded.is_active,
    sort_order = excluded.sort_order,
    terms_version = excluded.terms_version,
    updated_at = timezone('utc', now())
  returning * into v_saved;

  perform set_config('app.ai_compliance_rule_rpc_active', 'off', true);
  return v_saved;
exception
  when others then
    perform set_config('app.ai_compliance_rule_rpc_active', 'off', true);
    raise;
end;
$fn$;

revoke all on function public.upsert_ai_compliance_checklist_rule(
  text, text, text, text, boolean, boolean, integer, text
) from public, anon;
grant execute on function public.upsert_ai_compliance_checklist_rule(
  text, text, text, text, boolean, boolean, integer, text
) to authenticated, service_role;
