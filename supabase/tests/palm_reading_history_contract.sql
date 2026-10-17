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
    raise exception 'palm reading contract failed: %', failure_message;
  end if;
end;
$$;

insert into auth.users (id)
values
  ('b1111111-1111-4111-8111-111111111111'),
  ('b2222222-2222-4222-8222-222222222222');

insert into public.palm_readings (
  id,
  request_id,
  user_id,
  hand_side,
  image_path,
  image_mime_type,
  analysis,
  comparison,
  provider,
  model,
  quality_score
)
values
  (
    'b3111111-1111-4111-8111-111111111111',
    'b4111111-1111-4111-8111-111111111111',
    'b1111111-1111-4111-8111-111111111111',
    'left',
    'b1111111-1111-4111-8111-111111111111/left.jpg',
    'image/jpeg',
    '{"photo_quality":{"is_usable":true,"score":90}}'::jsonb,
    '{}'::jsonb,
    'google',
    'gemini-2.5-flash',
    90
  ),
  (
    'b3222222-2222-4222-8222-222222222222',
    'b4222222-2222-4222-8222-222222222222',
    'b2222222-2222-4222-8222-222222222222',
    'right',
    'b2222222-2222-4222-8222-222222222222/right.png',
    'image/png',
    '{"photo_quality":{"is_usable":true,"score":85}}'::jsonb,
    '{}'::jsonb,
    'google',
    'gemini-2.5-flash',
    85
  );

insert into storage.objects (bucket_id, name)
values
  (
    'palm-readings',
    'b1111111-1111-4111-8111-111111111111/left.jpg'
  ),
  (
    'palm-readings',
    'b2222222-2222-4222-8222-222222222222/right.png'
  );

select pg_temp.assert_true(
  (
    select not public
      and file_size_limit = 4194304
      and allowed_mime_types = array[
        'image/jpeg', 'image/png', 'image/webp'
      ]::text[]
    from storage.buckets
    where id = 'palm-readings'
  ),
  'palm image bucket must remain private, MIME-bounded, and limited to 4 MB'
);

select pg_temp.assert_true(
  has_table_privilege('authenticated', 'public.palm_readings', 'SELECT')
    and not has_table_privilege(
      'authenticated', 'public.palm_readings', 'INSERT'
    )
    and not has_table_privilege(
      'authenticated', 'public.palm_readings', 'UPDATE'
    )
    and not has_table_privilege(
      'authenticated', 'public.palm_readings', 'DELETE'
    )
    and not has_table_privilege('anon', 'public.palm_readings', 'SELECT')
    and has_table_privilege('service_role', 'public.palm_readings', 'INSERT')
    and has_table_privilege('service_role', 'public.palm_readings', 'DELETE'),
  'clients must be read-only owners while Edge Functions retain write access'
);

select pg_temp.assert_true(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.palm_readings'::regclass
  ),
  'row-level security must be enabled'
);

select pg_temp.assert_true(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'palm_readings'
      and indexname = 'palm_readings_user_created_idx'
  )
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'palm_readings'
      and indexname = 'palm_readings_user_hand_created_idx'
  ),
  'owner history and same-hand comparison queries must stay indexed'
);

do $$
declare
  blocked boolean := false;
begin
  begin
    insert into public.palm_readings (
      request_id,
      user_id,
      hand_side,
      image_path,
      image_mime_type,
      analysis,
      provider,
      model,
      quality_score
    )
    values (
      'b4333333-3333-4333-8333-333333333333',
      'b1111111-1111-4111-8111-111111111111',
      'left',
      'b2222222-2222-4222-8222-222222222222/not-owned.jpg',
      'image/jpeg',
      '{}'::jsonb,
      'google',
      'gemini-2.5-flash',
      90
    );
  exception when check_violation then
    blocked := true;
  end;
  perform pg_temp.assert_true(
    blocked,
    'database must reject image paths outside the owner folder'
  );
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', 'b1111111-1111-4111-8111-111111111111', true
);

select pg_temp.assert_true(
  (
    select count(*) = 1
      and bool_and(user_id = 'b1111111-1111-4111-8111-111111111111')
    from public.palm_readings
  ),
  'user A must read only user A palm history'
);

select pg_temp.assert_true(
  (
    select count(*) = 1
    from storage.objects
    where bucket_id = 'palm-readings'
  ),
  'user A must read only user A palm images'
);

select set_config(
  'request.jwt.claim.sub', 'b2222222-2222-4222-8222-222222222222', true
);

select pg_temp.assert_true(
  (
    select count(*) = 1
      and bool_and(user_id = 'b2222222-2222-4222-8222-222222222222')
    from public.palm_readings
  ),
  'user B must read only user B palm history'
);

select pg_temp.assert_true(
  (
    select count(*) = 1
    from storage.objects
    where bucket_id = 'palm-readings'
  ),
  'user B must read only user B palm images'
);

reset role;
rollback;
