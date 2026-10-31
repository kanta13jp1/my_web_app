import test from 'node:test';
import assert from 'node:assert/strict';
import {RunHistory,validRun,compareRuns,RUN_REVISION,Campaign} from '../../web/labs/jev-mario/history.mjs';
const run=(n=1)=>({id:`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`,revision:RUN_REVISION,course:17,controller:'manual',power:0,eligible:true,outcome:'won',score:1200,reached:18,cleared:17,elapsed_ms:15000,created_at:'2026-09-27T00:00:00Z'});
test('history persists, deduplicates and bounds records; broken storage preserves memory',()=>{
 let saved=null;const store={getItem:()=>saved,setItem:(_k,v)=>saved=v};const h=new RunHistory(store);for(let i=1;i<=110;i++)h.add(run(i));assert.equal(h.rows.length,100);h.add(run(110));assert.equal(h.rows.length,100);assert.equal(new RunHistory(store).rows[0].id,run(110).id);
 const bad=new RunHistory({getItem(){return '{broken';},setItem(){throw Error();}});assert.ok(bad.warning);assert.equal(bad.add(run()),true);assert.equal(bad.rows.length,1);assert.ok(bad.warning.includes('保存に失敗'));
 assert.equal(h.add({...run(),score:Infinity}),false);assert.equal(validRun({...run(),controller:'<script>'}),false);
});
test('campaign progress outranks score; elapsed wall time breaks ties',()=>{
 const a=run(),b={...run(2),outcome:'dead',reached:17,cleared:16,score:99999},c={...run(3),elapsed_ms:12000};assert.deepEqual([b,a,c].sort(compareRuns).map(r=>r.id),[c.id,a.id,b.id]);
});

test('campaign retains one ID over life retry and stage advance with wall time and cumulative score',()=>{
 let now=0;const c=new Campaign(()=>now,()=>run().id),w={stage:1,frames:0,p:{x:32},power:0,score:0,phase:'playing'};
 c.begin(w,'manual');now=1000;w.score=500;w.phase='dead';c.observe(w);w.frames=0;w.phase='playing';c.begin(w,'manual');now=5000;w.phase='won';c.observe(w);w.stage=2;w.phase='playing';c.begin(w,'manual');w.score=900;now=9000;
 const r=c.finish(w,'stopped');assert.deepEqual([r.course,r.reached,r.cleared,r.score,r.elapsed_ms],[1,2,1,900,9000]);assert.equal(validRun(r),true);assert.equal(c.finish(w,'stopped'),null);
});
