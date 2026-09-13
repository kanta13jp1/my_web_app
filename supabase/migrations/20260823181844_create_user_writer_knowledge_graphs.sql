-- User-owned Writer Knowledge Graph metadata.
--
-- Raw document contents and WRITER_API_KEY never enter Postgres. The Edge
-- Function uses the service role for writes while RLS gives authenticated
-- users read-only access to their own metadata.

create table public.user_writer_knowledge_graphs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  writer_graph_id uuid not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_writer_knowledge_graph_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_writer_knowledge_graphs(user_id)
    on delete cascade,
  writer_file_id text not null,
  file_name text not null,
  mime_type text not null,
  size_bytes bigint not null,
  processing_status text not null default 'in_progress',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_writer_knowledge_graph_documents_writer_file_unique
    unique (user_id, writer_file_id),
  constraint user_writer_knowledge_graph_documents_file_id_not_blank
    check (length(btrim(writer_file_id)) > 0),
  constraint user_writer_knowledge_graph_documents_file_name_not_blank
    check (length(btrim(file_name)) > 0),
  constraint user_writer_knowledge_graph_documents_mime_type_not_blank
    check (length(btrim(mime_type)) > 0),
  constraint user_writer_knowledge_graph_documents_size_bounds
    check (size_bytes > 0 and size_bytes <= 4194304),
  constraint user_writer_knowledge_graph_documents_status_not_blank
    check (length(btrim(processing_status)) > 0)
);

create index user_writer_knowledge_graph_documents_user_created_idx
  on public.user_writer_knowledge_graph_documents (user_id, created_at desc);

alter table public.user_writer_knowledge_graphs enable row level security;
alter table public.user_writer_knowledge_graph_documents enable row level security;

create policy user_writer_knowledge_graphs_select_own
  on public.user_writer_knowledge_graphs
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy user_writer_knowledge_graph_documents_select_own
  on public.user_writer_knowledge_graph_documents
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.user_writer_knowledge_graphs from anon, authenticated;
revoke all on table public.user_writer_knowledge_graph_documents from anon, authenticated;
grant select on table public.user_writer_knowledge_graphs to authenticated;
grant select on table public.user_writer_knowledge_graph_documents to authenticated;

drop trigger if exists user_writer_knowledge_graphs_set_updated_at
  on public.user_writer_knowledge_graphs;
create trigger user_writer_knowledge_graphs_set_updated_at
before update on public.user_writer_knowledge_graphs
for each row execute function public.update_updated_at_column();

drop trigger if exists user_writer_knowledge_graph_documents_set_updated_at
  on public.user_writer_knowledge_graph_documents;
create trigger user_writer_knowledge_graph_documents_set_updated_at
before update on public.user_writer_knowledge_graph_documents
for each row execute function public.update_updated_at_column();

comment on table public.user_writer_knowledge_graphs is
  'Maps each Supabase user to an isolated Writer Knowledge Graph; API keys stay in Edge Function secrets.';
comment on table public.user_writer_knowledge_graph_documents is
  'Owner-scoped metadata for documents retained by Writer; raw file contents are not stored in Supabase.';
