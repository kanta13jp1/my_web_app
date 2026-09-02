'use strict';

const crypto = require('crypto');
const http = require('http');

const METADATA_TOKEN_URL =
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token';
const JOB_ID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const INSTANCE_RE = /^[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?$/;
const ZONE_RE = /^[a-z]+-[a-z]+[0-9]-[a-z]$/;
const PROJECT_RE = /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/;
const READY_STATES = new Set(['RUNNING', 'STAGING', 'PROVISIONING']);

function safeEqual(left, right) {
  const a = Buffer.from(String(left || ''), 'utf8');
  const b = Buffer.from(String(right || ''), 'utf8');
  if (a.length < 32 || a.length > 256 || a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

function bearerToken(req) {
  const authorization = String(req.headers.authorization || '');
  return authorization.replace(/^Bearer\s+/i, '').trim();
}

function readJson(req, maximumBytes = 4096) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > maximumBytes) {
        reject(new Error('request_too_large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        resolve(parsed && typeof parsed === 'object' && !Array.isArray(parsed)
          ? parsed
          : null);
      } catch (_) {
        resolve(null);
      }
    });
    req.on('error', reject);
  });
}

async function accessToken(fetchImpl = fetch) {
  const response = await fetchImpl(METADATA_TOKEN_URL, {
    headers: { 'Metadata-Flavor': 'Google' },
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error('metadata_token_unavailable');
  const body = await response.json();
  if (!body || typeof body.access_token !== 'string') {
    throw new Error('metadata_token_invalid');
  }
  return body.access_token;
}

async function wakeInstance(config, dependencies = {}) {
  const fetchImpl = dependencies.fetchImpl || fetch;
  const token = dependencies.accessToken || await accessToken(fetchImpl);
  const instanceUrl =
    `https://compute.googleapis.com/compute/v1/projects/${config.projectId}` +
    `/zones/${config.zone}/instances/${config.instanceName}`;
  const headers = { Authorization: `Bearer ${token}` };
  const current = await fetchImpl(instanceUrl, {
    headers,
    signal: AbortSignal.timeout(8000),
  });
  if (!current.ok) throw new Error(`compute_get_${current.status}`);
  const instance = await current.json();
  const state = String(instance.status || '').toUpperCase();
  if (READY_STATES.has(state)) return { state, started: false };
  if (state !== 'TERMINATED') {
    throw new Error('compute_instance_transitioning');
  }
  const started = await fetchImpl(`${instanceUrl}/start`, {
    method: 'POST',
    headers,
    signal: AbortSignal.timeout(12000),
  });
  if (!started.ok) throw new Error(`compute_start_${started.status}`);
  return { state: 'PROVISIONING', started: true };
}

function configuration(environment = process.env) {
  const config = {
    projectId: String(environment.GCP_PROJECT_ID || '').trim(),
    zone: String(environment.GCP_VIDEO_WORKER_ZONE || '').trim(),
    instanceName: String(environment.GCP_VIDEO_WORKER_INSTANCE || '').trim(),
    wakeToken: String(environment.VIDEO_WORKER_WAKE_TOKEN || '').trim(),
  };
  if (!PROJECT_RE.test(config.projectId)) throw new Error('invalid_project');
  if (!ZONE_RE.test(config.zone)) throw new Error('invalid_zone');
  if (!INSTANCE_RE.test(config.instanceName)) throw new Error('invalid_instance');
  if (config.wakeToken.length < 32 || config.wakeToken.length > 256) {
    throw new Error('invalid_wake_token');
  }
  return config;
}

function sendJson(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

function createServer(config, dependencies = {}) {
  return http.createServer(async (req, res) => {
    const path = String(req.url || '').split('?')[0];
    if (req.method === 'GET' && path === '/healthz') {
      return sendJson(res, 200, { status: 'ok' });
    }
    if (req.method !== 'POST' || path !== '/wake') {
      return sendJson(res, 404, { error: 'not_found' });
    }
    if (!safeEqual(bearerToken(req), config.wakeToken)) {
      return sendJson(res, 401, { error: 'unauthorized' });
    }
    try {
      const body = await readJson(req);
      if (!body || !JOB_ID_RE.test(String(body.job_id || ''))) {
        return sendJson(res, 400, { error: 'invalid_job_id' });
      }
      const result = await wakeInstance(config, dependencies);
      return sendJson(res, 202, { status: result.state, started: result.started });
    } catch (error) {
      const code = error instanceof Error ? error.message : 'internal_error';
      console.error('[video-worker-controller]', /^[a-z0-9_]+$/i.test(code)
        ? code
        : 'internal_error');
      return sendJson(res, 503, { error: 'worker_wake_unavailable' });
    }
  });
}

if (require.main === module) {
  const config = configuration();
  const port = Number(process.env.PORT || 8080);
  createServer(config).listen(port, '0.0.0.0', () => {
    console.log(`video worker controller ready on ${port}`);
  });
}

module.exports = {
  configuration,
  createServer,
  safeEqual,
  wakeInstance,
};
