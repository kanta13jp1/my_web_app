import {pixelText,pixelCloud,pixelHill,pixelTile,pixelPipe} from './pixel-art.mjs?v=student-1';
// Independently authored 1-1 reconstruction. No ROM, sprite sheet or game code is loaded.
export const TILE = 16;
// Internal course IDs retain compatibility with saved simulations (1..28).
export const LAST_COURSE=32;
export const isUnderground=stage=>[2,14].includes(stage);
export const isCastle=stage=>[4,8,12,16,20,24,28,32].includes(stage);
export const isWater=stage=>[6,26].includes(stage);
export const isBridge=stage=>[7,27].includes(stage);
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
export function castleLevel(second=false,third=false){
 const cells=new Map(),contents=new Map(),set=(x,y,t='castle')=>cells.set(`${x},${y}`,t);
 const lava=third?[[28,31],[58,62],[92,96],[125,129],[157,161],[180,195]]:second?[[32,35],[64,68],[100,104],[137,141],[164,167],[180,195]]:[[30,33],[59,62],[92,95],[126,129],[158,161],[180,195]];
 for(let x=0;x<212;x++){
  for(let y=2;y<4;y++)set(x,y);
  if(!lava.some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y);
 }
 for(const x of (third?[19,43,76,108,141,170]:second?[22,48,80,116,150,174]:[20,45,73,106,140,168])){set(x,11);set(x+1,11);}
 for(let x=180;x<=195;x++)set(x,12,'bridge');
 cells.set('12,9','question');contents.set('12,9','mushroom');
 for(const x of [36,66,99,133,164])contents.set(`${x},11`,'loose');
 const fireBars=(third?[22,48,82,113,146,173]:second?[26,54,86,120,154,174]:[24,50,80,115,148,172]).map((x,i)=>({x:x*16+8,y:168,length:third?(i%2?5:4):4,offset:i*Math.PI/3,direction:i%2?-1:1}));
 const lavaBubbles=lava.slice(0,-1).map(([a,b],i)=>({x:(a+b+1)*8-6,y:232,w:12,h:16,vy:0,timer:30+i*19,active:false}));
 return {cells,contents,width:212*16,lava,fireBars,lavaBubbles};
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
// Independently authored night treetops with requested Lakitu encounters.
export function world33Level(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='platform')=>cells.set(`${x},${y}`,t);
 for(let x=0;x<212;x++)if(x<20||x>=185)for(let y=13;y<15;y++)set(x,y,'ground');
 for(const [a,b,y]of [[20,28,12],[32,41,10],[45,55,11],[59,68,9],[72,81,10],[85,94,8],[98,108,10],[112,121,9],[125,135,11],[139,148,10],[152,161,8],[165,174,10],[178,184,12]]){
  for(let x=a;x<=b;x++)set(x,y);for(let x=a+2;x<b;x+=2)contents.set(`${x},${y-2}`,'loose');
 }
 set(12,9,'question');contents.set('12,9','mushroom');set(198,12,'stone');
 return {cells,contents,width:212*16};
}
// Independent daytime course with open ground for Lakitu and Spiny encounters.
export function world41Level(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='brick',item)=>{cells.set(`${x},${y}`,t);if(item)contents.set(`${x},${y}`,item);};
 for(let x=0;x<212;x++)if(![[63,64],[118,120]].some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y,'ground');
 for(const [x,h]of [[28,2],[47,3],[83,2],[109,3],[144,2],[171,2]])for(let c=0;c<2;c++)for(let y=13-h;y<13;y++)set(x+c,y,y===13-h?'pipe-top':'pipe');
 for(const start of [12,37,70,96,128,154]){for(let x=start;x<start+4;x++)set(x,9,x===start+1?'question':'brick',x===start+1?(start===12||start===96?'mushroom':'coin'):null);for(let x=start;x<start+4;x++)contents.set(`${x},6`,'loose');}
 set(134,5,'question','star');set(55,8,'hidden','life');
 for(let k=0;k<8;k++)for(let y=12-k;y<13;y++)set(181+k,y,'stone');for(let y=5;y<13;y++)set(189,y,'stone');set(198,12,'stone');
 return {cells,contents,width:212*16};
}
// Independent fourth-world underground expansion with vertical one-way lifts.
export function world42Level(){
 const cells=new Map(),contents=new Map(),set=(x,y,t='brick',item)=>{cells.set(`${x},${y}`,t);if(item)contents.set(`${x},${y}`,item);};
 const gaps=[[54,61],[100,107],[146,153]];
 for(let x=0;x<212;x++){if(!gaps.some(([a,b])=>x>=a&&x<=b))for(let y=13;y<15;y++)set(x,y,'ground');if(x<185)for(let y=2;y<4;y++)set(x,y);}
 for(const [x,h]of [[24,2],[76,3],[128,2],[174,3]])for(let c=0;c<2;c++)for(let y=13-h;y<13;y++)set(x+c,y,y===13-h?'pipe-top':'pipe');
 for(const start of [12,34,66,86,114,136,160]){for(let x=start;x<start+5;x++)set(x,9,x===start+2?'question':'brick',x===start+2?(start===12||start===114?'mushroom':'coin'):null);for(let x=start;x<start+4;x++)contents.set(`${x},6`,'loose');}
 const lifts=gaps.map(([a,b],i)=>({id:i,x:(a+2)*16,y:176-i*16,previousY:176-i*16,w:48,h:8,minY:96,maxY:192,speed:.65,direction:i%2?1:-1}));
 for(let k=0;k<4;k++)for(let y=12-k;y<13;y++)set(184+k,y,'stone');for(let x=198;x<200;x++)for(let y=10;y<13;y++)set(x,y,'pipe');
 return {cells,contents,lifts,width:212*16};
}
// Independent high platforms and a beanstalk bonus route.
export function world43Level(){
 const g=skyLevel();
 for(const [x,y,kind]of [[8,9,'mushroom'],[12,9,'vine'],[36,7,'life'],[84,5,'star'],[132,7,'mushroom']]){g.cells.set(`${x},${y}`,'question');g.contents.set(`${x},${y}`,kind);}
 for(let x=14;x<=22;x++){g.cells.set(`${x},5`,'platform');if(x>15)g.contents.set(`${x},3`,'loose');}
 g.lifts=[{id:0,x:30*16,y:184,previousY:184,w:32,h:8,minY:112,maxY:192,speed:.55,direction:-1},{id:1,x:102*16,y:152,previousY:152,w:32,h:8,minY:96,maxY:192,speed:.7,direction:1}];
 return g;
}
export function world44Level(){
 const g=castleLevel(false,true);
 // A distinct fourth castle, with raised ledges and moving lava crossings.
 for(const x of [40,72,106,138]){g.cells.set(`${x},8`,'castle');g.cells.set(`${x+1},8`,'castle');}
 g.fireBars=g.fireBars.map((b,i)=>({...b,y:i%2?136:176,offset:b.offset+.8}));
 g.lifts=g.lava.slice(1,4).map(([a,b],i)=>({id:i,x:(a+1)*16,y:192,previousY:192,w:32,h:8,minY:144,maxY:192,speed:.5,direction:-1}));
 for(const [x,kind]of [[42,'star'],[110,'mushroom']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,kind);}
 return g;
}
// Independently arranged fifth world: ground encounters, terraces, treetops and castle.
export function world51Level(){
 const g=world32Level();
 for(const x of [40,86,132,173]){g.cells.delete(`${x},11`);g.cells.delete(`${x},12`);}
 g.cannons=[58,110,164].map(x=>{g.cells.set(`${x},11`,'cannon');g.cells.set(`${x},12`,'cannon');return {x:x*16,y:176,timer:0};});
 for(const [x,kind]of [[14,'mushroom'],[49,'star'],[94,'life'],[126,'mushroom']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,kind);}
 return g;
}
export function world52Level(){
 const g=nightLevel();
 for(const [x,kind]of [[14,'mushroom'],[35,'vine'],[84,'star'],[122,'life']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,kind);}
 for(let x=37;x<45;x++){g.cells.set(`${x},5`,'platform');g.contents.set(`${x},3`,'loose');}
 for(const a of [54,114,152])for(let x=a;x<a+4;x++)g.cells.set(`${x},10`,'platform');
 g.lifts=[{id:0,x:97*16,y:192,previousY:192,w:32,h:8,minY:128,maxY:192,speed:.55,direction:-1}];
 return g;
}
export function world53Level(){
 const g=world33Level();
 for(const [x,y,kind]of [[12,9,'mushroom'],[37,7,'life'],[89,5,'star'],[130,8,'mushroom']]){g.cells.set(`${x},${y}`,'question');g.contents.set(`${x},${y}`,kind);}
 g.lifts=[[42,144],[95,160],[162,152]].map(([x,y],id)=>({id,x:x*16,y,previousY:y,w:32,h:8,minY:112,maxY:192,speed:.6,direction:id%2?1:-1}));
 return g;
}
export function world54Level(){
 const g=castleLevel(true);
 g.fireBars=g.fireBars.map((b,i)=>({...b,length:i%2?5:4,y:i%2?144:176,offset:b.offset+1.2}));
 g.lifts=g.lava.slice(0,3).map(([a],id)=>({id,x:(a+1)*16,y:184,previousY:184,w:32,h:8,minY:144,maxY:192,speed:.5,direction:-1}));
 for(const [x,kind]of [[46,'mushroom'],[90,'star'],[128,'life']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,kind);}
 return g;
}
// Sixth world uses distinct night routes and a moving-platform castle.
export function world61Level(){
 const g=world51Level();g.cannons=[];
 for(const [k,v]of g.cells)if(v==='cannon')g.cells.delete(k);
 for(const [x,kind]of [[16,'mushroom'],[52,'star'],[98,'life'],[140,'mushroom']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,kind);}
 return g;
}
export function world62Level(){
 const g=world52Level();
 for(const [x,h]of [[62,3],[100,4],[138,2]])for(let y=13-h;y<13;y++)for(let d=0;d<2;d++)g.cells.set(`${x+d},${y}`,y===13-h?'pipe-top':'pipe');
 g.contents.set('35,9','vine');
 g.lifts.push({id:1,x:163*16,y:184,previousY:184,w:40,h:8,minY:120,maxY:192,speed:.5,direction:-1});
 return g;
}
export function world63Level(){
 const g=world53Level();
 g.lifts=g.lifts.map((l,i)=>({...l,w:40,speed:.45+i*.08,minY:104,maxY:192}));
 for(const a of [54,112,174])for(let x=a;x<a+4;x++)g.cells.set(`${x},8`,'platform');
 return g;
}
export function world64Level(){
 const g=world54Level();
 g.fireBars=g.fireBars.map((b,i)=>({...b,length:i%2?6:4,offset:b.offset+.7}));
 for(const x of [58,104,146])for(let d=0;d<3;d++)g.cells.set(`${x+d},8`,'castle');
 return g;
}
// Independently arranged seventh world: cannon ground, water, fish bridge and castle.
export function world71Level(){
 const g=world51Level();
 for(const [x,h]of [[60,3],[118,4],[166,3]]){for(let y=13-h;y<13;y++)g.cells.set(`${x},${y}`,'cannon');g.cannons.push({x:x*16,y:(13-h)*16,timer:0});}
 for(const [x,item]of [[14,'mushroom'],[42,'star'],[104,'life'],[151,'mushroom'],[134,'vine']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,item);}
 return g;
}
export function world72Level(){
 const g=waterLevel();
 for(const x of [42,78,116,156])for(let y=11;y<13;y++)g.cells.set(`${x},${y}`,'stone');
 for(const x of [24,70,128,174])g.contents.set(`${x},6`,'loose');
 return g;
}
export function world73Level(){
 const g=bridgeLevel();
 for(const [x,item]of [[64,'mushroom'],[99,'star'],[143,'life']]){g.cells.set(`${x},8`,'question');g.contents.set(`${x},8`,item);}
 g.lifts=[{id:0,x:119*16,y:184,previousY:184,w:48,h:8,minY:152,maxY:200,speed:.45,direction:-1}];
 return g;
}
export function world74Level(){
 const g=world64Level();
 for(const x of [48,96,140])for(let d=0;d<4;d++)g.cells.set(`${x+d},7`,'castle');
 g.fireBars=g.fireBars.map((b,i)=>({...b,offset:b.offset+.45,length:i%2?5:4}));
 return g;
}
// Final world: long ground jumps, Lakitu route, Hammer Bros approach, final castle.
export function world81Level(){
 const g=world51Level();g.cannons=[];
 for(const [k,v]of g.cells)if(v==='cannon')g.cells.delete(k);
 for(const a of [58,114,153])for(let x=a;x<a+3;x++)for(let y=13;y<15;y++)g.cells.delete(`${x},${y}`);
 for(const [x,item]of [[15,'mushroom'],[49,'star'],[98,'life'],[144,'vine']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,item);}
 return g;
}
export function world82Level(){
 const g=world71Level();
 for(const [x,h]of [[74,3],[145,4]])for(let d=0;d<2;d++)for(let y=13-h;y<13;y++)g.cells.set(`${x+d},${y}`,y===13-h?'pipe-top':'pipe');
 g.lifts=[{id:0,x:109*16,y:184,previousY:184,w:48,h:8,minY:128,maxY:192,speed:.5,direction:-1}];
 return g;
}
export function world83Level(){
 const g=world52Level();
 for(const a of [46,90,136])for(let x=a;x<a+5;x++){g.cells.set(`${x},9`,'brick');g.cells.set(`${x},5`,'brick');}
 for(const [x,item]of [[24,'mushroom'],[86,'star'],[132,'life']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,item);}
 return g;
}
export function world84Level(){
 const g=world74Level();
 g.fireBars=g.fireBars.map((b,i)=>({...b,length:i%2?5:6,offset:b.offset+1.1}));
 g.lifts=g.lifts.map(l=>({...l,w:48,speed:.4}));
 for(const [x,item]of [[18,'mushroom'],[83,'star'],[135,'life']]){g.cells.set(`${x},9`,'question');g.contents.set(`${x},9`,item);}
 return g;
}
export class World11 {
  constructor(stage=1){this.character='mario';this.stage=Number.isInteger(stage)&&stage>=1&&stage<=LAST_COURSE?stage:1;this.reset();}
  reset(){this.sounds=[];this.vines=[];this.pickups={mushroom:0,flower:0,life:0,star:0};this.lifts=[];this.lava=[];this.lavaBubbles=[];this.fireBars=[];this.cannons=[];this.hammers=[];this.fireworks=[];this.fireworksTotal=0;this.fireworksFired=0;Object.assign(this,this.stage===32?world84Level():this.stage===31?world83Level():this.stage===30?world82Level():this.stage===29?world81Level():this.stage===28?world74Level():this.stage===27?world73Level():this.stage===26?world72Level():this.stage===25?world71Level():this.stage===24?world64Level():this.stage===23?world63Level():this.stage===22?world62Level():this.stage===21?world61Level():this.stage===20?world54Level():this.stage===19?world53Level():this.stage===18?world52Level():this.stage===17?world51Level():this.stage===16?world44Level():this.stage===15?world43Level():this.stage===14?world42Level():this.stage===13?world41Level():this.stage===12?castleLevel(false,true):this.stage===11?world33Level():this.stage===10?world32Level():this.stage===9?nightLevel():this.stage===8?castleLevel(true):isBridge(this.stage)?bridgeLevel():isWater(this.stage)?waterLevel():this.stage===5?world21Level():this.stage===4?castleLevel():this.stage===3?skyLevel():this.stage===2?undergroundLevel():level());this.p={x:32,y:192,w:12,h:16,vx:0,vy:0,grounded:true};this.camera=0;this.time=400;this.frames=0;this.score=0;this.coins=0;this.lives=3;this.power=0;this.invincible=0;this.star=0;this.phase='playing';this.presentation=0;this.flagStartY=0;this.wasSkidding=false;this.hurry=false;this.room=isWater(this.stage)?'underwater':isCastle(this.stage)?'castle':isUnderground(this.stage)?'stage-underground':'overworld';this.input={};this.wasJump=false;this.wasFire=false;this.items=[];this.shots=[];this.effects=[];this.deaths=0;this.multi=0;this.saved=null;this.boss=isCastle(this.stage)?{x:189*16,y:160,w:28,h:32,vx:-.45,vy:0,grounded:true,hp:5,dead:false,active:0}:null;this.bossFlames=[];this.rescued=false;this.peachRescued=false;
    this.enemies=(this.stage===31?[20,34,58,72,102,120,158,172]:this.stage===30?[18,35,56,80,100,130,160,174]:this.stage===29?[18,22,36,65,80,97,120,139,165,178]:this.stage===25?[20,32,45,70,92,128,149,170]:this.stage===23?[24,36,49,63,76,89,102,116,130,144,156,169,181]:this.stage===22?[20,31,50,67,80,110,128,150,166]:this.stage===21?[18,32,47,70,92,120,149,170]:this.stage===19?[24,36,49,63,76,89,102,116,130,144,156,169,181]:this.stage===18?[20,31,50,67,80,110,128,150,166]:this.stage===17?[18,21,32,35,47,51,70,78,92,104,120,136,149,170]:this.stage===15?[37,61,85,109,133,157,180]:this.stage===14?[20,32,43,68,89,116,137,160,169]:this.stage===13?[]:this.stage===11?[36,51,64,77,90,103,117,130,144,158,170]:this.stage===10?[18,20,31,34,51,66,78,97,109,122,139,163,167]:this.stage===9?[19,31,43,57,66,79,91,106,116,140,153,168]:this.stage===5?[17,33,37,67,71,91,105,113,139,152,170]:isCastle(this.stage)?[]:this.stage===3?[37,61,85,109,133,157,180]:this.stage===2?[22,38,53,64,82,96,107,126,140,158,172]:[22,40,51,53,80,82,97,98,107,114,116,124,126,128,130,174,176]).map((x,i)=>({x:x*16,y:([3,11,15,19,23].includes(this.stage))?(Math.min(...[...this.cells.keys()].filter(k=>k.startsWith(x+',')).map(k=>Number(k.split(',')[1])))*16-16):this.stage!==2&&(x===80||x===82)?64:192,w:14,h:16,vx:-.5,vy:0,kind:(this.stage>=17?(i%3===1):this.stage===11?(i%2===0):this.stage===10?(i%2===0):this.stage===9?(i%3===1):this.stage===5?(i===3||i===7):i===8)?'koopa':'goomba',dead:0}));
    if([3,11,15,19,23,31].includes(this.stage))for(const e of this.enemies)if(e.kind==='koopa')e.red=true;
    if(isUnderground(this.stage)||[17,25,29,30].includes(this.stage))for(const i of [0,3,6])Object.assign(this.enemies[i],{kind:'beetle',armored:true});
    if([2,5,9,10,13,14,17,18,21,22,25,29,30,31].includes(this.stage))for(const [key,t]of this.cells){
      const [col,row]=key.split(',').map(Number);if(t!=='pipe-top'||this.tile(col-1,row)==='pipe-top')continue;
      this.enemies.push({x:col*16+8,y:row*16,w:16,h:0,vx:0,vy:0,kind:'piranha',dead:0,pipeY:row*16,age:0,hidden:true});
    }
    if([11,13,19,21,30].includes(this.stage))this.enemies.push({x:42*16,y:40,w:16,h:16,vx:0,vy:0,kind:'lakitu',dead:0,age:0,active:false});
    if([10,18,22,25,31].includes(this.stage))for(const x of (this.stage===18?[56,116,154]:[52,99,164]))this.enemies.push({x:x*16,y:184,w:14,h:24,vx:.35,vy:0,kind:'hammer-bro',dead:0,anchor:x*16,age:0});
    if([14,15,17,19,22,23,25,29,30].includes(this.stage))for(const x of ([19,23].includes(this.stage)?[38,90,132]:this.stage===17?[72,142]:this.stage===15?[38,86,134]:[40,122]))this.enemies.push({x:x*16,y:[15,19,23].includes(this.stage)?Math.min(...[...this.cells.keys()].filter(k=>k.startsWith(x+',')).map(k=>Number(k.split(',')[1])))*16-16:192,w:14,h:16,vx:-.6,vy:0,kind:'paratroopa',dead:0});
    if([15,19,23,30].includes(this.stage)){const e=this.enemies.find(e=>e.kind==='paratroopa');if(e){e.red=true;e.flightY=Number.isFinite(e.y)?Math.max(48,e.y-24):112;e.y=e.flightY;e.flightAge=0;e.vx=0;}}
    if(isWater(this.stage)){this.p.y=128;this.p.grounded=false;this.enemies=[32,54,70,94,120,145,168,184].map((x,i)=>({x:x*16,y:80+(i%3)*32,baseY:80+(i%3)*32,w:14,h:14,vx:i%2?.65:-.65,vy:0,kind:i%3?'fish':'squid',dead:0,offset:i*30}));}
    if(isBridge(this.stage))this.enemies=[30,39,55,67,78,92,106,114,131,143,153,167,177].map((x,i)=>({x:x*16,y:260,w:14,h:14,vx:i%2?-.8:.9,vy:-7,kind:'leaping-fish',dead:0,launched:false}));}


