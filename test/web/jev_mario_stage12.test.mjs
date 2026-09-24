import test from 'node:test';
import assert from 'node:assert/strict';
import {World11,undergroundLevel,courseInfo} from '../../web/labs/jev-mario/world11.mjs';
test('stage selection resets its own course and identifies telemetry',()=>{
 const a=new World11(),b=new World11(2);assert.equal(a.telemetry().stage,1);assert.equal(b.telemetry().stage,2);assert.equal(b.room,'stage-underground');assert.equal(b.tile(10,2),'brick');assert.equal(a.tile(10,2),undefined);
 b.p.x=400;b.reset();assert.equal(b.p.x,32);assert.equal(b.stage,2);assert.equal(b.tile(10,2),'brick');
});
test('underground camera scrolls; coins collect; exit and death are distinct',()=>{
 const g=new World11(2);g.p.x=300;g.p.y=192;g.step();assert.ok(g.camera>0);assert.equal(g.room,'stage-underground');
 const key=[...g.contents].find(([,v])=>v==='loose')[0];const [x,y]=key.split(',').map(Number);g.p.x=x*16;g.p.y=y*16;g.camera=0;g.step();assert.equal(g.coins,1);
 const win=new World11(2);win.p.x=196*16;win.step();assert.equal(win.phase,'won');assert.ok(win.drainSounds().includes('pipe'));win.presentationStep();assert.ok(Number.isFinite(win.p.y));
 const dead=new World11(2);dead.p.y=251;dead.step();assert.equal(dead.phase,'dead');
});


test('campaign advances only after clear presentation and preserves earned state',()=>{
 const g=new World11();assert.equal(g.advanceStage(),false);
 g.phase='dead';g.presentation=180;assert.equal(g.advanceStage(),false);
 g.phase='won';g.presentation=179;assert.equal(g.advanceStage(),false);
 Object.assign(g,{presentation:180,score:12300,coins:17,lives:2,power:2,deaths:1});
 assert.equal(g.advanceStage(),true);assert.equal(g.stage,2);assert.equal(g.p.x,32);assert.equal(g.p.h,28);
 assert.deepEqual([g.score,g.coins,g.lives,g.power,g.deaths],[12300,17,2,2,1]);
 assert.equal(g.phase,'playing');assert.equal(g.frames,0);assert.deepEqual(g.input,{});
 g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),true);assert.equal(g.stage,3);
 g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),true);assert.equal(g.stage,4);
 g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),true);assert.equal(g.stage,5);assert.deepEqual([g.score,g.coins,g.lives,g.power,g.deaths],[12300,17,2,2,1]);
 g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),false);assert.equal(g.stage,5);
});
test('sky course has elevated platforms, gaps, collectibles and a distinct finish',()=>{
 const g=new World11(3);assert.equal(g.telemetry().stage,3);assert.equal(g.tile(20,12),'platform');assert.equal(g.tile(30,13),undefined);
 assert.ok(g.contents.size>30);assert.ok(g.enemies.every(e=>Number.isFinite(e.y)));
 g.p.x=32*16;g.p.y=100;g.p.vy=3;for(let i=0;i<30;i++)g.step();assert.equal(g.p.y+g.p.h,160);
 const fall=new World11(3);fall.p.x=30*16;fall.p.y=240;for(let i=0;i<20;i++)fall.step();assert.equal(fall.phase,'dead');
 const win=new World11(3);win.p.x=198*16;win.step();assert.equal(win.phase,'won');
});

test('castle selection, lava, rotating fire and axe completion have separate outcomes',()=>{
 const g=new World11(4);assert.equal(g.room,'castle');assert.equal(g.telemetry().stage,4);assert.equal(g.tile(10,2),'castle');assert.equal(g.tile(30,13),undefined);assert.equal(g.tile(180,12),'bridge');
 const a=g.fireHazards();g.step();assert.notDeepEqual(g.fireHazards(),a);
 const lava=new World11(4);lava.p.x=31*16;lava.p.y=208;lava.step();assert.equal(lava.phase,'dead');
 const hit=new World11(4);hit.frames=0;const next=new World11(4);next.frames=1;const flame=next.fireHazards()[0];hit.p.x=flame.x;hit.p.y=flame.y;hit.step();assert.equal(hit.phase,'dead');
 const shield=new World11(4);shield.p.x=flame.x;shield.p.y=flame.y;shield.invincible=20;shield.step();assert.equal(shield.phase,'playing');
 const below=new World11(4);below.p.x=196*16;below.step();assert.equal(below.phase,'playing');
 const win=new World11(4);win.p.x=196*16;win.p.y=176;win.step();assert.equal(win.phase,'won');assert.ok(win.drainSounds().includes('bridge'));
 for(let i=0;i<180;i++)win.presentationStep();assert.equal(win.tile(180,12),undefined);assert.ok(win.p.x>196*16);
 win.reset();assert.equal(win.stage,4);assert.equal(win.phase,'playing');assert.equal(win.tile(180,12),'bridge');assert.equal(win.p.x,32);assert.equal(win.fireBars.length,6);
 win.stage=1;win.reset();assert.equal(win.fireBars.length,0);assert.equal(win.lava.length,0);
});
test('castle hazard prediction clones retain time and never alter live game',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(4);const before=JSON.stringify(g.snapshot());const future=advance(clone(g),'right',8);assert.equal(g.frames,0);assert.equal(future.frames,8);assert.equal(JSON.stringify(g.snapshot()),before);assert.notDeepEqual(future.fireHazards(),g.fireHazards());
});

test('world 2 course has distinct terrain, enemies, collectible coins and public world-stage IDs',()=>{
 const g=new World11(5);assert.deepEqual(courseInfo(5),{world:2,stage:1,label:'2-1'});assert.equal(g.telemetry().world,2);assert.equal(g.telemetry().stage,1);assert.equal(g.snapshot().course_id,5);assert.equal(g.snapshot().stage,1);
 assert.equal(g.room,'overworld');assert.equal(g.tile(44,13),undefined);assert.equal(g.tile(24,11),'pipe-top');assert.equal(new World11().tile(44,13),'ground');assert.ok(g.enemies.some(e=>e.kind==='koopa'));
 const [x,y]=[...g.contents].find(([,v])=>v==='loose')[0].split(',').map(Number);g.p.x=x*16;g.p.y=y*16;g.step();assert.equal(g.coins,1);
 g.reset();assert.equal(g.stage,5);assert.equal(g.p.x,32);assert.equal(g.coins,0);
 const fall=new World11(5);fall.p.x=45*16;fall.p.y=251;fall.step();assert.equal(fall.phase,'dead');assert.equal(fall.advanceStage(),false);
 const win=new World11(5);win.p.x=198*16;win.step();assert.equal(win.phase,'won');for(let i=0;i<180;i++)win.presentationStep();assert.equal(win.advanceStage(),false);
});

test('2-1 reaches the flag above its solid base with existing horizontal momentum',()=>{
 const g=new World11(5);g.p.x=198*16;g.p.y=160;g.p.vx=1.5;g.step();assert.equal(g.phase,'won');
});
