import test from 'node:test';
import assert from 'node:assert/strict';
import {StudentSession} from '../../web/labs/jev-mario/student-session.mjs';
test('stopped worker cannot apply a late decision or restart gameplay',()=>{
 let ready=0,updated=0,terminated=0;const worker={terminate(){terminated++;},postMessage(){}};
 const s=new StudentSession(()=>worker,()=>100);s.start({ready:()=>ready++,update:()=>updated++,error:()=>assert.fail('unexpected worker error')});
 worker.onmessage({data:{type:'ready'}});assert.equal(ready,1);
 s.tick({frames:0,p:{grounded:true},wasJump:false});s.stop();
 worker.onmessage({data:{type:'decision',action:'right_run',accepted:true,issued:100}});
 assert.equal(updated,0);assert.equal(s.action,'noop');assert.equal(s.active,false);assert.equal(terminated,1);
});
test('records model versus search and releases held jump without API',()=>{
 const messages=[],worker={terminate(){},postMessage(m){messages.push(m);}};let now=100;
 const s=new StudentSession(()=>worker,()=>now);s.start({ready(){},update(){},error:()=>assert.fail()});worker.onmessage({data:{type:'ready'}});
 const g={frames:0,p:{grounded:true},wasJump:false};s.tick(g);now=170;
 worker.onmessage({data:{type:'decision',requestId:messages[0].requestId,action:'right_jump',raw:'right',accepted:false,issued:100,frame:0,inferenceMs:.1}});
 g.wasJump=true;assert.equal(s.tick(g),'right');assert.equal(s.stats.overrides,1);assert.equal(s.stats.jump_releases,1);assert.equal(s.stats.samples[0].worker_round_trip_ms,70);assert.equal(messages.length,1);
});


test('life restart immediately requests a new decision and rejects the old attempt reply',()=>{
 const messages=[],worker={terminate(){},postMessage(m){messages.push(m);}};let updated=0;
 const s=new StudentSession(()=>worker,()=>100);s.start({ready(){},update(){updated++;},error:()=>assert.fail()});worker.onmessage({data:{type:'ready'}});
 const g={stage:22,room:'overworld',frames:120,p:{grounded:true},wasJump:false};s.tick(g);const old=messages[0].requestId;
 s.guard.pickupUntil=500;s.guard.next=500;s.itemAvoidance=[{stage:22,room:'overworld',x:32,until:500}];s.failures=[{stage:22,room:'overworld',x:988,count:4,kind:'death'}];
 g.frames=0;s.tick(g);assert.equal(messages.length,2);assert.notEqual(messages[1].requestId,old);assert.equal(s.guard.pickupUntil,0);assert.deepEqual(s.itemAvoidance,[]);assert.equal(s.failures.length,1);
 worker.onmessage({data:{type:'decision',requestId:old,action:'left',accepted:true,issued:100,frame:120}});assert.equal(updated,0);assert.equal(s.pending,true);assert.equal(s.action,'noop');
 worker.onmessage({data:{type:'decision',requestId:messages[1].requestId,action:'right',accepted:true,issued:100,frame:0}});assert.equal(updated,1);assert.equal(s.action,'right');
});

function escapeHarness(){
 const messages=[],worker={terminate(){},postMessage(m){messages.push(m);}};
 const s=new StudentSession(()=>worker,()=>100,null);
 s.start({ready(){},update(){},error(){assert.fail('worker error');}});
 worker.onmessage({data:{type:'ready'}});
 const g={phase:'playing',stage:32,room:'castle',frames:100,power:1,lives:5,p:{x:500,grounded:true},wasJump:false};
 // This test isolates session lifecycle; actual physics guard is tested separately.
 s.guard.decide=function(_g,a,_f,_i,commands){this.lastReason=commands?'retry_sequence':null;this.action=a;return a;};
 s.tick(g);
 const reply=(changes={})=>worker.onmessage({data:{type:'decision',requestId:messages[0].requestId,action:'right_run',accepted:false,issued:100,frame:100,
  escapeSequence:[{action:'right_run',frames:7},{action:'right_run_jump',frames:11},{action:'right_run',frames:60}],
  escapeOrigin:{stage:32,room:'castle',frame:100,x:500,power:1,lives:5},...changes}});
 return {s,g,messages,reply};
}
test('escape phases consume elapsed frames once and suspend new worker requests',()=>{
 const {s,g,messages,reply}=escapeHarness();reply();
 assert.equal(s.tick(g),'right_run');assert.equal(s.tick(g),'right_run');
 assert.equal(s.escape.commands[0].frames,7);
 g.frames+=7;assert.equal(s.tick(g),'right_run_jump');assert.equal(messages.length,1);
 g.frames+=11;assert.equal(s.tick(g),'right_run');assert.equal(s.escape.commands[0].frames,60);
 g.frames+=60;s.tick(g);assert.equal(s.escape,null);assert.equal(messages.length,2);
});
test('escape rejects stale and mismatched replies without accepting a plan',()=>{
 for(const changes of [{requestId:999},{escapeOrigin:{stage:32,room:'castle',frame:0,x:500,power:1,lives:5}},
  {escapeSequence:[{action:'right_run',frames:999}]}]){
  const {s,reply}=escapeHarness();reply(changes);assert.ok(!s.escape);
 }
});
test('escape is discarded on damage, stage/room changes, rewind, replacement and stop',()=>{
 for(const change of [{power:0},{lives:4},{stage:31},{room:'overworld'},{frames:99},{phase:'dead'}]){
  const {s,g,reply}=escapeHarness();reply();Object.assign(g,change);s.tick(g);assert.equal(s.escape,null);
 }
 const {s,g,reply}=escapeHarness();reply();s.tick({...g});assert.equal(s.escape,null);
 const other=escapeHarness();other.reply();other.s.stop();assert.equal(other.s.escape,null);
});
