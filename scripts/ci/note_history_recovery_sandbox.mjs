import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, realpathSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// No linked application config, migrations, ENEX or user credentials are loaded.
assert.equal(process.env.GITHUB_ACTIONS, 'true', 'GitHub-hosted execution required');
assert.equal(process.platform, 'linux', 'Linux runner required');
assert.match(process.env.GITHUB_RUN_ID ?? '', /^\d+$/);
assert.match(process.env.GITHUB_RUN_ATTEMPT ?? '', /^\d+$/);
assert.match(process.env.GITHUB_SHA ?? '', /^[0-9a-f]{40}$/);
assert.equal(process.env.SUPABASE_ACCESS_TOKEN ?? '', '', 'No project token allowed');
assert.equal(process.env.SUPABASE_DB_PASSWORD ?? '', '', 'No remote DB password allowed');

const root = join(realpathSync(process.env.RUNNER_TEMP), 'note-history-recovery-' +
  process.env.GITHUB_RUN_ID + '-' + process.env.GITHUB_RUN_ATTEMPT);
mkdirSync(root); // Refuse reuse instead of resetting an existing project.
const outputDir = join(process.env.GITHUB_WORKSPACE, '.ci-logs');
mkdirSync(outputDir, { recursive: true });
const result = {
  revision: process.env.GITHUB_SHA, syntheticOnly: true, cli: '2.117.0',
  checks: [], applicationRestorationImplemented: false,
  cleanup: 'not_started', passed: false,
};
let started = false;

function run(command, args, options = {}) {
  const response = spawnSync(command, args, {
    cwd: root, encoding: 'utf8', timeout: 600_000,
    maxBuffer: 16 * 1024 * 1024, ...options,
  });
  if (response.status !== 0) {
    // Startup output may contain generated test keys: never publish this log.
    writeFileSync(join(root, 'last-command-private.log'),
      String(response.stdout ?? '') + '\n' + String(response.stderr ?? ''));
    throw new Error(command + ' ' + args[0] + ' failed; exit=' + response.status);
  }
  return response.stdout;
}
function passed(label) {
  result.checks.push(label);
  console.log('PASS ' + label);
}
function loopbackUrl(value, expectedPort) {
  const url = new URL(value);
  assert.ok(['127.0.0.1', 'localhost'].includes(url.hostname), 'Loopback required');
  assert.equal(Number(url.port), expectedPort, 'Unexpected sandbox port');
  return url;
}

