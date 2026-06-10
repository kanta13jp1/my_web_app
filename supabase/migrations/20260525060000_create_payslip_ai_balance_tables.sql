-- Issues #3003, #3006, #3007: payslip ingestion, expense AI
-- classification, and salary-cycle disposable balance.

create or replace function public.set_finance_ai_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payslips',
  'payslips',
  false,
  10485760,
  array['application/pdf']::text[]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can upload their own payslips'
  ) then
    create policy "Users can upload their own payslips"
      on storage.objects for insert
      with check (
        bucket_id = 'payslips'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or owner::text = auth.uid()::text
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can view their own payslips'
  ) then
    create policy "Users can view their own payslips"
      on storage.objects for select
      using (
        bucket_id = 'payslips'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or owner::text = auth.uid()::text
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can update their own payslips'
  ) then
    create policy "Users can update their own payslips"
      on storage.objects for update
      using (
        bucket_id = 'payslips'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or owner::text = auth.uid()::text
        )
      )
      with check (
        bucket_id = 'payslips'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or owner::text = auth.uid()::text
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can delete their own payslips'
  ) then
    create policy "Users can delete their own payslips"
      on storage.objects for delete
      using (
        bucket_id = 'payslips'
        and (
          (storage.foldername(name))[1] = auth.uid()::text
          or owner::text = auth.uid()::text
        )
      );
  end if;
end $$;

create table if not exists public.payslips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pay_date date not null,
  company_name text not null default '',
  gross_amount numeric(14, 2) not null default 0,
  net_amount numeric(14, 2) not null default 0,
  taxable_amount numeric(14, 2),
  social_insurance_total numeric(14, 2),
  deductions jsonb not null default '{}'::jsonb,
  earnings jsonb not null default '{}'::jsonb,
  attendance jsonb not null default '{}'::jsonb,
  source_pdf_path text not null,
  parsed_by text not null default 'deterministic_text_layer',
  confidence numeric(4, 3) not null default 0,
  raw_text_sha256 text,
  review_status text not null default 'auto',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payslips_amounts_non_negative
    check (gross_amount >= 0 and net_amount >= 0),
  constraint payslips_confidence_range
    check (confidence >= 0 and confidence <= 1),
  constraint payslips_deductions_object
    check (jsonb_typeof(deductions) = 'object'),
  constraint payslips_earnings_object
    check (jsonb_typeof(earnings) = 'object'),
  constraint payslips_attendance_object
    check (jsonb_typeof(attendance) = 'object'),
  constraint payslips_review_status_valid
    check (review_status in ('auto', 'needs_review', 'confirmed', 'rejected')),
  constraint payslips_user_pay_date_company_unique
    unique (user_id, pay_date, company_name)
);

create table if not exists public.salary_incomes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pay_date date not null,
  amount numeric(14, 2) not null,
  description text not null default '',
  source text not null default 'manual',
  payslip_id uuid references public.payslips(id) on delete set null,
  confidence numeric(4, 3) not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint salary_incomes_amount_non_negative check (amount >= 0),
  constraint salary_incomes_confidence_range check (confidence >= 0 and confidence <= 1),
  constraint salary_incomes_user_date_source_unique unique (user_id, pay_date, source)
);

create table if not exists public.expense_classifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  classification_key text not null,
  expense_source text not null default 'manual',
  expense_id text,
  posted_at date,
  description text not null,
  amount numeric(14, 2) not null default 0,
  category text not null,
  subcategory text not null default '',
  confidence numeric(4, 3) not null default 0,
  status text not null default 'needs_review',
  classifier text not null default 'deterministic',
  trace_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_classifications_confidence_range
    check (confidence >= 0 and confidence <= 1),
  constraint expense_classifications_status_valid
    check (status in ('auto_confirmed', 'needs_review', 'confirmed', 'rejected')),
  constraint expense_classifications_user_key_unique unique (user_id, classification_key)
);

create table if not exists public.expense_classification_failures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trace_id text,
  expense_source text not null default 'manual',
  expense_id text,
  description text,
  error_message text not null,
  retry_after timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.expense_classification_examples (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  description_pattern text not null,
  category text not null,
  subcategory text not null default '',
  correction_source text not null default 'user_edit',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_classification_examples_user_pattern_unique
    unique (user_id, description_pattern)
);

create table if not exists public.weekly_spending_coaching_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  period_start date not null,
  period_end date not null,
  provider text,
  model text,
  status text not null default 'deterministic_fallback',
  payload jsonb not null default '{}'::jsonb,
  actions jsonb not null default '[]'::jsonb,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint weekly_spending_coaching_cards_payload_object
    check (jsonb_typeof(payload) = 'object'),
  constraint weekly_spending_coaching_cards_actions_array
    check (jsonb_typeof(actions) = 'array'),
  constraint weekly_spending_coaching_cards_user_week_unique
    unique (user_id, week_start)
);

create table if not exists public.recurring_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  amount numeric(14, 2) not null,
  day_of_month integer not null default 1,
  category text not null default 'fixed',
  source text not null default 'manual',
  paused_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recurring_expenses_amount_non_negative check (amount >= 0),
  constraint recurring_expenses_day_range check (day_of_month between 1 and 28)
);

create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  principal numeric(14, 2) not null default 0,
  monthly_payment numeric(14, 2) not null default 0,
  interest_rate numeric(8, 6) not null default 0,
  lender text not null default '',
  last_updated date not null default current_date,
  paused_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint debts_principal_non_negative check (principal >= 0),
  constraint debts_monthly_payment_non_negative check (monthly_payment >= 0),
  constraint debts_interest_rate_non_negative check (interest_rate >= 0)
);

