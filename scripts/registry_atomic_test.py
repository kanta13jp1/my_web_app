"""Credential-free PostgreSQL integration test; run only in an isolated CI DB."""
import concurrent.futures
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
MIGRATION = ROOT / 'supabase/migrations/20260927190917_integration_registry_atomic_versions.sql'
OWNER = '11111111-1111-4111-8111-111111111111'
OTHER = '22222222-2222-4222-8222-222222222222'


def sql(statement, database='registry_clean', success=True):
    result = subprocess.run(
        ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-At', '-d', database],
        input=statement, text=True, capture_output=True, check=False,
        env=os.environ,
    )
    if success and result.returncode:
        raise AssertionError(result.stderr)
    if not success and not result.returncode:
        raise AssertionError('Expected database rejection')
    return result.stdout.strip()


def seed(database):
    sql('CREATE DATABASE ' + database, database='postgres')
    sql('''
      CREATE SCHEMA auth;
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS
        $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      GRANT USAGE ON SCHEMA public, auth TO anon, authenticated, service_role;
      CREATE TABLE public.hub_data (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source text NOT NULL,
        metadata jsonb DEFAULT '{}', created_at timestamptz DEFAULT now());
      ALTER TABLE public.hub_data ENABLE ROW LEVEL SECURITY;
      GRANT SELECT, INSERT, UPDATE, DELETE ON public.hub_data
        TO authenticated, service_role;
      CREATE POLICY service_role_all ON public.hub_data FOR ALL
        TO service_role USING (true) WITH CHECK (true);
      CREATE POLICY authenticated_own_rows ON public.hub_data FOR ALL
        TO authenticated USING (metadata->>'user_id' = auth.uid()::text)
        WITH CHECK (metadata->>'user_id' = auth.uid()::text);
    ''', database)


def insert(source, key_field, owner=OWNER):
    return sql(f'''SET ROLE service_role;
      SELECT metadata->>'version' FROM public.insert_integration_registry_version(
        '{source}', '{owner}',
        '{{"{key_field}":"same-key","version":777,"user_id":"forged"}}');''')


def forced_lock_overlap():
    """Hold the first transaction open until the second is demonstrably blocked."""
    workers = []
    call = f'''SET ROLE service_role; SELECT metadata->>'version' FROM
      public.insert_integration_registry_version('integration_registry_system',
      '{OWNER}', '{{"system_key":"forced-overlap"}}');'''
    try:
        for name, prefix in [('registry-first', 'BEGIN;'), ('registry-second', '')]:
            proc = subprocess.Popen(
                ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-At', '-d', 'registry_clean'],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, env=os.environ,
            )
            workers.append(proc)
            proc.stdin.write(f"SET application_name = '{name}'; {prefix} {call}\n")
            proc.stdin.flush()
            granted = 'true' if name == 'registry-first' else 'false'
            deadline = time.monotonic() + 10
            while sql(f'''SELECT count(*) FROM pg_locks l
                JOIN pg_stat_activity a ON a.pid = l.pid
                WHERE a.application_name = '{name}' AND l.locktype = 'advisory'
                  AND l.granted = {granted}''') != '1':
                if time.monotonic() > deadline:
                    raise AssertionError(f'{name}: expected advisory lock state not observed')
                time.sleep(0.05)
        first_out, first_error = workers[0].communicate('COMMIT;\n', timeout=10)
        second_out, second_error = workers[1].communicate('', timeout=10)
        assert workers[0].returncode == 0, first_error
        assert workers[1].returncode == 0, second_error
        assert '1' in first_out.splitlines(), first_out
        assert second_out.splitlines()[-1] == '2', second_out
        print('PASS: second database transaction waited for the first advisory lock; versions 1 and 2')
    finally:
        for proc in workers:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()


