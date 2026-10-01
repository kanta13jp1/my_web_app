import {pipeRoute} from '../../web/labs/jev-mario/pipe-route.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {RetryMemory,MEMORY_KEY,retryLevel,stalledActionPenalty} from '../../web/labs/jev-mario/retry-memory.mjs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {StudentSession} from '../../web/labs/jev-mario/student-session.mjs';
import {LiveGuard} from '../../web/labs/jev-mario/live-guard.mjs';
import {itemValue} from '../../web/labs/jev-mario/item-goal.mjs';
const storage=()=>{const values=new Map();return {getItem:k=>values.get(k),setItem:(k,v)=>values.set(k,v),removeItem:k=>values.delete(k)};};
test('retry memory persists bounded clusters and rejects corrupt or foreign records',()=>{
 const s=storage(),m=new RetryMemory(s),g=new World11();g.phase='dead';g.p.x=300;
 for(let i=0;i<20;i++)m.record(g);
 assert.equal(m.records.length,1);assert.equal(new RetryMemory(s).records[0].count,12);
 for(let i=0;i<80;i++){g.p.x=500+i*60;m.record(g);}assert.equal(m.records.length,64);
 s.setItem(MEMORY_KEY,JSON.stringify([{stage:99,room:'overworld',x:2,y:2,count:1}]));assert.deepEqual(new RetryMemory(s).records,[]);
 s.setItem(MEMORY_KEY,'{bad');const corrupt=new RetryMemory(s);assert.deepEqual(corrupt.records,[]);corrupt.clear();assert.equal(s.getItem(MEMORY_KEY),undefined);corrupt.record(g);assert.equal(new RetryMemory(s).records.length,1);
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
 const g=new World11(15);g.character='luigi';g.reset();assert.equal(g.character,'luigi');const red=g.enemies.find(e=>e.red&&e.kind==='paratroopa');assert.ok(red);const floor=Math.min(...[...g.cells.keys()].filter(k=>k.startsWith(Math.floor(red.x/16)+',')).map(k=>Number(k.split(',')[1])*16));assert.ok(red.flightY+32+red.h<=floor,'vertical flight stays above its platform');g.camera=red.x-64;g.p.x=red.x-100;const x=red.x,y=red.y;for(let i=0;i<10;i++)g.step();assert.equal(red.x,x);assert.notEqual(red.y,y);
 const k={x:18,y:192,w:14,h:16,vx:.5,vy:0,grounded:true,kind:'koopa',red:true,dead:0};const a=new World11();a.enemies=[k];a.p.x=120;for(let c=2;c<6;c++)for(let r=13;r<16;r++)a.cells.delete(c+','+r);a.step();assert.ok(k.vx<0,'red Koopa turns before the missing floor');
 g.phase='won';g.presentation=300;g.advanceStage();assert.equal(g.character,'luigi');
});
test('item priorities adapt to small/fire form and low lives',()=>{const g=new World11();assert.ok(itemValue(g,'mushroom')>itemValue({...g,power:2},'mushroom'));assert.ok(itemValue({...g,lives:1},'life')>itemValue(g,'life'));assert.ok(itemValue(g,'flower')>itemValue({...g,power:2},'flower'));assert.ok(itemValue(g,'star')>itemValue({...g,star:300},'star'));});

test('running session discovers a stalled pipe and reuses its experience after a new start',()=>{
 const store=storage(),g=new World11();let worker;
 const session=new StudentSession(()=>worker={terminate(){},postMessage(m){this.onmessage({data:{type:'decision',requestId:m.requestId,action:'right_run',raw:'right_run',accepted:true,issued:m.issued,frame:m.state.frames,inferenceMs:0,probabilities:[]}});}},()=>g.frames*1000/60,store);
 const callbacks={ready(){},update(){},error(){assert.fail();}};session.start(callbacks);worker.onmessage({data:{type:'ready'}});
 let furthest=0;for(let i=0;i<900&&g.phase==='playing';i++){g.buttons(session.tick(g));g.step();g.drainSounds();furthest=Math.max(furthest,g.p.x);}
 assert.ok(session.failures.some(f=>f.kind==='stalled'));assert.ok(session.stats.retry_assists>0);assert.ok(furthest>470);
 const remembered=structuredClone(session.failures);session.stop();session.start(callbacks);assert.deepEqual(session.failures,remembered);assert.deepEqual(new RetryMemory(store).records,remembered);
 mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-retry-session.json',JSON.stringify({scenario:'mock worker always right_run; automatic stall discovery in actual session, not model inference',furthest,phase:g.phase,memory:remembered},null,2));session.stop();
});


