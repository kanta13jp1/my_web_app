-- Company-scoped research corpus and adaptive model routing for AI Company Builder.

create extension if not exists vector;

create table if not exists public.company_research_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.hub_data(id) on delete cascade,
  source_url text not null check (
    char_length(source_url) between 1 and 2048
  ),
  canonical_url text not null check (
    char_length(canonical_url) between 1 and 1500
  ),
  title text not null default '' check (char_length(title) <= 500),
  content_markdown text not null default '' check (
    char_length(content_markdown) <= 1000000
  ),
  excerpt text not null default '' check (char_length(excerpt) <= 1200),
  content_hash text not null default '' check (char_length(content_hash) <= 128),
  status text not null default 'processing' check (
    status in ('processing', 'ready', 'failed')
  ),
  http_status integer check (
    http_status is null or http_status between 100 and 599
  ),
  content_type text check (content_type is null or char_length(content_type) <= 200),
  last_error text check (last_error is null or char_length(last_error) <= 1000),
  metadata jsonb not null default '{}'::jsonb,
  fetched_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, company_id, canonical_url),
  unique (id, user_id, company_id)
);

create table if not exists public.company_research_chunks (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.hub_data(id) on delete cascade,
  chunk_index integer not null check (chunk_index between 0 and 9999),
  heading text not null default '' check (char_length(heading) <= 500),
  location text not null default '' check (char_length(location) <= 500),
  content text not null check (char_length(content) between 1 and 12000),
  embedding vector(768),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search_vector tsvector generated always as (
    setweight(to_tsvector('simple', coalesce(heading, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(location, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(content, '')), 'C')
  ) stored,
  unique (source_id, chunk_index),
  foreign key (source_id, user_id, company_id)
    references public.company_research_sources(id, user_id, company_id)
    on delete cascade
);

create table if not exists public.company_runtime_routing_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.hub_data(id) on delete cascade,
  routing_key text not null check (char_length(routing_key) between 1 and 120),
  base_tier text not null default 'free' check (
    base_tier in ('free', 'budget', 'performance', 'premium')
  ),
  current_tier text not null default 'free' check (
    current_tier in ('free', 'budget', 'performance', 'premium')
  ),
  consecutive_successes integer not null default 0 check (
    consecutive_successes between 0 and 1000000
  ),
  consecutive_failures integer not null default 0 check (
    consecutive_failures between 0 and 1000000
  ),
  escalation_count integer not null default 0 check (escalation_count >= 0),
  downgrade_count integer not null default 0 check (downgrade_count >= 0),
  last_provider text,
  last_model text,
  last_decision text,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, company_id, routing_key)
);

create index if not exists company_research_sources_owner_status_idx
  on public.company_research_sources (user_id, company_id, status, updated_at desc);

create index if not exists company_research_sources_company_fk_idx
  on public.company_research_sources (company_id);

create index if not exists company_research_chunks_owner_idx
  on public.company_research_chunks (user_id, company_id, updated_at desc);

create index if not exists company_research_chunks_source_fk_idx
  on public.company_research_chunks (source_id, chunk_index);

create index if not exists company_research_chunks_search_idx
  on public.company_research_chunks using gin (search_vector);

create index if not exists company_research_chunks_embedding_idx
  on public.company_research_chunks
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 100)
  where embedding is not null;

create index if not exists company_runtime_routing_profiles_company_idx
  on public.company_runtime_routing_profiles (company_id, updated_at desc);

create unique index if not exists agent_tasks_company_a2a_message_uidx
  on public.agent_tasks (
    user_id,
    task_type,
    (metadata ->> 'company_id'),
    (metadata ->> 'a2a_message_id')
  )
  where task_type = 'company_builder_a2a'
    and metadata ->> 'company_id' is not null
    and metadata ->> 'a2a_message_id' is not null;

drop trigger if exists trg_company_research_sources_updated_at
  on public.company_research_sources;
create trigger trg_company_research_sources_updated_at
  before update on public.company_research_sources
  for each row execute function public.set_agent_org_updated_at();

drop trigger if exists trg_company_research_chunks_updated_at
  on public.company_research_chunks;
create trigger trg_company_research_chunks_updated_at
  before update on public.company_research_chunks
  for each row execute function public.set_agent_org_updated_at();

drop trigger if exists trg_company_runtime_routing_profiles_updated_at
  on public.company_runtime_routing_profiles;
create trigger trg_company_runtime_routing_profiles_updated_at
  before update on public.company_runtime_routing_profiles
  for each row execute function public.set_agent_org_updated_at();

alter table public.company_research_sources enable row level security;
alter table public.company_research_chunks enable row level security;
alter table public.company_runtime_routing_profiles enable row level security;

drop policy if exists company_research_sources_select_own
  on public.company_research_sources;
