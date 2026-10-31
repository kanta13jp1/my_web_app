create or replace function public.reading_compare_and_swap(
p_id uuid, p_source text, p_user_id text, p_expected jsonb, p_metadata jsonb)
returns table(id uuid, metadata jsonb, created_at timestamptz)
language sql security invoker set search_path = '' as $$
 update public.hub_data as h set metadata = p_metadata
 where h.id = p_id and h.source = p_source and p_source = 'reading'
 and h.metadata->>'user_id' = p_user_id
 and p_metadata->>'user_id' = p_user_id
 and h.metadata = p_expected
 returning h.id,h.metadata,h.created_at;
$$;
revoke all on function public.reading_compare_and_swap(uuid,text,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.reading_compare_and_swap(uuid,text,text,jsonb,jsonb) to service_role;
