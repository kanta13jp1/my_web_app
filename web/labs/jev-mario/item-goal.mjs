// Local assistance only. Never modifies model-only actions or API observations.
const kinds=new Set(['mushroom','flower','life','star']);
export function itemTargets(g){
 const p=g.p,targets=g.items.filter(i=>!i.taken&&kinds.has(i.kind)).map(i=>({x:i.x+7,y:i.y,kind:i.kind,block:false}));
 for(const [key,kind]of g.contents)if(kinds.has(kind)){const [x,y]=key.split(',').map(Number);targets.push({x:x*16+8,y:y*16+16,kind,block:true});}
 return targets.filter(t=>t.x>=g.camera&&t.x>=p.x-24&&t.x<=p.x+80&&Math.abs(t.y-p.y)<80).sort((a,b)=>Math.abs(a.x-p.x)-Math.abs(b.x-p.x));
}
export function itemPotential(g){
 return itemTargets(g).reduce((best,t)=>Math.max(best,18-Math.abs(t.x-g.p.x-g.p.w/2)*.25-Math.abs(t.y-g.p.y)*.08),0);
}
export function itemIntent(g){
 const t=itemTargets(g)[0],p=g.p;if(!t||!p.grounded)return null;
 const dx=t.x-p.x-p.w/2;
 // Do not chase beyond visible terrain or across a hole.
 for(let x=Math.floor(Math.min(p.x,t.x)/16);x<=Math.floor(Math.max(p.x+p.w,t.x)/16);x++)if(!g.solid(x,Math.floor((p.y+p.h+1)/16))&&!g.solid(x,Math.floor((p.y+p.h+1)/16)+1))return null;
 if(t.block&&t.y<=p.y+4&&p.y-t.y<64&&Math.abs(dx)<15)return 'jump';
 if(!t.block&&Math.abs(t.y-p.y)<22&&dx<0&&dx>-24)return 'left';
 if(!t.block&&t.y<p.y-10&&Math.abs(dx)<24)return 'right_jump';
 return null;
}
