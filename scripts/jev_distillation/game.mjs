// Frozen recreation, not Nintendo ROM/gameplay. No network or renderer is used.
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {predict as infer} from './predict.mjs';
export const {World11}=await import(pathToFileURL(resolve('out/lightgbm/frozen/world11.mjs')));
export const {hazards,prediction}=await import(pathToFileURL(resolve('out/lightgbm/frozen/reaction.mjs')));
export const ACTIONS=['noop','right','right_jump','right_run','right_run_jump','jump','left'];
export const SOURCE='d224c892c1f16895f24978358717717f96bad657';
export function rng(seed){return ()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};}
export function features(g){
 const p=g.p,h=hazards(g),near=g.enemies.filter(e=>!e.dead&&Math.abs(e.x-p.x)<256).sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x)).slice(0,3);
 const x=[p.y,p.vx,p.vy,+p.grounded,p.h,g.power,+!!g.input.jump,+!!g.wasJump,+!!g.input.run,h.enemy_gap??300,h.contact_ms===null?10000:Math.min(10000,h.contact_ms),+h.gap_ahead,+h.wall_ahead];
 for(let i=0;i<3;i++){const e=near[i];x.push(e?e.x-p.x:300,e?e.y-p.y:300,e?.vx??0,e?.vy??0,e?1:0);}
 x.push(...g.telemetry().tiles.map(t=>+(t!==0)));
 if(!x.every(Number.isFinite))throw Error('non-finite features');return x;
}
export function rule(g){
 const h=hazards(g);
 if(g.p.grounded){
  if(g.wasJump)return 'right_run';
  if((h.enemy_gap!==null&&h.enemy_gap<48)||h.gap_ahead||h.wall_ahead)return 'right_run_jump';
  return 'right_run';
 }
 return g.input.jump?'right_run_jump':'right_run';
}
export function init(x=32,seed=0,perturb=false){
 const g=new World11(),random=rng(seed);g.p.x=x;g.camera=Math.max(0,x-96);
 // Checkpoint episodes are explicitly synthetic, never counted as full clears.
 if(x!==32){g.p.y=0;g.p.grounded=false;for(let i=0;i<90&&!g.p.grounded&&g.phase==='playing';i++)g.step();}
 if(perturb)for(const e of g.enemies)e.x+=(random()-.5)*8;
 return g;
}
export function predict(model,x){
 const result=infer(model,x);return {...result,action:ACTIONS[result.index]};
}
