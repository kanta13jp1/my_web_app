import {LiveGuard} from './live-guard.mjs?v=student-1';
export class StudentSession{
 constructor(factory=()=>new Worker(new URL('./student-worker.mjs?v=student-1',import.meta.url),{type:'module'}),clock=()=>performance.now()){this.factory=factory;this.clock=clock;this.token=0;this.active=false;this.action='noop';this.stats={};this.guard=new LiveGuard();this.failures=[];}
 clearFailures(){this.failures=[];}
 noteFailure(world){if(world.phase!=='dead')return;this.failures.push({stage:world.stage,room:world.room,x:world.p.x,y:world.p.y});this.failures=this.failures.slice(-24);this.stats.failures=structuredClone(this.failures);}
 start({ready,update,error}){
  this.stop();this.guard.reset();const token=++this.token;this.active=true;this.ready=false;this.pending=false;this.next=0;this.age=100;this.started=this.clock();this.action='noop';this.latest=null;
  this.stats={model:'jev-student-166-v1',teacher:'jev-1.13.0',control:'LightGBM + search + live collision guard + retry memory',decisions:0,accepted:0,overrides:0,jump_releases:0,live_guard:0,failures:structuredClone(this.failures),guard_events:[],samples:[]};
  try{
   const worker=this.factory();this.worker=worker;
   worker.onerror=()=>{if(this.token!==token)return;this.stop();error();};
   worker.onmessage=({data})=>{
    if(!this.active||this.token!==token)return;
    if(data.type==='ready'){this.ready=true;this.started=this.clock();ready();return;}
    if(data.type==='error'){this.stop();error();return;}
    if(data.type!=='decision'||!this.pending)return;
    this.pending=false;this.action=data.action;this.age=this.clock()-data.issued;
    this.stats.decisions++;if(data.accepted)this.stats.accepted++;else this.stats.overrides++;
    if(this.stats.samples.length<1000)this.stats.samples.push({frame:data.frame,raw:data.raw,action:data.action,accepted:data.accepted,worker_round_trip_ms:this.age,tree_inference_ms:data.inferenceMs});
    this.latest={...data,workerRoundTripMs:this.age};
    update(this.stats);
   };
  }catch{this.stop();error();}
 }
 tick(world){
  if(!this.active||!this.ready)return 'noop';
  if(!this.pending&&world.frames>=this.next){this.pending=true;this.next=world.frames+6;this.worker.postMessage({state:world,effective:this.guard.action??this.action,issued:this.clock(),failures:this.failures,forecastFrames:Math.max(1,Math.min(36,Math.round(this.age*.06)))});}
  const before=this.guard.interventions,action=this.guard.decide(world,this.action);this.stats.live_guard=this.guard.interventions;
  if(before!==this.guard.interventions&&this.stats.guard_events.length<600)this.stats.guard_events.push({frame:world.frames,proposed:this.action,action,reason:this.guard.lastReason});
  const release=world.p.grounded&&world.wasJump&&this.action.includes('jump');if(release)this.stats.jump_releases++;
  return release&&action===this.action?(action==='jump'?'noop':action.replace('_jump','')):action;
 }
 stop(){this.token++;this.worker?.terminate();this.worker=null;this.active=false;this.ready=false;this.pending=false;this.action='noop';}
}
