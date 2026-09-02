'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const { configuration, safeEqual, wakeInstance } = require('./server');

const config = {
  projectId: 'mighty-link-ai-connect',
  zone: 'asia-northeast1-c',
  instanceName: 'video-gpu-tokyo-01',
};

test('wake token comparison requires an exact bounded secret', () => {
  const token = '0123456789abcdef0123456789abcdef';
  assert.equal(safeEqual(token, token), true);
  assert.equal(safeEqual(`${token}x`, token), false);
  assert.equal(safeEqual('short', 'short'), false);
});

test('configuration rejects broad or malformed compute targets', () => {
  assert.throws(() => configuration({
    GCP_PROJECT_ID: 'mighty-link-ai-connect',
    GCP_VIDEO_WORKER_ZONE: 'asia-northeast1-c',
    GCP_VIDEO_WORKER_INSTANCE: '../all-instances',
    VIDEO_WORKER_WAKE_TOKEN: 'x'.repeat(32),
  }), /invalid_instance/);
});

test('running instance is accepted without a start request', async () => {
  const calls = [];
  const result = await wakeInstance(config, {
    accessToken: 'gcp-access-token',
    fetchImpl: async (url, options = {}) => {
      calls.push({ url, options });
      return new Response(JSON.stringify({ status: 'RUNNING' }), { status: 200 });
    },
  });
  assert.deepEqual(result, { state: 'RUNNING', started: false });
  assert.equal(calls.length, 1);
});

test('terminated instance receives one authenticated start request', async () => {
  const calls = [];
  const result = await wakeInstance(config, {
    accessToken: 'gcp-access-token',
    fetchImpl: async (url, options = {}) => {
      calls.push({ url, options });
      if (calls.length === 1) {
        return new Response(JSON.stringify({ status: 'TERMINATED' }), {
          status: 200,
        });
      }
      return new Response('{}', { status: 200 });
    },
  });
  assert.deepEqual(result, { state: 'PROVISIONING', started: true });
  assert.equal(calls.length, 2);
  assert.equal(calls[1].options.method, 'POST');
  assert.match(calls[1].url, /\/video-gpu-tokyo-01\/start$/);
  assert.equal(calls[1].options.headers.Authorization, 'Bearer gcp-access-token');
});

test('unsafe transition is not forced', async () => {
  await assert.rejects(
    wakeInstance(config, {
      accessToken: 'gcp-access-token',
      fetchImpl: async () => new Response(
        JSON.stringify({ status: 'STOPPING' }),
        { status: 200 },
      ),
    }),
    /compute_instance_transitioning/,
  );
});
