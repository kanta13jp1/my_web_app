-- Public competitor claims are rendered only when this audit metadata exists.
-- No prices, feature assertions, Japan-presence values, or other production
-- competitor data are inserted or changed by this migration.
create table if not exists public.competitor_claim_evidence (
  id uuid primary key default gen_random_uuid(),
  competitor_id text not null
    references public.competitors(id) on delete cascade,
  claim_key text not null check (
    char_length(btrim(claim_key)) between 1 and 120
  ),
  claim_type text not null check (
    claim_type in ('summary', 'pricing', 'feature', 'japan_presence', 'other')
  ),
  claim_text text not null check (char_length(btrim(claim_text)) > 0),
  source_url text not null check (source_url ~ '^https?://[^[:space:]]+$'),
  verified_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competitor_id, claim_key)
);

create index if not exists idx_competitor_claim_evidence_lookup
  on public.competitor_claim_evidence (competitor_id, claim_type, claim_key);

alter table public.competitor_claim_evidence enable row level security;

drop policy if exists "competitor claim evidence public read"
  on public.competitor_claim_evidence;
create policy "competitor claim evidence public read"
  on public.competitor_claim_evidence
  for select
  using (true);

drop policy if exists "competitor claim evidence service write"
  on public.competitor_claim_evidence;
create policy "competitor claim evidence service write"
  on public.competitor_claim_evidence
  for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

comment on table public.competitor_claim_evidence is
  'Audit metadata for public comparison claims. Rows require exact display text, a source URL, and verified_at; backfill requires separately approved evidence.';
