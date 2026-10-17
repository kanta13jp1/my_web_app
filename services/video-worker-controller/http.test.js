'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const { once } = require('node:events');
const { createServer } = require('./server');

const token = 'synthetic-controller-contract-token-20261018';
const jobId = '12345678-1234-4123-8123-123456789abc';

async function harness(t, fetchImpl = async () => {
  throw new Error('unexpected_cloud_request');
}) {
  const server = createServer({
    projectId: 'contract-project', zone: 'asia-northeast1-c',
    instanceName: 'contract-worker', wakeToken: token,
  }, { accessToken: 'synthetic-access-token', fetchImpl });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  return async (path, options = {}) => fetch(origin + path, {
    ...options,
    headers: { Connection: 'close', ...options.headers },
  });
}

function wake(body, authorization = `Bearer ${token}`) {
  return { method: 'POST', headers: { Authorization: authorization, 'Content-Type': 'application/json' },
    body: JSON.stringify(body) };
}

test('HTTP health and unknown routes do not contact cloud APIs', async t => {
  const request = await harness(t);
  const health = await request('/healthz');
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), { status: 'ok' });
  const missing = await request('/missing');
  assert.equal(missing.status, 404);
  assert.deepEqual(await missing.json(), { error: 'not_found' });
});

test('HTTP unauthorized wake rejects before any cloud request', async t => {
  let calls = 0;
  const request = await harness(t, async () => { calls++; throw new Error('unexpected_cloud_request'); });
  const response = await request('/wake', wake({ job_id: jobId }, 'Bearer invalid'));
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'unauthorized' });
  assert.equal(calls, 0);
});

test('HTTP malformed job rejects before any cloud request', async t => {
  let calls = 0;
  const request = await harness(t, async () => { calls++; throw new Error('unexpected_cloud_request'); });
  const response = await request('/wake', wake({ job_id: 'invalid' }));
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: 'invalid_job_id' });
  assert.equal(calls, 0);
});

test('HTTP accepted wake returns provisioning after one synthetic start', async t => {
  const calls = [];
  const request = await harness(t, async (url, options = {}) => {
    calls.push({ url, method: options.method || 'GET' });
    return new Response(JSON.stringify(calls.length === 1 ? { status: 'TERMINATED' } : {}));
  });
  const response = await request('/wake', wake({ job_id: jobId }));
  assert.equal(response.status, 202);
  assert.deepEqual(await response.json(), { status: 'PROVISIONING', started: true });
  assert.equal(calls.length, 2);
  assert.equal(calls[1].method, 'POST');
  assert.match(calls[1].url, /\/contract-worker\/start$/);
});

test('HTTP upstream failure remains retryable without exposing provider details', async t => {
  const request = await harness(t, async () => new Response('{}', { status: 503 }));
  const response = await request('/wake', wake({ job_id: jobId }));
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'worker_wake_unavailable' });
  assert.equal(response.headers.get('cache-control'), 'no-store');
});
