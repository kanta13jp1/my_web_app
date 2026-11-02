const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const yaml = fs.readFileSync(path.join(__dirname, '../.github/workflows/documentation-quality-notify.yml'), 'utf8');
const source = yaml.split('          script: |\n')[1].split('\n').map(line => line.replace(/^            /, '')).join('\n');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
function fixture(overrides = {}, comments = []) {
  const run = { id: 123, name: 'Documentation Quality Gate', path: '.github/workflows/documentation-quality.yml',
    repository: { full_name: 'owner/repo' }, head_repository: { full_name: 'owner/repo' },
    event: 'pull_request', status: 'completed', conclusion: 'failure', ...overrides };
  const sent = [];
  const actions = { getWorkflowRun: async () => ({ data: run }), listJobsForWorkflowRun: 'jobs' };
  const issues = { listComments: 'comments', createComment: async data => sent.push(data) };
  const github = { rest: { actions, issues }, paginate: async method => method === 'comments' ? comments
    : [{ id: 456, conclusion: 'failure', steps: [{ name: 'Validate Markdown and preserve all findings', conclusion: 'failure' }] }] };
  const context = { repo: { owner: 'owner', repo: 'repo' }, eventName: 'workflow_run', payload: { workflow_run: { id: 123 } } };
  return { run, sent, github, context, invoke: () => new AsyncFunction('github', 'context', 'core', source)(github, context, { info() {} }) };
}
test('one failure yields fixed issue, canonical links and repair guidance without logs', async () => {
  const f = fixture(); await f.invoke(); assert.equal(f.sent.length, 1);
  assert.equal(f.sent[0].issue_number, 2625); assert.match(f.sent[0].body, /run=123/);
  assert.match(f.sent[0].body, /runs\/123\/job\/456/); assert.match(f.sent[0].body, /findings.json/);
});
test('bot marker deduplicates even across attempts', async () => {
  const f = fixture({ run_attempt: 2 }, [{ user: { type: 'Bot' }, body: '<!-- documentation-quality-failure:run=123 -->' }]);
  await f.invoke(); assert.equal(f.sent.length, 0);
});
test('untrusted user marker cannot suppress the notification', async () => {
  const f = fixture({}, [{ user: { type: 'User' }, body: '<!-- documentation-quality-failure:run=123 -->' }]);
  await f.invoke(); assert.equal(f.sent.length, 1);
});
for (const overrides of [{ conclusion: 'success' }, { status: 'in_progress' }]) {
  test(`does not notify ${JSON.stringify(overrides)}`, async () => { const f = fixture(overrides); await f.invoke(); assert.equal(f.sent.length, 0); });
}
for (const overrides of [{ name: 'CI' }, { path: '.github/workflows/ci.yml' },
  { head_repository: { full_name: 'attacker/fork' } }, { repository: { full_name: 'other/repo' } }, { event: 'push' }, { id: 321 }]) {
  test(`rejects unrelated run ${JSON.stringify(overrides)}`, async () => {
    const f = fixture(overrides); await assert.rejects(f.invoke(), /untrusted_or_unrelated_run/); assert.equal(f.sent.length, 0);
  });
}
test('manual replay validates authoritative run, not dispatch claims', async () => {
  const f = fixture(); f.context.eventName = 'workflow_dispatch'; f.context.payload = { inputs: { run_id: '123' } };
  await f.invoke(); assert.equal(f.sent.length, 1);
});
test('invalid dispatch ID fails before API access', async () => {
  const f = fixture(); f.context.eventName = 'workflow_dispatch'; f.context.payload = { inputs: { run_id: '123;echo secret' } };
  await assert.rejects(f.invoke(), /invalid_run_id/); assert.equal(f.sent.length, 0);
});
test('unknown job or step names never enter the comment', async () => {
  const f = fixture(); f.github.paginate = async method => method === 'comments' ? []
    : [{ id: 456, name: 'SECRET_NAME', conclusion: 'failure', steps: [{ name: 'SECRET_STEP', conclusion: 'failure' }] }];
  await f.invoke(); assert.doesNotMatch(f.sent[0].body, /SECRET/);
});
test('missing failed-job evidence fails closed', async () => {
  const f = fixture(); f.github.paginate = async () => [];
  await assert.rejects(f.invoke(), /missing_failed_job_evidence/); assert.equal(f.sent.length, 0);
});
test('notification workflow has no checkout, artifact execution or broader write permissions', () => {
  assert.doesNotMatch(yaml, /actions\/checkout|download-artifact|contents: write|pull-requests: write|secrets\./);
  assert.match(yaml, /actions: read\n      issues: write/); assert.match(yaml, /cancel-in-progress: false/);
});
