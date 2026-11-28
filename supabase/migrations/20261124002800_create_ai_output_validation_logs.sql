-- Migration for Issue #2657: Deterministic AI output validation logs and drift audit

create table if not exists public.ai_output_validation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  rule_set_version text not null default 'v1.0'
    check (char_length(trim(rule_set_version)) between 1 and 64),
  decision text not null
    check (decision in ('passed', 'remediated', 'blocked')),
  format_contract text not null default 'markdown_sections'
    check (format_contract in ('markdown_sections', 'json_object', 'concise_summary', 'plain_text')),
  prompt_excerpt text not null
    check (char_length(trim(prompt_excerpt)) between 1 and 1000),
  original_output_excerpt text not null default ''
    check (char_length(original_output_excerpt) <= 2000),
  remediated_output_excerpt text not null default ''
    check (char_length(remediated_output_excerpt) <= 2000),
  violations jsonb not null default '[]'::jsonb
    check (jsonb_typeof(violations) = 'array'),
  violation_count integer not null default 0
    check (violation_count >= 0),
  drift_score numeric(5,4) not null default 0.0000
    check (drift_score >= 0 and drift_score <= 1),
  reviewed_by_admin boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_ai_output_validation_logs_user_created
  on public.ai_output_validation_logs (user_id, created_at desc);

create index if not exists idx_ai_output_validation_logs_decision_created
  on public.ai_output_validation_logs (decision, created_at desc);

create index if not exists idx_ai_output_validation_logs_rule_version_created
  on public.ai_output_validation_logs (rule_set_version, created_at desc);

alter table public.ai_output_validation_logs enable row level security;

revoke all on table public.ai_output_validation_logs from public, anon, authenticated;
grant select, update on table public.ai_output_validation_logs to authenticated;
grant all on table public.ai_output_validation_logs to service_role;

drop policy if exists "ai_output_validation_logs_select_own_or_admin"
  on public.ai_output_validation_logs;
create policy "ai_output_validation_logs_select_own_or_admin"
  on public.ai_output_validation_logs
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

drop policy if exists "ai_output_validation_logs_insert_own"
  on public.ai_output_validation_logs;

drop policy if exists "ai_output_validation_logs_update_admin"
  on public.ai_output_validation_logs;
create policy "ai_output_validation_logs_update_admin"
  on public.ai_output_validation_logs
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  )
  with check (
    exists (
      select 1
      from public.user_profiles as up
      where up.user_id = auth.uid()
        and up.is_admin = true
    )
  );

create or replace function public.guard_ai_output_validation_log_fields()
returns trigger
language plpgsql
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $guard$
declare
  v_jwt jsonb := null;
  v_claims jsonb := null;
  jwt_role text;
  caller_is_admin boolean;
  v_rpc_active boolean :=
    coalesce(current_setting('app.ai_output_validation_rpc_active', true), '') = 'on';