test('repeated stalled commands are persisted and penalized only at their own location',()=>{const store=storage(),m=new RetryMemory(store),g=new World11();g.p.x=300;for(let i=0;i<3;i++)m.record(g,'stalled','right_run');const loaded=new RetryMemory(store);assert.equal(loaded.records[0].failedActions.right_run,3);assert.equal(stalledActionPenalty(g,loaded.records,'right_run'),36);assert.equal(stalledActionPenalty(g,loaded.records,'right_jump'),0);g.p.x=400;assert.equal(stalledActionPenalty(g,loaded.records,'right_run'),0);g.p.x=300;g.stage=2;assert.equal(stalledActionPenalty(g,loaded.records,'right_run'),0);});


test('live retry escapes a stationary learned command without changing the world or inventing immunity',()=>{const g=new World11(),guard=new LiveGuard();g.enemies=[];g.contents.clear();g.p.x=300;const old={x:g.p.x,y:g.p.y,lives:g.lives,power:g.power},records=[{stage:1,room:'overworld',x:300,y:192,count:3,kind:'stalled',failedActions:{noop:3}}];const action=guard.decide(g,'noop',records);assert.notEqual(action,'noop');assert.equal(guard.lastReason,'retry_escape');assert.deepEqual({x:g.p.x,y:g.p.y,lives:g.lives,power:g.power},old);for(let i=0;i<30&&g.phase==='playing';i++){g.buttons(guard.decide(g,'noop',records));g.step();}assert.ok(g.p.x>old.x+8);assert.equal(g.phase,'playing');});

test('power-up acquisition resets stall observation but stationary play still records failure',()=>{const g=new World11();let worker;const s=new StudentSession(()=>worker={terminate(){},postMessage(){}},()=>g.frames*1000/60,null);s.start({ready(){},update(){},error(){assert.fail();}});worker.onmessage({data:{type:'ready'}});s.guard.decide=()=> 'noop';s.tick(g);g.frames=179;s.tick(g);assert.equal(s.failures.length,0);g.frames=180;g.pickups.mushroom++;s.tick(g);assert.equal(s.failures.length,0);g.frames=359;s.tick(g);assert.equal(s.failures.length,0);g.frames=360;s.tick(g);assert.equal(s.failures.length,1);assert.equal(s.failures[0].kind,'stalled');s.stop();});
test('unreachable reward behind camera does not block a usable pipe, reachable reward ahead does',()=>{const g=new World11();g.usablePipes=()=>[{id:'test',x:1600,y:160,exit:2000}];Object.assign(g.p,{x:1604,y:144,grounded:true});g.camera=1500;g.contents.clear();g.contents.set('16,9','flower');assert.equal(pipeRoute(g),'down');g.contents.set('110,9','star');assert.equal(pipeRoute(g),null);});

test('retry guard checks an airborne stationary jump loop without waiting for landing',()=>{const g=new World11();g.enemies=[];g.contents.clear();Object.assign(g.p,{x:300,y:180,vx:0,vy:-1,grounded:false});const records=[{stage:1,room:'overworld',x:300,y:180,count:12,kind:'stalled',failedActions:{jump:12}}];const guard=new LiveGuard();const old=structuredClone(g.p),action=guard.decide(g,'jump',records);assert.notEqual(action,'jump');assert.equal(guard.lastReason,'retry_escape');assert.deepEqual(g.p,old);});
