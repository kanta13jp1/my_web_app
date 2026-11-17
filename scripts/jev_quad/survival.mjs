import {clone,advance} from '../jev_triad/planner.mjs';
// Privileged simulator safety assistance, not a learned model or a rewind.
export function survival(g,action){
 const projected=advance(clone(g),action,30);
 if(projected.phase!=='dead')return action;
 let best=null,value=-Infinity;
 for(const candidate of ['right_run_jump','right_jump','jump','noop','left']){
  const future=advance(clone(g),candidate,30);
  if(future.phase==='dead')continue;
  const score=future.phase==='won'?1e6:future.p.x+(192-future.p.y)*.12;
  if(score>value){value=score;best=candidate;}
 }
 return best??action;
}
