import test from 'node:test';
import {mkdirSync,writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {World11,level,playerPose,drawWorld} from '../../web/labs/jev-mario/world11.mjs';

test('crouching anchors feet, stops acceleration and waits for headroom',()=>{
 const g=new World11();g.enemies=[];g.input={down:true,right:true};g.step();
 assert.equal(g.p.h,12);assert.equal(g.p.y+g.p.h,208);assert.equal(g.p.vx,0);
 assert.equal(playerPose(g),'crouch');g.input={};g.step();assert.equal(g.p.h,16);
 g.power=1;g.step();assert.equal(g.p.h,28);g.input={down:true};g.step();
 assert.equal(g.p.h,16);assert.equal(g.p.y+g.p.h,208);
 g.cells.set('2,11','brick');g.input={};g.step();assert.equal(g.p.h,16);assert.equal(playerPose(g),'crouch');
 g.cells.delete('2,11');g.step();assert.equal(g.p.h,28);assert.equal(g.p.y+g.p.h,208);
 g.reset();assert.equal(playerPose(g),'idle');
});
test('walk and airborne artwork change and facing follows input',()=>{
 const g=new World11();g.enemies=[];g.input={right:true};const seen=new Set();
 for(let i=0;i<30;i++){g.step();seen.add(playerPose(g));}
 assert.ok(['walk0','walk1','walk2'].every(p=>seen.has(p)));
 g.input={left:true};g.step();assert.equal(g.p.facing,-1);
 g.input={jump:true};g.step();assert.equal(playerPose(g),'jump');
 g.input={};for(let i=0;i<8;i++)g.step();assert.equal(playerPose(g),'fall');
 const pixels=[];const ctx=new Proxy({fillRect(...args){pixels.push([this.fillStyle,...args]);}},{get(o,k){return k in o?o[k]:()=>{};}});
 g.reset();drawWorld(ctx,g);const standing=JSON.stringify(pixels);pixels.length=0;
 g.input={down:true};g.step();drawWorld(ctx,g);assert.notEqual(JSON.stringify(pixels),standing);
});
test('1-1 landmarks',()=>{const {cells}=level();assert.equal(cells.get('28,11'),'pipe-top');assert.equal(cells.get('57,9'),'pipe-top');for(const x of[69,70,86,87,88,153,154])assert.equal(cells.get(`${x},13`),undefined);assert.equal(cells.get('189,5'),'stone');assert.equal(cells.get('198,12'),'stone');});
test('variable jump and run acceleration',()=>{function jump(hold){const g=new World11();g.input={jump:true};let top=192;for(let n=0;n<60;n++){g.input.jump=n<hold;g.step();top=Math.min(top,g.p.y);}return top;}assert.ok(jump(25)<jump(3)-15);const g=new World11();g.input={right:true,run:true};for(let n=0;n<20;n++)g.step();assert.ok(g.p.vx>2);assert.ok(g.p.x>55);});
test('question block, growth and brick breaking',()=>{const g=new World11();g.hitBlock(21,9);assert.equal(g.tile(21,9),'used');assert.equal(g.items[0].kind,'mushroom');Object.assign(g.p,{x:336,y:128});for(let i=0;i<18;i++)g.step();assert.equal(g.power,1);assert.equal(g.p.h,28);g.hitBlock(20,9);assert.equal(g.tile(20,9),undefined);g.hitBlock(16,9);assert.equal(g.coins,1);});
test('stomp, fall and goal',()=>{const g=new World11();const e=g.enemies[0];Object.assign(g.p,{x:e.x,y:e.y-16,vy:1});g.camera=250;g.step();assert.equal(e.dead,1);assert.ok(g.p.vy<0);g.p.y=260;g.step();assert.equal(g.phase,'dead');const frames=g.frames;g.step();assert.equal(g.frames,frames);g.reset();g.p.x=198*16;g.step();assert.equal(g.phase,'won');});
test('underground coins and return',()=>{const g=new World11();Object.assign(g.p,{x:57*16+5,y:128,grounded:true});g.enterRoom();assert.equal(g.room,'underground');assert.equal(g.contents.size,19);Object.assign(g.p,{x:80,y:112});g.step();assert.ok(g.coins>0);g.exitRoom();assert.equal(g.room,'overworld');assert.equal(g.tile(163,11),'pipe-top');assert.equal(g.p.x,164*16);});
test('live telemetry changes with gameplay',()=>{const g=new World11();const before=g.telemetry();g.input={right:true};for(let n=0;n<10;n++)g.step();const after=g.telemetry(123);assert.ok(after.player.x>before.player.x);assert.equal(after.tiles.length,117);assert.ok(after.enemies.length<=5);assert.equal(after.previous_response_ms,123);});
// A bounded deterministic search verifies physical reachability, not Jev skill.
test('look-ahead controller traverses overworld',()=>{
 const g=new World11();
 const clone=s=>Object.assign(Object.create(World11.prototype),structuredClone(s));
 for(let turn=0;turn<350&&g.phase==='playing';turn++){
  let beam=[{g:clone(g),first:false}];
  for(let depth=0;depth<12;depth++){
   const next=[];const seen=new Set();
   for(const node of beam)for(const jump of [false,true]){
    const sim=clone(node.g);sim.input={right:true,run:true,jump};for(let k=0;k<8;k++)sim.step();
    if(sim.phase==='dead')continue;
    const key=[Math.round(sim.p.x/2),Math.round(sim.p.y/2),Math.round(sim.p.vy),sim.wasJump,sim.power].join(',');if(seen.has(key))continue;seen.add(key);
    next.push({g:sim,first:depth?node.first:jump});
   }
   next.sort((a,b)=>(b.g.p.x+(192-b.g.p.y)*.2)-(a.g.p.x+(192-a.g.p.y)*.2));beam=next.slice(0,10);if(!beam.length)break;
  }
  assert.ok(beam.length,`no path at x=${g.p.x},y=${g.p.y}`);
  g.input={right:true,run:true,jump:beam[0].first};for(let k=0;k<8;k++)g.step();
 }
 mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-course-planner.json',JSON.stringify({controller:'deterministic_lookahead_not_Jev',phase:g.phase,x:g.p.x,frames:g.frames,score:g.score,coins:g.coins},null,2));
 assert.equal(g.phase,'won',`phase=${g.phase},x=${g.p.x},y=${g.p.y}`);
});

test('restart restores consumed blocks and room state',()=>{const g=new World11();for(let i=0;i<10;i++)g.hitBlock(94,9);g.saved={};g.reset();assert.equal(g.saved,null);assert.equal(g.coins,0);g.hitBlock(94,9);assert.equal(g.tile(94,9),'brick');assert.equal(g.multi,1);});

test('terminal presentation advances independently without restarting gameplay',()=>{
 const g=new World11();g.die();const x=g.p.x,y=g.p.y;for(let i=0;i<40;i++)g.presentationStep();
 assert.equal(g.phase,'dead');assert.equal(g.p.x,x);assert.ok(g.p.y<y);assert.equal(playerPose(g),'dead');
 for(let i=0;i<300;i++)g.presentationStep();assert.equal(g.presentation,180);g.step();assert.equal(g.frames,0);
 g.reset();g.p.x=198*16;g.step();const score=g.score;for(let i=0;i<180;i++)g.presentationStep();
 assert.equal(g.phase,'won');assert.ok(g.score>score);assert.equal(g.time,0);
});
test('snapshot owns its data and skidding differs from walking',()=>{
 const g=new World11();g.enemies=[];g.input={right:true};for(let i=0;i<20;i++)g.step();
 g.input={left:true};g.step();assert.equal(playerPose(g),'skid');const snap=g.snapshot();g.p.x+=50;g.input.left=false;
 assert.notEqual(snap.player.x,g.p.x);assert.equal(snap.input.left,true);
});

test('controlled identical jump demonstrates delay effect independently of Jev',()=>{
 const results=[];
 for(const delay of [0,50,200,1000]){
  const g=new World11();g.cells=new Map();g.contents=new Map();for(let x=0;x<80;x++)for(let y=13;y<15;y++)g.cells.set(`${x},${y}`,'ground');
  Object.assign(g.p,{x:160,y:192,vx:1.5});g.enemies=[{x:184,y:192,w:14,h:16,vx:-.5,vy:0,kind:'goomba',dead:0}];
  for(let frame=0;frame<40&&g.phase==='playing';frame++){g.input={right:true,jump:frame>=Math.round(delay*60/1000)};g.step();}
  results.push({delay_ms:delay,phase:g.phase,x:Number(g.p.x.toFixed(2)),frames:g.frames});
 }
 console.log('CONTROLLED_LATENCY_EXPERIMENT '+JSON.stringify(results));
 assert.equal(results[0].phase,'playing');assert.equal(results[3].phase,'dead');
});

test('flag descent starts at contact height and tally awards remaining time once',()=>{
 const g=new World11();g.enemies=[];Object.assign(g.p,{x:198*16,y:120,vy:0});g.step();const y=g.p.y,score=g.score,time=g.time;
 assert.equal(g.phase,'won');assert.deepEqual(g.drainSounds(),['flag']);g.presentationStep();assert.ok(g.p.y>=y&&g.p.y<=y+3);
 const sounds=[];for(let i=0;i<200;i++){g.presentationStep();sounds.push(...g.drainSounds());}
 assert.equal(g.time,0);assert.equal(g.score,score+time*50);assert.equal(sounds.filter(s=>s==='clear').length,1);assert.ok(sounds.includes('tally'));
 const end=g.score;for(let i=0;i<200;i++)g.presentationStep();assert.equal(g.score,end);
});
test('fireball follows remembered facing after directional input is released',()=>{
 const g=new World11();g.enemies=[];g.power=2;g.p.facing=-1;g.input={run:true};g.step();assert.equal(g.shots.length,1);assert.ok(g.shots[0].vx<0);assert.ok(g.shots[0].x<g.p.x);
});

test('held jump changes stomp bounce, both award a floating score once',()=>{
 const heights=[];
 for(const jump of [false,true]){const g=new World11();Object.assign(g.p,{x:100,y:175,vx:0,vy:2,grounded:false});g.input={jump};g.wasJump=jump;g.enemies=[{x:100,y:192,w:14,h:16,vx:0,vy:0,kind:'goomba',dead:0}];g.step();assert.equal(g.enemies[0].dead,1);assert.equal(g.score,100);assert.equal(g.p.grounded,false);assert.ok(g.effects.some(f=>f.kind==='score'&&f.value==='100'));heights.push(g.p.vy);g.step();assert.equal(g.score,100);}
 assert.ok(heights[1]<heights[0]);
});
test('a fireball defeats at most one overlapping enemy, and wall impact expires',()=>{
 const g=new World11();g.enemies=[0,1].map(()=>({x:104,y:192,w:14,h:16,vx:0,vy:0,kind:'goomba',dead:0}));g.shots=[{x:100,y:193,w:4,h:4,vx:3.5,vy:0}];g.step();assert.equal(g.enemies.filter(e=>e.dead).length,1);assert.equal(g.score,100);assert.equal(g.shots.length,0);assert.ok(g.drainSounds().includes('kick'));
 g.enemies=[];g.shots=[{x:444,y:180,w:4,h:4,vx:3.5,vy:0}];g.camera=300;g.p.x=330;g.step();assert.ok(g.drainSounds().includes('impact'));assert.ok(g.effects.some(f=>f.kind==='burst'));
 for(let i=0;i<50;i++)g.step();assert.ok(!g.effects.some(f=>f.kind==='burst'||f.kind==='score'));
});
