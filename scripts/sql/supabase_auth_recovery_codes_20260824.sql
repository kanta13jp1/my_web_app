-- Isolated restore target only; never apply to production.
-- Official Auth v2.195.0 -> v2.197.0; source commit 4eee58f296d9698a1c2c0ae14d7a0b379c7622d3
-- migrations/20260821000000_add_scim_users.up.sql
/* auth_migration: 20260821000000 */
-- SCIM Users provisioned into one SSO provider. The resource is stored as a
-- document; queryable columns are generated from it so the two cannot drift.
create table if not exists auth.scim_users (
    id uuid not null,
    sso_provider_id uuid not null references auth.sso_providers (id) on delete cascade,
    user_id uuid references auth.users (id) on delete set null,
    resource jsonb not null,
    user_name text not null generated always as (lower(resource->>'userName')) stored,
    external_id text generated always as (resource->>'externalId') stored,
    active boolean not null generated always as (coalesce((resource->>'active')::boolean, true)) stored,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    constraint scim_users_pkey primary key (id)
);

/* auth_migration: 20260821000000 */
-- userName is unique within a provider, case-folded, excluding soft-deleted rows.
create unique index if not exists scim_users_user_name_key
    on auth.scim_users (sso_provider_id, user_name)
    where deleted_at is null;

/* auth_migration: 20260821000000 */
-- externalId is unique within a provider when set; nulls are unconstrained.
create unique index if not exists scim_users_external_id_key
    on auth.scim_users (sso_provider_id, external_id)
    where external_id is not null and deleted_at is null;

/* auth_migration: 20260821000000 */
-- Links a SCIM user to its auth.users row; not partial, so an ON DELETE SET
-- NULL from auth.users can find soft-deleted rows too.
create index if not exists scim_users_user_id_idx
    on auth.scim_users (user_id);

/* auth_migration: 20260821000000 */
create index if not exists scim_users_id_idx
    on auth.scim_users (sso_provider_id, id)
    where deleted_at is null;

/* auth_migration: 20260821000000 */
create index if not exists scim_users_user_name_idx
    on auth.scim_users (sso_provider_id, user_name collate "C", id)
    where deleted_at is null;

/* auth_migration: 20260821000000 */
create index if not exists scim_users_created_at_idx
    on auth.scim_users (sso_provider_id, created_at, id)
    where deleted_at is null;

/* auth_migration: 20260821000000 */
create index if not exists scim_users_updated_at_idx
    on auth.scim_users (sso_provider_id, updated_at, id)
    where deleted_at is null;

/* auth_migration: 20260821000000 */
create index if not exists scim_users_sso_provider_id_idx
    on auth.scim_users (sso_provider_id);

/* auth_migration: 20260821000000 */
-- Supports purging soft-deleted rows.
create index if not exists scim_users_deleted_at_idx
    on auth.scim_users (deleted_at);

-- migrations/20260821010000_add_scim_tokens.up.sql
/* auth_migration: 20260821010000 */
-- Bearer tokens authorising SCIM requests for one SSO provider. Only the
-- SHA-256 digest is stored; a token carries 160 bits, so the digest needs no salt.
create table if not exists auth.scim_tokens (
    id uuid not null,
    sso_provider_id uuid not null references auth.sso_providers (id) on delete cascade,
    token_hash text not null,
    prefix text not null,
    created_at timestamptz not null default now(),
    expires_at timestamptz,
    revoked_at timestamptz,
    last_used_at timestamptz,
    constraint scim_tokens_pkey primary key (id),
    constraint scim_tokens_token_hash_check check (token_hash ~ '^[0-9a-f]{64}$'),
    constraint scim_tokens_expires_at_future check (expires_at is null or expires_at > created_at),
    constraint scim_tokens_revoked_after_created check (revoked_at is null or revoked_at >= created_at)
);

/* auth_migration: 20260821010000 */
-- The digest resolves a request to a provider, so it is unique across all providers.
create unique index if not exists scim_tokens_token_hash_key
    on auth.scim_tokens (token_hash);

/* auth_migration: 20260821010000 */
-- Not partial, so an ON DELETE CASCADE from sso_providers can find revoked
-- tokens too.
create index if not exists scim_tokens_sso_provider_id_idx
    on auth.scim_tokens (sso_provider_id);

/* auth_migration: 20260821010000 */
-- Supports purging expired tokens.
create index if not exists scim_tokens_expires_at_idx
    on auth.scim_tokens (expires_at);

/* auth_migration: 20260821010000 */
-- Supports purging revoked tokens.
create index if not exists scim_tokens_revoked_at_idx
    on auth.scim_tokens (revoked_at);

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

-- migrations/20260831180000_add_expires_at_to_one_time_tokens.up.sql
/* auth_migration: 20260831180000 */
alter table auth.one_time_tokens
    add column if not exists expires_at timestamptz;

