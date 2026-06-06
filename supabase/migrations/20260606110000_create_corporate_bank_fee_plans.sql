-- Issue #2926: master data for corporate bank account cost simulation.
-- Official fee facts are time-sensitive, so every seed row carries source URLs
-- and the date checked by Codex.

begin;

create table if not exists public.corporate_bank_fee_plans (
  id uuid primary key default gen_random_uuid(),
  plan_key text not null unique,
  bank_key text not null,
  bank_name text not null,
  plan_name text not null,
  monthly_base_fee_yen integer not null default 0,
  same_bank_transfer_fee_yen integer not null default 0,
  other_bank_transfer_fee_yen integer not null,
  free_transfer_count integer not null default 0,
  overseas_remittance_available boolean not null default false,
  overseas_receipt_available boolean not null default false,
  api_available boolean not null default false,
  supported_accounting_software text[] not null default '{}',
  source_urls text[] not null default '{}',
  source_checked_at date not null,
  notes text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint corporate_bank_fee_plans_bank_key_not_blank
    check (length(btrim(bank_key)) > 0),
  constraint corporate_bank_fee_plans_plan_key_not_blank
    check (length(btrim(plan_key)) > 0),
  constraint corporate_bank_fee_plans_bank_name_not_blank
    check (length(btrim(bank_name)) > 0),
  constraint corporate_bank_fee_plans_plan_name_not_blank
    check (length(btrim(plan_name)) > 0),
  constraint corporate_bank_fee_plans_monthly_base_non_negative
    check (monthly_base_fee_yen >= 0),
  constraint corporate_bank_fee_plans_same_bank_fee_non_negative
    check (same_bank_transfer_fee_yen >= 0),
  constraint corporate_bank_fee_plans_other_bank_fee_non_negative
    check (other_bank_transfer_fee_yen >= 0),
  constraint corporate_bank_fee_plans_free_transfer_non_negative
    check (free_transfer_count >= 0)
);

create index if not exists corporate_bank_fee_plans_active_cost_idx
  on public.corporate_bank_fee_plans
  (active, other_bank_transfer_fee_yen, monthly_base_fee_yen);

comment on table public.corporate_bank_fee_plans is
  'Master fee plans for Issue #2926 corporate account cost simulation.';
comment on column public.corporate_bank_fee_plans.source_checked_at is
  'Date the official fee/source URLs were checked before seeding.';
comment on column public.corporate_bank_fee_plans.supported_accounting_software is
  'Known accounting software ids: freee, money_forward, yayoi, other.';

alter table public.corporate_bank_fee_plans enable row level security;

drop policy if exists corporate_bank_fee_plans_select_active
  on public.corporate_bank_fee_plans;
create policy corporate_bank_fee_plans_select_active
on public.corporate_bank_fee_plans
for select
to anon, authenticated
using (active);

create or replace function public.set_corporate_bank_fee_plans_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists corporate_bank_fee_plans_updated_at
  on public.corporate_bank_fee_plans;
create trigger corporate_bank_fee_plans_updated_at
before update on public.corporate_bank_fee_plans
for each row execute function public.set_corporate_bank_fee_plans_updated_at();

insert into public.corporate_bank_fee_plans (
  plan_key,
  bank_key,
  bank_name,
  plan_name,
  monthly_base_fee_yen,
  same_bank_transfer_fee_yen,
  other_bank_transfer_fee_yen,
  free_transfer_count,
  overseas_remittance_available,
  overseas_receipt_available,
  api_available,
  supported_accounting_software,
  source_urls,
  source_checked_at,
  notes,
  active
) values
  (
    'gmo-aozora-standard',
    'gmo-aozora',
    'GMOあおぞらネット銀行',
    '通常',
    0,
    0,
    130,
    0,
    true,
    false,
    true,
    array['freee', 'money_forward', 'yayoi'],
    array[
      'https://gmo-aozora.com/business/service/payment.html',
      'https://gmo-aozora.com/business/service/overseas-remittance/',
      'https://gmo-aozora.com/business/api-cooperation/',
      'https://gmo-aozora.com/business/contents/faq.html'
    ],
    date '2026-06-06',
    '他行宛130円。海外送金はWise連携の送金専用で別途申込と審査が必要。',
    true
  ),
  (
    'gmo-aozora-tokutoku',
    'gmo-aozora',
    'GMOあおぞらネット銀行',
    '振込料金とくとく会員',
    500,
    0,
    121,
    0,
    true,
    false,
    true,
    array['freee', 'money_forward', 'yayoi'],
    array[
      'https://gmo-aozora.com/business/service/payment.html',
      'https://gmo-aozora.com/business/service/overseas-remittance/',
      'https://gmo-aozora.com/business/api-cooperation/'
    ],
    date '2026-06-06',
    '月額500円で他行宛121円。月56件以上の他行振込で通常プランより有利。',
    true
  ),
  (
    'sumishin-sbi-corporate',
    'sumishin-sbi',
    '住信SBIネット銀行',
    '法人口座',
    0,
    0,
    145,
    0,
    true,
    true,
    false,
    array['freee'],
    array[
      'https://www.netbk.co.jp/contents/hojin/charge/',
      'https://www.netbk.co.jp/contents/hojin/gaika/',
      'https://www.netbk.co.jp/contents/hojin/launch/'
    ],
    date '2026-06-06',
    '他行宛145円。外貨送金・受取サービスは別途申込、審査、初期導入手数料が必要。',
    true
  ),
  (
    'finswer-bank-free',
    'finswer-bank',
    'Finswer Bank',
    'フリープラン',
    0,
    13,
    90,
    0,
    false,
    false,
    true,
    array['freee', 'money_forward', 'yayoi', 'other'],
    array[
      'https://finswer-bank.finswer.jp/feature/bank',
      'https://finswer-bank.finswer.jp/price-list'
    ],
    date '2026-06-06',
    '北國銀行フィンサー支店のオンラインバンク。公式機能表に海外送金は掲載なし。',
    true
  )
on conflict (plan_key) do update set
  bank_key = excluded.bank_key,
  bank_name = excluded.bank_name,
  plan_name = excluded.plan_name,
  monthly_base_fee_yen = excluded.monthly_base_fee_yen,
  same_bank_transfer_fee_yen = excluded.same_bank_transfer_fee_yen,
  other_bank_transfer_fee_yen = excluded.other_bank_transfer_fee_yen,
  free_transfer_count = excluded.free_transfer_count,
  overseas_remittance_available = excluded.overseas_remittance_available,
  overseas_receipt_available = excluded.overseas_receipt_available,
  api_available = excluded.api_available,
  supported_accounting_software = excluded.supported_accounting_software,
  source_urls = excluded.source_urls,
  source_checked_at = excluded.source_checked_at,
  notes = excluded.notes,
  active = excluded.active,
  updated_at = now();

commit;
