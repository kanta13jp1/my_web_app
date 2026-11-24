-- One-line records of moments the user savored without spending money.
--
-- Prison mode counts restraint. A life of restraint alone does not last, so
-- this table keeps the other side: a plain sentence of something enjoyed.
-- Deliberately no score, rating or category column — the record is meant to
-- be lived, not analysed.
--
-- Append-only for authenticated clients, like prison_rule_events.
create table if not exists public.prison_savored_moments (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  note text not null,
  moment_date date not null,
  created_at timestamptz not null default now(),
  constraint prison_savored_moments_note_length
    check (char_length(btrim(note)) between 1 and 200)
);

create index if not exists prison_savored_moments_user_date_idx
  on public.prison_savored_moments (user_id, moment_date desc, id desc);

alter table public.prison_savored_moments enable row level security;

revoke all on table public.prison_savored_moments from anon;
revoke all on sequence public.prison_savored_moments_id_seq from anon;
revoke all on table public.prison_savored_moments from authenticated;
revoke all on sequence public.prison_savored_moments_id_seq from authenticated;

grant select, insert on table public.prison_savored_moments to authenticated;
grant usage, select on sequence public.prison_savored_moments_id_seq
  to authenticated;

drop policy if exists "Users can view own savored moments"
  on public.prison_savored_moments;
create policy "Users can view own savored moments"
  on public.prison_savored_moments
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can append own savored moments"
  on public.prison_savored_moments;
create policy "Users can append own savored moments"
  on public.prison_savored_moments
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

comment on table public.prison_savored_moments is
  'Append-only one-line records of moments the user enjoyed without spending, shown beside the prison-mode guard.';
