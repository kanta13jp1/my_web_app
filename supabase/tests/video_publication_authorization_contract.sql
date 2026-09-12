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
    raise exception 'video publication contract failed: %', failure_message;
  end if;
end;
$$;

do $$
declare
  v_user uuid := '77777777-7777-4777-8777-777777777777';
  v_artifact uuid;
  v_review uuid;
  v_authorization uuid;
  v_result jsonb;
  v_blocked boolean := false;
begin
  select id into strict v_artifact
  from public.video_artifacts
  where job_id = '88888888-8888-4888-8888-888888888888';

  v_result := public.video_record_artifact_review(
    v_user,
    v_artifact,
    4::smallint,
    5::smallint,
    4::smallint,
    4::smallint,
    'keep',
    'Clear commercial office composition',
    'No blocking finding remains',
    'A clean office scene with natural movement',
    'Approved as an exact video product source',
    'allowed',
    'cleared'
  );
  v_review := (v_result -> 'review' ->> 'id')::uuid;

  v_result := public.video_register_publication_authorization(
    v_user,
    v_artifact,
    v_review,
    now() + interval '7 days',
    'contract-office-broll-v1',
    'Office B-roll',
    'Five-second commercial office footage.',
    'First-party GPU-generated MP4 footage for commercial editing.',
    500,
    'Commercial editing allowed; standalone redistribution prohibited.',
    true,
    true,
    true,
    true,
    true
  );
  v_authorization := (
    v_result -> 'authorization' ->> 'id'
  )::uuid;

  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_publication_authorizations
      where id = v_authorization
        and user_id = v_user
        and artifact_id = v_artifact
        and review_id = v_review
        and product_id = 'contract-office-broll-v1'
        and price_jpy = 500
        and status = 'active'
    ),
    'the exact artifact, review and commercial packet must be fixed before publication'
  );

  perform public.video_claim_publication_authorization(
    v_user,
    v_authorization
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_publication_authorizations
      where id = v_authorization
        and status = 'publishing'
        and attempt_count = 1
        and lease_expires_at is not null
    ),
    'publication must hold a bounded exclusive lease'
  );

  perform public.video_stage_publication_product(
    v_user,
    v_authorization,
    'prod_Contract123',
    'price_Contract123',
    'video/contract-office-broll-v1/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.mp4',
    1024,
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.shop_products
      where id = 'contract-office-broll-v1'
        and not is_active
        and product_type = 'video'
        and price_jpy = 500
        and stripe_price_id = 'price_Contract123'
        and storage_bucket = 'product-downloads'
    ),
    'the product must stay private until price and delivery verification finish'
  );

  perform public.video_finalize_publication(v_user, v_authorization);
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_publication_authorizations
      where id = v_authorization and status = 'published'
    )
      and exists (
        select 1
        from public.shop_products
        where id = 'contract-office-broll-v1' and is_active
      )
      and exists (
        select 1
        from public.video_artifacts
        where id = v_artifact
          and shop_product_id = 'contract-office-broll-v1'
          and commerce_status = 'listed'
      ),
    'finalization must atomically activate the verified listing and link its artifact'
  );

  begin
    update public.video_publication_authorizations
    set price_jpy = 600
    where id = v_authorization;
  exception when others then
    v_blocked := sqlerrm = 'video_publication_packet_is_immutable';
  end;
  perform pg_temp.assert_true(
    v_blocked,
    'the approved publication packet must be immutable'
  );

  perform public.video_rollback_publication(
    v_user,
    v_authorization,
    'contract_verification_failure'
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.video_publication_authorizations
      where id = v_authorization and status = 'rolled_back'
    )
      and exists (
        select 1
        from public.shop_products
        where id = 'contract-office-broll-v1' and not is_active
      ),
    'rollback must stop new sales without deleting the immutable file record'
  );

  perform pg_temp.assert_true(
    not has_table_privilege(
      'authenticated',
      'public.video_publication_authorizations',
      'INSERT'
    )
      and not has_table_privilege(
        'authenticated',
        'public.video_publication_authorizations',
        'UPDATE'
      )
      and has_table_privilege(
        'authenticated',
        'public.video_publication_authorizations',
        'SELECT'
      ),
    'browser clients may inspect but never forge publication authorization state'
  );
end;
$$;

rollback;