  advanceStage(){
    if(this.phase!=='won'||this.presentation<this.presentationLength()||this.stage>=LAST_COURSE)return false;
    const saved={score:this.score,coins:this.coins,lives:this.lives,power:this.power,deaths:this.deaths};
    this.stage++;this.reset();Object.assign(this,saved);if(this.power)this.resizePlayer(28);return true;
  }
  presentationLength(){return this.phase==='won'&&this.fireworksTotal?Math.max(180,140+this.fireworksTotal*18+24):180;}
  restartLife(){
    if(this.phase!=='dead'||this.lives<=0||this.presentation<this.presentationLength())return false;
    const saved={score:this.score,coins:this.coins,lives:this.lives,deaths:this.deaths};
    this.reset();Object.assign(this,saved);return true;
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
    if(item){if(item==='vine'){this.vines.push({x:x*16+6,base:y*16,top:y*16,target:40,w:4});this.sound('appear');}
      else if(item==='coin'||item==='multi'){this.collectCoin();this.effects.push({x:x*16+5,y:y*16-16,life:25,kind:'coin'});}
      else {this.sound('appear');this.items.push({x:x*16,y:y*16,w:14,h:16,emerging:16,vx:item==='star'?1.3:1,vy:0,kind:item==='mushroom'&&this.power?'flower':item});}
      if(item==='multi'){const n=(this.multi??0)+1;this.multi=n;if(n>=10){this.contents.delete(key);this.cells.set(key,'used');}}
      else{this.contents.delete(key);this.cells.set(key,'used');}
    }else if(t==='brick'&&this.power){this.sound('break');this.cells.delete(key);this.score+=50;for(let i=0;i<4;i++)this.effects.push({x:x*16+(i%2)*8,y:y*16,life:25,kind:'debris',vx:i<2?-1:1,vy:-3-i%2});}
  }
  vineStep(){for(const v of this.vines)v.top=Math.max(v.target,v.top-1);}
  shellStep(){
    const p=this.p,k=this.input;
    let held=this.enemies.find(e=>e.carried&&!e.dead);
    if(!held&&k.carry&&this.phase==='playing'){
      held=this.enemies.find(e=>!e.dead&&e.kind==='shell'&&!e.vx&&Math.abs(e.x+e.w/2-p.x-p.w/2)<24&&Math.abs(e.y+e.h-p.y-p.h)<12);
      if(held){held.carried=true;this.sound('kick');}
    }
    if(!held)return;
    const facing=p.facing??1;held.x=facing>0?p.x+p.w+2:p.x-held.w-2;held.y=p.y+p.h-held.h-4;held.vx=0;held.vy=0;
    if(!k.carry||this.phase!=='playing'){held.carried=false;held.vx=facing*4;held.vy=this.phase==='playing'?-2.5:0;held.ownerGrace=12;this.sound('kick');}
  }
  liftStep(){
    if(this.phase!=='playing')return;
    const p=this.p;
    for(const lift of this.lifts){
      lift.previousY=lift.y;
      const next=Math.max(lift.minY,Math.min(lift.maxY,lift.y+lift.direction*lift.speed));
      const riding=p.grounded&&p.liftId===lift.id&&p.x+p.w>lift.x&&p.x<lift.x+lift.w&&Math.abs(p.y+p.h-lift.y)<1;
      const y=p.y+next-lift.y;
      let blocked=false;
      if(riding)for(let row=Math.floor(y/16);row<=Math.floor((y+p.h-.01)/16);row++)for(let col=Math.floor(p.x/16);col<=Math.floor((p.x+p.w-.01)/16);col++)if(this.solid(col,row))blocked=true;
      // Reverse before squeezing a rider into a solid ceiling or floor.
      if(blocked){lift.direction*=-1;continue;}
      if(riding)p.y=y;
      lift.y=next;if(next===lift.minY||next===lift.maxY)lift.direction*=-1;
    }
  }
  landOnLift(beforeY){
    const p=this.p,previous=p.liftId;delete p.liftId;
    if(p.vy<0)return;
    for(const lift of [...this.lifts].sort((a,b)=>a.y-b.y))if(p.x+p.w>lift.x&&p.x<lift.x+lift.w&&(beforeY+p.h<=lift.previousY+.5||previous===lift.id)&&p.y+p.h>=lift.y&&p.y<lift.y){p.y=lift.y-p.h;p.vy=0;p.grounded=true;p.liftId=lift.id;break;}
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
  die(){if(this.phase!=='playing')return;this.sound('death');this.phase='dead';this.presentation=0;this.deathY=this.p.y;this.deaths++;this.lives--;this.input={};this.shellStep();delete this.p.climbing;}
  presentationStep(){
    if(this.phase==='playing'||this.presentation>=this.presentationLength())return;
    this.presentation++;
    this.fireworks=this.fireworks.map(f=>({...f,age:f.age+1})).filter(f=>f.age<24);
    if(this.phase==='dead'){
      const t=Math.max(0,this.presentation-22);this.p.y=this.deathY-4.6*t+.095*t*t;
    }else{
      if(isCastle(this.stage)){if(this.presentation<65&&this.presentation%4===0)this.cells.delete(`${179+Math.floor(this.presentation/4)},12`);this.p.x=Math.min(201*16,this.p.x+1.2);this.p.y=208-this.p.h;this.p.grounded=true;this.p.vx=0;this.p.vy=0;this.p.stride=(this.p.stride??0)+1.2;}
      else if(isUnderground(this.stage)||isWater(this.stage)){this.p.x=Math.min(198*16,this.p.x+1.2);this.p.stride=(this.p.stride??0)+1.2;}
      else if(this.presentation<60)this.p.y=Math.min(192,this.flagStartY+this.presentation*2.7);
      else{this.p.y=208-this.p.h;this.p.grounded=true;this.p.vx=0;this.p.vy=0;this.p.x=Math.min(202*16+32,this.p.x+1.2);this.p.facing=1;this.p.stride=(this.p.stride??0)+1.2;}
      if(isCastle(this.stage)){if(this.boss&&this.presentation>32){this.boss.dead=true;this.boss.y+=3;}if(this.presentation===90){this.rescued=true;if(this.stage===LAST_COURSE)this.peachRescued=true;this.sound('life');}}
      if([9,10,11].includes(this.stage)&&this.presentation===140){this.peachRescued=true;this.sound('life');}
      if(this.fireworksFired<this.fireworksTotal&&this.presentation===140+this.fireworksFired*18){
        const i=this.fireworksFired++;this.fireworks.push({x:202*16+[8,56,24,72,0,44][i],y:[56,80,44,60,84,48][i],age:0});this.score+=500;this.sound('firework');
      }
      if(this.presentation===61)this.sound('clear');
      if(this.presentation>60&&this.time>0){if(this.presentation%4===0)this.sound('tally');const n=Math.min(6,this.time);this.time-=n;this.score+=n*50;}
    }
  }
  snapshot(){
    return {course_id:this.stage,...courseInfo(this.stage),frame:this.frames,phase:this.phase,room:this.room,time:this.time,lives:this.lives,deaths:this.deaths,fireworks_total:this.fireworksTotal,fireworks_fired:this.fireworksFired,
      vines:this.vines.map(v=>({...v})),pickups:{...this.pickups},lifts:this.lifts.map(f=>({...f})),lava_bubbles:this.lavaBubbles.map(f=>({...f})),boss:this.boss?{...this.boss}:null,boss_flames:this.bossFlames.map(f=>({...f})),rescued:this.rescued,peach_rescued:this.peachRescued,hammers:this.hammers.map(h=>({...h})),cannons:this.cannons.map(c=>({...c})),
      player:{...this.p},input:{...this.input},jump_was_pressed:this.wasJump,
      enemies:this.enemies.filter(e=>!e.dead&&!e.carried&&!e.hidden&&Math.abs(e.x-this.p.x)<256).slice(0,5).map(e=>({x:e.x,y:e.y,w:e.w,h:e.h,vx:e.vx,vy:e.vy,kind:e.kind,edge_gap:e.x-(this.p.x+this.p.w)}))};
  }
  fireHazards(){
    return this.fireBars.flatMap(bar=>Array.from({length:bar.length},(_,i)=>{const angle=bar.offset+this.frames*.025*bar.direction,r=(i+1)*8;return {x:bar.x+Math.cos(angle)*r-4,y:bar.y+Math.sin(angle)*r-4,w:8,h:8};}));
  }
  lavaBubbleStep(){
    if(this.phase!=='playing')return;
    for(const f of this.lavaBubbles){
      if(f.x<this.camera-24||f.x>this.camera+280)continue;
      if(!f.active){if(--f.timer>0)continue;f.active=true;f.y=232;f.vy=-6.6;this.sound('fire');}
      f.y+=f.vy;f.vy+=.18;
      if(f.y>=232&&f.vy>0){f.y=232;f.vy=0;f.active=false;f.timer=90;continue;}
      if(f.y<220&&overlap(this.p,f))this.hurt();
    }
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
  lakituStep(){
    if(![11,13,19,21,30].includes(this.stage)||this.phase!=='playing')return;
    this.enemies=this.enemies.filter(e=>!['spiny','spiny-egg'].includes(e.kind)||(!e.dead&&e.y<260&&e.x>=this.camera-32&&e.x<=this.camera+280));
    for(const e of this.enemies.filter(e=>e.kind==='lakitu'&&!e.dead)){
      if(!e.active){if(this.p.x<24*16)continue;e.active=true;e.x=this.p.x+72;}
      e.age++;const target=this.p.x<180*16?this.p.x+64:this.camera-64;
      e.vx=Math.max(-2.8,Math.min(2.8,(target-e.x)*.035));e.x+=e.vx;e.y=40+Math.sin(e.age/30)*5;
      if(this.p.x<180*16&&e.x>this.camera&&e.x<this.camera+240&&e.age%180===1&&this.enemies.filter(n=>!n.dead&&['spiny','spiny-egg'].includes(n.kind)).length<6){
        this.enemies.push({x:e.x+2,y:e.y+20,w:12,h:12,vx:0,vy:1.2,kind:'spiny-egg',dead:0,direction:this.p.x<e.x?-1:1});this.sound('fire');
      }
    }
  }
  plantStep(e){
    if(e.age===0&&Math.abs(this.p.x+this.p.w/2-(e.x+8))<40){e.h=0;e.y=e.pipeY;e.hidden=true;return;}
    e.age=(e.age+1)%240;
    const height=e.age<48?e.age/2:e.age<120?24:e.age<168?(168-e.age)/2:0;
    e.h=height;e.y=e.pipeY-height;e.hidden=height===0;
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
    if(k.down&&p.grounded&&!isWater(this.stage))this.resizePlayer(this.power?16:12);
    else this.resizePlayer(standing);
    p.crouching=p.h<standing;this.liftStep();this.vineStep();
    const intended=(k.right?1:0)-(k.left?1:0);
    if(intended)p.facing=intended;
    const skidding=p.grounded&&!p.crouching&&intended&&Math.abs(p.vx)>.4&&Math.sign(p.vx)!==intended;
    if(skidding&&!this.wasSkidding)this.sound('skid');this.wasSkidding=!!skidding;
    const dir=p.crouching?0:intended,max=isWater(this.stage)?1.4:k.run?2.6:1.55;
    p.vx=dir?Math.max(-max,Math.min(max,p.vx+dir*.13)):Math.abs(p.vx)<.08?0:p.vx-Math.sign(p.vx)*.08;
    if(isWater(this.stage)){
      if(k.jump&&!this.wasJump){this.sound('swim');p.vy=-2.4;}
      p.vy=Math.min(1.5,p.vy+.075);
    }else{
      if(k.jump&&!this.wasJump&&p.grounded&&!p.crouching){this.sound('jump');p.vy=Math.abs(p.vx)>1.6?-5.7:-5.2;p.grounded=false;}
      if(!k.jump&&p.vy<-2.5)p.vy=-2.5;
      p.vy=Math.min(6,p.vy+(k.jump&&p.vy<0?.18:.38));
    }
    const vine=this.vines.find(v=>p.x+p.w>v.x-4&&p.x<v.x+v.w+4&&p.y+p.h>v.top&&p.y<v.base);
    if(vine&&!k.jump&&(k.up||p.climbing)){
      p.climbing=true;p.vx=0;p.vy=(k.down?1.4:0)-(k.up?1.4:0);p.grounded=false;
      p.y=Math.max(vine.top,Math.min(vine.base-p.h,p.y+p.vy));p.vy=0;
      if(intended){p.climbing=false;p.vx=intended*1.3;}
    }else{if(p.climbing&&k.jump&&!this.wasJump){p.vy=-5.2;this.sound('jump');}p.climbing=false;}
    this.wasJump=!!k.jump;const beforeY=p.y;this.move(p,true);this.landOnLift(beforeY);
    if(isWater(this.stage)&&p.y<40){p.y=40;p.vy=Math.max(0,p.vy);}
    p.x=Math.max(this.camera,p.x);p.stride=(p.stride??0)+(p.grounded?Math.abs(p.vx):0);if(p.y>250)this.die();
    if(k.down)this.enterRoom();
    if(this.power===2&&k.run&&!this.wasFire&&this.shots.length<2){this.sound('fire');const facing=p.facing??1;this.shots.push({x:facing<0?p.x-4:p.x+p.w,y:p.y+10,w:4,h:4,vx:facing*3.5,vy:1});}this.wasFire=!!k.run;
    if(this.room==='underground'||this.stage>=2){
      for(const [key,item]of this.contents)if(item==='loose'){const[x,y]=key.split(',').map(Number);if(overlap(p,{x:x*16,y:y*16,w:12,h:16})){this.contents.delete(key);this.collectCoin();}}
      if(this.room==='underground'&&p.x>=12*16&&p.y+p.h<=160&&k.right)this.exitRoom();
      if(this.stage!==1)this.camera=Math.max(this.camera,Math.min(this.width-256,p.x-96));
    }else this.camera=Math.max(this.camera,Math.min(this.width-256,p.x-96));
    if(isCastle(this.stage)&&this.phase==='playing'){
      if(p.y+p.h>=220&&this.lava.some(([a,b])=>p.x+p.w>a*16&&p.x<(b+1)*16))this.die();
      if(this.fireHazards().some(f=>overlap(p,f)))this.hurt();
    }
    this.shellStep();this.lavaBubbleStep();this.projectileStep();this.lakituStep();this.bossStep();
    for(const e of this.enemies){if(e.dead||e.carried||e.x>this.camera+280||e.x<this.camera-32)continue;
      if(e.kind==='hammer-bro'){e.age++;if(e.x<e.anchor-18)e.vx=.35;if(e.x>e.anchor+18)e.vx=-.35;if(e.age%160===0&&e.grounded)e.vy=-5;if(e.age%75===1&&this.hammers.length<12){this.hammers.push({x:e.x,y:e.y-4,w:8,h:8,vx:(p.x<e.x?-1:1)*1.3,vy:-4.2,spin:0});this.sound('fire');}}
      if(e.kind==='piranha'){this.plantStep(e);if(e.hidden)continue;}
      else if(e.kind==='lakitu'){if(!e.active)continue;}
      else if(e.kind==='bullet')e.x+=e.vx;
      else if(e.kind==='paratroopa'&&e.red){e.flightAge++;e.y=e.flightY+Math.sin(e.flightAge/45)*32;e.vy=Math.cos(e.flightAge/45)*32/45;}
      else if(e.kind==='paratroopa'){const speed=e.vx;e.vy=Math.min(6,e.vy+.22);this.move(e);if(e.grounded)e.vy=-4.2;if(!e.vx)e.vx=-speed;}
      else if(e.kind==='leaping-fish'){if(!e.launched){if(e.x>p.x+176)continue;e.launched=true;}e.x+=e.vx;e.vy+=.16;e.y+=e.vy;}
      else {const speed=e.vx;if(isWater(this.stage)){e.vy=Math.sin((this.frames+e.offset)/35)*.6;this.move(e);e.y=Math.max(44,Math.min(194,e.y));if(e.vx===0)e.vx=-speed;}else{if(e.kind==='koopa'&&e.red&&e.grounded&&!this.solid(Math.floor((e.vx<0?e.x-1:e.x+e.w+1)/16),Math.floor((e.y+e.h+2)/16)))e.vx=-e.vx;e.vy=Math.min(6,e.vy+.38);this.move(e);if(e.vx===0)e.vx=-speed;}}
      if(e.kind==='spiny-egg'&&e.grounded){e.kind='spiny';e.vx=e.direction*.6;}
      if(e.y>270||(e.kind!=='leaping-fish'&&e.y>250)){e.dead=1;continue;}if(e.ownerGrace)e.ownerGrace--;if(overlap(p,e)&&!e.ownerGrace&&this.phase==='playing'){
        if(this.star){this.defeat(e);}
        else if(!isWater(this.stage)&&!['spiny','spiny-egg','piranha'].includes(e.kind)&&p.vy>=0&&beforeY+p.h<=e.y+6){this.sound('stomp');p.y=e.y-p.h;p.vy=k.jump?-5.2:-3.5;p.grounded=false;this.score+=100;this.popup(100,e.x,e.y);if(e.kind==='paratroopa'){e.kind='koopa';e.vy=0;e.vx=-.5;}else if(e.kind==='koopa'||e.kind==='beetle'){e.kind='shell';e.vx=0;}else if(e.kind==='shell'){e.vx=e.vx?0:(p.x<e.x?4:-4);}else{e.dead=1;this.effects.push({x:e.x,y:e.y+12,kind:'squash',life:20});}}
        else if(e.kind==='shell'&&!e.vx){this.sound('kick');e.vx=p.x<e.x?4:-4;e.x+=Math.sign(e.vx)*10;}else this.hurt();
      }
      if(e.kind==='shell'&&e.vx)for(const other of this.enemies)if(other!==e&&!other.dead&&!other.hidden&&!other.carried&&overlap(e,other)){this.defeat(other);}
    }
    for(const item of this.items){if(item.taken)continue;if(item.emerging>0){item.y--;item.emerging--;continue;}const speed=item.vx;if(item.kind!=='flower'){item.vy=Math.min(6,item.vy+.3);this.move(item);if(!item.vx)item.vx=-speed;if(item.kind==='star'&&item.grounded)item.vy=-4;}
      if(this.phase==='playing'&&overlap(p,item)){this.pickups[item.kind]=(this.pickups[item.kind]??0)+1;this.sound(item.kind==='life'?'life':'item');item.taken=true;this.score+=1000;this.popup(item.kind==='life'?'1UP':1000,item.x,item.y);if(item.kind==='star')this.star=600;else if(item.kind==='life')this.lives++;else{this.power=Math.max(this.power,item.kind==='flower'?2:1);if(p.h===16){p.y-=12;p.h=28;}}}}
    for(const shot of this.shots){shot.vy+=.35;this.move(shot);if(shot.grounded)shot.vy=-2.8;if(!shot.vx){shot.dead=true;this.sound('impact');this.effects.push({kind:'burst',x:shot.x,y:shot.y,life:10});}if(shot.x<this.camera||shot.x>this.camera+256)shot.dead=true;if(!shot.dead)for(const e of this.enemies)if(!e.dead&&!e.carried&&!e.hidden&&e.kind!=='bullet'&&overlap(shot,e)){if(!e.armored)this.defeat(e);shot.dead=true;this.effects.push({kind:'burst',x:shot.x,y:shot.y,life:10});break;}}
    this.shots=this.shots.filter(s=>!s.dead);
    for(const fx of this.effects){fx.life--;if(fx.kind==='coin')fx.y-=1;if(fx.kind==='score')fx.y-=.35;if(fx.kind==='debris'){fx.x+=fx.vx;fx.y+=fx.vy;fx.vy+=.25;}}this.effects=this.effects.filter(f=>f.life>0);
    if((isCastle(this.stage)?overlap(p,{x:196*16,y:160,w:16,h:32}):isWater(this.stage)?p.x>=196*16&&p.y+p.h>=176:isUnderground(this.stage)?p.x>=196*16:this.room==='overworld'&&p.x>=198*16)&&this.phase==='playing'){this.sound(isCastle(this.stage)?'bridge':(isUnderground(this.stage)||isWater(this.stage))?'pipe':'flag');this.phase='won';const digit=this.time%10;this.fireworksTotal=!isCastle(this.stage)&&!isUnderground(this.stage)&&!isWater(this.stage)&&[1,3,6].includes(digit)?digit:0;this.fireworksFired=0;this.fireworks=[];this.enemies=this.enemies.filter(e=>!['lakitu','spiny','spiny-egg'].includes(e.kind));this.bossFlames=[];for(const f of this.lavaBubbles){f.active=false;f.y=232;}this.hammers=[];this.presentation=0;this.flagStartY=p.y;this.score+=Math.max(100,5000-Math.floor(p.y)*20);this.input={};}
  }
  telemetry(previous=0){const p=this.p,tiles=[];for(let row=0;row<13;row++)for(let col=-2;col<=6;col++){const x=(Math.floor(p.x/16)+col)*16,y=(row+2)*16;tiles.push(this.solid(x/16,y/16)||this.lifts.some(l=>l.x<x+16&&l.x+l.w>x&&l.y>=y&&l.y<y+16)?84:0);};
    return{player:{x:p.x,y:p.y+p.h-16,vx:p.vx,vy:p.vy,grounded:p.grounded},tiles,enemies:[...(this.boss&&!this.boss.dead?[this.boss]:[]),...this.bossFlames,...this.lavaBubbles.filter(f=>f.active&&f.y<220),...this.hammers,...this.enemies].filter(e=>!e.dead&&!e.carried&&!e.hidden&&Math.abs(e.x-p.x)<256).slice(0,5).map(e=>({dx:e.x-p.x,y:e.y,type:e.kind==='goomba'?6:0})),world:courseInfo(this.stage).world,stage:courseInfo(this.stage).stage,previous_response_ms:Math.min(10000,previous)};}
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
  if(g.phase==='won'&&(isUnderground(g.stage)||isCastle(g.stage)||isWater(g.stage)))return `walk${Math.floor((g.p.stride??0)/5)%3}`;
  if(g.phase==='won')return g.presentation<60?'climb':`walk${Math.floor((g.p.stride??0)/5)%3}`;
  if(g.p.climbing)return 'climb';
  if(isWater(g.stage))return g.frames%24<12?'jump':'fall';
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
export function drawWorld(ctx,g){const cam=Math.floor(g.camera),water=isWater(g.stage),underground=g.room==='underground'||isUnderground(g.stage)||isCastle(g.stage);ctx.imageSmoothingEnabled=false;ctx.fillStyle=water?'#2048a0':underground?'#101020':[9,10,11,18,21,22,23].includes(g.stage)?'#081028':'#6888fc';ctx.fillRect(0,0,256,240);
  if(!underground&&!water){
    for(let start=0;start<g.width;start+=768){
      for(const [x,y,count]of[[128,32,1],[304,24,3],[528,40,1]])pixelCloud(ctx,x+start-cam,Math.max(40,y),count);
      for(const [x,h]of([3,7,11].includes(g.stage)?[]:[[0,32],[256,16],[576,32]]))pixelHill(ctx,x+start-cam,208,h);
      for(const [x,count]of([3,7,11].includes(g.stage)?[]:[[184,1],[368,3],[664,2]]))pixelCloud(ctx,x+start-cam,194,count,true);
    }
    const flag=198*16-cam;ctx.fillStyle='#80d010';ctx.fillRect(flag+7,32,2,160);ctx.fillRect(flag+5,28,6,6);ctx.fillStyle='#fff';ctx.beginPath();const flagY=g.phase==='won'?36+Math.min(144,g.presentation*2.7):36;ctx.moveTo(flag+7,flagY);ctx.lineTo(flag-9,flagY);ctx.lineTo(flag+7,flagY+12);ctx.fill();
    const castle=202*16-cam;for(let row=11;row<13;row++)for(let col=0;col<5;col++)pixelTile(ctx,'brick',castle+col*16,row*16);for(let row=9;row<11;row++)for(let col=1;col<4;col++)pixelTile(ctx,'brick',castle+col*16,row*16);ctx.fillStyle='#b85020';for(let i=0;i<5;i++)ctx.fillRect(castle+i*16,168,8,8);for(let i=0;i<3;i++)ctx.fillRect(castle+16+i*16,144,8,8);ctx.fillStyle='#101020';ctx.fillRect(castle+32,184,16,24);ctx.fillRect(castle+24,160,8,10);ctx.fillRect(castle+48,160,8,10);
  }
  if(isBridge(g.stage)){
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
    if(t==='bridge'){if(isBridge(g.stage)){ctx.fillStyle='#b89060';ctx.fillRect(x,y-12,16,2);ctx.fillRect(x+1,y-12,2,12);ctx.fillStyle='#583818';ctx.fillRect(x+6,y+8,4,240-y);}ctx.fillStyle='#904018';ctx.fillRect(x,y,16,8);ctx.fillStyle='#f8b850';ctx.fillRect(x,y,16,2);ctx.fillRect(x+3,y+2,2,6);continue;}
    if(t==='platform'){ctx.fillStyle=g.stage===11?'#987848':'#755035';ctx.fillRect(x+6,y+8,4,240-y);ctx.fillStyle=g.stage===11?'#d8e8e8':'#e07038';ctx.fillRect(x,y,16,8);ctx.fillStyle='#ffe4a8';ctx.fillRect(x+1,y+1,14,3);continue;}
    if(t.startsWith('pipe')){if(g.tile(col-1,row)?.startsWith('pipe'))continue;let width=1;while(g.tile(col+width,row)?.startsWith('pipe'))width++;pixelPipe(ctx,x,y,width*16,t==='pipe-top');continue;}
    pixelTile(ctx,t,x,y,underground,g.frames);
  }
  for(const l of g.lifts){if(l.x+l.w<cam||l.x>cam+256)continue;const x=Math.round(l.x)-cam,y=Math.round(l.y);ctx.fillStyle='#a84800';ctx.fillRect(x,y,l.w,l.h);ctx.fillStyle='#ffe0b0';ctx.fillRect(x,y,l.w,2);ctx.fillRect(x,y+2,3,4);ctx.fillRect(x+l.w-3,y+2,3,4);ctx.fillStyle='#f88830';for(let c=6;c<l.w-3;c+=8)ctx.fillRect(x+c,y+3,4,3);}
  if(isCastle(g.stage)){
    for(const[a,b]of g.lava){const left=Math.max(0,a*16-cam),right=Math.min(256,(b+1)*16-cam);if(right<=left)continue;ctx.fillStyle='#b82000';ctx.fillRect(left,220,right-left,20);ctx.fillStyle='#ff7800';ctx.fillRect(left,220,right-left,4);ctx.fillStyle='#ffd040';for(let x=left;x<right;x+=8)ctx.fillRect(x,220+(Math.floor(g.frames/8+x/8)%2)*2,4,2);}
    for(const f of g.lavaBubbles){
      if(!f.active||f.y>=220||f.x<cam-16||f.x>cam+256)continue;
      const rows=['....RRRR....','..RRYYYYRR..','.RRYYYYYYRR.','RRYYWWWWYYRR','RRYYWWWWYYRR','.RRYYYYYYRR.','..RRYYYYRR..','...RRYYRR...','....RRRR....','.....RR.....'];
      ctx.save();ctx.translate(Math.round(f.x)-cam,Math.round(f.y));if(f.vy>0){ctx.translate(0,16);ctx.scale(1,-1);}sprite(ctx,rows,0,0,{R:'#f83800',Y:'#ffb030',W:'#fff0b0'},1,1.6);ctx.restore();
    }
    for(const bar of g.fireBars){ctx.fillStyle='#909098';ctx.fillRect(bar.x-4-cam,bar.y-4,8,8);}
    for(const h of g.fireHazards()){if(h.x<cam-8||h.x>cam+256)continue;ctx.fillStyle='#f83800';ctx.fillRect(Math.round(h.x)-cam,Math.round(h.y),8,8);ctx.fillStyle='#ffb030';ctx.fillRect(Math.round(h.x)+1-cam,Math.round(h.y)+1,6,6);ctx.fillStyle='#fff0b0';ctx.fillRect(Math.round(h.x)+3-cam,Math.round(h.y)+2,2,3);}
    if(g.phase!=='won'){const x=196*16-cam;ctx.fillStyle='#b85020';ctx.fillRect(x+7,166,3,26);ctx.fillStyle='#fcfcfc';ctx.fillRect(x,160,10,7);ctx.fillRect(x-2,162,4,9);}
    const door=202*16-cam;ctx.fillStyle='#000';ctx.fillRect(door,176,24,32);ctx.fillStyle='#b8b8c0';ctx.fillRect(door-2,174,28,2);
  }
  if(isCastle(g.stage)){
    const b=g.boss;
    if(b&&b.y<250){const rows=['....WW....WW....','...GGGGGGGGGG...','..GGGGGGGGGGGG..','.GGSSSSGGGGGGGG.','GGSSBSSSGGGGGGGG','GGSSSSSSSGGGWGGG','SSSSSSSSSGGWWWGG','.SSSSSSSSGGGWGGG','..RRRSSSSGGWGGGG','...SSSSSSGGGGGG.','..SSSSSSSSGGGG..','.SSSSSSSSSSGGG..','SSSSSSSSSSSSGGG.','.SSSSSSSSSSSGG..',g.frames%24<12?'..HHHH...HHHH...':'...HHHH.HHHH....',g.frames%24<12?'..HHHH...HHHH...':'.HHHH.....HHHH..'];sprite(ctx,rows,b.x-cam,b.y,{W:'#fff0b0',G:'#60a820',S:'#ffc070',B:'#101020',R:'#e84020',H:'#b86820'},1.75,2);}
    for(const f of g.bossFlames){ctx.fillStyle='#ff4800';ctx.fillRect(f.x-cam,f.y,14,8);ctx.fillStyle='#ffe080';ctx.fillRect(f.x-cam+2,f.y+2,10,4);}
    const rows=['....RRRRRR....','..RRWWRRWWRR..','.RRWWWRRWWWRR.','RRRWWWRRWWWRRR','RRRRRRRRRRRRRR','.WWWWWWWWWWWW.','...SSBSSBSS...','...SSSSSSSS...','....SSSSSS....','...BSSSSSSB...','..SBBSSSSBBS..','..SSBBBBBBSS..','....SSSSSS....','...HHH..HHH...'];sprite(ctx,rows,204*16-cam,194,{R:'#f83800',W:'#fff',S:'#ffbc80',B:'#2858b0',H:'#804020'},1,1);
    if(g.rescued){ctx.fillStyle='#101020';ctx.fillRect(8,72,240,52);pixelText(ctx,g.character==='luigi'?'THANK YOU LUIGI!':'THANK YOU MARIO!',68,82);pixelText(ctx,g.stage===LAST_COURSE?'TOAD AND PEACH SAFE':'TOAD IS SAFE',g.stage===LAST_COURSE?56:80,102);}
  }
  if([9,10,11,LAST_COURSE].includes(g.stage)&&g.phase==='won'&&g.presentation>=(g.stage===LAST_COURSE?90:100)){
    // Bonus ending requested by the user, not an original stage ending.
    const rows=['.....Y.Y.Y.....','.....YYYYY.....','....HHHHHHH....','....HSSBSSH....','....HSSSSSH....','....HHSSSHH....','.....PPPPP.....','....PPPSPPP....','...SPPPPPPS...','..SSPPPPPPSS..','....PPPPPPP....','...PPPPPPPPP...','..PPPPPPPPPPP..','.PPPPPPPPPPPPP.','....HH...HH....'];
    sprite(ctx,rows,(g.stage===LAST_COURSE?202.5:205)*16-cam,178,{Y:'#ffd040',H:'#e8a030',S:'#ffcfaa',B:'#2048a0',P:'#f878b8'},1,2);
    if(g.stage!==LAST_COURSE&&g.peachRescued&&g.fireworksFired===g.fireworksTotal&&!g.fireworks.length){ctx.fillStyle='#101020ee';ctx.fillRect(12,72,232,64);pixelText(ctx,g.character==='luigi'?'THANK YOU LUIGI!':'THANK YOU MARIO!',68,82);pixelText(ctx,'PEACH IS SAFE',76,102);pixelText(ctx,'BONUS ENDING',80,122);}
  }
  for(const v of g.vines){ctx.fillStyle='#00a800';ctx.fillRect(v.x-cam,v.top,4,v.base-v.top);for(let y=v.base-8;y>v.top;y-=12){ctx.fillRect(v.x-cam-5,y,5,3);ctx.fillRect(v.x-cam+4,y-5,5,3);}}
  for(const[key,item]of g.contents)if(item==='loose'){const[x,y]=key.split(',').map(Number);drawCoin(ctx,x*16+4-cam,y*16+2,g.frames);}
  for(const e of g.enemies){if(e.dead||e.x<cam-16||e.x>cam+256)continue;
    const walking=g.frames%16<8;
    if(e.kind==='piranha'){
      if(e.hidden)continue;
      const open=g.frames%32<16,rows=['....GGGGGGGG....','..GGWWGGWWGGGG..','.GGWWWWWWWWWWGG.','GGWWWWWWWWWWWWGG',open?'GG............GG':'GGGGWWWWWWWWGGGG',open?'.GG..........GG.':'.GGGGGGGGGGGGGG.','..GGGGGGGGGGGG..','....GGGGGGGG....','.......GG.......','.......GG.......','...GG..GG..GG...','....GGGGGGGG....','.....GGGGGG.....','.......GG.......','.......GG.......','.......GG.......'];
      ctx.save();ctx.beginPath();ctx.rect(e.x-cam,e.pipeY-e.h,16,e.h);ctx.clip();sprite(ctx,rows,e.x-cam,e.y,{G:'#28a848',W:'#fff8d8'},1,1.5);ctx.restore();continue;
    }
    if(e.kind==='beetle'||(e.kind==='shell'&&e.armored)){
      const rows=['....BBBBBB....','..BBGGGGGGBB..','.BGGGGGGGGGGB.','BGGGGGGGGGGGGB','BGGGGGGGGGGGGB','BBBBBBBBBBBBBB','.SSSSSSSSSSSS.',...(e.kind==='beetle'?[walking?'..SS...SSSS...':'...SSSS...SS..']:[])];
      sprite(ctx,rows,e.x-cam,e.y+e.h-rows.length,{B:'#101020',G:'#506898',S:'#ffe0b0'});continue;
    }
    if(e.kind==='lakitu'){
      if(!e.active)continue;
      const rows=['.....GGGGGG.....','....GYYYYYYG....','...GYYBYYBYYG...','...YYYBYYBYYY...','....YYYYYYYY....','.....YYYYYY.....','....GGGGGGGG....','...GYYYYYYYYG...','....YYYYYYYY....','.....Y....Y.....'];
      sprite(ctx,rows,e.x-cam,e.y,{G:'#388828',Y:'#ffd080',B:'#202028'});
      const cloud=['....WWWWWWWW....','..WWWWWWWWWWWW..','.WWWWWWWWWWWWWW.','WWWWWWBWWBWWWWWW','WWWWWWWWWWWWWWWW','.WWWWWWBBWWWWWW.','..WWWWWWWWWWWW..','....WWWWWWWW....'];
      sprite(ctx,cloud,e.x-cam,e.y+10,{W:'#f8f8f8',B:'#606878'});continue;
    }
    if(e.kind==='spiny'||e.kind==='spiny-egg'){
      const rows=e.kind==='spiny-egg'?['....W..W....','...WRRRRW...','..RRWRRWRR..','.WRRRRRRRRW.','..RRWRRWRR..','...WRRRRW...','....W..W....']:['..W..W..W...','..WRRWRRW...','.RRRRRRRRR..','WRRRRRRRRRW.','.RRRRRRRRR..','..SSSSSBSS..','...SSSSSS...',walking?'..SS...SS...':'...SS...SS..'];
    sprite(ctx,rows,e.x-cam,e.y+e.h-rows.length,{R:'#e83828',W:'#fff0d0',S:'#ffc080',B:'#202028'});continue;
    }
    if(e.kind==='bullet'){const rows=['...BBBBBBBBBBBB.','.BBBBBBBBBBBBBBB','BBBBBBBBBBBBBBBB','BBSSBBBBBBBBBBBB','BBSBBSBBBBBBBBBB','BBBBBBBBBBBBBBBB','BBBBBBBBSSSBBBBB','BBBBBBBSSSSSBBBB','BBBBBBBBSSSBBBBB','.BBBBBBBBBBBBBBB','...BBBBBBBBBBBB.'];const outlined=rows.map((r,j)=>[...r].map((c,i)=>c==='B'&&(!rows[j-1]?.[i]||rows[j-1][i]==='.'||!rows[j+1]?.[i]||rows[j+1][i]==='.'||i===0||i===r.length-1||r[i-1]==='.'||r[i+1]==='.')?'G':c).join(''));sprite(ctx,e.vx<0?outlined:outlined.map(r=>[...r].reverse().join('')),e.x-cam,e.y+1,{B:'#101018',G:'#888898',S:'#f0f0f0'});continue;}
    if(e.kind==='hammer-bro'){const rows=['....GGGGGG....','...GWWWWWWG...','..GWWWWWWWWG..','..WWSSBSSWW...','...SSSSSSS....','....SSSSS.....','...GGGGSSS....','..GWWWWGSSS...','.GWWGGWWGSS...','.GWWWWWWG.....','..GGGGGGG.....','...SSSSSS.....',walking?'..SS...SSS....':'...SSS..SS....'];sprite(ctx,rows,e.x-cam,e.y,{G:'#208838',W:'#f8f8d8',S:'#ffd090',B:'#101018'},1,1.8);continue;}
    const rows=(e.kind==='fish'||e.kind==='leaping-fish')?['.....RRRR.....','...RRRRRRRR...','..RRRRRRRRSS..','.RRRRRRRBSSSS.','RRRRRRRRBSSSS.','RRRRRRRRRSSSS.','.RRRRRSSSSSSS.','..RRRSSSSSSS..','..RRRSSSSSS...',walking?'SSRRRRSSSS....':'.SSRRRSSSS....',walking?'SSSRRRRR......':'..SSRRRR......','...RRRRR......','....SSS.......','.....SS.......']:e.kind==='squid'?['....SSSS....','...SSSSSS...','..SSSSSSSS..','.SSSBSSBSSS.','..SSSSSSSS..','...SSSSSS...',walking?'..SS.SS.SS..':'...SS..SS...']:e.kind==='shell'?['....GGGG....','..GGLLLLGG..','.GLLLLLLLLG.','GGLLGGGGLLGG','GLLGGLLGGLLG','GGGGGGGGGGGG','.SSSSSSSSSS.']:
      (e.kind==='koopa'||e.kind==='paratroopa')?['.......SSS..','......SSBSS.','......SSSSS.','...GGGGSS...','..GLLLLGSS..','.GLLGGLLG...','.GLLLLLLG...','..GGGGGG....','...SSSSS....',walking?'..SS...SSS..':'...SSS..SS..']:
      ['.....HHHHHH.....','....HHHHHHHH....','...HHHHHHHHHH...','..HHHHHHHHHHHH..','.HHHBBHHHHBBHHH.','HHHSSBBHHBBSSHHH','HHHSSSBHHBSSSHHH','.HHSSSSSSSSSSHH.','..HHHHHHHHHHHH..','....SSSSSSSS....','....SSSSSSSS....','...SSSSSSSSSS...',walking?'..BBBBBSSBBBB...':'...BBBBSSBBBBB..',walking?'.BBBBBB..BBBBB..':'..BBBBB..BBBBBB.',walking?'.BBBB....BBBB...':'...BBBB....BBBB.','................'];
    if(e.kind==='paratroopa'){const wing=walking?['W....','WW...','WWW..','.WWW.','..WWW']:['...WW','..WWW','.WWWW','..WWW','...WW'];sprite(ctx,wing,e.x-cam-3,e.y+1,{W:'#fff8e0'});sprite(ctx,wing.map(r=>[...r].reverse().join('')),e.x-cam+10,e.y+1,{W:'#fff8e0'});}
    sprite(ctx,rows,e.x-cam,e.y+e.h-rows.length,{R:'#f83800',H:'#a84800',S:'#ffe0b0',B:'#101020',G:e.red?'#a81000':'#005800',L:e.red?'#ff6040':'#80d010'});
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
  for(const f of g.fireworks){const radius=2+f.age*.65;ctx.fillStyle=f.age%4<2?'#fff0a0':'#ff7830';for(let i=0;i<8;i++){const a=i*Math.PI/4;ctx.fillRect(Math.round(f.x-cam+Math.cos(a)*radius),Math.round(f.y+Math.sin(a)*radius),3,3);}if(f.age<8){ctx.fillStyle='#fff';ctx.fillRect(f.x-cam-2,f.y-2,5,5);}}
  if(g.phase!=='playing'||!g.invincible||g.frames%6<3){const palette={R:g.power===2?'#fff':g.character==='luigi'?'#28b848':'#f83800',H:'#803000',S:'#ffbc80',B:g.star&&g.frames%12<6?'#00d8f8':g.character==='luigi'?'#f8f8d8':'#b85000',Y:'#ffc000'};drawPlayer(ctx,g,palette);}
  pixelText(ctx,'LIVES X'+Math.max(0,g.lives),24,4);
  pixelText(ctx,g.character==='luigi'?'LUIGI':'MARIO',24,16);pixelText(ctx,String(g.score).padStart(6,'0'),24,24);
  drawCoin(ctx,88,20,g.frames);pixelText(ctx,'X'+String(g.coins).padStart(2,'0'),96,24);
  pixelText(ctx,'WORLD',144,16);pixelText(ctx,courseInfo(g.stage??1).label,152,24);
  pixelText(ctx,'TIME',208,16);pixelText(ctx,String(g.time).padStart(3,'0'),216,24);
  if(g.phase==='dead'&&g.presentation>=80){ctx.fillStyle='#101020ee';ctx.fillRect(20,86,216,64);const title=g.lives>0?'WORLD '+courseInfo(g.stage).label:'GAME OVER';pixelText(ctx,title,(256-title.length*8)/2,100);pixelText(ctx,(g.character==='luigi'?'LUIGI':'MARIO')+' X '+Math.max(0,g.lives),92,120);}
  if(g.phase==='won'&&g.presentation>=g.presentationLength()&&!g.rescued&&!g.peachRescued){ctx.fillStyle='#101020dd';ctx.fillRect(20,86,216,52);const title=`WORLD ${courseInfo(g.stage??1).label} CLEAR!`;pixelText(ctx,title,(256-title.length*8)/2,102);pixelText(ctx,'RESTART TO PLAY AGAIN',48,121);}

}
