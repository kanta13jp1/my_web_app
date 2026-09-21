// Independently authored 1-1 reconstruction. No ROM, sprite sheet or game code is loaded.
export const TILE = 16;
export function level() {
  const cells = new Map(), contents = new Map();
  const set = (x,y,t='brick',item) => { cells.set(`${x},${y}`,t); if(item) contents.set(`${x},${y}`,item); };
  for(let x=0;x<212;x++) if(!((x>=69&&x<=70)||(x>=86&&x<=88)||(x>=153&&x<=154))) for(let y=13;y<15;y++) set(x,y,'ground');
  for(const [x,h] of [[28,2],[38,3],[46,4],[57,4],[163,2],[179,2]]) for(let c=0;c<2;c++) for(let y=13-h;y<13;y++) set(x+c,y,y===13-h?'pipe-top':'pipe');
  set(16,9,'question','coin');
  for(let x=20;x<=24;x++) set(x,9,x%2?'question':'brick',x===21?'mushroom':x===23?'coin':null);
  set(22,5,'question','coin');set(64,8,'hidden','life');
  for(let x=77;x<=79;x++) set(x,9,x===78?'question':'brick',x===78?'mushroom':null);
  for(let x=80;x<=87;x++) set(x,5);
  for(let x=91;x<=93;x++) set(x,5);set(94,5,'question','coin');set(94,9,'brick','multi');
  set(100,9);set(101,9,'brick','star');
  for(const x of [106,109,112]) set(x,9,'question','coin');set(109,5,'question','mushroom');
  set(118,9);for(let x=121;x<=123;x++) set(x,5);
  for(let x=128;x<=131;x++) set(x,5,x===129||x===130?'question':'brick',x===129||x===130?'coin':null);
  set(129,9);set(130,9);
  for(const start of [134,148]) for(let k=0;k<4;k++) for(let y=12-k;y<13;y++) set(start+k,y,'stone');
  for(const start of [140,155]) for(let k=0;k<4;k++) for(let y=9+k;y<13;y++) set(start+k,y,'stone');
  for(let x=168;x<=171;x++) set(x,9,x===170?'question':'brick',x===170?'coin':null);
  for(let k=0;k<8;k++) for(let y=12-k;y<13;y++) set(181+k,y,'stone');
  for(let y=5;y<13;y++) set(189,y,'stone');set(198,12,'stone');for(let y=9;y<13;y++)set(152,y,'stone');
  return {cells,contents,width:212*16};
}
const overlap=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;
export class World11 {
  constructor(){this.reset();}
  reset(){this.sounds=[];Object.assign(this,level());this.p={x:32,y:192,w:12,h:16,vx:0,vy:0,grounded:true};this.camera=0;this.time=400;this.frames=0;this.score=0;this.coins=0;this.lives=3;this.power=0;this.invincible=0;this.star=0;this.phase='playing';this.presentation=0;this.hurry=false;this.room='overworld';this.input={};this.wasJump=false;this.wasFire=false;this.items=[];this.shots=[];this.effects=[];this.deaths=0;this.multi=0;this.saved=null;
    this.enemies=[22,40,51,53,80,82,97,98,107,114,116,124,126,128,130,174,176].map((x,i)=>({x:x*16,y:x===80||x===82?64:192,w:14,h:16,vx:-.5,vy:0,kind:i===8?'koopa':'goomba',dead:0}));}
  sound(name){if(this.sounds.length<32)this.sounds.push(name);}
  resizePlayer(height){
    const p=this.p,top=p.y+p.h-height;
    if(height>p.h){
      for(let y=Math.floor(top/16);y<=Math.floor((p.y+p.h-.01)/16);y++)
        for(let x=Math.floor(p.x/16);x<=Math.floor((p.x+p.w-.01)/16);x++)if(this.solid(x,y))return false;
    }
    p.y=top;p.h=height;return true;
  }
  drainSounds(){return this.sounds.splice(0);}
  buttons(action){this.input={right:action.startsWith('right'),left:action==='left',jump:action.includes('jump'),run:action.includes('run')};}
  tile(x,y){return this.cells.get(`${x},${y}`);}
  solid(x,y){const t=this.tile(x,y);return !!t&&t!=='hidden';}
  hitBlock(x,y){const key=`${x},${y}`,t=this.cells.get(key);if(!t||t==='used'||t.includes('pipe')||t==='stone'||t==='ground')return;
    this.sound('bump');const item=this.contents.get(key);this.effects.push({x:x*16,y:y*16,life:12,kind:'bump'});
    if(item){if(item==='coin'||item==='multi'){this.sound('coin');this.coins++;this.score+=200;this.effects.push({x:x*16+5,y:y*16-16,life:25,kind:'coin'});}
      else this.items.push({x:x*16,y:y*16-16,w:14,h:16,vx:item==='star'?1.3:1,vy:0,kind:item==='mushroom'&&this.power?'flower':item});
      if(item==='multi'){const n=(this.multi??0)+1;this.multi=n;if(n>=10){this.contents.delete(key);this.cells.set(key,'used');}}
      else{this.contents.delete(key);this.cells.set(key,'used');}
    }else if(t==='brick'&&this.power){this.sound('break');this.cells.delete(key);this.score+=50;for(let i=0;i<4;i++)this.effects.push({x:x*16+(i%2)*8,y:y*16,life:25,kind:'debris',vx:i<2?-1:1,vy:-3-i%2});}
  }
  move(a,head=false){
    a.x+=a.vx;
    for(let y=Math.floor(a.y/16);y<=Math.floor((a.y+a.h-.01)/16);y++)for(let x=Math.floor(a.x/16);x<=Math.floor((a.x+a.w-.01)/16);x++)if(this.solid(x,y)){if(a.vx>0)a.x=x*16-a.w;else if(a.vx<0)a.x=(x+1)*16;a.vx=0;}
    a.y+=a.vy;a.grounded=false;
    for(let y=Math.floor(a.y/16);y<=Math.floor((a.y+a.h-.01)/16);y++)for(let x=Math.floor(a.x/16);x<=Math.floor((a.x+a.w-.01)/16);x++){
      const t=this.tile(x,y);if(!t||(t==='hidden'&&!(head&&a.vy<0)))continue;
      if(a.vy>0){a.y=y*16-a.h;a.grounded=true;}else if(a.vy<0){a.y=(y+1)*16;if(head)this.hitBlock(x,y);}a.vy=0;
    }
  }
  die(){if(this.phase!=='playing')return;this.sound('death');this.phase='dead';this.presentation=0;this.deathY=this.p.y;this.deaths++;this.lives--;this.input={};}
  presentationStep(){
    if(this.phase==='playing'||this.presentation>=180)return;
    this.presentation++;
    if(this.phase==='dead'){
      const t=Math.max(0,this.presentation-22);this.p.y=this.deathY-4.6*t+.095*t*t;
    }else{
      if(this.presentation<60)this.p.y=Math.min(192,32+this.presentation*2.7);
      else{this.p.y=208-this.p.h;this.p.x=Math.min(202*16+32,this.p.x+1.2);this.p.facing=1;this.p.stride=(this.p.stride??0)+1.2;}
      if(this.presentation>60&&this.time>0){const n=Math.min(6,this.time);this.time-=n;this.score+=n*50;}
    }
  }
  snapshot(){
    return {frame:this.frames,phase:this.phase,room:this.room,time:this.time,
      player:{...this.p},input:{...this.input},jump_was_pressed:this.wasJump,
      enemies:this.enemies.filter(e=>!e.dead&&Math.abs(e.x-this.p.x)<256).slice(0,5).map(e=>({x:e.x,y:e.y,w:e.w,h:e.h,vx:e.vx,vy:e.vy,kind:e.kind,edge_gap:e.x-(this.p.x+this.p.w)}))};
  }
  hurt(){if(this.invincible||this.star)return;if(this.power){this.sound('hurt');this.power=0;this.p.y+=this.p.h-16;this.p.h=16;this.invincible=120;}else this.die();}
  enterRoom(){const p=this.p;if(this.room==='overworld'&&p.grounded&&p.x>57*16-2&&p.x<58*16+2&&p.y+p.h===144){this.saved={cells:this.cells,contents:this.contents,enemies:this.enemies};this.cells=new Map();this.contents=new Map();this.enemies=[];this.sound('pipe');this.room='underground';this.camera=0;p.x=32;p.y=32;
      for(let x=0;x<16;x++){this.cells.set(`${x},13`,'brick');this.cells.set(`${x},14`,'brick');if(x<13)this.cells.set(`${x},1`,'brick');}
      for(let x=4;x<11;x++)for(let y=7;y<10;y++)if(!(y===7&&(x===4||x===10)))this.contents.set(`${x},${y}`,'loose');
      for(let y=10;y<13;y++)for(let x=13;x<16;x++)this.cells.set(`${x},${y}`,'pipe');this.items=[];
    }}
  exitRoom(){this.sound('pipe');Object.assign(this,this.saved);this.saved=null;this.room='overworld';this.p.x=164*16;this.p.y=176-this.p.h;this.p.vx=0;this.p.vy=0;this.camera=this.p.x-96;this.items=[];}
  step(){if(this.phase!=='playing')return;const p=this.p,k=this.input;this.frames++;this.time=Math.max(0,400-Math.floor(this.frames/24));if(!this.time){this.die();return;}
    if(this.time<=100&&!this.hurry){this.hurry=true;this.sound('hurry');}
    this.invincible=Math.max(0,this.invincible-1);this.star=Math.max(0,this.star-1);
    const standing=this.power?28:16;
    if(k.down&&p.grounded)this.resizePlayer(this.power?16:12);
    else this.resizePlayer(standing);
    p.crouching=p.h<standing;
    const intended=(k.right?1:0)-(k.left?1:0);
    if(intended)p.facing=intended;
    const dir=p.crouching?0:intended,max=k.run?2.6:1.55;
    p.vx=dir?Math.max(-max,Math.min(max,p.vx+dir*.13)):Math.abs(p.vx)<.08?0:p.vx-Math.sign(p.vx)*.08;
    if(k.jump&&!this.wasJump&&p.grounded&&!p.crouching){this.sound('jump');p.vy=Math.abs(p.vx)>1.6?-5.7:-5.2;p.grounded=false;}
    this.wasJump=!!k.jump;if(!k.jump&&p.vy<-2.5)p.vy=-2.5;
    p.vy=Math.min(6,p.vy+(k.jump&&p.vy<0?.18:.38));const beforeY=p.y;this.move(p,true);
    p.x=Math.max(this.camera,p.x);p.stride=(p.stride??0)+(p.grounded?Math.abs(p.vx):0);if(p.y>250)this.die();
    if(k.down)this.enterRoom();
    if(this.power===2&&k.run&&!this.wasFire&&this.shots.length<2){this.sound('fire');this.shots.push({x:p.x+12,y:p.y+10,w:4,h:4,vx:k.left?-3.5:3.5,vy:1});}this.wasFire=!!k.run;
    if(this.room==='underground'){
      for(const [key,item]of this.contents)if(item==='loose'){const[x,y]=key.split(',').map(Number);if(overlap(p,{x:x*16,y:y*16,w:12,h:16})){this.contents.delete(key);this.sound('coin');this.coins++;this.score+=200;}}
      if(p.x>=12*16&&p.y+p.h<=160&&k.right)this.exitRoom();
    }else this.camera=Math.max(this.camera,Math.min(this.width-256,p.x-96));
    for(const e of this.enemies){if(e.dead||e.x>this.camera+280||e.x<this.camera-32)continue;
      const speed=e.vx;e.vy=Math.min(6,e.vy+.38);this.move(e);if(e.vx===0)e.vx=-speed;
      if(e.y>250){e.dead=1;continue;}if(overlap(p,e)&&this.phase==='playing'){
        if(this.star){e.dead=1;this.score+=100;}
        else if(p.vy>=0&&beforeY+p.h<=e.y+6){this.sound('stomp');p.y=e.y-p.h;p.vy=-3.5;this.score+=100;if(e.kind==='koopa'){e.kind='shell';e.vx=0;}else if(e.kind==='shell'){e.vx=e.vx?0:(p.x<e.x?4:-4);}else{e.dead=1;this.effects.push({x:e.x,y:e.y+12,kind:'squash',life:20});}}
        else if(e.kind==='shell'&&!e.vx){e.vx=p.x<e.x?4:-4;e.x+=Math.sign(e.vx)*10;}else this.hurt();
      }
      if(e.kind==='shell'&&e.vx)for(const other of this.enemies)if(other!==e&&!other.dead&&overlap(e,other)){other.dead=1;this.score+=100;}
    }
    for(const item of this.items){if(item.taken)continue;const speed=item.vx;if(item.kind!=='flower'){item.vy=Math.min(6,item.vy+.3);this.move(item);if(!item.vx)item.vx=-speed;if(item.kind==='star'&&item.grounded)item.vy=-4;}
      if(overlap(p,item)){this.sound('item');item.taken=true;this.score+=1000;if(item.kind==='star')this.star=600;else if(item.kind==='life')this.lives++;else{this.power=item.kind==='flower'?2:1;if(p.h===16){p.y-=12;p.h=28;}}}}
    for(const shot of this.shots){shot.vy+=.35;this.move(shot);if(shot.grounded)shot.vy=-2.8;if(!shot.vx||shot.x<this.camera||shot.x>this.camera+256)shot.dead=true;for(const e of this.enemies)if(!e.dead&&overlap(shot,e)){e.dead=1;shot.dead=true;this.score+=100;}}
    this.shots=this.shots.filter(s=>!s.dead);
    for(const fx of this.effects){fx.life--;if(fx.kind==='coin')fx.y-=1;if(fx.kind==='debris'){fx.x+=fx.vx;fx.y+=fx.vy;fx.vy+=.25;}}this.effects=this.effects.filter(f=>f.life>0);
    if(this.room==='overworld'&&p.x>=198*16&&this.phase==='playing'){this.sound('clear');this.phase='won';this.presentation=0;this.score+=Math.max(100,5000-Math.floor(p.y)*20);this.input={};}
  }
  telemetry(previous=0){const p=this.p,tiles=[];for(let row=0;row<13;row++)for(let col=-2;col<=6;col++)tiles.push(this.solid(Math.floor(p.x/16)+col,row+2)?84:0);
    return{player:{x:p.x,y:p.y+p.h-16,vx:p.vx,vy:p.vy,grounded:p.grounded},tiles,enemies:this.enemies.filter(e=>!e.dead&&Math.abs(e.x-p.x)<256).slice(0,5).map(e=>({dx:e.x-p.x,y:e.y,type:e.kind==='goomba'?6:0})),world:1,stage:1,previous_response_ms:Math.min(10000,previous)};}
}
const playerPixels=['....RRRRR...','...RRRRRRRR.','...HHHSSBS..','..HSHSSSBSSS','..HSHHSSSBSS','..HHSSSSBBB.','....SSSSSS..','...RBRRRB...','..RRBRRRBRR.','.RRRBBBBBRRR','.SSRBYBYBRSS','.SSBBBBBBBSS','...BBB.BBB..','..BBB...BBB.','.HHH.....HHH','HHHH.....HHHH'];
const poses={
  idle:playerPixels,
  walk0:[...playerPixels.slice(0,7),'...RBRRRB...','..RRBRRRBRR.','.SSRBBBBBRRR','.SSBBYBYBRSS','...BBBBBB.SS','..BBBB.BB...','.BBB...BBB..','HHHH....HH..','........HHHH'],
  walk1:[...playerPixels.slice(0,7),'...RBRRRB...','...RBRRRBR..','..RRBBBBBRR.','..SRBYBYBRS.','..SSBBBBBSS.','....BBBB...','....BBBB...','...HHHH....','...HHHHH...'],
  walk2:[...playerPixels.slice(0,7),'...RBRRRB...','..RRBRRRBRR.','.RRRBBBBBSS.','.SSRBYBYBSS.','.SS.BBBBB...','....BB.BBBB.','...BBB...BBB','..HH....HHHH','HHHH........'],
  jump:[...playerPixels.slice(0,7),'SS.RBRRRB.SS','SSRRBRRRBRSS','.RRRBBBBBRR.','...BBYBYB...','...BBBBBB...','..BBB..BBBB.','.BBB.....BB.','HHHH.....HHH','............'],
  fall:[...playerPixels.slice(0,7),'...RBRRRB...','SSRRBRRRBRSS','SSRRBBBBBRSS','...BBYBYB...','...BBBBBB...','....BB.BB...','....BB.BB...','...HHH.HHH..','..HHHH.HHHH.'],
  dead:[...playerPixels.slice(0,7),'SS.RBRRRB.SS','SSRRBBBBBRSS','...BBYBYB...','...BBBBBB...','..BBB..BBB..','.HHHH..HHHH.'],
  skid:[...playerPixels.slice(0,7),'...RBRRRB...','..RRBBBBBSS.','.RRBBYBYBSS.','.SSBBBBBB...','..BBBB.BBB..','.HHHH...HHHH','HHHH....HHHH'],
  climb:[...playerPixels.slice(0,7),'...RRRRB.SS.','..RRBBBBBSS.','...BBYBYB...','...BBBBBB...','...BBB.BBB..','..HHHH.HHHH.'],
  crouch:[...playerPixels.slice(0,7),'..RRBRRRBRR.','.SSRBYBYBRSS','.SSBBBBBBBSS','..BBBBBBBBB.','.HHHH...HHHH'],
};
export function playerPose(g){
  if(g.phase==='dead')return 'dead';
  if(g.phase==='won')return g.presentation<60?'climb':`walk${Math.floor((g.p.stride??0)/5)%3}`;
  if(g.p.crouching)return 'crouch';
  if(g.p.grounded&&Math.abs(g.p.vx)>.4&&((g.input.left&&g.p.vx>0)||(g.input.right&&g.p.vx<0)))return 'skid';
  if(!g.p.grounded)return g.p.vy<0?'jump':'fall';
  if(Math.abs(g.p.vx)<.1)return 'idle';
  return `walk${Math.floor((g.p.stride??0)/5)%3}`;
}
function drawPlayer(ctx,g,palette){
  const rows=poses[playerPose(g)],width=Math.max(...rows.map(r=>r.length));
  // Integer row boundaries keep enlarged poses crisp and anchor both feet.
  for(let j=0;j<rows.length;j++)for(let i=0;i<rows[j].length;i++)if(palette[rows[j][i]]){
    const top=Math.floor(j*g.p.h/rows.length),bottom=Math.floor((j+1)*g.p.h/rows.length);
    ctx.fillStyle=palette[rows[j][i]];
    ctx.fillRect(Math.round(g.p.x-g.camera+((g.p.facing??1)<0?width-1-i:i)),Math.round(g.p.y)+top,1,bottom-top);
  }
}
function sprite(ctx,rows,x,y,palette,sx=1,sy=1){for(let j=0;j<rows.length;j++)for(let i=0;i<rows[j].length;i++)if(palette[rows[j][i]]){ctx.fillStyle=palette[rows[j][i]];ctx.fillRect(Math.round(x+i*sx),Math.round(y+j*sy),sx,sy);}}
export function drawWorld(ctx,g){const cam=g.camera,underground=g.room==='underground';ctx.imageSmoothingEnabled=false;ctx.fillStyle=underground?'#101020':'#5c94fc';ctx.fillRect(0,0,256,240);
  if(!underground){
    for(let start=0;start<g.width;start+=768){for(const [x,y,w]of[[130,42,30],[315,26,44],[530,42,30]]){const px=x+start-cam*.6;ctx.fillStyle='#fff';ctx.fillRect(px,y,w,12);ctx.fillRect(px+6,y-6,w-12,6);ctx.fillStyle='#cbdcff';ctx.fillRect(px+2,y+10,w-4,2);}
      for(const [x,h]of[[0,32],[256,16],[576,32]]){const px=x+start-cam;ctx.fillStyle='#00a800';ctx.beginPath();ctx.moveTo(px,208);ctx.lineTo(px+h,208-h);ctx.lineTo(px+h*2,208);ctx.fill();ctx.fillStyle='#005800';ctx.fillRect(px+h,202-h,2,4);}
      for(const x of[184,368,664]){ctx.fillStyle='#00a800';for(let i=0;i<3;i++)ctx.fillRect(x+start-cam+i*8,198-(i%2)*4,16,10+(i%2)*4);}
    }
    const flag=198*16-cam;ctx.fillStyle='#80d010';ctx.fillRect(flag+7,32,2,160);ctx.fillRect(flag+5,28,6,6);ctx.fillStyle='#fff';ctx.beginPath();const flagY=g.phase==='won'?36+Math.min(144,g.presentation*2.7):36;ctx.moveTo(flag+7,flagY);ctx.lineTo(flag-9,flagY);ctx.lineTo(flag+7,flagY+12);ctx.fill();
    const castle=202*16-cam;ctx.fillStyle='#b85020';ctx.fillRect(castle,176,80,32);ctx.fillRect(castle+16,152,48,24);for(let i=0;i<5;i++)ctx.fillRect(castle+i*16,168,8,8);for(let i=0;i<3;i++)ctx.fillRect(castle+16+i*16,144,8,8);ctx.fillStyle='#101020';ctx.fillRect(castle+32,184,16,24);ctx.fillRect(castle+24,160,8,10);ctx.fillRect(castle+48,160,8,10);
  }
  for(const[key,t]of g.cells){if(t==='hidden')continue;const[col,row]=key.split(',').map(Number),x=col*16-cam,baseY=row*16,bump=g.effects.find(f=>f.kind==='bump'&&f.x===col*16&&f.y===baseY),y=baseY-(bump?Math.sin((12-bump.life)/12*Math.PI)*4:0);if(x<-16||x>256)continue;
    if(t.startsWith('pipe')){ctx.fillStyle='#005800';ctx.fillRect(x,y,16,16);ctx.fillStyle='#00a800';ctx.fillRect(x+2,y,11,16);ctx.fillStyle='#80d010';ctx.fillRect(x+3,y,3,16);if(t==='pipe-top'){ctx.fillStyle='#003800';ctx.fillRect(x,y,16,2);ctx.fillRect(x,y+14,16,2);}continue;}
    ctx.fillStyle=t==='question'?['#f8a040','#d88020','#f8a040'][Math.floor(g.frames/12)%3]:t==='used'?'#a85820':underground?'#0088a8':'#c84c0c';ctx.fillRect(x,y,16,16);ctx.strokeStyle='#381800';ctx.lineWidth=1;ctx.strokeRect(x+.5,y+.5,15,15);ctx.fillStyle='#f8c080';ctx.fillRect(x+1,y+1,14,1);
    if(t==='question'){ctx.fillStyle='#702800';ctx.font='bold 14px monospace';ctx.fillText('?',x+4,y+13);}else if(t==='brick'||t==='ground'){ctx.fillStyle='#502800';ctx.fillRect(x,y+7,16,1);ctx.fillRect(x+7,y,1,7);ctx.fillRect(x+3,y+8,1,8);}else if(t==='stone'){ctx.fillStyle='#f8a050';ctx.fillRect(x+2,y+2,3,11);}
  }
  for(const[key,item]of g.contents)if(item==='loose'){const[x,y]=key.split(',').map(Number);ctx.fillStyle='#ffd040';ctx.fillRect(x*16+5,y*16+2,6,12);}
  for(const e of g.enemies){if(e.dead||e.x<cam-16||e.x>cam+256)continue;const x=Math.round(e.x-cam),y=Math.round(e.y);ctx.fillStyle=e.kind==='goomba'?'#a84800':'#00a800';ctx.fillRect(x+2,y+2,10,10);ctx.fillRect(x,y+6,14,6);ctx.fillStyle='#ffe0b0';ctx.fillRect(x+3,y+10,8,4);ctx.fillStyle='#101020';ctx.fillRect(x+3,y+5,2,3);ctx.fillRect(x+9,y+5,2,3);ctx.fillRect(x+(g.frames%16<8?0:2),y+14,5,2);ctx.fillRect(x+9,y+14,5,2);}
  for(const i of g.items)if(!i.taken){ctx.fillStyle=i.kind==='star'?'#ffd040':i.kind==='life'?'#00a800':'#f83800';ctx.fillRect(i.x-cam,i.y+2,14,8);ctx.fillStyle='#ffe0b0';ctx.fillRect(i.x-cam+4,i.y+10,6,6);ctx.fillRect(i.x-cam+2,i.y+3,3,3);ctx.fillRect(i.x-cam+9,i.y+3,3,3);}
  for(const f of [...g.effects,...g.shots]){if(f.kind==='bump')continue;ctx.fillStyle=f.kind==='debris'||f.kind==='squash'?'#b85020':'#ffd040';ctx.fillRect(f.x-cam,f.y,f.kind==='squash'?14:5,f.kind==='squash'?4:7);}
  if(!g.invincible||g.frames%6<3){const palette={R:g.power===2?'#fff':'#f83800',H:'#803000',S:'#ffbc80',B:g.star&&g.frames%12<6?'#00d8f8':'#b85000',Y:'#ffc000'};drawPlayer(ctx,g,palette);}
  ctx.fillStyle='#fff';ctx.font='8px monospace';ctx.fillText('MARIO',16,15);ctx.fillText(String(g.score).padStart(6,'0'),16,25);ctx.fillText(`COIN ${String(g.coins).padStart(2,'0')}`,82,25);ctx.fillText('WORLD',144,15);ctx.fillText('1-1',150,25);ctx.fillText('TIME',208,15);ctx.fillText(String(g.time),216,25);
  if(g.phase!=='playing'&&g.presentation>=180){ctx.fillStyle='#101020dd';ctx.fillRect(20,86,216,52);ctx.fillStyle='#fff';ctx.font='bold 14px monospace';ctx.fillText(g.phase==='won'?'WORLD 1-1 CLEAR!':'TRY AGAIN',g.phase==='won'?38:88,108);ctx.font='8px monospace';ctx.fillText('RESTART TO PLAY AGAIN',47,126);}
}
