// Explicit model-based search assistance, NOT learned inference.
// Hypothetical clones never replace or rewind the real simulation.
import {retryLevel} from './retry-memory.mjs?v=student-1';
import {itemPotential,itemTargets,itemValue,itemApproach} from './item-goal.mjs?v=student-1';
import {World11,isWater} from './world11.mjs?v=student-1';
export function clone(g){return Object.assign(Object.create(World11.prototype),structuredClone(g));}
export function edge(g,a){return (g.p.grounded||(isWater(g.stage)&&g.frames%20===0))&&g.wasJump&&a.includes('jump')?(a==='jump'?'noop':a.replace('_jump','')):a;}
export function advance(g,a,n){for(let i=0;i<n&&g.phase==='playing';i++){g.buttons(edge(g,a));g.step();g.drainSounds();}return g;}
function score(g,start,failures,target){
 if(g.phase==='dead')return -1e6+g.p.x;
 if(g.phase==='won')return 1e6-g.frames;
 const collected=Object.keys(g.pickups).reduce((n,k)=>n+(g.pickups[k]-start.pickups[k])*itemValue(start,k),0);
 if(isWater(g.stage)){
  // Progress ends at the pipe approach. Swimming above or beyond it is not progress.
  const exit=196*16,desiredY=g.p.x>exit-160?184-g.p.h:64;
  return collected+Math.min(exit,g.p.x)-Math.min(exit,start.p.x)-Math.abs(g.p.y-desiredY)*1.4-Math.max(0,g.p.x-exit)*2-(g.power<start.power?300:0);
 }
 let pursuit=0;
 if(target){
  const spawned=g.items.filter(i=>!i.taken&&Math.abs(i.x-target.x)<112).sort((a,b)=>Math.abs(a.x-g.p.x)-Math.abs(b.x-g.p.x))[0];
  const revealed=target.block&&!g.contents.has(target.key);
  const goal=spawned?{x:spawned.x+7,y:spawned.y}:itemApproach(g,target);
  pursuit=-Math.abs(goal.x-g.p.x-g.p.w/2)*1.4-Math.abs(goal.y-g.p.y)*.4+(revealed?70:0);
 }
 const repeat=0; // Failure memory expands foresight instead of creating an invisible wall.
 return -repeat+collected*2+pursuit+Math.max(0,g.power-start.power)*60+itemPotential(g)-itemPotential(start)+(g.p.x-start.p.x)*(target ? .25 : 1)+(192-g.p.y)*.12+g.p.vx*2-(g.power<start.power?80:0)-(g.p.y>208?(g.p.y-208)*8:0);
}
export function plan(g,raw=null,failures=[],itemAvoidance=[]){
 // Retreat from a low item-block ceiling before trying to jump over its adjacent ledge.
 // This is explicit geometric assistance; no model score is presented as an escape prediction.
 const p=g.p,col=Math.floor((p.x+p.w)/16),foot=Math.floor((p.y+p.h-1)/16);
 const wall=[col,col+1,col+2].some(c=>g.solid(c,foot-1)),head=[Math.floor(p.x/16),Math.floor((p.x+p.w-0.01)/16)].some(c=>g.solid(c,Math.floor(p.y/16)-2));
 if(!isWater(g.stage)&&p.grounded&&wall&&head&&p.x>g.camera+20)return {retry_level:retryLevel(g,failures),search_depth:0,action:'left',accepted:false,score:null,raw_score:null};
 if(!isWater(g.stage)&&p.grounded&&wall&&!head)return {retry_level:retryLevel(g,failures),search_depth:0,action:edge(g,'right_jump'),accepted:false,score:null,raw_score:null};
 const target=isWater(g.stage)?null:itemTargets(g).find(t=>!itemAvoidance.some(r=>r.stage===g.stage&&r.room===g.room&&Math.abs(t.x-r.x)<128)),level=retryLevel(g,failures),depthLimit=Math.max(target?12:8,8+level*2);
 const actions=[...new Set([...(isWater(g.stage)||level>=2||target?['left',...(!isWater(g.stage)?['left_jump']:[])]:[]),raw,'right_run','right_run_jump','right','right_jump','jump','noop'].filter(Boolean))];
 let beam=[{g,first:null,value:0}],byFirst={};
 for(let depth=0;depth<depthLimit;depth++){
  const expanded=[];
  for(const b of beam)for(const a of actions){
   const next=advance(clone(b.g),a,8),first=b.first??a,value=score(next,g,failures,target);
   expanded.push({g:next,first,value});
  }
  expanded.sort((a,b)=>b.value-a.value);
  const seen=new Set();beam=[];
  for(const b of expanded){const p=b.g.p,k=[Math.round(p.x/3),Math.round(p.y/3),Math.round(p.vx),Math.round(p.vy),+b.g.wasJump,b.g.power,b.g.lives,b.g.star>0,+!!b.g.p.climbing,JSON.stringify(b.g.pickups),b.first].join(':');if(!seen.has(k)){seen.add(k);beam.push(b);}if(beam.length===12)break;}
  if(depth===depthLimit-1)for(const b of expanded)byFirst[b.first]=Math.max(byFirst[b.first]??-Infinity,b.value);
 }
 const best=beam[0];
 // Accept the model only when its searched continuation is near the best.
 const accepted=raw!==null&&Number.isFinite(byFirst[raw])&&byFirst[raw]>=best.value-4;
 return {retry_level:level,search_depth:depthLimit,action:accepted?raw:best.first,accepted,score:best.value,raw_score:byFirst[raw]??null};
}
