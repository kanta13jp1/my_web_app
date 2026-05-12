create table profiles (
  id uuid primary key,
  email text not null,
  created_at timestamptz not null default now()
);

create table wbs_tasks (
  id uuid primary key,
  title text not null,
  status text not null default 'pending',
  owner_instance text not null,
  source_issue integer,
  created_at timestamptz not null default now()
);

create table ai_circuit_breaker (
  provider text primary key,
  is_open boolean not null default false,
  failure_count integer not null default 0,
  updated_at timestamptz not null default now()
);
