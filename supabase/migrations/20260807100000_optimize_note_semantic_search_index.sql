-- nocheck: time-relative
-- This migration only updates public.note_search_index, which has no
-- time-relative enforcement trigger. The detector otherwise reads the schema
-- qualifier in `update public.note_search_index` as a table named `public`.

create or replace function public.sync_note_search_index_note(
  p_user_id uuid,
  p_note_id integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.note_search_index (
    note_id,
    user_id,
    title,
    content,
    tags,
    category_id,
    is_archived,
    note_updated_at,
    indexed_at,
    search_text,
    embedding
  )
  select
    n.id,
    n.user_id,
    coalesce(n.title, ''),
    coalesce(n.content, ''),
    coalesce(n.tags, '{}'::text[]),
    n.category_id::text,
    coalesce(n.is_archived, false),
    n.updated_at,
    now(),
    trim(
      concat_ws(
        ' ',
        coalesce(n.title, ''),
        coalesce(array_to_string(coalesce(n.tags, '{}'::text[]), ' '), ''),
        coalesce(n.content, '')
      )
    ),
    idx.embedding
  from public.notes n
  left join public.note_search_index idx
    on idx.note_id = n.id
  where n.user_id = p_user_id
    and n.id = p_note_id
  on conflict (note_id) do update
  set
    user_id = excluded.user_id,
    title = excluded.title,
    content = excluded.content,
    tags = excluded.tags,
    category_id = excluded.category_id,
    is_archived = excluded.is_archived,
    note_updated_at = excluded.note_updated_at,
    indexed_at = now(),
    search_text = excluded.search_text,
    embedding = case
      when public.note_search_index.search_text is not distinct from excluded.search_text
        then public.note_search_index.embedding
      else null
    end;

  if not found then
    delete from public.note_search_index
    where note_id = p_note_id
      and user_id = p_user_id;
  end if;
end;
$$;

revoke execute on function public.sync_note_search_index_note(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.sync_note_search_index_note(uuid, integer)
  to service_role;

create or replace function public.refresh_note_search_index_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.note_search_index where note_id = old.id;
    return old;
  end if;

  perform public.sync_note_search_index_note(new.user_id, new.id);
  return new;
end;
$$;

revoke execute on function public.refresh_note_search_index_row()
  from public, anon, authenticated;

drop trigger if exists notes_refresh_search_index on public.notes;
create trigger notes_refresh_search_index
after insert or update of user_id, title, content, tags, category_id, is_archived
or delete on public.notes
for each row execute function public.refresh_note_search_index_row();

select public.sync_note_search_index_text(null);

-- Existing vectors were generated without an explicit retrieval-document
-- task type. Rebuild them incrementally through ai-hub before comparing them
-- with RETRIEVAL_QUERY vectors.
update public.note_search_index
set embedding = null
where embedding is not null;
