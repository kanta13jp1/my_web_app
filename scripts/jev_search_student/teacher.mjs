// Teacher for the student: exact-state beam search on the current game that
// scores progress toward the goal only (the lab's search before item pursuit
// and retry memory were added). Privileged: it clones the simulator. The
// student never sees its output at play time.
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {edge} from '../../web/labs/jev-mario/search-assist.mjs';
export {edge};
const clone=g=>Object.assign(Object.create(World11.prototype),structuredClone(g));
function advance(g,a,n){for(let i=0;i<n&&g.phase==='playing';i++){g.buttons(edge(g,a));g.step();g.drainSounds();}return g;}
function score(g,start){
 if(g.phase==='dead')return -1e6+g.p.x;
 if(g.phase==='won')return 1e6-g.frames;
 return g.p.x-start.p.x+(192-g.p.y)*.12+g.p.vx*2-(g.power<start.power?80:0)-(g.p.y>208?(g.p.y-208)*8:0);
}
export function plan(g,depthLimit=8){
 const actions=['right_run','right_run_jump','right','right_jump','jump','noop'];
 let beam=[{g,first:null,value:0}];
 for(let depth=0;depth<depthLimit;depth++){
  const expanded=[];
  for(const b of beam)for(const a of actions){const next=advance(clone(b.g),a,8);expanded.push({g:next,first:b.first??a,value:score(next,g)});}
  expanded.sort((a,b)=>b.value-a.value);
  const seen=new Set();beam=[];
  for(const b of expanded){const p=b.g.p,k=[Math.round(p.x/3),Math.round(p.y/3),Math.round(p.vx),Math.round(p.vy),+b.g.wasJump,b.g.power,b.first].join(':');if(!seen.has(k)){seen.add(k);beam.push(b);}if(beam.length===12)break;}
 }
 return {action:beam[0].first,score:beam[0].value};
}