begin
  begin
    v_jwt := auth.jwt();
  exception
    when others then
      v_jwt := null;
  end;

  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    if jsonb_typeof(v_claims) <> 'object' then
      v_claims := null;
    end if;
  exception
    when others then
      v_claims := null;
  end;

  jwt_role := coalesce(
    nullif(v_jwt ->> 'role', ''),
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(v_claims ->> 'role', ''),
    ''
  );

  if tg_op = 'DELETE' then
    if not (
      jwt_role = 'service_role'
      or (
        session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
        and jwt_role = ''
      )
    ) then
      raise exception 'ai_output_validation_logs records cannot be deleted directly'
        using errcode = '42501';
    end if;
    return old;
  end if;

  new.violation_count := coalesce(jsonb_array_length(new.violations), 0);

  if new.decision in ('remediated', 'blocked') and new.violation_count = 0 then
    raise exception 'Remediated or blocked validation logs must record at least one violation'
      using errcode = '23514';
  end if;
  if new.decision = 'passed' and new.violation_count > 0 then
    raise exception 'Passed validation logs cannot record violations'
      using errcode = '23514';
  end if;

  if jwt_role = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and jwt_role = ''
     ) then
    if tg_op = 'INSERT' then
      new.created_at := coalesce(new.created_at, timezone('utc', now()));
    end if;
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  caller_is_admin := exists (
    select 1
    from public.user_profiles as up
    where up.user_id = auth.uid()
      and up.is_admin = true
  );

  if tg_op = 'INSERT' then
    if not v_rpc_active then
      raise exception 'ai_output_validation_logs inserts must go through record_ai_output_validation'
        using errcode = '42501';
    end if;
    if auth.uid() is null or new.user_id is distinct from auth.uid() then
      raise exception 'Authenticated owner user_id is required on insert'
        using errcode = '42501';
    end if;
    if new.reviewed_by_admin is distinct from false then
      raise exception 'Clients cannot set reviewed_by_admin on insert'
        using errcode = '42501';
    end if;
    new.created_at := timezone('utc', now());
    new.updated_at := timezone('utc', now());
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if not caller_is_admin then
      raise exception 'Only administrators may update validation audit logs'
        using errcode = '42501';
    end if;
    if new.id is distinct from old.id
       or new.user_id is distinct from old.user_id
       or new.rule_set_version is distinct from old.rule_set_version
       or new.decision is distinct from old.decision
       or new.format_contract is distinct from old.format_contract
       or new.prompt_excerpt is distinct from old.prompt_excerpt
       or new.original_output_excerpt is distinct from old.original_output_excerpt
       or new.remediated_output_excerpt is distinct from old.remediated_output_excerpt
       or new.violations is distinct from old.violations
       or new.violation_count is distinct from old.violation_count
       or new.drift_score is distinct from old.drift_score
       or new.created_at is distinct from old.created_at then
      raise exception 'Immutable validation audit columns cannot be altered'
        using errcode = '42501';
    end if;
    new.updated_at := timezone('utc', now());
  end if;

  return new;
end;
$guard$;

revoke all on function public.guard_ai_output_validation_log_fields() from public, anon, authenticated;

drop trigger if exists guard_ai_output_validation_log_fields
  on public.ai_output_validation_logs;
create trigger guard_ai_output_validation_log_fields
  before insert or update or delete on public.ai_output_validation_logs
  for each row
  execute function public.guard_ai_output_validation_log_fields();

create or replace function public.record_ai_output_validation(
  p_prompt text,
  p_candidate_output text,
  p_format_contract text default 'markdown_sections',
  p_required_headings text[] default array['## 結論', '## 根拠'],
  p_required_fields text[] default array[]::text[],
  p_banned_terms text[] default array[]::text[],
  p_max_length integer default 4000
)
returns public.ai_output_validation_logs
language plpgsql
security definer
set search_path = public, auth, pg_catalog, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_contract text := lower(trim(coalesce(p_format_contract, 'markdown_sections')));
  v_working text := trim(coalesce(p_candidate_output, ''));
  v_violations jsonb := '[]'::jsonb;
  v_pii_masked text;
  v_raw_term text;
  v_term text;
  v_term_re text;
  v_decoded jsonb;
  v_invalid_json boolean := false;
  v_field text;
  v_headings text[];
  v_heading text;
  v_limit integer;
  v_has_block boolean := false;
  v_has_remediate boolean := false;
  v_decision text := 'passed';
  v_drift numeric(8,4) := 0;
  v_item jsonb;
  v_sev text;
  v_safe_prompt text;
  v_safe_original text;
  v_safe_remediated text;
  v_cred_re text := '(sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sb_secret_[A-Za-z0-9_]{12,}|AIza[0-9A-Za-z_-]{30,})';
  v_email_re text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_phone_re text := '0[0-9]{1,4}-[0-9]{1,4}-[0-9]{3,4}';
  v_row public.ai_output_validation_logs;
