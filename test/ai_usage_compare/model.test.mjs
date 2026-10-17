import test from 'node:test';
import assert from 'node:assert/strict';
import {parse,compare} from '../../web/labs/ai-usage-compare/model.mjs';
import {sample} from '../../web/labs/ai-usage-compare/sample.mjs';
test('reproduces archived measurement means without changing cost scope', () => {
  const out=compare(parse(JSON.stringify(sample)),'A');
  assert.equal(out.length,3); assert.equal(out[0].meanInput,172169.5);
  assert.ok(Math.abs(out[1].meanInput-236966.66666666666)<1e-8);
  assert.equal(out[2].meanInput,207643);
  assert.ok(Math.abs(out[0].runUSD-.7609595)<1e-10);
  assert.ok(out[0].modelUSD<out[0].runUSD);
});
test('rejects invalid counts, duplicate ids, mixed models and money scope', () => {
  for(const field of ['input','cacheWrite','cacheRead','output','turns']) for(const value of [-1,'3',1.5,null]) assert.throws(()=>parse(JSON.stringify([{...sample[0],[field]:value}])));
  assert.throws(()=>parse(JSON.stringify([{...sample[0],turns:0}])));
  assert.throws(()=>parse(JSON.stringify([sample[0],sample[0]])));
  assert.throws(()=>parse(JSON.stringify([sample[0],{...sample[1],model:'other'}])));
  assert.throws(()=>parse(JSON.stringify([{...sample[0],modelUSD:2,runUSD:1}])));
});
test('zero baseline stays unknown and requests use weighted total', () => {
  const rows=parse(JSON.stringify([{...sample[0],input:0,cacheRead:0,cacheWrite:0},{...sample[1],input:10,cacheRead:0,cacheWrite:0,turns:2}]));
  const out=compare(rows,'A'); assert.equal(out[1].ratio,null); assert.equal(out[1].perTurn,5);
});
test('bounded input and user strings remain data', () => {
  assert.throws(()=>parse('[]')); assert.throws(()=>parse('x'.repeat(500001)));
  assert.throws(()=>parse(JSON.stringify(Array.from({length:201},(_,i)=>({...sample[0],id:String(i)})))));
  const row=parse(JSON.stringify([{...sample[0],condition:'<img src=x onerror=alert(1)>'}]))[0];
  assert.equal(row.condition,'<img src=x onerror=alert(1)>');
});
