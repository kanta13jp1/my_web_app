-- Paid video products use the same protected delivery path as existing ZIP
-- products. Keep the bucket private and preserve every existing MIME type.
-- Rollback removes only 'video/mp4' from allowed_mime_types after video sales
-- are deactivated; it must not delete paid entitlements or stored objects.
do $$
begin
  if not exists (
    select 1
    from storage.buckets
    where id = 'product-downloads'
      and not public
  ) then
    raise exception 'private product-downloads bucket required';
  end if;

  update storage.buckets
  set allowed_mime_types = case
    when allowed_mime_types is null then array['video/mp4']::text[]
    else array_append(allowed_mime_types, 'video/mp4')
  end
  where id = 'product-downloads'
    and (
      allowed_mime_types is null
      or not ('video/mp4' = any (allowed_mime_types))
    );
end;
$$;
