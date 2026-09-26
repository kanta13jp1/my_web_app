import {pixelText,pixelCloud,pixelHill,pixelTile,pixelPipe} from './pixel-art.mjs?v=student-1';
// Independently authored 1-1 reconstruction. No ROM, sprite sheet or game code is loaded.
export const TILE = 16;
// Internal course IDs retain compatibility with saved simulations (1..10).
export const LAST_COURSE=10;
export function courseInfo(id=1){const world=Math.floor((id-1)/4)+1,stage=(id-1)%4+1;return {world,stage,label:`${world}-${stage}`};}
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

// Independently laid out underground course, inspired by the early console era.
export function undergroundLevel(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='brick',item)=>{cells.set(`${x},${y}`,t);if(item)contents.set(`${x},${y}`,item);};
 for(let x=0;x<212;x++){
  if(!((x>=70&&x<=71)||(x>=112&&x<=113)||(x>=150&&x<=151)))for(let y=13;y<15;y++)set(x,y,'ground');
  if(x<185)for(let y=2;y<4;y++)set(x,y);
 }
 for(const [x,h]of [[27,2],[44,3],[88,2],[132,3],[176,2]])for(let c=0;c<2;c++)for(let y=13-h;y<13;y++)set(x+c,y,y===13-h?'pipe-top':'pipe');
 for(const start of [12,35,58,78,100,122,142,160]){
  for(let x=start;x<start+5;x++)set(x,8,x===start+2?'question':'brick',x===start+2?(start===12?'mushroom':'coin'):null);
  for(let x=start;x<start+5;x++)contents.set(`${x},11`,'loose');
 }
 for(let k=0;k<4;k++)for(let y=12-k;y<13;y++)set(184+k,y,'stone');
 // Exit tunnel opens at ground level; reaching it ends this stage.
 for(let x=198;x<200;x++)for(let y=10;y<13;y++)set(x,y,'pipe');
 return {cells,contents,width:212*16};
}
// Independent elevated-platform course; no original game assets.
export function skyLevel(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='platform')=>cells.set(`${x},${y}`,t);
 for(let x=0;x<20;x++)for(let y=13;y<15;y++)set(x,y,'ground');
 for(let x=185;x<212;x++)for(let y=13;y<15;y++)set(x,y,'ground');
 const platforms=[[20,29,12],[32,41,10],[44,53,11],[56,65,9],[68,77,10],[80,89,8],[92,101,10],[104,113,11],[116,125,9],[128,137,10],[140,149,8],[152,161,10],[164,173,11],[176,184,12]];
 for(const [a,b,y] of platforms){for(let x=a;x<=b;x++)set(x,y);for(let x=a+2;x<b-1;x+=2)contents.set(`${x},${y-2}`,'loose');}
 cells.set('12,9','question');contents.set('12,9','mushroom');
 set(198,12,'stone');return {cells,contents,width:212*16};
}
// Independently designed castle: lava gaps, timed fire bars and an axe bridge exit.
export function castleLevel(second=false){
 const cells=new Map(),contents=new Map(),set=(x,y,t='castle')=>cells.set(`${x},${y}`,t);
 const lava=second?[[32,35],[64,68],[100,104],[137,141],[164,167],[180,195]]:[[30,33],[59,62],[92,95],[126,129],[158,161],[180,195]];
 for(let x=0;x<212;x++){
  for(let y=2;y<4;y++)set(x,y);
  if(!lava.some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y);
 }
 for(const x of (second?[22,48,80,116,150,174]:[20,45,73,106,140,168])){set(x,11);set(x+1,11);}
 for(let x=180;x<=195;x++)set(x,12,'bridge');
 cells.set('12,9','question');contents.set('12,9','mushroom');
 for(const x of [36,66,99,133,164])contents.set(`${x},11`,'loose');
 const fireBars=(second?[26,54,86,120,154,174]:[24,50,80,115,148,172]).map((x,i)=>({x:x*16+8,y:168,length:4,offset:i*Math.PI/3,direction:i%2?-1:1}));
 return {cells,contents,width:212*16,lava,fireBars};
}
// Independent second-world ground course; distinct from the 1-1 layout.
export function world21Level(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='brick',item)=>{cells.set(`${x},${y}`,t);if(item)contents.set(`${x},${y}`,item);};
 for(let x=0;x<212;x++)if(![[44,46],[98,100],[146,148]].some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y,'ground');
 for(const[x,h]of [[24,2],[55,3],[78,2],[120,3],[162,2],[176,2]])for(let c=0;c<2;c++)for(let y=13-h;y<13;y++)set(x+c,y,y===13-h?'pipe-top':'pipe');
 for(const start of [12,35,63,88,108,132,154]){
  for(let x=start;x<start+4;x++)set(x,9,x===start+1?'question':'brick',x===start+1?(start===12||start===108?'mushroom':'coin'):null);
  for(let x=start;x<start+4;x++)contents.set(`${x},7`,'loose');
 }
 for(let x=68;x<73;x++)set(x,6);
 set(135,5,'question','star');
 for(let k=0;k<8;k++)for(let y=12-k;y<13;y++)set(181+k,y,'stone');
 for(let y=5;y<13;y++)set(189,y,'stone');set(198,12,'stone');
 return {cells,contents,width:212*16};
}
// Independent water course with a reachable lower exit tunnel.
export function waterLevel(){
 const cells=new Map(),contents=new Map();
 for(let x=0;x<212;x++)for(let y=13;y<15;y++)cells.set(`${x},${y}`,'ground');
 for(const [x,h] of [[24,3],[48,5],[76,3],[102,6],[132,4],[162,5]])for(let c=0;c<3;c++)for(let y=13-h;y<13;y++)cells.set(`${x+c},${y}`,'stone');
 for(const x of [16,36,61,90,118,146,174])for(let c=0;c<4;c++)contents.set(`${x+c},7`,'loose');
 for(let x=198;x<200;x++)for(let y=10;y<13;y++)cells.set(`${x},${y}`,'pipe');
 return {cells,contents,width:212*16};
}
// Independent bridge course with deterministic leaping fish.
export function bridgeLevel(){
 const cells=new Map(),contents=new Map();
 for(let x=0;x<212;x++){
  if(x<20||x>=185){for(let y=13;y<15;y++)cells.set(`${x},${y}`,'ground');}
  else if(![[48,50],[83,85],[119,122],[158,160]].some(([a,b])=>x>=a&&x<=b))cells.set(`${x},12`,'bridge');
 }
 for(const start of [28,62,97,137,171])for(let x=start;x<start+5;x++)contents.set(`${x},9`,'loose');
 cells.set('12,9','question');contents.set('12,9','mushroom');cells.set('198,12','stone');
 return {cells,contents,width:212*16};
}
const overlap=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;
// Independently authored night course; not an extracted original map.
export function nightLevel(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='brick',item)=>{cells.set(`${x},${y}`,t);if(item)contents.set(`${x},${y}`,item);};
 for(let x=0;x<212;x++)if(![[48,50],[96,98],[143,145]].some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y,'ground');
 for(const[x,h]of [[26,2],[39,3],[61,2],[111,3],[156,3],[173,2]])for(let c=0;c<2;c++)for(let y=13-h;y<13;y++)set(x+c,y,y===13-h?'pipe-top':'pipe');
 for(const a of [12,33,69,82,120,132,163]){for(let x=a;x<a+5;x++)set(x,9,x===a+2?'question':'brick',x===a+2?(a===12||a===120?'mushroom':'coin'):null);for(let x=a;x<a+4;x++)contents.set(`${x},6`,'loose');}
 for(let x=71;x<77;x++)set(x,6);set(74,5,'question','star');
 for(const start of [86,102])for(let k=0;k<4;k++)for(let y=12-k;y<13;y++)set(start+k,y,'stone');
 for(let k=0;k<8;k++)for(let y=12-k;y<13;y++)set(181+k,y,'stone');for(let y=5;y<13;y++)set(189,y,'stone');set(198,12,'stone');
 return {cells,contents,width:212*16};
}
// Independent night-ground expansion with requested additional enemy types.
export function world32Level(){
 const cells=new Map(),contents=new Map(),cannons=[],set=(x,y,t='brick',item)=>{cells.set(`${x},${y}`,t);if(item)contents.set(`${x},${y}`,item);};
 for(let x=0;x<212;x++)if(![[59,61],[114,116],[155,157]].some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y,'ground');
 for(const [x,h]of [[24,2],[74,3],[105,2],[148,3]])for(let c=0;c<2;c++)for(let y=13-h;y<13;y++)set(x+c,y,y===13-h?'pipe-top':'pipe');
 for(const start of [12,47,92,124,163]){for(let x=start;x<start+5;x++)set(x,9,x===start+2?'question':'brick',x===start+2?(start===12||start===124?'mushroom':'coin'):null);for(let x=start;x<start+4;x++)contents.set(`${x},6`,'loose');}
 for(const x of [40,86,132,173]){set(x,11,'cannon');set(x,12,'cannon');cannons.push({x:x*16,y:176,timer:0});}
 for(let k=0;k<8;k++)for(let y=12-k;y<13;y++)set(181+k,y,'stone');for(let y=5;y<13;y++)set(189,y,'stone');set(198,12,'stone');
 return {cells,contents,cannons,width:212*16};
}
export class World11 {
  constructor(stage=1){this.stage=[1,2,3,4,5,6,7,8,9,10].includes(stage)?stage:1;this.reset();}
  reset(){this.sounds=[];this.lava=[];this.fireBars=[];this.cannons=[];this.hammers=[];Object.assign(this,this.stage===10?world32Level():this.stage===9?nightLevel():this.stage===8?castleLevel(true):this.stage===7?bridgeLevel():this.stage===6?waterLevel():this.stage===5?world21Level():this.stage===4?castleLevel():this.stage===3?skyLevel():this.stage===2?undergroundLevel():level());this.p={x:32,y:192,w:12,h:16,vx:0,vy:0,grounded:true};this.camera=0;this.time=400;this.frames=0;this.score=0;this.coins=0;this.lives=3;this.power=0;this.invincible=0;this.star=0;this.phase='playing';this.presentation=0;this.flagStartY=0;this.wasSkidding=false;this.hurry=false;this.room=this.stage===6?'underwater':(this.stage===4||this.stage===8)?'castle':this.stage===2?'stage-underground':'overworld';this.input={};this.wasJump=false;this.wasFire=false;this.items=[];this.shots=[];this.effects=[];this.deaths=0;this.multi=0;this.saved=null;this.boss=this.stage===8?{x:189*16,y:160,w:28,h:32,vx:-.45,vy:0,grounded:true,hp:5,dead:false,active:0}:null;this.bossFlames=[];this.rescued=false;this.peachRescued=false;
    this.enemies=(this.stage===10?[18,20,31,34,51,66,78,97,109,122,139,163,167]:this.stage===9?[19,31,43,57,66,79,91,106,116,140,153,168]:this.stage===5?[17,33,37,67,71,91,105,113,139,152,170]:(this.stage===4||this.stage===8)?[]:this.stage===3?[37,61,85,109,133,157,180]:this.stage===2?[22,38,53,64,82,96,107,126,140,158,172]:[22,40,51,53,80,82,97,98,107,114,116,124,126,128,130,174,176]).map((x,i)=>({x:x*16,y:this.stage===3?(Math.min(...[...this.cells.keys()].filter(k=>k.startsWith(x+',')).map(k=>Number(k.split(',')[1])))*16-16):this.stage!==2&&(x===80||x===82)?64:192,w:14,h:16,vx:-.5,vy:0,kind:(this.stage===10?(i%2===0):this.stage===9?(i%3===1):this.stage===5?(i===3||i===7):i===8)?'koopa':'goomba',dead:0}));
    if(this.stage===10)for(const x of [52,99,164])this.enemies.push({x:x*16,y:184,w:14,h:24,vx:.35,vy:0,kind:'hammer-bro',dead:0,anchor:x*16,age:0});
    if(this.stage===6){this.p.y=128;this.p.grounded=false;this.enemies=[32,54,70,94,120,145,168,184].map((x,i)=>({x:x*16,y:80+(i%3)*32,baseY:80+(i%3)*32,w:14,h:14,vx:i%2?.65:-.65,vy:0,kind:i%3?'fish':'squid',dead:0,offset:i*30}));}
    if(this.stage===7)this.enemies=[30,39,55,67,78,92,106,114,131,143,153,167,177].map((x,i)=>({x:x*16,y:260,w:14,h:14,vx:i%2?-.8:.9,vy:-7,kind:'leaping-fish',dead:0,launched:false}));}