create policy company_research_sources_select_own
  on public.company_research_sources
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists company_research_chunks_select_own
  on public.company_research_chunks;
create policy company_research_chunks_select_own
  on public.company_research_chunks
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists company_runtime_routing_profiles_select_own
  on public.company_runtime_routing_profiles;
create policy company_runtime_routing_profiles_select_own
  on public.company_runtime_routing_profiles
  for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.company_research_sources from public, anon, authenticated;
revoke all on public.company_research_chunks from public, anon, authenticated;
revoke all on public.company_runtime_routing_profiles from public, anon, authenticated;
grant select on public.company_research_sources to authenticated;
grant select on public.company_research_chunks to authenticated;
grant select on public.company_runtime_routing_profiles to authenticated;
grant all on public.company_research_sources to service_role;
grant all on public.company_research_chunks to service_role;
grant all on public.company_runtime_routing_profiles to service_role;

do $migration$
declare
  vector_schema text;
begin
  select namespace.nspname
    into vector_schema
  from pg_catalog.pg_extension as extension
  join pg_catalog.pg_namespace as namespace
    on namespace.oid = extension.extnamespace
  where extension.extname = 'vector';

  if vector_schema is null then
    raise exception 'vector extension schema was not found';
  end if;

  execute format($function$
    create or replace function public.company_vector_cosine_similarity(
      p_left text,
      p_right text
    )
    returns double precision
    language sql
    immutable
    strict
    parallel safe
    set search_path = ''
    as $body$
      select greatest(
        0::double precision,
        1 - (
          p_left::%1$I.vector operator(%1$I.<=>) p_right::%1$I.vector
        )
      );
    $body$;
  $function$, vector_schema);
end;
$migration$;

revoke execute on function public.company_vector_cosine_similarity(text, text)
  from public, anon, authenticated, service_role;

create or replace function public.match_company_research_chunks(
  p_user_id uuid,
  p_company_id uuid,
  p_query_text text default '',
  p_query_embedding vector(768) default null,
  p_match_count integer default 8,
  p_match_threshold double precision default 0.05
)
returns table (
  chunk_id uuid,
  source_id uuid,
  source_url text,
  title text,
  heading text,
  location text,
  content text,
  fetched_at timestamptz,
  lexical_score double precision,
  vector_score double precision,
  score double precision
)
language sql
stable
security definer
set search_path = ''
as $$
  with query_input as (
    select websearch_to_tsquery(
      'simple',
      left(coalesce(nullif(trim(p_query_text), ''), '__empty_query__'), 1000)
    ) as query
  ), ranked as (
    select
      chunk.id as chunk_id,
      chunk.source_id,
      source.source_url,
      source.title,
      chunk.heading,
      chunk.location,
      chunk.content,
      source.fetched_at,
      case
        when chunk.search_vector @@ query_input.query
          then ts_rank_cd(chunk.search_vector, query_input.query)::double precision
        else 0::double precision
      end as lexical_score,
      case
        when p_query_embedding is not null and chunk.embedding is not null
          then public.company_vector_cosine_similarity(
            chunk.embedding::text,
            p_query_embedding::text
          )
        else 0::double precision
      end as vector_score
    from public.company_research_chunks as chunk
    join public.company_research_sources as source
      on source.id = chunk.source_id
      and source.user_id = chunk.user_id
      and source.company_id = chunk.company_id
    cross join query_input
    where chunk.user_id = p_user_id
      and chunk.company_id = p_company_id
      and source.status = 'ready'
  )
  select
    ranked.chunk_id,
    ranked.source_id,
    ranked.source_url,
    ranked.title,
    ranked.heading,
    ranked.location,
    ranked.content,
    ranked.fetched_at,
    ranked.lexical_score,
    ranked.vector_score,
    (ranked.lexical_score * 0.45 + ranked.vector_score * 0.55) as score
  from ranked
  where ranked.lexical_score > 0
    or ranked.vector_score >= greatest(0, least(coalesce(p_match_threshold, 0.05), 1))
  order by score desc, ranked.fetched_at desc nulls last, ranked.chunk_id
  limit greatest(1, least(coalesce(p_match_count, 8), 30));
$$;

revoke execute on function public.match_company_research_chunks(
  uuid, uuid, text, vector, integer, double precision
) from public, anon, authenticated;
grant execute on function public.match_company_research_chunks(
  uuid, uuid, text, vector, integer, double precision
) to service_role;

comment on table public.company_research_sources is
  'Owner-scoped external sources ingested by AI Company Builder';
comment on table public.company_research_chunks is
  'Citation-addressable text chunks with full-text and pgvector indexes';
comment on table public.company_runtime_routing_profiles is
  'Persisted success/failure feedback for adaptive company model tiers';
