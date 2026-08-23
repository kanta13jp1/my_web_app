-- public.notes.id is bigint, while the search index and its single-row sync
-- function use integer note IDs. Without an explicit cast, the row trigger
-- resolves sync_note_search_index_note(uuid, bigint), which does not exist and
-- rolls back note inserts and updates.
create or replace function public.refresh_note_search_index_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.note_search_index where note_id = old.id;
    return old;
  end if;

  perform public.sync_note_search_index_note(new.user_id, new.id::integer);
  return new;
end;
$$;

revoke execute on function public.refresh_note_search_index_row()
  from public, anon, authenticated;
