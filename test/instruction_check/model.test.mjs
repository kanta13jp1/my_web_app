import {test} from 'node:test';import assert from 'node:assert/strict';import {compare} from '../../web/labs/instruction-check/model.mjs';
test('exact token comparison and absent observations',()=>{assert.deepEqual(compare('A B','A AB',0).rows,[{mark:'A',seen:true},{mark:'B',seen:false}]);assert.equal(compare('A','',0).rows[0].seen,false);});
test('tool activity preserves evidence limitation',()=>{assert.match(compare('A','A',1).scope,/除外できません/);});
test('invalid expectations and counts rejected',()=>{for(const x of ['', 'A A'])assert.throws(()=>compare(x,'A',0));for(const n of [-1,NaN,Infinity,.5])assert.throws(()=>compare('A','A',n));});

import {readFileSync} from 'node:fs';
import {inspectRecord} from '../../web/labs/instruction-check/evidence.mjs';
const evidence = JSON.parse(readFileSync(new URL('../../web/labs/instruction-check/evidence.json', import.meta.url)));
test('12 historical excerpts match answers, versions, and zero tool events', () => {
  assert.deepEqual(evidence.records.map(record => record.id), ['old-N','old-C','old-A','old-B','old-I','old-E','new-N','new-C','new-A','new-B','new-I','new-E']);
  for (const record of evidence.records) {
    const result = inspectRecord(record, evidence.marks);
    assert.deepEqual(result.tools, []);
    assert.deepEqual(result.availableTools, []);
    assert.equal(result.answer, record.answer);
    assert.equal(record.events[0].sourceLine, 1);
    assert.ok([2,3].includes(record.events[1].sourceLine));
    assert.equal(record.events[2].sourceLine, 4);
    assert.equal(record.sourceEventCount, 4);
  }
  assert.equal(evidence.records.find(record => record.id === 'new-A').answer, 'NONE');
  assert.equal(inspectRecord(evidence.records.find(record => record.id === 'new-E'), evidence.marks).rows.every(row => row.seen), true);
  assert.doesNotMatch(JSON.stringify(evidence), /session_id|request_id|apiKeySource|uuid|C:\\|C:\//);
});
test('incomplete or inconsistent excerpts never produce a zero count', () => {
  for (const mutate of [
    record => record.events.pop(),
    record => record.events.shift(),
    record => record.sourceEventCount++,
    record => record.answer = 'different',
    record => record.events[1].event.message.content[0].text = 'different',
    record => record.events[1].event.message.content.push({type:'tool_use', name:'Read'}),
    record => record.events.at(-1).event.is_error = true,
    record => delete record.omittedEventTypes,
  ]) {
    const record = structuredClone(evidence.records[0]);
    mutate(record);
    assert.throws(() => inspectRecord(record, evidence.marks));
  }
});

import {validateCause} from '../../web/labs/instruction-check/cause.mjs';
const cause = JSON.parse(readFileSync(new URL('../../web/labs/instruction-check/cause.json', import.meta.url)));
test('captured inputs preserve the Windows one-variable contrast without model answers', () => {
  validateCause(cause);
  const markers = id => cause.runs.find(r => r.id === id).observations.flatMap(o => o.markers.messages);
  assert.deepEqual(markers('windows-278-A-telemetry-on-cache-false'), []);
  assert.deepEqual(markers('windows-278-A-telemetry-on-cache-true'), ['A']);
  assert.deepEqual(markers('windows-278-E-telemetry-on-cache-false'), ['C']);
  assert.deepEqual(markers('windows-278-E-telemetry-on-cache-true'), ['A','C']);
  assert.doesNotMatch(JSON.stringify(cause), /session_id|request_id|apiKeySource|uuid|USERPROFILE|ANTHROPIC_API_KEY/);
});
test('missing observations and unknown tool definitions cannot turn into zero', () => {
  for (const mutate of [r => r.observations = [], r => delete r.modelCalls, r => r.observations[0].tools_count = null, r => delete r.observations[0].markers, r => r.source.sha256 = 'missing']) {
    const broken = structuredClone(cause); mutate(broken.runs[0]);
    assert.throws(() => validateCause(broken));
  }
});