create table if not exists public.disposable_balance_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  as_of_date date not null,
  next_payday date not null,
  days_remaining integer not null,
  income numeric(14, 2) not null default 0,
  fixed_total numeric(14, 2) not null default 0,
  debt_total numeric(14, 2) not null default 0,
  disposable numeric(14, 2) not null default 0,
  daily_pace numeric(14, 2) not null default 0,
  breakdown jsonb not null default '[]'::jsonb,
  required_actions jsonb not null default '[]'::jsonb,
  provider text,
  model text,
  status text not null default 'deterministic',
  trace_id text,
  generated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint disposable_balance_runs_breakdown_array
    check (jsonb_typeof(breakdown) = 'array'),
  constraint disposable_balance_runs_required_actions_array
    check (jsonb_typeof(required_actions) = 'array'),
  constraint disposable_balance_runs_user_date_unique unique (user_id, as_of_date)
);

create table if not exists public.disposable_balance_failures (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  as_of_date date,
  trace_id text,
  error_message text not null,
  recovery_plan text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.disposable_balance_action_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  run_id uuid references public.disposable_balance_runs(id) on delete cascade,
  action_key text not null,
  decision text not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  constraint disposable_balance_action_feedback_decision_valid
    check (decision in ('accepted', 'dismissed', 'snoozed', 'completed'))
);

create index if not exists payslips_user_pay_date_idx
  on public.payslips (user_id, pay_date desc);
create index if not exists salary_incomes_user_pay_date_idx
  on public.salary_incomes (user_id, pay_date desc);
create index if not exists expense_classifications_user_status_idx
  on public.expense_classifications (user_id, status, posted_at desc);
create index if not exists recurring_expenses_user_active_idx
  on public.recurring_expenses (user_id, paused_at, day_of_month);
create index if not exists debts_user_last_updated_idx
  on public.debts (user_id, last_updated);
create index if not exists disposable_balance_runs_user_date_idx
  on public.disposable_balance_runs (user_id, as_of_date desc);

drop trigger if exists payslips_updated_at on public.payslips;
create trigger payslips_updated_at
before update on public.payslips
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists salary_incomes_updated_at on public.salary_incomes;
create trigger salary_incomes_updated_at
before update on public.salary_incomes
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists expense_classifications_updated_at
  on public.expense_classifications;
create trigger expense_classifications_updated_at
before update on public.expense_classifications
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists expense_classification_examples_updated_at
  on public.expense_classification_examples;
create trigger expense_classification_examples_updated_at
before update on public.expense_classification_examples
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists weekly_spending_coaching_cards_updated_at
  on public.weekly_spending_coaching_cards;
create trigger weekly_spending_coaching_cards_updated_at
before update on public.weekly_spending_coaching_cards
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists recurring_expenses_updated_at on public.recurring_expenses;
create trigger recurring_expenses_updated_at
before update on public.recurring_expenses
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists debts_updated_at on public.debts;
create trigger debts_updated_at
before update on public.debts
for each row execute function public.set_finance_ai_updated_at();

drop trigger if exists disposable_balance_runs_updated_at
  on public.disposable_balance_runs;
create trigger disposable_balance_runs_updated_at
before update on public.disposable_balance_runs
for each row execute function public.set_finance_ai_updated_at();

create or replace function public.sync_salary_income_from_payslip()
returns trigger
language plpgsql
as $$
begin
  insert into public.salary_incomes (
    user_id,
    pay_date,
    amount,
    description,
    source,
    payslip_id,
    confidence
  )
  values (
    new.user_id,
    new.pay_date,
    new.net_amount,
    concat('Payslip: ', coalesce(nullif(new.company_name, ''), 'salary')),
    'payslip_auto',
    new.id,
    new.confidence
  )
  on conflict (user_id, pay_date, source) do update
  set
    amount = excluded.amount,
    description = excluded.description,
    payslip_id = excluded.payslip_id,
    confidence = excluded.confidence,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists payslips_sync_salary_income on public.payslips;
create trigger payslips_sync_salary_income
after insert or update of pay_date, net_amount, company_name, confidence
on public.payslips
for each row execute function public.sync_salary_income_from_payslip();

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'payslips',
    'salary_incomes',
    'expense_classifications',
    'expense_classification_failures',
    'expense_classification_examples',
    'weekly_spending_coaching_cards',
    'recurring_expenses',
    'debts',
    'disposable_balance_runs',
    'disposable_balance_failures',
    'disposable_balance_action_feedback'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = table_name
        and policyname = table_name || '_select_own'
    ) then
      execute format(
        'create policy %I on public.%I for select to authenticated using (auth.uid() = user_id)',
        table_name || '_select_own',
        table_name
      );
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = table_name
        and policyname = table_name || '_insert_own'
    ) then
      execute format(
        'create policy %I on public.%I for insert to authenticated with check (auth.uid() = user_id)',
        table_name || '_insert_own',
        table_name
      );
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = table_name
        and policyname = table_name || '_update_own'
    ) then
      execute format(
        'create policy %I on public.%I for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)',
        table_name || '_update_own',
        table_name
      );
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = table_name
        and policyname = table_name || '_delete_own'
    ) then
      execute format(
        'create policy %I on public.%I for delete to authenticated using (auth.uid() = user_id)',
        table_name || '_delete_own',
        table_name
      );
    end if;
  end loop;
end $$;

comment on table public.payslips is
  'Structured monthly payslip rows parsed from owner-scoped PDF uploads.';
comment on table public.expense_classifications is
  'AI or deterministic category decisions for imported expense lines.';
comment on table public.disposable_balance_runs is
  'Salary-cycle disposable balance results and mentor action prompts.';
