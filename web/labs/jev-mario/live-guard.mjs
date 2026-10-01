import {pipeRoute} from './pipe-route.mjs?v=student-1';
import {itemIntent,itemDescent,itemTargets} from './item-goal.mjs?v=student-1';
// Bounded live-state collision check. Assistance, never learned model inference.
import {retryLevel,stalledActionPenalty} from './retry-memory.mjs?v=student-1';
import {clone,advance,edge} from './search-assist.mjs?v=student-1';
export class LiveGuard {
 constructor(){this.reset();}
 reset(){this.descentKey=null;this.descentSide=null;this.pickupAction=null;this.pickupUntil=0;this.next=0;this.action=null;this.interventions=0;this.lastReason=null;}
 decide(world,proposed,failures=[],itemAvoidance=[]){
  if(!world.cells||world.phase!=='playing')return proposed;
  const target=itemTargets(world).find(t=>!itemAvoidance.some(r=>r.stage===world.stage&&r.room===world.room&&r.until>world.frames&&Math.abs(t.x-r.x)<128));
  const descentKey=target?.block&&world.room==='overworld'&&world.p.y<target.y-2?world.stage+':'+target.key:null;if(descentKey!==this.descentKey){this.descentKey=descentKey;this.descentSide=null;}
  const descent=target?itemDescent(world,target,this.descentSide):null;
  const pipe=pipeRoute(world);let item=!target||pipe||world.room!=='overworld'?null:(descent??(this.pickupUntil>world.frames&&!world.p.grounded&&world.p.vy<0?this.pickupAction:itemIntent(world,target))),route=pipe??item;if(route)proposed=route;
  const level=retryLevel(world,failures);
  if(world.frames<this.next&&proposed===this.proposed&&level===this.level)return edge(world,this.action??proposed);
  this.level=level;this.proposed=proposed;this.next=world.frames+(route?1:6);this.lastReason=pipe?'pipe_geometry_route':item?'item_pickup_route':null;
  // High platforms need enough time to see a fall before leaving the takeoff edge.
  const foot=Math.floor((world.p.y+world.p.h)/16),col=Math.floor((world.p.x+world.p.w)/16);
  const gapAhead=world.room!=='underwater'&&world.p.grounded&&Array.from({length:6},(_,i)=>col+i+1).some(x=>!Array.from({length:Math.max(0,16-foot)},(_,i)=>foot+i).some(y=>world.solid(x,y)));
  const penalty=action=>stalledActionPenalty(world,failures,action);
  const evaluate=action=>{const g=advance(clone(world),action,Math.max(24+level*16,descent||gapAhead?72:0));return {action,g,value:(g.phase==='dead'?-100000:0)+(g.power<world.power?-300:0)+(g.phase==='won'?100000:0)+g.p.x-world.p.x-Math.max(0,g.p.y-208)*8-penalty(action)};};
  let best=evaluate(proposed);
  const repeatedStall=penalty(proposed)>0&&world.p.grounded&&Math.abs(best.g.p.x-world.p.x)<4;
  // Commit to the other edge when the nearest descent would land on an enemy.
  // Keeping that side until below the reward prevents safe/unsafe oscillation.
  if(descent&&!this.descentSide&&(best.g.phase==='dead'||best.g.power<world.power||best.g.p.y>224)){
   const side=world.p.x+world.p.w/2<target.x?'right':'left',other=itemDescent(world,target,side);
   if(other){const candidate=evaluate(other);if(candidate.g.phase!=='dead'&&candidate.g.power>=world.power&&candidate.g.p.y<=224){this.descentSide=side;item=other;route=other;proposed=other;this.proposed=other;best=candidate;}}
  }
  // Keep a safe model/search command intact. Only imminent death/damage triggers alternatives.
  if(repeatedStall||best.g.phase==='dead'||best.g.power<world.power||best.g.p.y>224||(level&&world.p.grounded&&proposed.includes('right')&&best.g.p.x-world.p.x<2)){
   for(const action of ['right','right_run','right_jump','right_run_jump','jump','noop','left',...(!['underwater'].includes(world.room)?['left_jump']:[])]){const candidate=evaluate(action);if(candidate.value>best.value)best=candidate;}
   if(best.action!==proposed){this.interventions++;this.lastReason=repeatedStall?'retry_escape':level?'retry_lookahead':'live_collision_guard';}
  }
  if(route&&best.action===route){this.interventions++;if(item?.includes('jump')&&world.p.grounded){this.pickupUntil=world.frames+18;this.pickupAction=item;}}
  this.action=best.action;return edge(world,best.action);
 }
}
