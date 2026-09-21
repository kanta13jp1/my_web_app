const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, '.github/workflows', name), 'utf8');
const body = read('production-followup-scope.yml').split('          script: |\n')[1]
  .split('\n').map(line => line.slice(12)).join('\n');
const execute = new (Object.getPrototypeOf(async function(){}).constructor)('core', 'context', 'github', body);
function fixture() {
  const repo = {full_name:'owner/repo'};
  const run = {id:12,head_sha:'a'.repeat(40),run_attempt:2,repository:repo,
    head_repository:repo,path:'.github/workflows/deploy-prod.yml',head_branch:'main',
    event:'push',status:'completed',conclusion:'success'};
  const job = {name:'Deploy to Production Environment',head_sha:run.head_sha,
    status:'completed',conclusion:'success',steps:[{name:'Confirmed production no-op',status:'completed',conclusion:'success'}]};
  return {run,jobs:[job],context:{eventName:'workflow_run',repo:{owner:'owner',repo:'repo'},payload:{repository:repo,workflow_run:{...run}}}};
}
async function check(f, throws=false) {
  const out={};
  await execute({setOutput:(k,v)=>out[k]=v,info:()=>{},warning:()=>{}},f.context,
    {rest:{actions:{getWorkflowRun:async()=>{if(throws)throw Error('unavailable');return {data:f.run}},listJobsForWorkflowRunAttempt:()=>{}}},
    paginate:async(_,args)=>{assert.equal(args.attempt_number,2);assert.equal(args.run_id,12);return f.jobs}});
  return out.skip;
}
test('positive exact-attempt no-op skips',async()=>assert.equal(await check(fixture()),'true'));
for(const event of ['workflow_dispatch','schedule','pull_request']) test(event+' preserved',async()=>{
  const f=fixture();f.context.eventName=event;assert.equal(await check(f),'false');
});
for(const [key,value] of [['head_sha','different'],['run_attempt',3],['path','other.yml'],['event','workflow_dispatch'],['head_branch','other'],['conclusion','failure'],['status','in_progress']]) test('reject '+key,async()=>{
  const f=fixture();f.run[key]=value;assert.equal(await check(f),'false');
});
test('API error retains validation',async()=>assert.equal(await check(fixture(),true),'false'));
for(const scenario of ['missing','skipped','failed','duplicate','wrong-sha','fork','db','edge','web']) test(scenario+' evidence retains validation',async()=>{
  const f=fixture();
  if(scenario==='missing')f.jobs[0].steps=[];
  if(['skipped','failed','db','edge','web'].includes(scenario))f.jobs[0].steps[0].conclusion=scenario==='failed'?'failure':'skipped';
  if(scenario==='duplicate')f.jobs.push({...f.jobs[0]});
  if(scenario==='wrong-sha')f.jobs[0].head_sha='old';
  if(scenario==='fork')f.run.head_repository={full_name:'fork/repo'};
  assert.equal(await check(f),'false');
});
test('producer requires every explicit false and successful push',()=>{
  const marker=read('deploy-prod.yml').split('- name: Confirmed production no-op')[1].split('- name: Job Summary')[0];
  for(const field of ['deployable','web','edge','migration']) assert.ok(marker.includes(`steps.changes.outputs.${field} == 'false'`));
  assert.ok(marker.includes("steps.db_edge_smoke.outputs.required == 'false'"));
  assert.ok(marker.includes('success()'));assert.ok(marker.includes("github.event_name == 'push'"));
});
test('all four consumers fail closed on unavailable gate outputs',()=>{
  for(const file of ['minimal-e2e-gate.yml','blog-news-prod-smoke.yml','release-readiness.yml','ga-readiness-gate.yml']) {
    assert.ok(read(file).includes('uses: ./.github/workflows/production-followup-scope.yml'));
    assert.ok(read(file).includes("always() && needs.deployment-scope.outputs.skip != 'true'"));
  }
});