  advanceStage(){
    if(this.phase!=='won'||this.presentation<180||this.stage>=LAST_COURSE)return false;
    const saved={score:this.score,coins:this.coins,lives:this.lives,power:this.power,deaths:this.deaths};
    this.stage++;this.reset();Object.assign(this,saved);if(this.power)this.resizePlayer(28);return true;
  }
  sound(name){if(this.sounds.length<32)this.sounds.push(name);}
  resizePlayer(height){
    const p=this.p,top=p.y+p.h-height;
    if(height>p.h){
      for(let y=Math.floor(top/16);y<=Math.floor((p.y+p.h-.01)/16);y++)
        for(let x=Math.floor(p.x/16);x<=Math.floor((p.x+p.w-.01)/16);x++)if(this.solid(x,y))return false;
    }
    p.y=top;p.h=height;return true;
  }
  popup(value,x=this.p.x,y=this.p.y){this.effects.push({kind:'score',value:String(value),x,y:y-20,life:40});}
  defeat(enemy){if(enemy.dead)return;enemy.dead=1;this.score+=100;this.popup(100,enemy.x,enemy.y);this.sound('kick');this.effects.push({x:enemy.x,y:enemy.y,kind:'debris',life:25,vx:1,vy:-3});}
  collectCoin(){this.sound('coin');this.coins++;this.score+=200;if(this.coins>=100){this.coins-=100;this.lives++;this.sound('life');}}
  drainSounds(){return this.sounds.splice(0);}
  buttons(action){this.input={right:action.startsWith('right'),left:action==='left',jump:action.includes('jump'),run:action.includes('run')};}
  tile(x,y){return this.cells.get(`${x},${y}`);}
  solid(x,y){const t=this.tile(x,y);return !!t&&t!=='hidden';}
  hitBlock(x,y){const key=`${x},${y}`,t=this.cells.get(key);if(!t||t==='used'||t.includes('pipe')||t==='stone'||t==='ground'||t==='castle'||t==='bridge'||t==='cannon')return;
    this.sound('bump');
    for(const e of this.enemies)if(!e.dead&&e.x+e.w>x*16&&e.x<(x+1)*16&&Math.abs(e.y+e.h-y*16)<2){e.dead=1;this.score+=100;this.sound('stomp');this.effects.push({x:e.x,y:e.y,kind:'debris',life:25,vx:1,vy:-3});}
    const item=this.contents.get(key);this.effects.push({x:x*16,y:y*16,life:12,kind:'bump'});
    if(item){if(item==='coin'||item==='multi'){this.collectCoin();this.effects.push({x:x*16+5,y:y*16-16,life:25,kind:'coin'});}
      else {this.sound('appear');this.items.push({x:x*16,y:y*16,w:14,h:16,emerging:16,vx:item==='star'?1.3:1,vy:0,kind:item==='mushroom'&&this.power?'flower':item});}
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
      if(this.stage===4||this.stage===8){if(this.presentation<65&&this.presentation%4===0)this.cells.delete(`${179+Math.floor(this.presentation/4)},12`);this.p.x=Math.min(201*16,this.p.x+1.2);this.p.y=208-this.p.h;this.p.grounded=true;this.p.vx=0;this.p.vy=0;this.p.stride=(this.p.stride??0)+1.2;}
      else if(this.stage===2||this.stage===6){this.p.x=Math.min(198*16,this.p.x+1.2);this.p.stride=(this.p.stride??0)+1.2;}
      else if(this.presentation<60)this.p.y=Math.min(192,this.flagStartY+this.presentation*2.7);
      else{this.p.y=208-this.p.h;this.p.grounded=true;this.p.vx=0;this.p.vy=0;this.p.x=Math.min(202*16+32,this.p.x+1.2);this.p.facing=1;this.p.stride=(this.p.stride??0)+1.2;}
      if(this.stage===8){if(this.boss&&this.presentation>32){this.boss.dead=true;this.boss.y+=3;}if(this.presentation===90){this.rescued=true;this.sound('life');}}
      if(this.stage>=9&&this.presentation===140){this.peachRescued=true;this.sound('life');}
      if(this.presentation===61)this.sound('clear');
      if(this.presentation>60&&this.time>0){if(this.presentation%4===0)this.sound('tally');const n=Math.min(6,this.time);this.time-=n;this.score+=n*50;}
    }
  }
  snapshot(){
    return {course_id:this.stage,...courseInfo(this.stage),frame:this.frames,phase:this.phase,room:this.room,time:this.time,
      boss:this.boss?{...this.boss}:null,boss_flames:this.bossFlames.map(f=>({...f})),rescued:this.rescued,peach_rescued:this.peachRescued,hammers:this.hammers.map(h=>({...h})),cannons:this.cannons.map(c=>({...c})),
      player:{...this.p},input:{...this.input},jump_was_pressed:this.wasJump,
      enemies:this.enemies.filter(e=>!e.dead&&Math.abs(e.x-this.p.x)<256).slice(0,5).map(e=>({x:e.x,y:e.y,w:e.w,h:e.h,vx:e.vx,vy:e.vy,kind:e.kind,edge_gap:e.x-(this.p.x+this.p.w)}))};
  }
  fireHazards(){
    return this.fireBars.flatMap(bar=>Array.from({length:bar.length},(_,i)=>{const angle=bar.offset+this.frames*.025*bar.direction,r=(i+1)*8;return {x:bar.x+Math.cos(angle)*r-4,y:bar.y+Math.sin(angle)*r-4,w:8,h:8};}));
  }
  projectileStep(){
    if(this.phase!=='playing')return;
    this.enemies=this.enemies.filter(e=>e.kind!=='bullet'||(!e.dead&&e.x>=this.camera-32&&e.x<=this.camera+280));
    for(const c of this.cannons){
      if(c.x<this.camera||c.x>this.camera+256||Math.abs(c.x-this.p.x)<32)continue;
      c.timer++;
      if(c.timer%150===1&&this.enemies.filter(e=>e.kind==='bullet'&&!e.dead).length<4){const direction=this.p.x<c.x?-1:1;this.enemies.push({x:c.x+(direction<0?-16:16),y:c.y+8,w:16,h:14,vx:direction*2.2,vy:0,kind:'bullet',dead:0});this.sound('fire');}
    }
    for(const h of this.hammers){h.x+=h.vx;h.y+=h.vy;h.vy+=.18;h.spin++;if(overlap(this.p,h))this.hurt();}
    this.hammers=this.hammers.filter(h=>h.y<260&&h.x>this.camera-48&&h.x<this.camera+304);
  }
  bossStep(){
    const b=this.boss;if(!b||this.phase!=='playing')return;
    if(!b.dead&&b.x<this.camera+288){
      b.active++;if(b.active%140===0&&b.grounded)b.vy=-4.2;
      b.vy=Math.min(6,b.vy+.22);const speed=b.vx;this.move(b);if(!b.vx)b.vx=-speed;
      if(b.x<184*16)b.vx=.45;if(b.x>193*16)b.vx=-.45;
      if(b.active%100===1){this.bossFlames.push({x:b.x-12,y:b.y+8,w:14,h:8,vx:-1.8,vy:0});this.sound('fire');}
      if(overlap(this.p,b))this.hurt();
      for(const shot of this.shots)if(!shot.dead&&overlap(shot,b)){shot.dead=true;b.hp--;this.sound('impact');if(b.hp<=0){b.dead=true;this.score+=1000;this.sound('kick');break;}}
    }
    if(b.dead&&b.y<260)b.y+=3;
    for(const f of this.bossFlames){f.x+=f.vx;if(overlap(this.p,f))this.hurt();}
    this.bossFlames=this.bossFlames.filter(f=>f.x>this.camera-24);
  }
  hurt(){if(this.invincible||this.star)return;if(this.power){this.sound('hurt');this.power=0;this.p.y+=this.p.h-16;this.p.h=16;this.invincible=120;}else this.die();}
  enterRoom(){const p=this.p;if(this.stage===1&&this.room==='overworld'&&p.grounded&&p.x>57*16-2&&p.x<58*16+2&&p.y+p.h===144){this.saved={cells:this.cells,contents:this.contents,enemies:this.enemies};this.cells=new Map();this.contents=new Map();this.enemies=[];this.sound('pipe');this.room='underground';this.camera=0;p.x=32;p.y=32;
      for(let x=0;x<16;x++){this.cells.set(`${x},13`,'brick');this.cells.set(`${x},14`,'brick');if(x<13)this.cells.set(`${x},1`,'brick');}
      for(let x=4;x<11;x++)for(let y=7;y<10;y++)if(!(y===7&&(x===4||x===10)))this.contents.set(`${x},${y}`,'loose');
      for(let y=10;y<13;y++)for(let x=13;x<16;x++)this.cells.set(`${x},${y}`,'pipe');this.items=[];
    }}
  exitRoom(){this.sound('pipe');Object.assign(this,this.saved);this.saved=null;this.room='overworld';this.p.x=164*16;this.p.y=176-this.p.h;this.p.vx=0;this.p.vy=0;this.camera=this.p.x-96;this.items=[];}
  step(){if(this.phase!=='playing')return;const p=this.p,k=this.input;this.frames++;this.time=Math.max(0,400-Math.floor(this.frames/24));if(!this.time){this.die();return;}
    if(this.time<=100&&!this.hurry){this.hurry=true;this.sound('hurry');}
    this.invincible=Math.max(0,this.invincible-1);this.star=Math.max(0,this.star-1);
    const standing=this.power?28:16;
    if(k.down&&p.grounded&&this.stage!==6)this.resizePlayer(this.power?16:12);
    else this.resizePlayer(standing);
    p.crouching=p.h<standing;
    const intended=(k.right?1:0)-(k.left?1:0);
    if(intended)p.facing=intended;
    const skidding=p.grounded&&!p.crouching&&intended&&Math.abs(p.vx)>.4&&Math.sign(p.vx)!==intended;
    if(skidding&&!this.wasSkidding)this.sound('skid');this.wasSkidding=!!skidding;
    const dir=p.crouching?0:intended,max=this.stage===6?1.4:k.run?2.6:1.55;
    p.vx=dir?Math.max(-max,Math.min(max,p.vx+dir*.13)):Math.abs(p.vx)<.08?0:p.vx-Math.sign(p.vx)*.08;
    if(this.stage===6){
      if(k.jump&&!this.wasJump){this.sound('swim');p.vy=-2.4;}
      p.vy=Math.min(1.5,p.vy+.075);
    }else{
      if(k.jump&&!this.wasJump&&p.grounded&&!p.crouching){this.sound('jump');p.vy=Math.abs(p.vx)>1.6?-5.7:-5.2;p.grounded=false;}
      if(!k.jump&&p.vy<-2.5)p.vy=-2.5;
      p.vy=Math.min(6,p.vy+(k.jump&&p.vy<0?.18:.38));
    }
    this.wasJump=!!k.jump;const beforeY=p.y;this.move(p,true);
    if(this.stage===6&&p.y<40){p.y=40;p.vy=Math.max(0,p.vy);}
    p.x=Math.max(this.camera,p.x);p.stride=(p.stride??0)+(p.grounded?Math.abs(p.vx):0);if(p.y>250)this.die();
    if(k.down)this.enterRoom();
    if(this.power===2&&k.run&&!this.wasFire&&this.shots.length<2){this.sound('fire');const facing=p.facing??1;this.shots.push({x:facing<0?p.x-4:p.x+p.w,y:p.y+10,w:4,h:4,vx:facing*3.5,vy:1});}this.wasFire=!!k.run;
    if(this.room==='underground'||this.stage>=2){
      for(const [key,item]of this.contents)if(item==='loose'){const[x,y]=key.split(',').map(Number);if(overlap(p,{x:x*16,y:y*16,w:12,h:16})){this.contents.delete(key);this.collectCoin();}}
      if(this.room==='underground'&&p.x>=12*16&&p.y+p.h<=160&&k.right)this.exitRoom();
      if(this.stage!==1)this.camera=Math.max(this.camera,Math.min(this.width-256,p.x-96));
    }else this.camera=Math.max(this.camera,Math.min(this.width-256,p.x-96));
    if((this.stage===4||this.stage===8)&&this.phase==='playing'){
      if(p.y+p.h>=220&&this.lava.some(([a,b])=>p.x+p.w>a*16&&p.x<(b+1)*16))this.die();
      if(this.fireHazards().some(f=>overlap(p,f)))this.hurt();
    }
    this.projectileStep();this.bossStep();
    for(const e of this.enemies){if(e.dead||e.x>this.camera+280||e.x<this.camera-32)continue;
      if(e.kind==='hammer-bro'){e.age++;if(e.x<e.anchor-18)e.vx=.35;if(e.x>e.anchor+18)e.vx=-.35;if(e.age%160===0&&e.grounded)e.vy=-5;if(e.age%75===1&&this.hammers.length<12){this.hammers.push({x:e.x,y:e.y-4,w:8,h:8,vx:(p.x<e.x?-1:1)*1.3,vy:-4.2,spin:0});this.sound('fire');}}
      if(e.kind==='bullet')e.x+=e.vx;
      else if(e.kind==='leaping-fish'){if(!e.launched){if(e.x>p.x+176)continue;e.launched=true;}e.x+=e.vx;e.vy+=.16;e.y+=e.vy;}
      else {const speed=e.vx;if(this.stage===6){e.vy=Math.sin((this.frames+e.offset)/35)*.6;this.move(e);e.y=Math.max(44,Math.min(194,e.y));if(e.vx===0)e.vx=-speed;}else{e.vy=Math.min(6,e.vy+.38);this.move(e);if(e.vx===0)e.vx=-speed;}}
      if(e.y>270||(e.kind!=='leaping-fish'&&e.y>250)){e.dead=1;continue;}if(overlap(p,e)&&this.phase==='playing'){
        if(this.star){this.defeat(e);}
        else if(this.stage!==6&&p.vy>=0&&beforeY+p.h<=e.y+6){this.sound('stomp');p.y=e.y-p.h;p.vy=k.jump?-5.2:-3.5;p.grounded=false;this.score+=100;this.popup(100,e.x,e.y);if(e.kind==='koopa'){e.kind='shell';e.vx=0;}else if(e.kind==='shell'){e.vx=e.vx?0:(p.x<e.x?4:-4);}else{e.dead=1;this.effects.push({x:e.x,y:e.y+12,kind:'squash',life:20});}}
        else if(e.kind==='shell'&&!e.vx){this.sound('kick');e.vx=p.x<e.x?4:-4;e.x+=Math.sign(e.vx)*10;}else this.hurt();
      }
      if(e.kind==='shell'&&e.vx)for(const other of this.enemies)if(other!==e&&!other.dead&&overlap(e,other)){this.defeat(other);}
    }
    for(const item of this.items){if(item.taken)continue;if(item.emerging>0){item.y--;item.emerging--;continue;}const speed=item.vx;if(item.kind!=='flower'){item.vy=Math.min(6,item.vy+.3);this.move(item);if(!item.vx)item.vx=-speed;if(item.kind==='star'&&item.grounded)item.vy=-4;}
      if(overlap(p,item)){this.sound(item.kind==='life'?'life':'item');item.taken=true;this.score+=1000;this.popup(item.kind==='life'?'1UP':1000,item.x,item.y);if(item.kind==='star')this.star=600;else if(item.kind==='life')this.lives++;else{this.power=item.kind==='flower'?2:1;if(p.h===16){p.y-=12;p.h=28;}}}}
    for(const shot of this.shots){shot.vy+=.35;this.move(shot);if(shot.grounded)shot.vy=-2.8;if(!shot.vx){shot.dead=true;this.sound('impact');this.effects.push({kind:'burst',x:shot.x,y:shot.y,life:10});}if(shot.x<this.camera||shot.x>this.camera+256)shot.dead=true;if(!shot.dead)for(const e of this.enemies)if(!e.dead&&e.kind!=='bullet'&&overlap(shot,e)){this.defeat(e);shot.dead=true;this.effects.push({kind:'burst',x:shot.x,y:shot.y,life:10});break;}}
    this.shots=this.shots.filter(s=>!s.dead);
    for(const fx of this.effects){fx.life--;if(fx.kind==='coin')fx.y-=1;if(fx.kind==='score')fx.y-=.35;if(fx.kind==='debris'){fx.x+=fx.vx;fx.y+=fx.vy;fx.vy+=.25;}}this.effects=this.effects.filter(f=>f.life>0);
    if(((this.stage===4||this.stage===8)?overlap(p,{x:196*16,y:160,w:16,h:32}):this.stage===6?p.x>=196*16&&p.y+p.h>=176:this.stage===2?p.x>=196*16:this.room==='overworld'&&p.x>=198*16)&&this.phase==='playing'){this.sound((this.stage===4||this.stage===8)?'bridge':(this.stage===2||this.stage===6)?'pipe':'flag');this.phase='won';this.bossFlames=[];this.hammers=[];this.presentation=0;this.flagStartY=p.y;this.score+=Math.max(100,5000-Math.floor(p.y)*20);this.input={};}
  }
  telemetry(previous=0){const p=this.p,tiles=[];for(let row=0;row<13;row++)for(let col=-2;col<=6;col++)tiles.push(this.solid(Math.floor(p.x/16)+col,row+2)?84:0);
    return{player:{x:p.x,y:p.y+p.h-16,vx:p.vx,vy:p.vy,grounded:p.grounded},tiles,enemies:[...(this.boss&&!this.boss.dead?[this.boss]:[]),...this.bossFlames,...this.hammers,...this.enemies].filter(e=>!e.dead&&Math.abs(e.x-p.x)<256).slice(0,5).map(e=>({dx:e.x-p.x,y:e.y,type:e.kind==='goomba'?6:0})),world:courseInfo(this.stage).world,stage:courseInfo(this.stage).stage,previous_response_ms:Math.min(10000,previous)};}
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
  if(g.phase==='won'&&(g.stage===2||g.stage===4||g.stage===8||g.stage===6))return `walk${Math.floor((g.p.stride??0)/5)%3}`;
  if(g.phase==='won')return g.presentation<60?'climb':`walk${Math.floor((g.p.stride??0)/5)%3}`;
  if(g.stage===6)return g.frames%24<12?'jump':'fall';
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
function drawCoin(ctx,x,y,frame){
  const width=[8,5,2,5][Math.floor(frame/5)%4],left=Math.round(x+(8-width)/2);
  ctx.fillStyle='#a85800';ctx.fillRect(left,y+1,width,10);
  ctx.fillStyle='#ffd040';ctx.fillRect(left,y+2,width,8);
  if(width>2){ctx.fillStyle='#fff0a0';ctx.fillRect(left+1,y+3,1,5);ctx.fillStyle='#b87800';ctx.fillRect(left+width-2,y+3,1,5);}
}
export function drawWorld(ctx,g){const cam=Math.floor(g.camera),water=g.stage===6,underground=g.room==='underground'||g.stage===2||g.stage===4||g.stage===8;ctx.imageSmoothingEnabled=false;ctx.fillStyle=water?'#2048a0':underground?'#101020':g.stage>=9?'#081028':'#6888fc';ctx.fillRect(0,0,256,240);
  if(!underground&&!water){
    for(let start=0;start<g.width;start+=768){
      for(const [x,y,count]of[[128,32,1],[304,24,3],[528,40,1]])pixelCloud(ctx,x+start-cam,y,count);
      for(const [x,h]of(g.stage===7?[]:[[0,32],[256,16],[576,32]]))pixelHill(ctx,x+start-cam,208,h);
      for(const [x,count]of(g.stage===7?[]:[[184,1],[368,3],[664,2]]))pixelCloud(ctx,x+start-cam,194,count,true);
    }
    const flag=198*16-cam;ctx.fillStyle='#80d010';ctx.fillRect(flag+7,32,2,160);ctx.fillRect(flag+5,28,6,6);ctx.fillStyle='#fff';ctx.beginPath();const flagY=g.phase==='won'?36+Math.min(144,g.presentation*2.7):36;ctx.moveTo(flag+7,flagY);ctx.lineTo(flag-9,flagY);ctx.lineTo(flag+7,flagY+12);ctx.fill();
    const castle=202*16-cam;for(let row=11;row<13;row++)for(let col=0;col<5;col++)pixelTile(ctx,'brick',castle+col*16,row*16);for(let row=9;row<11;row++)for(let col=1;col<4;col++)pixelTile(ctx,'brick',castle+col*16,row*16);ctx.fillStyle='#b85020';for(let i=0;i<5;i++)ctx.fillRect(castle+i*16,168,8,8);for(let i=0;i<3;i++)ctx.fillRect(castle+16+i*16,144,8,8);ctx.fillStyle='#101020';ctx.fillRect(castle+32,184,16,24);ctx.fillRect(castle+24,160,8,10);ctx.fillRect(castle+48,160,8,10);
  }
  if(g.stage===7){
    ctx.fillStyle='#1858a0';ctx.fillRect(0,224,256,16);ctx.fillStyle='#8ce0f8';for(let x=0;x<256;x+=16)ctx.fillRect(x,224+Math.floor((g.frames/12+x/16)%2)*2,10,2);
  }
  if(water){
    ctx.fillStyle='#78d8f8';ctx.fillRect(0,36,256,2);
    for(let x=0;x<256;x+=24){const y=44+((x*11-g.frames)%152+152)%152;ctx.fillStyle='#a8e8ff';ctx.fillRect(x,y,2,3);}
    for(let x=8;x<g.width;x+=112){const left=x-cam;if(left<-20||left>256)continue;ctx.fillStyle='#38a858';for(let y=180;y<208;y+=4)ctx.fillRect(left+Math.round(Math.sin((g.frames+y)/14)*3),y,4,4);ctx.fillStyle='#f87880';ctx.fillRect(left+20,190,4,18);ctx.fillRect(left+14,194,16,4);}
  }
  for(const[key,t]of g.cells){if(t==='hidden')continue;const[col,row]=key.split(',').map(Number),x=col*16-cam,baseY=row*16,bump=g.effects.find(f=>f.kind==='bump'&&f.x===col*16&&f.y===baseY),y=baseY-(bump?Math.sin((12-bump.life)/12*Math.PI)*4:0);if(x<(t.startsWith('pipe')?-64:-16)||x>256)continue;
    if(t==='cannon'){ctx.fillStyle='#080810';ctx.fillRect(x,y,16,16);ctx.fillStyle='#d0d0d8';ctx.fillRect(x,y,16,2);ctx.fillRect(x,y+12,16,2);ctx.fillStyle='#707078';ctx.fillRect(x+3,y+2,3,10);continue;}
    if(t==='castle'){ctx.fillStyle='#303038';ctx.fillRect(x,y,16,16);ctx.fillStyle='#909098';ctx.fillRect(x,y,16,1);ctx.fillRect(x,y+8,16,1);ctx.fillRect(x+8,y,1,8);ctx.fillRect(x,y+8,1,8);continue;}
    if(t==='bridge'){if(g.stage===7){ctx.fillStyle='#b89060';ctx.fillRect(x,y-12,16,2);ctx.fillRect(x+1,y-12,2,12);ctx.fillStyle='#583818';ctx.fillRect(x+6,y+8,4,240-y);}ctx.fillStyle='#904018';ctx.fillRect(x,y,16,8);ctx.fillStyle='#f8b850';ctx.fillRect(x,y,16,2);ctx.fillRect(x+3,y+2,2,6);continue;}
    if(t==='platform'){ctx.fillStyle='#755035';ctx.fillRect(x+6,y+8,4,240-y);ctx.fillStyle='#e07038';ctx.fillRect(x,y,16,8);ctx.fillStyle='#ffe4a8';ctx.fillRect(x+1,y+1,14,3);continue;}
    if(t.startsWith('pipe')){if(g.tile(col-1,row)?.startsWith('pipe'))continue;let width=1;while(g.tile(col+width,row)?.startsWith('pipe'))width++;pixelPipe(ctx,x,y,width*16,t==='pipe-top');continue;}
    pixelTile(ctx,t,x,y,underground,g.frames);
  }
  if(g.stage===4||g.stage===8){
    for(const[a,b]of g.lava){const left=Math.max(0,a*16-cam),right=Math.min(256,(b+1)*16-cam);if(right<=left)continue;ctx.fillStyle='#b82000';ctx.fillRect(left,220,right-left,20);ctx.fillStyle='#ff7800';ctx.fillRect(left,220,right-left,4);ctx.fillStyle='#ffd040';for(let x=left;x<right;x+=8)ctx.fillRect(x,220+(Math.floor(g.frames/8+x/8)%2)*2,4,2);}
    for(const bar of g.fireBars){ctx.fillStyle='#909098';ctx.fillRect(bar.x-4-cam,bar.y-4,8,8);}
    for(const h of g.fireHazards()){if(h.x<cam-8||h.x>cam+256)continue;ctx.fillStyle='#f83800';ctx.fillRect(Math.round(h.x)-cam,Math.round(h.y),8,8);ctx.fillStyle='#ffb030';ctx.fillRect(Math.round(h.x)+1-cam,Math.round(h.y)+1,6,6);ctx.fillStyle='#fff0b0';ctx.fillRect(Math.round(h.x)+3-cam,Math.round(h.y)+2,2,3);}
    if(g.phase!=='won'){const x=196*16-cam;ctx.fillStyle='#b85020';ctx.fillRect(x+7,166,3,26);ctx.fillStyle='#fcfcfc';ctx.fillRect(x,160,10,7);ctx.fillRect(x-2,162,4,9);}
    const door=202*16-cam;ctx.fillStyle='#000';ctx.fillRect(door,176,24,32);ctx.fillStyle='#b8b8c0';ctx.fillRect(door-2,174,28,2);
  }
  if(g.stage===8){
    const b=g.boss;
    if(b&&b.y<250){const rows=['....WW....WW....','...GGGGGGGGGG...','..GGGGGGGGGGGG..','.GGSSSSGGGGGGGG.','GGSSBSSSGGGGGGGG','GGSSSSSSSGGGWGGG','SSSSSSSSSGGWWWGG','.SSSSSSSSGGGWGGG','..RRRSSSSGGWGGGG','...SSSSSSGGGGGG.','..SSSSSSSSGGGG..','.SSSSSSSSSSGGG..','SSSSSSSSSSSSGGG.','.SSSSSSSSSSSGG..',g.frames%24<12?'..HHHH...HHHH...':'...HHHH.HHHH....',g.frames%24<12?'..HHHH...HHHH...':'.HHHH.....HHHH..'];sprite(ctx,rows,b.x-cam,b.y,{W:'#fff0b0',G:'#60a820',S:'#ffc070',B:'#101020',R:'#e84020',H:'#b86820'},1.75,2);}
    for(const f of g.bossFlames){ctx.fillStyle='#ff4800';ctx.fillRect(f.x-cam,f.y,14,8);ctx.fillStyle='#ffe080';ctx.fillRect(f.x-cam+2,f.y+2,10,4);}
    const rows=['....RRRRRR....','..RRWWRRWWRR..','.RRWWWRRWWWRR.','RRRWWWRRWWWRRR','RRRRRRRRRRRRRR','.WWWWWWWWWWWW.','...SSBSSBSS...','...SSSSSSSS...','....SSSSSS....','...BSSSSSSB...','..SBBSSSSBBS..','..SSBBBBBBSS..','....SSSSSS....','...HHH..HHH...'];sprite(ctx,rows,204*16-cam,194,{R:'#f83800',W:'#fff',S:'#ffbc80',B:'#2858b0',H:'#804020'},1,1);
    if(g.rescued){ctx.fillStyle='#101020';ctx.fillRect(8,72,240,52);pixelText(ctx,'THANK YOU MARIO!',68,82);pixelText(ctx,'TOAD IS SAFE',80,102);}
  }
  if(g.stage>=9&&g.phase==='won'&&g.presentation>=100){
    // Bonus ending requested by the user, not an original stage ending.
    const rows=['.....Y.Y.Y.....','.....YYYYY.....','....HHHHHHH....','....HSSBSSH....','....HSSSSSH....','....HHSSSHH....','.....PPPPP.....','....PPPSPPP....','...SPPPPPPS...','..SSPPPPPPSS..','....PPPPPPP....','...PPPPPPPPP...','..PPPPPPPPPPP..','.PPPPPPPPPPPPP.','....HH...HH....'];
    sprite(ctx,rows,205*16-cam,178,{Y:'#ffd040',H:'#e8a030',S:'#ffcfaa',B:'#2048a0',P:'#f878b8'},1,2);
    if(g.peachRescued){ctx.fillStyle='#101020ee';ctx.fillRect(12,72,232,64);pixelText(ctx,'THANK YOU MARIO!',68,82);pixelText(ctx,'PEACH IS SAFE',76,102);pixelText(ctx,'BONUS ENDING',80,122);}
  }
  for(const[key,item]of g.contents)if(item==='loose'){const[x,y]=key.split(',').map(Number);drawCoin(ctx,x*16+4-cam,y*16+2,g.frames);}
  for(const e of g.enemies){if(e.dead||e.x<cam-16||e.x>cam+256)continue;
    const walking=g.frames%16<8;
    if(e.kind==='bullet'){const rows=['...BBBBBBBBBBBB.','.BBBBBBBBBBBBBBB','BBBBBBBBBBBBBBBB','BBSSBBBBBBBBBBBB','BBSBBSBBBBBBBBBB','BBBBBBBBBBBBBBBB','BBBBBBBBSSSBBBBB','BBBBBBBSSSSSBBBB','BBBBBBBBSSSBBBBB','.BBBBBBBBBBBBBBB','...BBBBBBBBBBBB.'];const outlined=rows.map((r,j)=>[...r].map((c,i)=>c==='B'&&(!rows[j-1]?.[i]||rows[j-1][i]==='.'||!rows[j+1]?.[i]||rows[j+1][i]==='.'||i===0||i===r.length-1||r[i-1]==='.'||r[i+1]==='.')?'G':c).join(''));sprite(ctx,e.vx<0?outlined:outlined.map(r=>[...r].reverse().join('')),e.x-cam,e.y+1,{B:'#101018',G:'#888898',S:'#f0f0f0'});continue;}
    if(e.kind==='hammer-bro'){const rows=['....GGGGGG....','...GWWWWWWG...','..GWWWWWWWWG..','..WWSSBSSWW...','...SSSSSSS....','....SSSSS.....','...GGGGSSS....','..GWWWWGSSS...','.GWWGGWWGSS...','.GWWWWWWG.....','..GGGGGGG.....','...SSSSSS.....',walking?'..SS...SSS....':'...SSS..SS....'];sprite(ctx,rows,e.x-cam,e.y,{G:'#208838',W:'#f8f8d8',S:'#ffd090',B:'#101018'},1,1.8);continue;}
    const rows=(e.kind==='fish'||e.kind==='leaping-fish')?['.....RRRR.....','...RRRRRRRR...','..RRRRRRRRSS..','.RRRRRRRBSSSS.','RRRRRRRRBSSSS.','RRRRRRRRRSSSS.','.RRRRRSSSSSSS.','..RRRSSSSSSS..','..RRRSSSSSS...',walking?'SSRRRRSSSS....':'.SSRRRSSSS....',walking?'SSSRRRRR......':'..SSRRRR......','...RRRRR......','....SSS.......','.....SS.......']:e.kind==='squid'?['....SSSS....','...SSSSSS...','..SSSSSSSS..','.SSSBSSBSSS.','..SSSSSSSS..','...SSSSSS...',walking?'..SS.SS.SS..':'...SS..SS...']:e.kind==='shell'?['....GGGG....','..GGLLLLGG..','.GLLLLLLLLG.','GGLLGGGGLLGG','GLLGGLLGGLLG','GGGGGGGGGGGG','.SSSSSSSSSS.']:
      e.kind==='koopa'?['.......SSS..','......SSBSS.','......SSSSS.','...GGGGSS...','..GLLLLGSS..','.GLLGGLLG...','.GLLLLLLG...','..GGGGGG....','...SSSSS....',walking?'..SS...SSS..':'...SSS..SS..']:
      ['.....HHHHHH.....','....HHHHHHHH....','...HHHHHHHHHH...','..HHHHHHHHHHHH..','.HHHBBHHHHBBHHH.','HHHSSBBHHBBSSHHH','HHHSSSBHHBSSSHHH','.HHSSSSSSSSSSHH.','..HHHHHHHHHHHH..','....SSSSSSSS....','....SSSSSSSS....','...SSSSSSSSSS...',walking?'..BBBBBSSBBBB...':'...BBBBSSBBBBB..',walking?'.BBBBBB..BBBBB..':'..BBBBB..BBBBBB.',walking?'.BBBB....BBBB...':'...BBBB....BBBB.','................'];
    sprite(ctx,rows,e.x-cam,e.y+e.h-rows.length,{R:'#f83800',H:'#a84800',S:'#ffe0b0',B:'#101020',G:'#005800',L:'#80d010'});
  }
  for(const h of g.hammers){ctx.save();ctx.translate(Math.round(h.x-cam+4),Math.round(h.y+4));ctx.rotate(h.spin*.3);ctx.fillStyle='#c87828';ctx.fillRect(-1,-1,2,7);ctx.fillStyle='#d8d8e0';ctx.fillRect(-4,-4,8,4);ctx.restore();}
  for(const i of g.items)if(!i.taken){
    ctx.save();if(i.emerging>0){ctx.beginPath();ctx.rect(0,0,256,i.y+16-i.emerging);ctx.clip();}
    const rows=i.kind==='star'?['......Y.....','.....YYY....','.YYYYYYYYYYY','..YYYBYBYYY.','...YYYYYYY..','..YYYYYYYYY.','..YYY...YYY.','.YY.......YY']:
      i.kind==='flower'?['....RRRR....','..RRSSSSRR..','.RSSBSSBS SR.'.replace(' ',''),'..RRSSSSRR..','....RRRR....','.....GG.....','..G..GG..G..','...GGGGGG...','.....GG.....']:
      ['....RRRR....','..RRSSRRRR..','.RRSSSSRRRR.','RRRRSSRRSSRR','RRRRRRRRSSRR','.RRRRRRRRRR.','...SSB SBS...'.replace(' ',''),'...SSSSSS...','....SSSS....'];
    sprite(ctx,rows,i.x-cam,i.y+16-rows.length,{R:i.kind==='life'?'#00a800':i.kind==='flower'?['#f83800','#ffb030','#fff0a0','#ffb030'][Math.floor(g.frames/6)%4]:'#f83800',S:'#ffe0b0',B:'#101020',G:'#00a800',Y:g.frames%12<6?'#ffd040':'#fff'});ctx.restore();
  }
  for(const f of [...g.effects,...g.shots]){if(f.kind==='bump')continue;if(f.kind==='coin'){drawCoin(ctx,f.x-cam,f.y,g.frames);continue;}if(f.kind==='score'){pixelText(ctx,f.value,f.x-cam,f.y-7);continue;}if(f.kind==='burst'){ctx.fillStyle=f.life%2?'#fff':'#ffb030';ctx.fillRect(f.x-cam-2,f.y+2,8,2);ctx.fillRect(f.x-cam+1,f.y-1,2,8);continue;}ctx.fillStyle=f.kind==='debris'||f.kind==='squash'?'#b85020':'#ffd040';ctx.fillRect(f.x-cam,f.y,f.kind==='squash'?14:5,f.kind==='squash'?4:7);}
  if(!g.invincible||g.frames%6<3){const palette={R:g.power===2?'#fff':'#f83800',H:'#803000',S:'#ffbc80',B:g.star&&g.frames%12<6?'#00d8f8':'#b85000',Y:'#ffc000'};drawPlayer(ctx,g,palette);}
  pixelText(ctx,'MARIO',24,16);pixelText(ctx,String(g.score).padStart(6,'0'),24,24);
  drawCoin(ctx,88,20,g.frames);pixelText(ctx,'X'+String(g.coins).padStart(2,'0'),96,24);
  pixelText(ctx,'WORLD',144,16);pixelText(ctx,courseInfo(g.stage??1).label,152,24);
  pixelText(ctx,'TIME',208,16);pixelText(ctx,String(g.time).padStart(3,'0'),216,24);
  if(g.phase!=='playing'&&g.presentation>=180&&!g.rescued&&!g.peachRescued){ctx.fillStyle='#101020dd';ctx.fillRect(20,86,216,52);const title=g.phase==='won'?`WORLD ${courseInfo(g.stage??1).label} CLEAR!`:'TRY AGAIN';pixelText(ctx,title,(256-title.length*8)/2,102);pixelText(ctx,'RESTART TO PLAY AGAIN',48,121);}

}
