create extension if not exists vector;
create extension if not exists pg_trgm;

create table if not exists public.note_search_index (
  note_id int primary key references public.notes(id) on delete cascade,
  user_id uuid not null,
  title text not null default '',
  content text not null default '',
  tags text[] not null default '{}'::text[],
  category_id text,
  is_archived boolean not null default false,
  note_updated_at timestamptz,
  indexed_at timestamptz not null default now(),
  search_text text not null default '',
  embedding vector(768)
);

create index if not exists note_search_index_user_id_idx
  on public.note_search_index (user_id);

create index if not exists note_search_index_text_trgm_idx
  on public.note_search_index using gin (search_text gin_trgm_ops);

create index if not exists note_search_index_embedding_idx
  on public.note_search_index using ivfflat (embedding vector_cosine_ops)
  with (lists = 50)
  where embedding is not null;

alter table public.note_search_index enable row level security;

drop policy if exists note_search_index_select_own on public.note_search_index;
create policy note_search_index_select_own
  on public.note_search_index
  for select
  to authenticated
  using (auth.uid() = user_id);

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
  where p_user_id is null or n.user_id = p_user_id
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

create or replace function public.upsert_note_search_embedding(
  p_note_id int,
  p_embedding real[]
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.note_search_index
  set
    embedding = case
      when p_embedding is null or cardinality(p_embedding) = 0
        then null
      else format('[%s]', array_to_string(p_embedding, ','))::vector(768)
    end,
    indexed_at = now()
  where note_id = p_note_id;
$$;

grant execute on function public.upsert_note_search_embedding(int, real[]) to authenticated;
grant execute on function public.upsert_note_search_embedding(int, real[]) to service_role;

create or replace function public.search_note_index_hybrid(
  p_user_id uuid,
  p_query text,
  p_limit int default 20,
  p_query_embedding real[] default null
)
returns table (
  note_id int,
  title text,
  content text,
  tags text[],
  category_id text,
  note_updated_at timestamptz,
  text_rank real,
  vector_rank real,
  combined_rank real,
  match_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  with params as (
    select
      trim(coalesce(p_query, '')) as raw_query,
      lower(trim(coalesce(p_query, ''))) as normalized_query,
      greatest(1, least(coalesce(p_limit, 20), 50)) as row_limit,
      case
        when p_query_embedding is null or cardinality(p_query_embedding) = 0
          then null
        else format('[%s]', array_to_string(p_query_embedding, ','))::vector(768)
      end as query_vector
  ),
  scored as (
    select
      i.note_id,
      i.title,
      i.content,
      i.tags,
      i.category_id,
      i.note_updated_at,
      (
        case
          when p.normalized_query <> ''
            and position(p.normalized_query in lower(coalesce(i.title, ''))) > 0
            then 1.40
          else 0
        end +
        case
          when p.normalized_query <> ''
            and position(p.normalized_query in lower(coalesce(i.search_text, ''))) > 0
            then 0.80
          else 0
        end +
        case
          when p.normalized_query <> ''
            then similarity(lower(coalesce(i.title, '')), p.normalized_query) * 0.90
          else 0
        end +
        case
          when p.normalized_query <> ''
            then similarity(lower(coalesce(i.search_text, '')), p.normalized_query) * 0.55
          else 0
        end
      )::real as text_rank,
      case
        when p.query_vector is not null and i.embedding is not null
          then greatest(0::real, (1 - (i.embedding <=> p.query_vector))::real)
        else null
      end as vector_rank
    from public.note_search_index i
    cross join params p
    where i.user_id = p_user_id
      and i.is_archived = false
  ),
  filtered as (
    select
      s.*,
      case
        when s.vector_rank is null then s.text_rank
        when s.text_rank <= 0 then s.vector_rank
        else (s.text_rank * 0.65 + s.vector_rank * 0.35)
      end::real as combined_rank
    from scored s
    where s.text_rank > 0.12
       or coalesce(s.vector_rank, 0) > 0.55
  )
  select
    note_id,
    title,
    content,
    tags,
    category_id,
    note_updated_at,
    text_rank,
    vector_rank,
    combined_rank,
    case
      when vector_rank is not null and text_rank > 0.12 then 'hybrid'
      when vector_rank is not null then 'vector'
      else 'text'
    end as match_reason
  from filtered
  order by combined_rank desc, note_updated_at desc nulls last, note_id desc
  limit (select row_limit from params);
$$;

grant execute on function public.search_note_index_hybrid(uuid, text, int, real[]) to authenticated;
grant execute on function public.search_note_index_hybrid(uuid, text, int, real[]) to service_role;

select public.sync_note_search_index_text(null);

update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  end_date = '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added Supabase note_search_index%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added Supabase note_search_index (pgvector + pg_trgm text search), ai-hub hybrid note search, and fallback ranking for AIノート検索.'
  end
where title = '[追加要望] Supabaseでの pg_vector + 全文検索';
