import test from 'node:test';
import assert from 'node:assert/strict';
import {World11,level} from '../../web/jev-mario-lab/world11.mjs';
test('1-1 landmarks',()=>{const {cells}=level();assert.equal(cells.get('28,11'),'pipe-top');assert.equal(cells.get('57,9'),'pipe-top');for(const x of[69,70,86,87,88,153,154])assert.equal(cells.get(`${x},13`),undefined);assert.equal(cells.get('189,5'),'stone');assert.equal(cells.get('198,12'),'stone');});
test('variable jump and run acceleration',()=>{function jump(hold){const g=new World11();g.input={jump:true};let top=192;for(let n=0;n<60;n++){g.input.jump=n<hold;g.step();top=Math.min(top,g.p.y);}return top;}assert.ok(jump(25)<jump(3)-15);const g=new World11();g.input={right:true,run:true};for(let n=0;n<20;n++)g.step();assert.ok(g.p.vx>2);assert.ok(g.p.x>55);});
test('question block, growth and brick breaking',()=>{const g=new World11();g.hitBlock(21,9);assert.equal(g.tile(21,9),'used');assert.equal(g.items[0].kind,'mushroom');Object.assign(g.p,{x:336,y:128});g.step();assert.equal(g.power,1);assert.equal(g.p.h,28);g.hitBlock(20,9);assert.equal(g.tile(20,9),undefined);g.hitBlock(16,9);assert.equal(g.coins,1);});
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
 assert.equal(g.phase,'won',`phase=${g.phase},x=${g.p.x},y=${g.p.y}`);
});