begin
  if v_uid is null then
    raise exception 'Authenticated user required to record validation log'
      using errcode = '42501';
  end if;

  if v_contract = '' then
    v_contract := 'markdown_sections';
  end if;
  if v_contract not in ('markdown_sections', 'json_object', 'concise_summary', 'plain_text') then
    raise exception 'Invalid format_contract: %', v_contract
      using errcode = '22023';
  end if;

  v_safe_prompt := trim(
    regexp_replace(
      regexp_replace(
        regexp_replace(coalesce(p_prompt, ''), v_email_re, '***', 'gi'),
        v_phone_re,
        '***',
        'g'
      ),
      v_cred_re,
      '***',
      'g'
    )
  );
  if char_length(v_safe_prompt) > 1000 then
    v_safe_prompt := left(v_safe_prompt, 997) || '...';
  end if;
  if v_safe_prompt = '' then
    v_safe_prompt := '(empty-prompt)';
  end if;

  v_safe_original := trim(
    regexp_replace(
      regexp_replace(
        regexp_replace(coalesce(p_candidate_output, ''), v_email_re, '***', 'gi'),
        v_phone_re,
        '***',
        'g'
      ),
      v_cred_re,
      '***',
      'g'
    )
  );
  if char_length(v_safe_original) > 2000 then
    v_safe_original := left(v_safe_original, 1997) || '...';
  end if;

  if v_working = '' then
    v_violations := jsonb_build_array(
      jsonb_build_object(
        'code', 'empty_output',
        'severity', 'block',
        'message', 'AI出力が空のためブロックしました。'
      )
    );
    perform set_config('app.ai_output_validation_rpc_active', 'on', true);
    insert into public.ai_output_validation_logs (
      user_id,
      rule_set_version,
      decision,
      format_contract,
      prompt_excerpt,
      original_output_excerpt,
      remediated_output_excerpt,
      violations,
      violation_count,
      drift_score,
      reviewed_by_admin
    ) values (
      v_uid,
      'v1.0',
      'blocked',
      v_contract,
      v_safe_prompt,
      '',
      '[BLOCKED]',
      v_violations,
      1,
      0.5000,
      false
    )
    returning * into v_row;
    perform set_config('app.ai_output_validation_rpc_active', 'off', true);
    return v_row;
  end if;

  if v_working ~* '(SYSTEM_PROMPT:|BEGIN_INTERNAL_INSTRUCTIONS|DEVELOPER_POLICY_OVERRIDE)' then
    v_violations := v_violations || jsonb_build_array(
      jsonb_build_object(
        'code', 'system_prompt_leak_marker',
        'severity', 'block',
        'message', '内部システムプロンプト露出マーカーを検出したため出力をブロックしました。'
      )
    );
  end if;

  if v_working ~* '(100%[[:space:]]*guaranteed[[:space:]]*(profit|return)|確実に儲かる|元本保証で必ず増える|絶対に副作用はありません|医学的診断を確定します)' then
    v_violations := v_violations || jsonb_build_array(
      jsonb_build_object(
        'code', 'ungrounded_absolute_guarantee',
        'severity', 'block',
        'message', '根拠のない断定的保証表現を検出したため出力をブロックしました。'
      )
    );
  end if;

  if v_working ~ v_cred_re then
    v_violations := v_violations || jsonb_build_array(
      jsonb_build_object(
        'code', 'compliance_pii_credential',
        'severity', 'block',
        'message', '認証トークンリテラルを検出したため出力をブロックしました。'
      )
    );
  end if;

  v_pii_masked := regexp_replace(
    regexp_replace(v_working, v_email_re, '***', 'gi'),
    v_phone_re,
    '***',
    'g'
  );
  if v_pii_masked is distinct from v_working then
    v_working := v_pii_masked;
    v_violations := v_violations || jsonb_build_array(
      jsonb_build_object(
        'code', 'compliance_pii_masked',
        'severity', 'remediate',
        'message', '連絡先等の機微情報を自動マスクしました。'
      )
    );
  end if;

  if v_working ~* '\m(TODO_PLACEHOLDER|FIXME_OUTPUT|LOREM_IPSUM_PLACEHOLDER)\M' then
    v_working := trim(
      regexp_replace(
        v_working,
        '\m(TODO_PLACEHOLDER|FIXME_OUTPUT|LOREM_IPSUM_PLACEHOLDER)\M',
        '[REMOVED]',
        'gi'
      )
    );
    v_violations := v_violations || jsonb_build_array(
      jsonb_build_object(
        'code', 'degenerate_placeholder_token',
        'severity', 'remediate',
        'message', '未完成プレースホルダートークンを除去しました。'
      )
    );
  end if;

  if p_banned_terms is not null then
    foreach v_raw_term in array p_banned_terms loop
      v_term := trim(coalesce(v_raw_term, ''));
      if v_term <> '' then
        v_term_re := regexp_replace(
          v_term,
          '([.\\+*?\[\]^$(){}=!<>|:-])',
          '\\\1',
          'g'
        );
        if position(lower(v_term) in lower(v_working)) > 0 then
          v_working := trim(regexp_replace(v_working, v_term_re, '[REMOVED]', 'gi'));
          v_violations := v_violations || jsonb_build_array(
            jsonb_build_object(
              'code', 'custom_banned_term_remediated',
              'severity', 'remediate',
              'message', '指定禁止語句を自動除去しました。'
            )
          );
        end if;
      end if;
    end loop;
  end if;

  if v_contract = 'json_object' then
    if v_working ~ '^```(json|JSON)?[[:space:]]*\r?\n' and v_working ~ '\r?\n```$' then
      v_working := trim(
        regexp_replace(
          regexp_replace(v_working, '^```(json|JSON)?[[:space:]]*\r?\n', '', 'i'),
          '\r?\n```$',
          ''
        )
      );
      v_violations := v_violations || jsonb_build_array(
        jsonb_build_object(
          'code', 'json_code_fence_stripped',
          'severity', 'remediate',
          'message', 'JSON周囲のMarkdownコードフェンスを除去しました。'
        )
      );
    end if;

    begin
      v_decoded := v_working::jsonb;
    exception
      when others then
        v_invalid_json := true;
    end;

    if v_invalid_json then
      v_violations := v_violations || jsonb_build_array(
        jsonb_build_object(
          'code', 'invalid_json_syntax',
          'severity', 'block',
          'message', 'JSON構文のパースに失敗しました。'
        )
      );
    elsif jsonb_typeof(v_decoded) <> 'object' then
      v_violations := v_violations || jsonb_build_array(
        jsonb_build_object(
          'code', 'invalid_json_object_type',
          'severity', 'block',
          'message', 'JSON出力はオブジェクト形式である必要があります。'
        )
      );
    else
      if p_required_fields is not null then
        foreach v_field in array p_required_fields loop
          v_field := trim(coalesce(v_field, ''));
          if v_field <> '' then
            if (v_decoded -> v_field) is null
              or (v_decoded -> v_field) = 'null'::jsonb
              or (
                jsonb_typeof(v_decoded -> v_field) = 'string'
                and trim(v_decoded ->> v_field) = ''
              ) then
              v_violations := v_violations || jsonb_build_array(
                jsonb_build_object(
                  'code', 'missing_required_field_' || v_field,
                  'severity', 'block',
                  'message', '必須JSONフィールド「' || v_field || '」が欠落しています。'
                )
              );
            end if;
          end if;
        end loop;
      end if;
      v_working := v_decoded::text;
    end if;
  elsif v_contract = 'markdown_sections' then
    if coalesce(array_length(p_required_headings, 1), 0) > 0 then
      v_headings := p_required_headings;
    else
      v_headings := array['## 結論', '## 根拠'];
    end if;
    foreach v_heading in array v_headings loop
      v_heading := trim(coalesce(v_heading, ''));
      if v_heading <> '' and position(v_heading in v_working) = 0 then
        v_violations := v_violations || jsonb_build_array(
          jsonb_build_object(
            'code', 'missing_required_markdown_heading',
            'severity', 'block',
            'message', '必須Markdown見出し「' || v_heading || '」が不足しています。'
          )
        );
      end if;
    end loop;
  elsif v_contract = 'concise_summary' then
    v_limit := greatest(40, least(coalesce(p_max_length, 4000), 20000));
    if char_length(v_working) > v_limit then
      v_working := rtrim(left(v_working, v_limit - 3)) || '...';
      v_violations := v_violations || jsonb_build_array(
        jsonb_build_object(
          'code', 'summary_max_length_truncated',
          'severity', 'remediate',
          'message', '上限文字数 (' || v_limit::text || ') を超過したため短縮しました。'
        )
      );
    end if;
  end if;

  for v_item in select value from jsonb_array_elements(v_violations) loop
    v_sev := v_item ->> 'severity';
    if v_sev = 'block' then
      v_has_block := true;
      v_drift := v_drift + 0.5;
    elsif v_sev = 'remediate' then
      v_has_remediate := true;
      v_drift := v_drift + 0.2;
    else
      v_drift := v_drift + 0.05;
    end if;
  end loop;

  if v_has_block then
    v_decision := 'blocked';
  elsif v_has_remediate or jsonb_array_length(v_violations) > 0 then
    v_decision := 'remediated';
  else
    v_decision := 'passed';
  end if;

  if v_decision = 'blocked' then
    v_safe_remediated := '[BLOCKED]';
  else
    v_safe_remediated := trim(
      regexp_replace(
        regexp_replace(
          regexp_replace(v_working, v_email_re, '***', 'gi'),
          v_phone_re,
          '***',
          'g'
        ),
        v_cred_re,
        '***',
        'g'
      )
    );
    if char_length(v_safe_remediated) > 2000 then
      v_safe_remediated := left(v_safe_remediated, 1997) || '...';
    end if;
  end if;

  perform set_config('app.ai_output_validation_rpc_active', 'on', true);
  insert into public.ai_output_validation_logs (
    user_id,
    rule_set_version,
    decision,
    format_contract,
    prompt_excerpt,
    original_output_excerpt,
    remediated_output_excerpt,
    violations,
    violation_count,
    drift_score,
    reviewed_by_admin
  ) values (
    v_uid,
    'v1.0',
    v_decision,
    v_contract,
    v_safe_prompt,
    v_safe_original,
    v_safe_remediated,
    v_violations,
    jsonb_array_length(v_violations),
    round(least(greatest(v_drift, 0), 1), 4),
    false
  )
  returning * into v_row;
  perform set_config('app.ai_output_validation_rpc_active', 'off', true);
  return v_row;
