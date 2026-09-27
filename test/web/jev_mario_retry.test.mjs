import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {RetryMemory,MEMORY_KEY,retryLevel} from '../../web/labs/jev-mario/retry-memory.mjs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {LiveGuard} from '../../web/labs/jev-mario/live-guard.mjs';
import {itemValue} from '../../web/labs/jev-mario/item-goal.mjs';
const storage=()=>{const values=new Map();return {getItem:k=>values.get(k),setItem:(k,v)=>values.set(k,v),removeItem:k=>values.delete(k)};};
test('retry memory persists bounded clusters and rejects corrupt or foreign records',()=>{
 const s=storage(),m=new RetryMemory(s),g=new World11();g.phase='dead';g.p.x=300;
 for(let i=0;i<20;i++)m.record(g);
 assert.equal(m.records.length,1);assert.equal(new RetryMemory(s).records[0].count,12);
 for(let i=0;i<80;i++){g.p.x=500+i*60;m.record(g);}assert.equal(m.records.length,64);
 s.setItem(MEMORY_KEY,JSON.stringify([{stage:99,room:'overworld',x:2,y:2,count:1}]));assert.deepEqual(new RetryMemory(s).records,[]);
 s.setItem(MEMORY_KEY,'{bad');assert.deepEqual(new RetryMemory(s).records,[]);
 m.clear();assert.deepEqual(new RetryMemory(s).records,[]);
 const denied=new RetryMemory({getItem(){throw Error();}});denied.record(g);assert.equal(denied.records.length,1);assert.equal(denied.saved,false);
});
test('retry horizon applies only to the matching approach, independently of pit death height',()=>{
 const g=new World11();g.p.x=200;const records=[{stage:1,room:'overworld',x:350,y:270,count:3}];assert.equal(retryLevel(g,records),3);g.stage=2;assert.equal(retryLevel(g,records),0);g.stage=1;g.p.x=380;assert.equal(retryLevel(g,records),0);
});
test('repeated failure experience improves a deterministic obstacle approach',()=>{
 // Fixed commands isolate assistance from model inference. Same actual physics and starting state.
 const run=(start,records)=>{const g=new World11(),guard=new LiveGuard();g.p.x=start;let max=g.p.x;for(let i=0;i<600&&g.phase==='playing';i++){g.buttons(guard.decide(g,'right_run',records));g.step();g.drainSounds();max=Math.max(max,g.p.x);}return {phase:g.phase,x:g.p.x,y:g.p.y,furthest:max,frames:g.frames,interventions:guard.interventions};};
 const rows=[];for(const start of [32,96,160,192,224,256]){const before=run(start,[]);const records=[{stage:1,room:'overworld',x:before.x,y:before.y,count:3}];const after=run(start,records);rows.push({start,before,after});}
 mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-retry-comparison.json',JSON.stringify({scenario:'fixed right_run, 600-frame budget, deterministic assistance comparison, not a learned-model clear',rows},null,2));
 console.log('RETRY_COMPARISON',JSON.stringify(rows));
 assert.ok(rows.some(r=>r.after.furthest>r.before.furthest+32),'at least one reproduced failure must pass its previous failure point');
});
test('Luigi survives reset/progression and red variants have distinct platform behavior',()=>{
 const g=new World11(15);g.character='luigi';g.reset();assert.equal(g.character,'luigi');const red=g.enemies.find(e=>e.red&&e.kind==='paratroopa');assert.ok(red);g.camera=red.x-64;g.p.x=red.x-100;const x=red.x,y=red.y;for(let i=0;i<10;i++)g.step();assert.equal(red.x,x);assert.notEqual(red.y,y);
 const k={x:18,y:192,w:14,h:16,vx:.5,vy:0,grounded:true,kind:'koopa',red:true,dead:0};const a=new World11();a.enemies=[k];a.p.x=120;for(let c=2;c<6;c++)for(let r=13;r<16;r++)a.cells.delete(c+','+r);a.step();assert.ok(k.vx<0,'red Koopa turns before the missing floor');
 g.phase='won';g.presentation=300;g.advanceStage();assert.equal(g.character,'luigi');
});
test('item priorities adapt to small/fire form and low lives',()=>{const g=new World11();assert.ok(itemValue(g,'mushroom')>itemValue({...g,power:2},'mushroom'));assert.ok(itemValue({...g,lives:1},'life')>itemValue(g,'life'));assert.ok(itemValue(g,'flower')>itemValue({...g,power:2},'flower'));assert.ok(itemValue(g,'star')>itemValue({...g,star:300},'star'));});
