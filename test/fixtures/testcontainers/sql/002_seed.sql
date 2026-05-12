insert into profiles (id, email)
values ('00000000-0000-4000-8000-000000000001', 'smoke@example.invalid');

insert into wbs_tasks (id, title, status, owner_instance, source_issue)
values (
  '00000000-0000-4000-8000-000000000002',
  'Testcontainers smoke task',
  'pending',
  'Codex #1',
  1595
);

insert into ai_circuit_breaker (provider, is_open, failure_count)
values ('smoke-provider', false, 0);
