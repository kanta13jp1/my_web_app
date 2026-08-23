begin;

create or replace function pg_temp.assert_true(
  condition boolean,
  failure_message text
)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition, false) then
    raise exception 'artifact publishing contract failed: %', failure_message;
  end if;
end;
$$;

insert into auth.users (id)
values
  ('a1111111-1111-4111-8111-111111111111'),
  ('a2222222-2222-4222-8222-222222222222');

insert into public.user_profiles (user_id, is_admin, is_public)
values
  ('a1111111-1111-4111-8111-111111111111', true, false),
  ('a2222222-2222-4222-8222-222222222222', false, false);

insert into public.shop_products (
  id, name_ja, summary_ja, price_jpy, stripe_price_id,
  storage_bucket, storage_path, version, file_size_bytes, sha256, is_active
)
values (
  'artifact-contract-product', '契約テスト商品', 'ローカルrollback対象',
  1200, 'price_contract_only', 'product-downloads',
  'contract/artifact.zip', '1.0', 1024,
  repeat('a', 64), false
);

insert into storage.objects (bucket_id, name, metadata)
values (
  'product-downloads', 'contract/artifact.zip', '{"size": 1024}'::jsonb
);

select pg_temp.assert_true(
  not has_table_privilege('anon', 'public.artifact_candidates', 'SELECT')
  and not has_table_privilege('anon', 'public.artifact_checks', 'SELECT')
  and not has_table_privilege(
    'authenticated', 'public.artifact_publication_events', 'INSERT'
  ),
  'buyers and anonymous callers must not read candidates or forge events'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true
);

insert into public.artifact_candidates (
  id, title, artifact_sha256, mime_type, file_size_bytes, artifact_kind,
  intended_price_jpy, product_id, proposed_storage_bucket,
  proposed_storage_path, human_contribution_summary
)
values (
  'a3333333-3333-4333-8333-333333333333',
  '契約テスト成果物', repeat('a', 64), 'application/zip', 1024, 'bundle',
  1200, 'artifact-contract-product', 'product-downloads',
  'contract/artifact.zip', '人間が構成、校正、権利確認、商品説明の最終編集を担当した記録です。'
);

insert into public.artifact_provenance (
  candidate_id, source_tool, intake_method, source_locator
)
values (
  'a3333333-3333-4333-8333-333333333333',
  'codex', 'local_workspace', 'contract/artifact.zip'
);

select pg_temp.assert_true(
  (
    select count(*) = 9
    from public.artifact_checks
    where candidate_id = 'a3333333-3333-4333-8333-333333333333'
  ),
  'candidate intake must seed all nine hard gates atomically'
);

update public.artifact_candidates
set stage = 'automated_checks'
where id = 'a3333333-3333-4333-8333-333333333333';

do $$
declare
  blocked boolean := false;
begin
  begin
    update public.artifact_checks
    set status = 'pass', evidence_summary = 'premature human review'
    where candidate_id = 'a3333333-3333-4333-8333-333333333333'
      and check_key = 'third_party_license';
  exception when check_violation then
    blocked := sqlerrm = 'artifact_check_wrong_stage';
  end;
  perform pg_temp.assert_true(blocked, 'checks must be reviewed in their stage');
end;
$$;

do $$
declare
  blocked boolean := false;
begin
  begin
    update public.artifact_candidates
    set stage = 'human_review'
    where id = 'a3333333-3333-4333-8333-333333333333';
  exception when check_violation then
    blocked := sqlerrm = 'automated_risk_checks_not_passed';
  end;
  perform pg_temp.assert_true(blocked, 'PII/secrets must block human review');
end;
$$;

update public.artifact_checks
set status = 'pass', evidence_summary = 'local scanner found no matched values'
where candidate_id = 'a3333333-3333-4333-8333-333333333333'
  and check_key in ('secret_scan', 'pii_scan');

update public.artifact_candidates
set stage = 'human_review'
where id = 'a3333333-3333-4333-8333-333333333333';

update public.artifact_checks
set
  status = case
    when check_key in (
      'third_party_license', 'face_voice_consent', 'chatgpt_voice_output'
    ) then 'not_applicable'
    else 'pass'
  end,
  evidence_summary = 'reviewed locally without including sensitive values'
where candidate_id = 'a3333333-3333-4333-8333-333333333333'
  and check_key in (
    'third_party_license', 'face_voice_consent',
    'chatgpt_voice_output', 'human_contribution'
  );

update public.artifact_candidates
set stage = 'approved'
where id = 'a3333333-3333-4333-8333-333333333333';
update public.artifact_candidates
set stage = 'staged'
where id = 'a3333333-3333-4333-8333-333333333333';

reset role;
do $$
declare
  blocked boolean := false;
begin
  begin
    update public.shop_products
    set is_active = true
    where id = 'artifact-contract-product';
  exception when check_violation then
    blocked := sqlerrm = 'linked_artifact_product_not_publication_ready';
  end;
  perform pg_temp.assert_true(blocked, 'an incomplete candidate must not activate');
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true
);
update public.artifact_checks
set status = 'pass', evidence_summary = 'staged product evidence matched locally'
where candidate_id = 'a3333333-3333-4333-8333-333333333333'
  and check_key in ('price_match', 'private_object', 'content_integrity');
update public.artifact_candidates
set stage = 'ready'
where id = 'a3333333-3333-4333-8333-333333333333';

select pg_temp.assert_true(
  (
    select approved_by = 'a1111111-1111-4111-8111-111111111111'
      and approved_at is not null
    from public.artifact_candidates
    where id = 'a3333333-3333-4333-8333-333333333333'
  ),
  'human approval identity must be derived from auth.uid()'
);

select set_config(
  'request.jwt.claim.sub', 'a2222222-2222-4222-8222-222222222222', true
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.artifact_candidates
    where id = 'a3333333-3333-4333-8333-333333333333'
  ),
  'an authenticated non-admin must not read candidate rows'
);

reset role;
update public.shop_products
set is_active = true
where id = 'artifact-contract-product';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true
);
update public.artifact_candidates
set stage = 'published'
where id = 'a3333333-3333-4333-8333-333333333333';

select pg_temp.assert_true(
  (
    select count(*) >= 8
    from public.artifact_publication_events
    where candidate_id = 'a3333333-3333-4333-8333-333333333333'
  ),
  'stage, check, and activation changes must emit append-only audit events'
);

rollback;
