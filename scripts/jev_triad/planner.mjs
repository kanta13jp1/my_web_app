// Explicit model-based search assistance, NOT learned inference.
// Hypothetical clones never replace or rewind the real simulation.
import {World11} from '../jev_distillation/game.mjs';
export function clone(g){return Object.assign(Object.create(World11.prototype),structuredClone(g));}
export function edge(g,a){return g.p.grounded&&g.wasJump&&a.includes('jump')?(a==='jump'?'noop':a.replace('_jump','')):a;}
export function advance(g,a,n){for(let i=0;i<n&&g.phase==='playing';i++){g.buttons(edge(g,a));g.step();g.drainSounds();}return g;}
function score(g,start){
 if(g.phase==='dead')return -1e6+g.p.x;
 if(g.phase==='won')return 1e6-g.frames;
 return g.p.x-start.p.x+(192-g.p.y)*.12+g.p.vx*2-(g.power<start.power?80:0)-(g.p.y>208?(g.p.y-208)*8:0);
}
export function plan(g,raw=null){
 const actions=[...new Set([raw,'right_run','right_run_jump','right','right_jump','jump','noop'].filter(Boolean))];
 let beam=[{g,first:null,value:0}],byFirst={};
 for(let depth=0;depth<8;depth++){
  const expanded=[];
  for(const b of beam)for(const a of actions){
   const next=advance(clone(b.g),a,8),first=b.first??a,value=score(next,g);
   expanded.push({g:next,first,value});
  }
  expanded.sort((a,b)=>b.value-a.value);
  const seen=new Set();beam=[];
  for(const b of expanded){const p=b.g.p,k=[Math.round(p.x/3),Math.round(p.y/3),Math.round(p.vx),Math.round(p.vy),+b.g.wasJump,b.g.power,b.first].join(':');if(!seen.has(k)){seen.add(k);beam.push(b);}if(beam.length===12)break;}
  if(depth===7)for(const b of expanded)byFirst[b.first]=Math.max(byFirst[b.first]??-Infinity,b.value);
 }
 const best=beam[0];
 // Accept the model only when its searched continuation is near the best.
 const accepted=raw!==null&&Number.isFinite(byFirst[raw])&&byFirst[raw]>=best.value-4;
 return {action:accepted?raw:best.first,accepted,score:best.value,raw_score:byFirst[raw]??null};
}
