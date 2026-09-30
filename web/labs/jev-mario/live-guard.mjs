import {pipeRoute} from './pipe-route.mjs?v=student-1';
import {itemIntent,itemDescent} from './item-goal.mjs?v=student-1';
// Bounded live-state collision check. Assistance, never learned model inference.
import {retryLevel} from './retry-memory.mjs?v=student-1';
import {clone,advance,edge} from './search-assist.mjs?v=student-1';
export class LiveGuard {
 constructor(){this.reset();}
 reset(){this.pickupUntil=0;this.next=0;this.action=null;this.interventions=0;this.lastReason=null;}
 decide(world,proposed,failures=[]){
  if(!world.cells||world.phase!=='playing')return proposed;
  const pipe=pipeRoute(world),item=pipe?null:(itemDescent(world)??(this.pickupUntil>world.frames&&!world.p.grounded&&world.p.vy<0?'jump':itemIntent(world))),route=pipe??item;if(route)proposed=route;
  const level=retryLevel(world,failures);
  if(world.frames<this.next&&proposed===this.proposed&&level===this.level)return edge(world,this.action??proposed);
  this.level=level;this.proposed=proposed;this.next=world.frames+(route?1:6);this.lastReason=pipe?'pipe_geometry_route':item?'item_pickup_route':null;
  const evaluate=action=>{const g=advance(clone(world),action,24+level*16);return {action,g,value:(g.phase==='dead'?-100000:0)+(g.power<world.power?-300:0)+(g.phase==='won'?100000:0)+g.p.x-world.p.x-Math.max(0,g.p.y-208)*8};};
  let best=evaluate(proposed);
  // Keep a safe model/search command intact. Only imminent death/damage triggers alternatives.
  if(best.g.phase==='dead'||best.g.power<world.power||best.g.p.y>224||(level&&world.p.grounded&&proposed.includes('right')&&best.g.p.x-world.p.x<2)){
   for(const action of ['right_jump','right_run_jump','jump','noop','left',...(!['underwater'].includes(world.room)?['left_jump']:[])]){const candidate=evaluate(action);if(candidate.value>best.value)best=candidate;}
   if(best.action!==proposed){this.interventions++;this.lastReason=level?'retry_lookahead':'live_collision_guard';}
  }
  if(route&&best.action===route){this.interventions++;if(item==='jump'&&world.p.grounded)this.pickupUntil=world.frames+18;}
  this.action=best.action;return edge(world,best.action);
 }
}
