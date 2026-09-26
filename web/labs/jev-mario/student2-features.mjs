// Features for the search-taught student: what is on the current screen only.
// No course position, course number, future state or planner output.
import {hazards} from './reaction.mjs?v=student-1';
export const ACTIONS=['noop','right','right_jump','right_run','right_run_jump','jump','left'];
export const FEATURE_VERSION='search-student-features-v1';
const KIND={goomba:0,koopa:1,shell:2};
export function features2(g){
 const p=g.p,h=hazards(g);
 const x=[p.y,p.vx,p.vy,+p.grounded,p.h,g.power,+!!g.input.jump,+!!g.wasJump,+!!g.input.run,h.enemy_gap??300,h.contact_ms===null?10000:Math.min(10000,h.contact_ms),+h.gap_ahead,+h.wall_ahead];
 const near=g.enemies.filter(e=>!e.dead&&Math.abs(e.x-p.x)<256).sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x)).slice(0,3);
 for(let i=0;i<3;i++){const e=near[i];x.push(e?e.x-p.x:300,e?e.y-p.y:300,e?.vx??0,e?.vy??0,e?1:0,e?KIND[e.kind]??0:-1);}
 x.push(...g.telemetry().tiles.map(t=>+(t!==0)));
 if(!x.every(Number.isFinite))throw Error('non-finite features');
 return x;
}
export const FEATURE_COUNT=13+18+117;
