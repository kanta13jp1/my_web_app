-- 端末ローカル設定の汎用バックアップミラー (#3246: paymentDayOverrides 同期)。
-- v1 は書き込みミラー + ローカル空時の復元のみ。キー単位の jsonb で将来の
-- ローカル設定 (表示モード等) にも流用できる。
create table if not exists public.asset_pref_mirror (
  user_id uuid not null references auth.users (id) on delete cascade,
  pref_key text not null,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, pref_key)
);

alter table public.asset_pref_mirror enable row level security;

drop policy if exists "asset_pref_mirror_own_all" on public.asset_pref_mirror;
create policy "asset_pref_mirror_own_all"
  on public.asset_pref_mirror
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