def main():
    sql('CREATE ROLE service_role NOLOGIN BYPASSRLS; '
        'CREATE ROLE authenticated NOLOGIN; CREATE ROLE anon NOLOGIN;', 'postgres')
    migration = MIGRATION.read_text(encoding='utf-8')
    for database, bad_values in [
        ('registry_duplicate', f'''('integration_registry_system',
          '{{"user_id":"{OWNER}","system_key":"dup","version":1}}'),
          ('integration_registry_system',
          '{{"user_id":"{OWNER}","system_key":"dup","version":1}}')'''),
        ('registry_invalid', '''('integration_registry_system', '{}')'''),
    ]:
        seed(database)
        sql('INSERT INTO public.hub_data(source, metadata) VALUES ' + bad_values, database)
        before = sql('SELECT jsonb_agg(to_jsonb(h) ORDER BY id) FROM public.hub_data h', database)
        sql(migration, database, success=False)
        assert before == sql('SELECT jsonb_agg(to_jsonb(h) ORDER BY id) FROM public.hub_data h', database)
        assert sql("SELECT count(*) FROM pg_constraint WHERE conname = 'integration_registry_valid_history'", database) == '0'
        assert sql("SELECT to_regprocedure('public.insert_integration_registry_version(text,uuid,jsonb)') IS NULL", database) == 't'
    seed('registry_clean')
    sql(f'''INSERT INTO public.hub_data(source, metadata) VALUES
      ('integration_registry_system',
      '{{"user_id":"{OWNER}","system_key":"historic","version":7,"name":"keep"}}');''')
    historical = sql("SELECT to_jsonb(h) FROM public.hub_data h WHERE metadata->>'system_key' = 'historic'")
    sql(migration)
    assert historical == sql("SELECT to_jsonb(h) FROM public.hub_data h WHERE metadata->>'system_key' = 'historic'")
    assert sql(f'''SET ROLE service_role; SELECT metadata->>'version' FROM
      public.insert_integration_registry_version('integration_registry_system',
      '{OWNER}', '{{"system_key":"historic"}}');''').splitlines()[-1] == '8'
    assert sql("SELECT prosecdef FROM pg_proc WHERE oid = 'public.insert_integration_registry_version(text,uuid,jsonb)'::regprocedure") == 'f'
    for source, key in [
        ('integration_registry_system', 'system_key'),
        ('integration_registry_interface', 'interface_key'),
        ('integration_registry_mapping', 'mapping_key'),
    ]:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            outcomes = list(pool.map(lambda _: insert(source, key), range(24)))
        versions = sorted(int(value.splitlines()[-1]) for value in outcomes)
        assert versions == list(range(1, 25)), versions
        assert insert(source, key, OTHER).splitlines()[-1] == '1'
    assert sql("SELECT count(*) FROM public.hub_data WHERE metadata->>'user_id' = 'forged'") == '0'
    assert sql(f'''SET ROLE authenticated; SET request.jwt.claim.sub = '{OWNER}';
      SELECT count(*) FROM public.hub_data WHERE metadata->>'user_id' = '{OTHER}';''').splitlines()[-1] == '0'
    assert sql(f'''SET ROLE authenticated; SET request.jwt.claim.sub = '{OWNER}';
      SELECT count(*) FROM public.hub_data WHERE metadata->>'user_id' = '{OWNER}';''').splitlines()[-1] == '74'
    for role in ['anon', 'authenticated']:
        sql(f'''SET ROLE {role}; SELECT public.insert_integration_registry_version(
          'integration_registry_system', '{OWNER}', '{{"system_key":"denied"}}');''', success=False)
    sql(f'''SET ROLE authenticated; SET request.jwt.claim.sub = '{OWNER}';
      INSERT INTO public.hub_data(source,metadata) VALUES ('integration_registry_system',
      '{{"user_id":"{OWNER}","system_key":"denied","version":1}}');''', success=False)
    sql(f'''SET ROLE authenticated; SET request.jwt.claim.sub = '{OWNER}';
      INSERT INTO public.hub_data(source,metadata) VALUES ('unrelated', '{{"user_id":"{OWNER}"}}');
      UPDATE public.hub_data SET metadata = metadata || '{{"ok":true}}' WHERE source = 'unrelated';''')
    sql(f'''SET ROLE authenticated; SET request.jwt.claim.sub = '{OWNER}';
      UPDATE public.hub_data SET source = 'integration_registry_system',
      metadata = '{{"user_id":"{OWNER}","system_key":"bypass","version":1}}'
      WHERE source = 'unrelated';''', success=False)
    sql(f'''SET ROLE authenticated; SET request.jwt.claim.sub = '{OWNER}';
      DELETE FROM public.hub_data WHERE source = 'unrelated';''')
    for operation in ["UPDATE public.hub_data SET metadata = metadata || '{\"version\":100}'",
                      'DELETE FROM public.hub_data']:
        sql('SET ROLE service_role; ' + operation + " WHERE source = 'integration_registry_system'", success=False)
    sql(f'''SET ROLE service_role; INSERT INTO public.hub_data(source,metadata)
      VALUES ('integration_registry_system',
      '{{"user_id":"{OWNER}","system_key":"same-key","version":1}}');''', success=False)
    sql('ALTER TABLE public.hub_data ADD CONSTRAINT test_abort '
        "CHECK (metadata->>'system_key' IS DISTINCT FROM 'abort');")
    sql(f'''SET ROLE service_role; SELECT public.insert_integration_registry_version(
      'integration_registry_system', '{OWNER}', '{{"system_key":"abort"}}');''', success=False)
    assert sql("SELECT count(*) FROM public.hub_data WHERE metadata->>'system_key' = 'abort'") == '0'
    sql('ALTER TABLE public.hub_data DROP CONSTRAINT test_abort;')
    assert sql(f'''SET ROLE service_role; SELECT metadata->>'version' FROM
      public.insert_integration_registry_version('integration_registry_system',
        '{OWNER}', '{{"system_key":"abort"}}');''').splitlines()[-1] == '1'
    forced_lock_overlap()
    print('PASS: concurrent allocation, isolation, server-only writes, uniqueness, immutable history, rollback, and migration preflight')


if __name__ == '__main__':
    main()
