create extension if not exists vector;
create extension if not exists pg_trgm;

alter table public.notes
  add column if not exists capture_status text;
alter table public.notes
  add column if not exists capture_source text;
alter table public.notes
  add column if not exists classification_status text;
alter table public.notes
  add column if not exists classified_at timestamptz;
alter table public.notes
  add column if not exists inbox_saved_at timestamptz;

update public.notes
set
  capture_status = coalesce(capture_status, 'organized'),
  capture_source = coalesce(capture_source, 'editor'),
  classification_status = coalesce(classification_status, 'classified')
where capture_status is null
   or capture_source is null
   or classification_status is null;

alter table public.notes
  alter column capture_status set default 'organized',
  alter column capture_status set not null,
  alter column capture_source set default 'editor',
  alter column capture_source set not null,
  alter column classification_status set default 'classified',
  alter column classification_status set not null;

do $$
begin
  alter table public.notes
    add constraint notes_capture_status_check
    check (capture_status in ('inbox', 'organized', 'archived')) not valid;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter table public.notes
    add constraint notes_classification_status_check
    check (classification_status in ('pending', 'classified', 'failed', 'skipped')) not valid;
exception
  when duplicate_object then null;
end $$;

create index if not exists idx_notes_inbox_status
  on public.notes (user_id, capture_status, classification_status, created_at desc)
  where is_archived = false;

alter table public.note_search_index
  add column if not exists capture_status text not null default 'organized';
alter table public.note_search_index
  add column if not exists classification_status text not null default 'classified';

create or replace function public.sync_note_search_index_text(p_user_id uuid default null)
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
    capture_status,
    classification_status,
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
    coalesce(n.capture_status, 'organized'),
    coalesce(n.classification_status, 'classified'),
    n.updated_at,
    now(),
    trim(
      concat_ws(
        ' ',
        coalesce(n.title, ''),
        coalesce(array_to_string(coalesce(n.tags, '{}'::text[]), ' '), ''),
        coalesce(n.capture_status, 'organized'),
        coalesce(n.classification_status, 'classified'),
        coalesce(n.content, '')
      )
    ),
    idx.embedding
  from public.notes n
  left join public.note_search_index idx
    on idx.note_id = n.id
  where p_user_id is null or n.user_id = p_user_id
  on conflict (note_id) do update
  set
    user_id = excluded.user_id,
    title = excluded.title,
    content = excluded.content,
    tags = excluded.tags,
    category_id = excluded.category_id,
    is_archived = excluded.is_archived,
    capture_status = excluded.capture_status,
    classification_status = excluded.classification_status,
    note_updated_at = excluded.note_updated_at,
    indexed_at = now(),
    search_text = excluded.search_text,
    embedding = case
      when public.note_search_index.note_updated_at is not distinct from excluded.note_updated_at
        then public.note_search_index.embedding
      else null
    end;

  delete from public.note_search_index idx
  where (p_user_id is null or idx.user_id = p_user_id)
    and not exists (
      select 1
      from public.notes n
      where n.id = idx.note_id
    );
end;
$$;

grant execute on function public.sync_note_search_index_text(uuid) to authenticated;
grant execute on function public.sync_note_search_index_text(uuid) to service_role;

create or replace function public.find_related_notes(
  p_user_id uuid,
  p_note_id int,
  p_limit int default 5
)
returns table (
  note_id int,
  title text,
  content text,
  tags text[],
  category_id text,
  note_updated_at timestamptz,
  similarity_score real,
  match_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with src as (
    select idx.*
    from public.note_search_index idx
    where idx.user_id = p_user_id
      and idx.note_id = p_note_id
      and idx.is_archived = false
    limit 1
  ),
  scored as (
    select
      i.note_id,
      i.title,
      i.content,
      i.tags,
      i.category_id,
      i.note_updated_at,
      similarity(lower(coalesce(i.search_text, '')), lower(coalesce(src.search_text, '')))::real as text_rank,
      case
        when cardinality(coalesce(i.tags, '{}'::text[])) = 0
          or cardinality(coalesce(src.tags, '{}'::text[])) = 0
          then 0::real
        else (
          select count(*)::real
          from unnest(i.tags) as tag(name)
          where tag.name = any(src.tags)
        ) / greatest(cardinality(i.tags), cardinality(src.tags), 1)::real
      end as tag_rank,
      case
        when i.embedding is not null and src.embedding is not null
          then greatest(0::real, (1 - (i.embedding <=> src.embedding))::real)
        else null
      end as vector_rank
    from public.note_search_index i
    cross join src
    where i.user_id = p_user_id
      and i.note_id <> p_note_id
      and i.is_archived = false
  ),
  ranked as (
    select
      *,
      (
        text_rank * 0.55 +
        tag_rank * 0.25 +
        coalesce(vector_rank, 0) * 0.20
      )::real as combined_rank
    from scored
  )
  select
    note_id,
    title,
    content,
    tags,
    category_id,
    note_updated_at,
    combined_rank as similarity_score,
    case
      when coalesce(vector_rank, 0) > 0.55 and tag_rank > 0 then 'hybrid'
      when tag_rank > 0 then 'tag'
      when coalesce(vector_rank, 0) > 0.55 then 'vector'
      else 'text'
    end as match_reason
  from ranked
  where combined_rank > 0.08
  order by combined_rank desc, note_updated_at desc nulls last, note_id desc
  limit greatest(1, least(coalesce(p_limit, 5), 5));
$$;

grant execute on function public.find_related_notes(uuid, int, int) to authenticated;
grant execute on function public.find_related_notes(uuid, int, int) to service_role;

select public.sync_note_search_index_text(null);
