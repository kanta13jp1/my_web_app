-- Isolated restore target only. Never apply to the production database.
-- Source: supabase/auth commit 5e4bec6847bb47162f28c4c3ad02af0f51b748f1
-- migrations/20260824000000_add_recovery_codes_factor_type.up.sql
/* auth_migration: 20260824000000 */
do $$ begin
    alter type auth.factor_type add value 'recovery_code';
exception
    when duplicate_object then null;
end $$;

-- migrations/20260824000001_add_recovery_codes_tables.up.sql
/* auth_migration: 20260824000001 */
create table if not exists auth.mfa_recovery_code_sets (
    id uuid primary key,
    user_id uuid not null unique references auth.users (id) on delete cascade,
    mfa_factor_id uuid not null unique references auth.mfa_factors (id) on delete cascade,
    failed_verification_count integer not null default 0 check (failed_verification_count >= 0),
    verification_locked_until timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

/* auth_migration: 20260824000001 */
create table if not exists auth.mfa_recovery_codes (
    id uuid primary key,
    mfa_recovery_code_set_id uuid not null references auth.mfa_recovery_code_sets (id) on delete cascade,
    code_hash text not null,
    consumed_at timestamptz,
    created_at timestamptz not null default now()
);

/* auth_migration: 20260824000001 */
create index if not exists mfa_recovery_codes_set_id_idx
    on auth.mfa_recovery_codes (mfa_recovery_code_set_id);

