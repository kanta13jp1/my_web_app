// Features for the search-taught student: what is on the current screen only.
// No course position, course number, future state or planner output.
import {hazards} from './reaction.mjs?v=student-1';
export const ACTIONS=['noop','right','right_jump','right_run','right_run_jump','jump','left'];
export const FEATURE_VERSION='search-student-features-v2';
const KIND={goomba:0,koopa:1,shell:2};
// Exact distances to the terrain in front of Mario. The tile window alone only
// resolves whole tiles, which cannot tell "jump now" from "jump next decision".
export function geometry(g){
 const p=g.p,feet=p.y+p.h,front=p.x+p.w,col=Math.floor(front/16),center=Math.floor((p.x+p.w/2)/16);
 const top=Math.floor(p.y/16),bottom=Math.floor((feet-1)/16),hole=c=>!g.solid(c,13)&&!g.solid(c,14);
 let pitDx=400,pitWidth=0,wallDx=400,wallHeight=0,below=400,above=400;
 for(let c=col;c<=col+10;c++)if(hole(c)){pitDx=Math.max(0,c*16-front);while(pitWidth<12&&hole(c+pitWidth))pitWidth++;break;}
 for(let c=col;c<=col+8&&wallDx===400;c++)for(let r=top;r<=bottom;r++)if(g.solid(c,r)){wallDx=Math.max(0,c*16-front);for(let y=12;y>=0&&g.solid(c,y);y--)wallHeight++;break;}
 for(let r=Math.floor(feet/16);r<=14;r++)if(g.solid(center,r)){below=r*16-feet;break;}
 for(let r=Math.floor((p.y-1)/16);r>=0;r--)if(g.solid(center,r)){above=p.y-(r+1)*16;break;}
 return [p.x-Math.floor(p.x/16)*16,pitDx,pitWidth*16,wallDx,wallHeight,below,above];
}
export function features2(g){
 const p=g.p,h=hazards(g);
 const x=[p.y,p.vx,p.vy,+p.grounded,p.h,g.power,+!!g.input.jump,+!!g.wasJump,+!!g.input.run,h.enemy_gap??300,h.contact_ms===null?10000:Math.min(10000,h.contact_ms),+h.gap_ahead,+h.wall_ahead];
 const near=g.enemies.filter(e=>!e.dead&&Math.abs(e.x-p.x)<256).sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x)).slice(0,3);
 for(let i=0;i<3;i++){const e=near[i];x.push(e?e.x-p.x:300,e?e.y-p.y:300,e?.vx??0,e?.vy??0,e?1:0,e?KIND[e.kind]??0:-1);}
 x.push(...geometry(g));
 x.push(...g.telemetry().tiles.map(t=>+(t!==0)));
 if(!x.every(Number.isFinite))throw Error('non-finite features');
 return x;
}
export const FEATURE_COUNT=13+18+7+117;
