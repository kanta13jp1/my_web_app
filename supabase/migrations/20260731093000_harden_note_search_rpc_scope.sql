-- Note search runs through ai-hub, which verifies the caller and invokes these
-- SECURITY DEFINER functions with the service-role client. Direct client
-- execution would allow a caller to supply another user's p_user_id.

revoke execute on function public.sync_note_search_index_text(uuid)
  from public, anon, authenticated;
revoke execute on function public.upsert_note_search_embedding(integer, real[])
  from public, anon, authenticated;
revoke execute on function public.search_note_index_hybrid(uuid, text, integer, real[])
  from public, anon, authenticated;

grant execute on function public.sync_note_search_index_text(uuid)
  to service_role;
grant execute on function public.upsert_note_search_embedding(integer, real[])
  to service_role;
grant execute on function public.search_note_index_hybrid(uuid, text, integer, real[])
  to service_role;
