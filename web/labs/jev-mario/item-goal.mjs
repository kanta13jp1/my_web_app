// Local assistance only. Never modifies model-only actions or API observations.
const kinds=new Set(['mushroom','flower','life','star']);
export function itemValue(g,kind){return kind==='life'?(g.lives<=1?180:120):kind==='star'?(g.star>120?70:130):kind==='flower'?(g.power<2?150:65):g.power===0?150:60;}
export function itemTargets(g){
 const p=g.p,targets=g.items.filter(i=>!i.taken&&kinds.has(i.kind)).map(i=>({x:i.x+7,y:i.y,kind:i.kind,block:false}));
 for(const [key,kind]of g.contents)if(kinds.has(kind)){const [x,y]=key.split(',').map(Number);targets.push({x:x*16+8,y:y*16+16,kind:kind==='mushroom'&&g.power?'flower':kind,key,block:true});}
 return targets.filter(t=>t.x>=g.camera&&t.x>=p.x-80&&t.x<=p.x+160&&Math.abs(t.y-p.y)<160).sort((a,b)=>(Math.abs(a.x-p.x)-itemValue(g,a.kind)*.15-(a.block?0:48))-(Math.abs(b.x-p.x)-itemValue(g,b.kind)*.15-(b.block?0:48)));
}
export function itemPotential(g){
 return itemTargets(g).reduce((best,t)=>Math.max(best,itemValue(g,t.kind)*.15-Math.abs(t.x-g.p.x-g.p.w/2)*.25-Math.abs(t.y-g.p.y)*.08),0);
}
export function itemIntent(g,t=itemTargets(g)[0]){
 const p=g.p;if(!t||!p.grounded)return null;
 const dx=t.x-p.x-p.w/2;
 // Do not chase beyond visible terrain or across a hole.
 for(let x=Math.floor(Math.min(p.x,t.x)/16);x<=Math.floor(Math.max(p.x+p.w,t.x)/16);x++)if(!g.solid(x,Math.floor((p.y+p.h+1)/16))&&!g.solid(x,Math.floor((p.y+p.h+1)/16)+1))return null;
 if(t.block&&t.y<=p.y+4&&p.y-t.y<64)return Math.abs(dx)<15?'jump':dx<0?'left':'right';
 if(!t.block&&Math.abs(t.y-p.y)<22&&dx<0&&dx>-24)return 'left';
 if(!t.block&&t.y<p.y-10&&Math.abs(dx)<24)return dx<0?'left_jump':'right_jump';
 return null;
}

// Approach a block from below, rather than rewarding a jump over its top.
export function itemApproach(g,target,side=null){
 if(!target.block||g.p.y>=target.y-2)return target;
 const [col,row]=target.key.split(',').map(Number),left=side?side==='left':g.p.x+g.p.w/2<target.x;
 let edge=col;
 // A lower supporting row may extend beyond the reward block itself.
 // Leave that support too; stopping just outside the reward would never descend.
 const foot=Math.floor((g.p.y+g.p.h+1)/16);
 while((g.solid(edge+(left?-1:1),row)||g.solid(edge+(left?-1:1),foot))&&Math.abs(edge-col)<12)edge+=left?-1:1;
 // Eight pixels of clearance exceed the descent steering tolerance for the whole body.
 return {x:left?edge*16-g.p.w/2-8:(edge+1)*16+g.p.w/2+8,y:target.y+20};
}

// Complete a safe descent before attempting to open a reward block from below.
export function itemDescent(g,target=itemTargets(g)[0],side=null){
 const p=g.p;
 if(!target?.block||g.room!=='overworld'||p.climbing||p.vy<0||p.y>=target.y-2)return null;
 const approach=itemApproach(g,target,side),landing=Math.floor(approach.x/16);
 if(approach.x<g.camera+p.w/2||!g.solid(landing,13))return null;
 const dx=approach.x-p.x-p.w/2;
 return Math.abs(dx)<5?'noop':dx<0?'left':'right';
}
