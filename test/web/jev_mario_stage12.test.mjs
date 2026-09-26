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
 g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),true);assert.equal(g.stage,6);g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),true);assert.equal(g.stage,7);assert.deepEqual([g.score,g.coins,g.lives,g.power,g.deaths],[12300,17,2,2,1]);g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),true);assert.equal(g.stage,8);g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),false);
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
 const win=new World11(5);win.p.x=198*16;win.step();assert.equal(win.phase,'won');for(let i=0;i<180;i++)win.presentationStep();assert.equal(win.advanceStage(),true);assert.equal(win.stage,6);
});

test('2-1 reaches the flag above its solid base with existing horizontal momentum',()=>{
 const g=new World11(5);g.p.x=198*16;g.p.y=160;g.p.vx=1.5;g.step();assert.equal(g.phase,'won');
});


test('water stroke, surface, enemy contact and low exit follow swimming rules',()=>{
 const g=new World11(6);assert.deepEqual(courseInfo(6),{world:2,stage:2,label:'2-2'});assert.equal(g.room,'underwater');assert.equal(g.telemetry().stage,2);assert.equal(g.enemies[0].kind,'squid');
 g.buttons('jump');g.step();assert.ok(g.p.vy<0);assert.ok(g.drainSounds().includes('swim'));for(let i=0;i<40;i++)g.step();assert.ok(g.p.vy>0,'holding jump does not retrigger strokes');
 g.buttons('noop');g.step();g.buttons('jump');g.step();assert.ok(g.p.vy<0);g.p.y=40;g.p.vy=-2;g.step();assert.ok(g.p.y>=40);
 const hit=new World11(6);hit.enemies=[{x:32,y:129,w:14,h:14,vx:0,vy:0,kind:'fish',offset:0,dead:0}];hit.step();assert.equal(hit.phase,'dead');assert.equal(hit.score,0);
 const win=new World11(6);win.p.x=196*16;win.p.y=80;win.step();assert.equal(win.phase,'playing');win.p.y=180;win.step();assert.equal(win.phase,'won');assert.ok(win.drainSounds().includes('pipe'));for(let i=0;i<180;i++)win.presentationStep();assert.equal(win.advanceStage(),true);assert.equal(win.stage,7);
 win.stage=6;win.reset();assert.equal(win.stage,6);assert.equal(win.room,'underwater');assert.equal(win.p.y,128);
});

test('water simulator clones preserve swim physics without changing live state',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(6),saved=JSON.stringify(g.snapshot());const future=advance(clone(g),'right_jump',8);assert.equal(future.stage,6);assert.ok(future.p.y<g.p.y);assert.equal(JSON.stringify(g.snapshot()),saved);
});


test('2-3 bridge gaps, coins and leaping fish have deterministic motion and a terminal flag',()=>{
 const g=new World11(7);assert.deepEqual(courseInfo(7),{world:2,stage:3,label:'2-3'});assert.equal(g.room,'overworld');assert.equal(g.tile(25,12),'bridge');assert.equal(g.tile(49,12),undefined);assert.equal(g.tile(49,13),undefined);assert.equal(g.telemetry().stage,3);assert.ok(g.contents.size>20);
 g.p.x=400;g.p.y=176;g.camera=304;const fish=g.enemies[0];g.step();assert.equal(fish.launched,true);assert.ok(fish.vy<0);for(let i=0;i<20;i++)g.step();assert.ok(fish.y<192,'fish jumps through bridge from below');
 for(let i=0;i<90;i++)g.step();assert.equal(fish.dead,1,'fish falls below the screen and expires');
 const hit=new World11(7);hit.enemies=[{x:32,y:192,w:14,h:14,vx:0,vy:0,kind:'leaping-fish',launched:true,dead:0}];hit.step();assert.equal(hit.phase,'dead');
 const fall=new World11(7);fall.p.x=49*16;fall.p.y=251;fall.step();assert.equal(fall.phase,'dead');assert.equal(fall.advanceStage(),false);
 const win=new World11(7);win.p.x=198*16;win.p.y=160;win.step();assert.equal(win.phase,'won');for(let i=0;i<180;i++)win.presentationStep();assert.equal(win.advanceStage(),true);assert.equal(win.stage,8);win.stage=7;win.reset();assert.equal(win.stage,7);assert.equal(win.enemies[0].launched,false);assert.equal(win.p.x,32);
});

test('2-3 prediction keeps leaping fish motion and live state separate',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(7);g.p.x=400;g.p.y=176;g.camera=304;const before=JSON.stringify(g.snapshot());const a=advance(clone(g),'right',8),b=advance(clone(g),'right',8);assert.equal(JSON.stringify(a.snapshot()),JSON.stringify(b.snapshot()));assert.ok(a.enemies[0].y<260);assert.equal(JSON.stringify(g.snapshot()),before);
});


test('2-4 boss patrol, jump, flames, collision and fireball defeat',()=>{
 const g=new World11(8);assert.equal(g.room,'castle');assert.equal(g.tile(32,13),undefined);assert.equal(g.snapshot().label,'2-4');assert.equal(g.boss.hp,5);
 g.camera=180*16;g.p.x=181*16;g.p.y=176;g.invincible=500;g.step();assert.equal(g.bossFlames.length,1);assert.ok(g.boss.x<189*16);g.boss.active=139;g.boss.grounded=true;g.step();assert.ok(g.boss.vy<0);
 const hit=new World11(8);hit.camera=180*16;hit.p.x=hit.boss.x;hit.p.y=hit.boss.y;hit.step();assert.equal(hit.phase,'dead');
 const flame=new World11(8);flame.bossFlames=[{x:33,y:192,w:14,h:8,vx:-1,vy:0}];flame.step();assert.equal(flame.phase,'dead');
 const shot=new World11(8);shot.camera=180*16;shot.p.x=181*16;shot.p.y=176;shot.boss.hp=1;shot.shots=[{x:shot.boss.x,y:shot.boss.y+8,w:4,h:4,vx:3,vy:0}];shot.step();assert.equal(shot.boss.dead,true);assert.equal(shot.phase,'playing','defeating boss still requires axe');
});

test('2-4 axe collapses bridge, rescues Toad and resets all boss state',()=>{
 const g=new World11(8);g.p.x=196*16;g.p.y=176;g.step();assert.equal(g.phase,'won');assert.equal(g.bossFlames.length,0);for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.tile(180,12),undefined);assert.equal(g.boss.dead,true);assert.equal(g.rescued,true);assert.equal(g.advanceStage(),false);assert.ok(g.drainSounds().includes('life'));
 g.reset();assert.equal(g.boss.hp,5);assert.equal(g.boss.dead,false);assert.equal(g.rescued,false);assert.equal(g.tile(180,12),'bridge');g.stage=1;g.reset();assert.equal(g.boss,null);assert.deepEqual(g.bossFlames,[]);
});

test('boss predictions and projectiles do not mutate live encounter',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(8);g.camera=180*16;g.p.x=181*16;g.p.y=176;const before=JSON.stringify(g.snapshot());const future=advance(clone(g),'noop',8);assert.ok(future.boss.active>0);assert.ok(future.bossFlames.length);assert.equal(JSON.stringify(g.snapshot()),before);
});