exception
  when others then
    perform set_config('app.ai_output_validation_rpc_active', 'off', true);
    raise;
end;
$fn$;

revoke all on function public.record_ai_output_validation(
  text, text, text, text[], text[], text[], integer
) from public, anon;
grant execute on function public.record_ai_output_validation(
  text, text, text, text[], text[], text[], integer
) to authenticated, service_role;

create or replace function public.get_ai_output_validation_summary(
  p_days integer default 7
)
returns table (
  decision text,
  total_count bigint,
  avg_drift_score numeric
)
language sql
stable
security invoker
set search_path = public, auth, pg_catalog, pg_temp
as $$
  select
    l.decision,
    count(*)::bigint as total_count,
    round(coalesce(avg(l.drift_score), 0), 4) as avg_drift_score
  from public.ai_output_validation_logs as l
  where l.created_at >= timezone('utc', now())
    - make_interval(days => greatest(1, least(coalesce(p_days, 7), 90)))
  group by l.decision
  order by l.decision asc;
$$;

revoke all on function public.get_ai_output_validation_summary(integer) from public, anon;
grant execute on function public.get_ai_output_validation_summary(integer) to authenticated, service_role;

comment on table public.ai_output_validation_logs is
  'Stores deterministic validation decisions, masked excerpts, violations, and drift scores for emergent AI outputs (#2657).';
