// Explicit geometry/pipe assistance. It never changes the actual player's position.
export function pipeRoute(g){
 if(g.room==='underground')return g.p.x>=160?'right_jump':null;
 const p=g.p,entries=g.usablePipes().filter(t=>!g.visitedPipes.includes(t.id)&&!(t.exit-t.x>128&&[...g.contents].some(([key,kind])=>Number(key.split(',')[0])*16>=Math.max(g.camera,p.x-80)&&Number(key.split(',')[0])*16<t.exit&&['mushroom','flower','life','star'].includes(kind))));
 const entry=entries.find(t=>Math.abs(t.x+16-p.x-p.w/2)<12&&Math.abs(p.y+p.h-t.y)<1&&p.grounded);
 if(entry)return 'down';
 // An overhang adjoining a pipe needs a jump from outside its left edge.
 for(let col=Math.floor(p.x/16);col<=Math.floor(p.x/16)+8;col++)for(let row=5;row<13;row++){
  if(g.tile(col,row)!=='pipe-top'||g.tile(col-1,row)!=='platform')continue;
  let left=col-1;while(g.tile(left-1,row)==='platform')left--;
  const launch=left*16-p.w-4,top=row*16;
  if(launch<g.camera||p.x<launch-8||p.x>col*16+32||p.y+p.h<=top)continue;
  if(p.x>launch+2)return 'left';
  return 'jump';
 }
 // Aim down only on defined entrances; decorative pipes remain obstacles.
 const ahead=entries.find(t=>t.x+32>=p.x&&t.x-p.x<96);
 if(ahead&&p.y+p.h<=ahead.y+1)return p.x+p.w/2<ahead.x+12?'right':'left';
 return null;
}
