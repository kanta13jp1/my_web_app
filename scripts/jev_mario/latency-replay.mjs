import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {clone,advance} from '../../web/labs/jev-mario/search-assist.mjs';
import {StudentSession} from '../../web/labs/jev-mario/student-session.mjs';
import {findEscapeSequence} from '../../web/labs/jev-mario/escape-plan.mjs';
function revive(v){if(Array.isArray(v))return v.map(revive);if(v&&typeof v==='object'){
 if(Object.keys(v).length===1&&Array.isArray(v.map))return new Map(v.map.map(([k,x])=>[k,revive(x)]));
 if(Object.keys(v).length===1&&Array.isArray(v.set))return new Set(v.set.map(revive));
 return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,revive(x)]));}return v;}
const root='test-results/source-observation',results=[];
for(const entry of await fs.readdir(root,{recursive:true})){
 if(!entry.endsWith('world84-complete-worker.json'))continue;
 const data=JSON.parse(await fs.readFile(root+'/'+entry,'utf8')),snap=data.workerObservation.firstStall;
 assert.ok(snap);const initial=Object.assign(Object.create(World11.prototype),revive(snap.state));
 for(const delay of [0,6,24,36])for(const profile of ['captured','forecast']){
  const world=clone(initial),queue=[],counts={};let offers=0,acceptedTicks=0;
  const worker={terminate(){},postMessage(data){
   const state=clone(data.state),forecast=advance(clone(state),data.effective,Math.max(1,delay));
   const planning=profile==='forecast'&&forecast.phase==='playing'?forecast:state;
   const escape=findEscapeSequence(planning,data.failures);if(escape)offers++;
   queue.push({due:world.frames+delay,data:{type:'decision',requestId:data.requestId,issued:data.issued,frame:state.frames,
    action:escape?.commands[0].action??snap.latest.raw,accepted:false,escapeSequence:escape?.commands,
    escapeOrigin:{stage:state.stage,room:state.room,frame:state.frames,x:state.p.x,power:state.power,lives:state.lives}}});
  }};
  const session=new StudentSession(()=>worker,()=>world.frames*1000/60,null);
  session.failures=structuredClone(snap.failures);session.start({ready(){},update(){},error(){assert.fail();}});
  worker.onmessage({data:{type:'ready'}});session.age=delay*1000/60;session.action=snap.latest.action;
  Object.assign(session.guard,snap.guard);
  for(let i=0;i<180&&world.phase==='playing'&&world.p.x-initial.p.x<120;i++){
   for(let j=queue.length-1;j>=0;j--)if(queue[j].due<=world.frames){worker.onmessage({data:queue.splice(j,1)[0].data});}
   const action=session.tick(world),reason=session.guard.lastReason??'none';counts[reason]=(counts[reason]??0)+1;
   if(reason==='retry_sequence')acceptedTicks++;
   world.buttons(action);world.step();world.drainSounds();
  }
  session.stop();results.push({delay,profile,offers,acceptedTicks,counts,phase:world.phase,progress:world.p.x-initial.p.x,power:world.power,lives:world.lives});
 }
}
assert.equal(results.length,8);console.log(JSON.stringify({scope:'isolated latency replay; fixed captured raw fallback, not whole async worker acceptance',results}));
