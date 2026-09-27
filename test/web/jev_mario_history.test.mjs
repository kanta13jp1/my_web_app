import test from 'node:test';
import assert from 'node:assert/strict';
import {RunHistory,validRun,compareRuns,RUN_REVISION} from '../../web/labs/jev-mario/history.mjs';
const run=(n=1)=>({id:`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`,revision:RUN_REVISION,course:17,controller:'manual',power:0,eligible:true,outcome:'won',score:1200,frames:900,created_at:'2026-09-27T00:00:00Z'});
test('history persists, deduplicates and bounds records; broken storage preserves memory',()=>{
 let saved=null;const store={getItem:()=>saved,setItem:(_k,v)=>saved=v};const h=new RunHistory(store);for(let i=1;i<=110;i++)h.add(run(i));assert.equal(h.rows.length,100);h.add(run(110));assert.equal(h.rows.length,100);assert.equal(new RunHistory(store).rows[0].id,run(110).id);
 const bad=new RunHistory({getItem(){return '{broken';},setItem(){throw Error();}});assert.ok(bad.warning);assert.equal(bad.add(run()),true);assert.equal(bad.rows.length,1);assert.ok(bad.warning.includes('保存に失敗'));
 assert.equal(h.add({...run(),score:Infinity}),false);assert.equal(validRun({...run(),controller:'<script>'}),false);
});
test('clear outranks failure, score then simulation time break ties',()=>{
 const a=run(),b={...run(2),outcome:'dead',score:99999},c={...run(3),frames:800};assert.deepEqual([b,a,c].sort(compareRuns).map(r=>r.id),[c.id,a.id,b.id]);
});
