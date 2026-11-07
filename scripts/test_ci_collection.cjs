// Pure mock of the exact github-script body in the checked-out workflow.
// No GitHub calls, network, production files, or CI execution.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const yaml = fs.readFileSync(path.join(__dirname, '..', '.github', 'workflows', 'ci.yml'), 'utf8');
const begin = yaml.indexOf('      - name: Collect PR changed files\n');
const end = yaml.indexOf('      - name: Classify CI scope\n', begin);
if (begin < 0 || end < 0) throw new Error('CI collection section missing');
const section = yaml.slice(begin, end);
const prefix = '          script: |\n';
const scriptIndex = section.indexOf(prefix);
if (scriptIndex < 0) throw new Error('github-script body missing');
const body = section.slice(scriptIndex + prefix.length).split('\n')
  .map((line) => line.startsWith('            ') ? line.slice(12) : line)
  .join('\n');
const execute = new AsyncFunction('github', 'context', 'require', body);
const shaA = 'a'.repeat(40), shaB = 'b'.repeat(40), shaC = 'c'.repeat(40);
const original = 'lib/pages/asset_management_page.dart';
const renamed = 'lib/pages/renamed.dart';
const baseSnapshot = () => ({base: {sha: shaA}, head: {sha: shaB}, changed_files: 1});

async function scenario({ before = baseSnapshot(), after = baseSnapshot(),
                          files = [{filename: renamed, previous_filename: original, status: 'renamed'}],
                          payload = baseSnapshot(), unsafeDir = false,
                          preexistingJson = false } = {}) {
  const writes = new Map();
  let getCount = 0, listCount = 0;
  const github = {
    rest: {pulls: {
      get: async () => ({data: getCount++ === 0 ? before : after}),
      listFiles: () => { throw new Error('paginate should receive function, not call directly'); },
    }},
    paginate: async () => { listCount++; return files; },
  };
  const context = {repo: {owner: 'synthetic', repo: 'synthetic'}, payload: {
    pull_request: {number: 7, base: payload.base, head: payload.head, changed_files: payload.changed_files},
  }};
  const fakeFs = {
    mkdirSync() {},
    lstatSync() { return {isSymbolicLink: () => unsafeDir, isDirectory: () => !unsafeDir}; },
    writeFileSync(name, value, options) {
      if (name.endsWith('debt-read-files.json')) {
        assert.equal(options.flag, 'wx');
        if (preexistingJson) throw new Error('EEXIST');
      }
      writes.set(name, value);
    },
  };
  try {
    await execute(github, context, (name) => {
      if (name !== 'fs') throw new Error('unexpected module');
      return fakeFs;
    });
    return {ok: true, writes, getCount, listCount};
  } catch (error) {
    return {ok: false, writes, getCount, listCount, message: String(error.message)};
  }
}

test('valid rename retains old and new names and original list', async () => {
  const result = await scenario();
  assert.equal(result.ok, true);
  assert.equal(result.getCount, 2);
  assert.equal(result.listCount, 1);
  const data = JSON.parse(result.writes.get('.ci-logs/debt-read-files.json'));
  assert.equal(data.files[0].filename, renamed);
  assert.equal(data.files[0].previous_filename, original);
  assert.equal(data.count, 1);
  assert.equal(result.writes.get('.ci-logs/changed-files.txt'), renamed + '\n');
});

test('head changed before collection fails without file writes', async () => {
  const result = await scenario({before: {...baseSnapshot(), head: {sha: shaC}}});
  assert.equal(result.ok, false);
  assert.equal(result.listCount, 0);
  assert.equal(result.writes.size, 0);
});

test('head changed after collection fails without file writes', async () => {
  const result = await scenario({after: {...baseSnapshot(), head: {sha: shaC}}});
  assert.equal(result.ok, false);
  assert.equal(result.listCount, 1);
  assert.equal(result.writes.size, 0);
});

test('mismatched pagination count fails', async () => {
  const result = await scenario({files: []});
  assert.equal(result.ok, false);
  assert.equal(result.writes.size, 0);
});

test('3000 files is rejected before collection', async () => {
  const snapshot = {...baseSnapshot(), changed_files: 3000};
  const result = await scenario({before: snapshot, after: snapshot, payload: snapshot});
  assert.equal(result.ok, false);
  assert.equal(result.listCount, 0);
  assert.equal(result.writes.size, 0);
});

test('count changed after collection is rejected', async () => {
  const result = await scenario({after: {...baseSnapshot(), changed_files: 2}});
  assert.equal(result.ok, false);
  assert.equal(result.writes.size, 0);
});

test('malformed event refs fail without file writes', async () => {
  const result = await scenario({payload: {...baseSnapshot(), base: {sha: 'bad'}}});
  assert.equal(result.ok, false);
  assert.equal(result.listCount, 0);
  assert.equal(result.writes.size, 0);
});

test('linked metadata directory is rejected', async () => {
  const result = await scenario({unsafeDir: true});
  assert.equal(result.ok, false);
  assert.equal(result.writes.size, 0);
});

test('preexisting metadata file is not overwritten', async () => {
  const result = await scenario({preexistingJson: true});
  assert.equal(result.ok, false);
  assert.equal(result.writes.size, 0);
});
