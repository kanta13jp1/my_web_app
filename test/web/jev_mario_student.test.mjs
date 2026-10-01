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
