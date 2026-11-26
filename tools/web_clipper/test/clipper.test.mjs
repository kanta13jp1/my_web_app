import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  buildClipMarkdown,
  buildSourceKey,
  MAX_CONTENT_LENGTH,
  MAX_TITLE_LENGTH,
  normalizeTagsInput,
  sanitizeClipUrl,
} from '../lib/clip_formatter.mjs';
import {
  DEFAULT_ENDPOINT,
  saveClippedNote,
  testConnection,
  validateApiKey,
} from '../lib/jibun_api_client.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const extensionRoot = path.resolve(__dirname, '..');

test('manifest.json uses Manifest V3 with least-privilege permissions', () => {
  const manifestPath = path.join(extensionRoot, 'manifest.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  assert.equal(manifest.manifest_version, 3);
  assert.deepEqual(manifest.permissions, ['activeTab', 'scripting', 'storage']);
  assert.deepEqual(manifest.host_permissions, [
    'https://smmkxxavexumewbfaqpy.supabase.co/*',
  ]);
  assert.equal(manifest.host_permissions.includes('<all_urls>'), false);
});

test('sanitizeClipUrl permits http/https and rejects unsafe protocols', () => {
  assert.equal(sanitizeClipUrl('https://example.com/a?x=1'), 'https://example.com/a?x=1');
  assert.equal(sanitizeClipUrl('http://example.com/post'), 'http://example.com/post');
  assert.equal(sanitizeClipUrl('javascript:alert(1)'), null);
  assert.equal(sanitizeClipUrl('data:text/html,<script>'), null);
  assert.equal(sanitizeClipUrl('chrome://extensions'), null);
  assert.equal(sanitizeClipUrl(''), null);
});

test('normalizeTagsInput trims, strips hashes, deduplicates, and caps tags', () => {
  assert.deepEqual(
    normalizeTagsInput(' #AI, 生産性  #ai  web-clip '),
    ['AI', '生産性', 'web-clip'],
  );
  const longList = Array.from({ length: 30 }, (_, i) => `tag${i}`).join(',');
  const capped = normalizeTagsInput(longList);
  assert.equal(capped.length, 20);
});

test('buildSourceKey is deterministic and within 160 chars', () => {
  const k1 = buildSourceKey('https://example.com/article/123', 'article');
  const k2 = buildSourceKey('https://example.com/article/123', 'article');
  const k3 = buildSourceKey('https://example.com/article/123', 'selection');
  assert.equal(k1, k2);
  assert.notEqual(k1, k3);
  assert.ok(k1.startsWith('web-clip:article:'));
  assert.ok(k1.length <= 160);
});

test('buildClipMarkdown formats article, selection, and enforces bounds', () => {
  const article = buildClipMarkdown({
    title: '  Long   Title  '.padEnd(250, 'x'),
    url: 'https://example.com/post',
    excerpt: '記事の概要',
    markdownBody: '## 見出し\n\n本文です。',
    clippedAtIso: '2026-11-26T10:00:00Z',
    mode: 'article',
  });
  assert.equal(article.title.length, MAX_TITLE_LENGTH);
  assert.match(article.content, /出典: \[https:\/\/example\.com\/post\]/);
  assert.match(article.content, /記事の概要/);
  assert.match(article.content, /## 見出し/);

  const selection = buildClipMarkdown({
    title: '引用',
    url: 'javascript:alert(1)',
    selectedText: '1行目\n2行目',
    clippedAtIso: '2026-11-26T10:00:00Z',
    mode: 'selection',
  });
  assert.equal(selection.url, null);
  assert.equal(selection.content.includes('javascript:'), false);
  assert.match(selection.content, /> 1行目\n> 2行目/);

  const huge = buildClipMarkdown({
    title: 'Huge',
    url: 'https://example.com',
    markdownBody: 'あ'.repeat(100500),
    clippedAtIso: '2026-11-26T10:00:00Z',
  });
  assert.equal(huge.content.length, MAX_CONTENT_LENGTH);
});

test('validateApiKey rejects missing or malformed keys before network calls', () => {
  assert.equal(validateApiKey('').ok, false);
  assert.equal(validateApiKey('not_a_key_123456').ok, false);
  assert.equal(validateApiKey('jibun_sk_short').ok, false);
  assert.equal(validateApiKey('  jibun_sk_aaaaaaaaaaaa  ').ok, true);
});

test('saveClippedNote posts web_clipper metadata and maps errors', async () => {
  const captured = [];
  const fakeFetch = async (url, init) => {
    captured.push({ url, init, body: JSON.parse(init.body) });
    return new Response(
      JSON.stringify({
        success: true,
        note: { id: 42, title: 'T', content: 'C' },
        trace_id: 'tr-1',
      }),
      { status: 201, headers: { 'Content-Type': 'application/json' } },
    );
  };

  const okRes = await saveClippedNote({
    apiKey: 'jibun_sk_aaaaaaaaaaaa',
    title: 'Clip Title',
    content: 'Clip Body',
    tags: ['web-clip', 'flutter'],
    captureStatus: 'inbox',
    sourceKey: 'web-clip:article:1234',
    fetchImpl: fakeFetch,
  });
  assert.equal(okRes.ok, true);
  assert.equal(okRes.note.id, 42);
  assert.equal(captured[0].url, DEFAULT_ENDPOINT);
  assert.equal(captured[0].body.action, 'api.notes.create');
  assert.equal(captured[0].body.capture_source, 'web_clipper');
  assert.equal(captured[0].body.capture_status, 'inbox');
  assert.deepEqual(captured[0].body.tags, ['web-clip', 'flutter']);

  const deniedRes = await saveClippedNote({
    apiKey: 'jibun_sk_aaaaaaaaaaaa',
    title: 'T',
    content: 'C',
    fetchImpl: async () =>
      new Response(JSON.stringify({ error: 'Permission denied: notes.write required' }), {
        status: 403,
      }),
  });
  assert.equal(deniedRes.ok, false);
  assert.equal(deniedRes.status, 403);
  assert.match(deniedRes.error, /notes\.write/);
});

test('testConnection detects notes.write scope on api.me', async () => {
  const res = await testConnection({
    apiKey: 'jibun_sk_aaaaaaaaaaaa',
    fetchImpl: async () =>
      new Response(
        JSON.stringify({
          success: true,
          user_id: 'user-1',
          key: { scopes: ['notes.read', 'notes.write'] },
        }),
        { status: 200 },
      ),
  });
  assert.equal(res.ok, true);
  assert.equal(res.canWriteNotes, true);
});