try {
  assert.match(run('supabase', ['--version']), /2\.117\.0/);
  for (const args of [
    ['--help'], ['init', '--help'], ['start', '--help'], ['stop', '--help'],
    ['status', '--help'], ['migration', '--help'], ['migration', 'new', '--help'],
  ]) console.log(run('supabase', args));
  run('supabase', ['init', '--workdir', root]);
  const config = readFileSync(join(root, 'supabase/config.toml'), 'utf8');
  assert.ok(!config.includes('smmkxxavexumewbfaqpy'), 'Production project forbidden');
  run('supabase', ['migration', 'new', 'note_history_recovery', '--workdir', root]);
  const names = readdirSync(join(root, 'supabase/migrations'));
  assert.equal(names.length, 1);
  assert.match(names[0], /^\d{14}_note_history_recovery\.sql$/);
  result.cliGeneratedMigration = names[0];
  console.log('CLI_GENERATED_MIGRATION ' + names[0]);

  started = true;
  run('supabase', [
    'start', '--workdir', root, '--exclude',
    'studio,imgproxy,realtime,mailpit,postgres-meta,edge-runtime,logflare,vector,supavisor',
  ]);
  const status = JSON.parse(run('supabase', ['status', '--workdir', root, '--output', 'json']));
  console.log('Sandbox status fields: ' + Object.keys(status).sort().join(', '));
  const api = loopbackUrl(status.API_URL, 54321);
  assert.equal(api.protocol, 'http:');
  const db = loopbackUrl(status.DB_URL, 54322);
  assert.ok(['postgres:', 'postgresql:'].includes(db.protocol));
  assert.equal(db.pathname, '/postgres');
  assert.ok(status.ANON_KEY && status.SERVICE_ROLE_KEY, 'Local test keys required');
  for (const value of [status.ANON_KEY, status.SERVICE_ROLE_KEY]) console.log('::add-mask::' + value);
  const anonKey = status.ANON_KEY;
  const serviceKey = status.SERVICE_ROLE_KEY;
  const bucket = 'recovery-' + randomUUID();
  const payload = randomBytes(128 * 1024);
  const digest = value => createHash('sha256').update(value).digest('hex');
  const expectedHash = digest(payload);

  async function request(label, path, {
    method = 'GET', token, key = anonKey, json, bytes,
  } = {}) {
    const url = new URL(path, api);
    assert.equal(url.origin, api.origin, 'External HTTP forbidden');
    const headers = { apikey: key };
    if (token) headers.Authorization = 'Bearer ' + token;
    if (json !== undefined) headers['Content-Type'] = 'application/json';
    if (bytes !== undefined) headers['Content-Type'] = 'application/octet-stream';
    try {
      return await fetch(url, {
        method, headers, body: json !== undefined ? JSON.stringify(json) : bytes,
        redirect: 'error', signal: AbortSignal.timeout(20_000),
      });
    } catch {
      throw new Error(label + ' transport failed');
    }
  }
  async function ok(label, response) {
    if (!response.ok) throw new Error(label + ' status=' + response.status);
    return response;
  }
  async function makeOwner() {
    const email = randomUUID() + '@recovery.invalid';
    const password = randomBytes(32).toString('hex');
    await ok('create synthetic owner', await request('create owner', '/auth/v1/admin/users', {
      method: 'POST', token: serviceKey, key: serviceKey,
      json: { email, password, email_confirm: true },
    }));
    const signedIn = await ok('sign in synthetic owner', await request('sign in',
      '/auth/v1/token?grant_type=password', {
        method: 'POST', json: { email, password },
      }));
    const data = await signedIn.json();
    assert.ok(data.access_token && data.user?.id);
    console.log('::add-mask::' + data.access_token);
    return { id: data.user.id, token: data.access_token };
  }
  const owner = await makeOwner();
  const other = await makeOwner();
  passed('two_real_auth_sessions');
  await ok('create synthetic private bucket', await request('create bucket', '/storage/v1/bucket', {
    method: 'POST', token: serviceKey, key: serviceKey,
    json: { id: bucket, name: bucket, public: false },
  }));
  assert.match(bucket, /^recovery-[0-9a-f-]+$/);
  // Isolated policies test a primitive, not the pending application migration.
  const sql = [
    'create policy recovery_probe_read on storage.objects for select to authenticated',
    "using (bucket_id = '" + bucket + "' and (storage.foldername(name))[1] = (select auth.uid())::text);",
    'create policy recovery_probe_insert on storage.objects for insert to authenticated',
    "with check (bucket_id = '" + bucket + "' and (storage.foldername(name))[1] = (select auth.uid())::text);",
    'create policy recovery_probe_delete_working on storage.objects for delete to authenticated',
    "using (bucket_id = '" + bucket + "' and (storage.foldername(name))[1] = (select auth.uid())::text",
    "and (storage.foldername(name))[2] = 'working');",
  ].join('\n');
  run('psql', ['-X', '-v', 'ON_ERROR_STOP=1'], {
    input: sql,
    env: { ...process.env,
      PGHOST: db.hostname, PGPORT: db.port, PGUSER: decodeURIComponent(db.username),
      PGPASSWORD: decodeURIComponent(db.password), PGDATABASE: 'postgres',
    },
  });
  const working = owner.id + '/working/note.bin';
  const backup = owner.id + '/retained/note.bin';
  const objectUrl = path => '/storage/v1/object/' + bucket + '/' + path;
  const readUrl = path => '/storage/v1/object/authenticated/' + bucket + '/' + path;
  async function verifyBytes(label, path) {
    const response = await ok(label, await request(label, readUrl(path), { token: owner.token }));
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.equal(bytes.length, payload.length, label + ' byte count');
    assert.equal(digest(bytes), expectedHash, label + ' SHA-256');
    passed(label);
  }
  async function copy(label, from, to) {
    await ok(label, await request(label, '/storage/v1/object/copy', {
      method: 'POST', token: owner.token,
      json: { bucketId: bucket, sourceKey: from, destinationKey: to },
    }));
  }
  await ok('owner upload', await request('upload', objectUrl(working), {
    method: 'POST', token: owner.token, bytes: payload,
  }));
  await verifyBytes('private_upload_round_trip', working);
  for (const [label, token] of [['other_owner_read_denied', other.token], ['anonymous_read_denied', null]]) {
    const response = await request(label, readUrl(working), { token });
    assert.ok([400, 401, 403, 404].includes(response.status), label);
    passed(label);
  }
  await copy('copy to retained snapshot', working, backup);
  await verifyBytes('retained_copy_byte_identity', backup);
  const overwrite = await request('overwrite retained copy', objectUrl(backup), {
    method: 'PUT', token: owner.token, bytes: randomBytes(128),
  });
  assert.ok([400, 401, 403, 404].includes(overwrite.status), 'Retained overwrite must be denied');
  await verifyBytes('retained_copy_survives_overwrite_attempt', backup);
  const backupDelete = await request('delete retained copy', '/storage/v1/object/' + bucket, {
    method: 'DELETE', token: owner.token, json: { prefixes: [backup] },
  });
  // RLS can produce 200 with no deleted rows; verify retained bytes afterwards.
  assert.ok([200, 400, 401, 403, 404].includes(backupDelete.status));
  await verifyBytes('retained_copy_survives_delete_attempt', backup);
  await ok('remove synthetic working object', await request('remove working',
    '/storage/v1/object/' + bucket, {
      method: 'DELETE', token: owner.token, json: { prefixes: [working] },
    }));
  const gone = await request('working object absent', readUrl(working), { token: owner.token });
  assert.ok([400, 404].includes(gone.status), 'Synthetic working object must be removed');
  passed('synthetic_working_object_removed');
  await verifyBytes('backup_survives_working_object_removal', backup);
  await copy('restore working bytes', backup, working);
  await verifyBytes('cloud_copy_restores_exact_working_bytes', working);
  result.payloadBytes = payload.length;
  result.syntheticSha256 = expectedHash;
  result.passed = true;
} catch (error) {
  result.failure = error.message;
  process.exitCode = 1;
  console.error('Sandbox failed: ' + error.message);
} finally {
  if (started) {
    try {
      run('supabase', ['stop', '--workdir', root, '--no-backup']);
      result.cleanup = 'disposable_project_stopped_and_volumes_removed';
    } catch {
      result.cleanup = 'failed';
      result.passed = false;
      process.exitCode = 1;
      console.error('Disposable project cleanup failed; runner disposal is the fallback');
    }
  }
  writeFileSync(join(outputDir, 'note-history-recovery-result.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
}
