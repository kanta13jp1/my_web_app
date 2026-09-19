-- Additional post-level records. Do not replace the legacy funnel key while
-- old deployed writers still use it, and do not fabricate historical tags.
-- Requires human schema/RLS acknowledgement before application.
begin;

create table public.shop_post_funnel_events (
  visitor_id uuid not null,
  product_id text not null references public.shop_products(id) on delete cascade,
  source text not null default 'direct'
    check (source ~ '^[a-z0-9_.-]{1,64}$'),
  campaign text not null default ''
    check (campaign ~ '^[a-z0-9_.-]{0,64}$'),
  content_id text not null default ''
    check (content_id ~ '^[a-z0-9_.-]{0,64}$'),
  stage text not null check (stage in (
    'product_view', 'purchase_click', 'checkout_redirect', 'purchase_complete'
  )),
  first_occurred_at timestamptz not null default now(),
  primary key (visitor_id, product_id, source, campaign, content_id, stage)
);

comment on table public.shop_post_funnel_events is
  'Post-level shop funnel. New observations only; never sum with legacy shop_funnel_events. Tags and client stages are untrusted; purchase_complete is written only by the verified paid webhook.';
comment on column public.shop_post_funnel_events.visitor_id is
  'Pseudonymous browser identifier; may be linked to legacy authenticated events. Not anonymous data. No extra user/account identifier is stored here.';
comment on column public.shop_post_funnel_events.content_id is
  'utm_content post identifier; empty means not supplied, not inferred. Never store customer information in campaign tags.';

create index shop_post_funnel_events_report_idx
  on public.shop_post_funnel_events (product_id, first_occurred_at);

alter table public.shop_post_funnel_events enable row level security;
revoke all on public.shop_post_funnel_events
  from public, anon, authenticated, service_role;
-- Do not rely on Supabase default grants. ON CONFLICT DO NOTHING needs no
-- update policy/permission; only the server-held role can read or insert.
grant select, insert on public.shop_post_funnel_events to service_role;

commit;
