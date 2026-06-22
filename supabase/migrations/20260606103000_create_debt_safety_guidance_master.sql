-- Master guidance for debt safety guardrails. The Flutter client keeps a
-- built-in fallback, while this table gives operations a single Supabase
-- source for legal-rate warnings, lending self-exclusion links, and education
-- notices.

create table if not exists public.debt_safety_guidance_master (
  guidance_key text primary key,
  category text not null,
  severity text not null,
  title text not null,
  body text not null,
  action_label text not null,
  url text not null,
  source_url text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint debt_safety_guidance_master_category_valid
    check (
      category in (
        'legal_rate',
        'self_exclusion',
        'registered_lender',
        'education'
      )
    ),
  constraint debt_safety_guidance_master_severity_valid
    check (severity in ('info', 'warning', 'danger')),
  constraint debt_safety_guidance_master_title_not_blank
    check (length(btrim(title)) > 0),
  constraint debt_safety_guidance_master_body_not_blank
    check (length(btrim(body)) > 0),
  constraint debt_safety_guidance_master_action_not_blank
    check (length(btrim(action_label)) > 0),
  constraint debt_safety_guidance_master_https_url
    check (url ~ '^https://'),
  constraint debt_safety_guidance_master_https_source_url
    check (source_url ~ '^https://')
);

create index if not exists debt_safety_guidance_master_category_idx
  on public.debt_safety_guidance_master (
    category,
    active,
    sort_order,
    guidance_key
  );

alter table public.debt_safety_guidance_master enable row level security;

drop policy if exists debt_safety_guidance_master_select_active
  on public.debt_safety_guidance_master;
create policy debt_safety_guidance_master_select_active
on public.debt_safety_guidance_master
for select
to anon, authenticated
using (active);

create or replace function public.set_debt_safety_guidance_master_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists debt_safety_guidance_master_updated_at
  on public.debt_safety_guidance_master;
create trigger debt_safety_guidance_master_updated_at
before update on public.debt_safety_guidance_master
for each row execute function
  public.set_debt_safety_guidance_master_updated_at();

insert into public.debt_safety_guidance_master (
  guidance_key,
  category,
  severity,
  title,
  body,
  action_label,
  url,
  source_url,
  active,
  sort_order
) values
  (
    'legal_rate_over_20_block',
    'legal_rate',
    'danger',
    '年利20%超の登録ブロック',
    '年利20%を超える条件は出資法違反となる可能性があるため、借入先と契約条件を確認してください。',
    '金融庁の注意を見る',
    'https://www.fsa.go.jp/ordinary/chuui/index.html',
    'https://www.fsa.go.jp/ordinary/chuui/index.html',
    true,
    10
  ),
  (
    'principal_based_interest_limit_warning',
    'legal_rate',
    'warning',
    '元本別上限金利の確認',
    '利息制限法の上限金利は元本に応じて15%から20%です。20%以下でも元本別の上限を超える場合は契約条件を確認してください。',
    '上限金利を確認',
    'https://www.j-fsa.or.jp/association/money_lending/law/maximum_interest_rate.php',
    'https://www.j-fsa.or.jp/association/money_lending/law/maximum_interest_rate.php',
    true,
    20
  ),
  (
    'lending_self_exclusion',
    'self_exclusion',
    'warning',
    '貸付自粛制度',
    '新たな借入れを自分の意思だけで止めにくい場合は、日本貸金業協会の貸付自粛制度を確認してください。',
    '制度を見る',
    'https://www.j-fsa.or.jp/personal/useful/question/selfcontrol.php',
    'https://www.j-fsa.or.jp/personal/useful/question/selfcontrol.php',
    true,
    30
  ),
  (
    'lending_consultation_center',
    'self_exclusion',
    'info',
    '貸金業相談・紛争解決センター',
    '返済や借入れの相談は、日本貸金業協会の相談窓口につなげます。',
    '相談窓口',
    'https://www.j-fsa.or.jp/personal/borrowing/',
    'https://www.j-fsa.or.jp/personal/borrowing/',
    true,
    40
  ),
  (
    'registered_lender_search',
    'registered_lender',
    'info',
    '登録貸金業者情報検索サービス',
    '借入れや借換えの前に、金融庁の登録貸金業者情報検索サービスで業者の登録を確認してください。',
    '登録検索',
    'https://www.fsa.go.jp/ordinary/kensaku/index.html',
    'https://www.fsa.go.jp/ordinary/kensaku/index.html',
    true,
    50
  ),
  (
    'name_lending_notice',
    'education',
    'warning',
    '名義貸しに注意',
    '自分名義で借りて他人に渡す話は、返済義務とトラブルだけが残る危険があります。',
    '事例を見る',
    'https://www.j-fsa.or.jp/topics/association/for_young.php',
    'https://www.j-fsa.or.jp/topics/association/for_young.php',
    true,
    60
  ),
  (
    'credit_card_cashing_notice',
    'education',
    'warning',
    'クレジットカード現金化に注意',
    'ショッピング枠の現金化や後払い現金化は、手数料負担と規約違反のリスクが高い取引です。',
    '注意喚起',
    'https://www.j-fsa.or.jp/personal/bad_contractor/',
    'https://www.j-fsa.or.jp/personal/bad_contractor/',
    true,
    70
  )
on conflict (guidance_key) do update set
  category = excluded.category,
  severity = excluded.severity,
  title = excluded.title,
  body = excluded.body,
  action_label = excluded.action_label,
  url = excluded.url,
  source_url = excluded.source_url,
  active = excluded.active,
  sort_order = excluded.sort_order,
  updated_at = now();

comment on table public.debt_safety_guidance_master is
  'Master data for legal-rate guardrails, lending self-exclusion guidance, registered lender checks, and debt-trouble education notices.';
