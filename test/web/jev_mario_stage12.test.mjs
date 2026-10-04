import test from 'node:test';
import assert from 'node:assert/strict';
import {World11,undergroundLevel,courseInfo,LAST_COURSE} from '../../web/labs/jev-mario/world11.mjs';
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
 const g=new World11();assert.equal(g.advanceStage(),false);g.phase='dead';g.presentation=180;assert.equal(g.advanceStage(),false);g.phase='won';g.presentation=179;assert.equal(g.advanceStage(),false);
 Object.assign(g,{score:12300,coins:17,lives:2,power:2,deaths:1});
 for(let next=2;next<=LAST_COURSE;next++){g.phase='won';g.presentation=g.presentationLength();assert.equal(g.advanceStage(),true);assert.equal(g.stage,next);assert.equal(g.p.x,32);assert.deepEqual([g.score,g.coins,g.lives,g.power,g.deaths],[12300,17,2,2,1]);assert.equal(g.phase,'playing');assert.equal(g.frames,0);}
 g.phase='won';g.presentation=g.presentationLength();assert.equal(g.advanceStage(),false);
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
 const g=new World11(8);g.p.x=196*16;g.p.y=176;g.step();assert.equal(g.phase,'won');assert.equal(g.bossFlames.length,0);for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.tile(180,12),undefined);assert.equal(g.boss.dead,true);assert.equal(g.rescued,true);assert.equal(g.p.grounded,true);assert.equal(g.p.vy,0);assert.ok(g.drainSounds().includes('life'));assert.equal(g.advanceStage(),true);assert.equal(g.stage,9);g.stage=8;
 g.reset();assert.equal(g.boss.hp,5);assert.equal(g.boss.dead,false);assert.equal(g.rescued,false);assert.equal(g.tile(180,12),'bridge');g.stage=1;g.reset();assert.equal(g.boss,null);assert.deepEqual(g.bossFlames,[]);
});

test('boss predictions and projectiles do not mutate live encounter',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(8);g.camera=180*16;g.p.x=181*16;g.p.y=176;const before=JSON.stringify(g.snapshot());const future=advance(clone(g),'noop',8);assert.ok(future.boss.active>0);assert.ok(future.bossFlames.length);assert.equal(JSON.stringify(g.snapshot()),before);
});


test('3-1 night course uses world 3 numbering, distinct terrain and enemies',()=>{
 const g=new World11(9);assert.deepEqual(courseInfo(9),{world:3,stage:1,label:'3-1'});assert.equal(g.telemetry().world,3);assert.equal(g.telemetry().stage,1);assert.equal(g.snapshot().course_id,9);assert.equal(g.room,'overworld');assert.equal(g.boss,null);assert.equal(g.tile(48,13),undefined);assert.equal(g.tile(26,11),'pipe-top');assert.equal(g.tile(71,6),'brick');assert.equal(g.enemies.filter(e=>e.kind==='koopa').length,4);
 const [x,y]=[...g.contents].find(([,v])=>v==='loose')[0].split(',').map(Number);g.p.x=x*16;g.p.y=y*16;g.step();assert.equal(g.coins,1);
 const dead=new World11(9);dead.p.x=49*16;dead.p.y=251;dead.step();assert.equal(dead.phase,'dead');assert.equal(dead.advanceStage(),false);
});

test('3-1 flag ending reveals Peach only after clear and resets cleanly',()=>{
 const g=new World11(9);assert.equal(g.peachRescued,false);g.p.x=198*16;g.p.y=160;g.step();assert.equal(g.phase,'won');for(let i=0;i<139;i++)g.presentationStep();assert.equal(g.peachRescued,false);g.presentationStep();assert.equal(g.peachRescued,true);for(let i=140;i<180;i++)g.presentationStep();assert.equal(g.p.grounded,true);assert.equal(g.snapshot().peach_rescued,true);assert.equal(g.advanceStage(),true);assert.equal(g.stage,10);g.stage=9;g.reset();assert.equal(g.stage,9);assert.equal(g.peachRescued,false);assert.equal(g.phase,'playing');assert.equal(g.p.x,32);
});

test('night course prediction preserves live state',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(9),before=JSON.stringify(g.snapshot());const future=advance(clone(g),'right',8);assert.equal(future.stage,9);assert.ok(future.p.x>g.p.x);assert.equal(JSON.stringify(g.snapshot()),before);
});


test('3-2 map, observations, clear, and reset retain correct campaign IDs',()=>{
 const g=new World11(10);assert.deepEqual(courseInfo(10),{world:3,stage:2,label:'3-2'});assert.equal(g.telemetry().stage,2);assert.equal(g.tile(59,13),undefined);assert.equal(g.tile(40,11),'cannon');assert.equal(g.cannons.length,4);assert.equal(g.enemies.filter(e=>e.kind==='hammer-bro').length,3);g.hitBlock(40,11);assert.equal(g.tile(40,11),'cannon');
 g.p.x=198*16;g.p.y=160;g.step();assert.equal(g.phase,'won');for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.peachRescued,true);assert.equal(g.advanceStage(),true);assert.equal(g.stage,11);g.stage=10;g.reset();assert.equal(g.phase,'playing');assert.equal(g.peachRescued,false);assert.equal(g.cannons[0].timer,0);assert.deepEqual(g.hammers,[]);g.stage=1;g.reset();assert.deepEqual(g.cannons,[]);
});

test('cannons launch toward player, respect proximity and retire off-screen bullets',()=>{
 const g=new World11(10);g.enemies=[];g.p.x=500;g.camera=404;g.step();const bullet=g.enemies.find(e=>e.kind==='bullet');assert.ok(bullet);assert.ok(bullet.vx<0);const y=bullet.y,x=bullet.x;g.step();assert.equal(bullet.y,y);assert.ok(bullet.x<x);
 bullet.x=g.camera-60;g.step();assert.ok(!g.enemies.includes(bullet));
 for(const [offset,vx]of [[279,2.2],[-31,-2.2]]){const edge={...bullet,x:g.camera+offset,vx,dead:0};g.enemies.push(edge);g.step();g.step();assert.ok(!g.enemies.includes(edge),'offscreen bullet must not freeze and consume spawn quota');}
 const near=new World11(10);near.enemies=[];near.p.x=640;near.p.y=150;near.camera=544;near.step();assert.equal(near.enemies.length,0);
 const right=new World11(10);right.enemies=[];right.p.x=710;right.camera=614;right.step();assert.ok(right.enemies.find(e=>e.kind==='bullet').vx>0);
});

test('Bullet Bill can be stomped or star-defeated but ignores fireballs',()=>{
 const fixture=()=>{const g=new World11(10);g.cannons=[];g.enemies=[{x:40,y:192,w:16,h:14,vx:0,vy:0,kind:'bullet',dead:0}];return g;};
 const hit=fixture();hit.step();assert.equal(hit.phase,'dead');
 const stomp=fixture();stomp.p.y=175;stomp.p.vy=2;stomp.step();assert.equal(stomp.enemies[0].dead,1);assert.equal(stomp.phase,'playing');assert.ok(stomp.p.vy<0);
 const fire=fixture();fire.p.x=0;fire.shots=[{x:40,y:194,w:4,h:4,vx:1,vy:0}];fire.step();assert.equal(fire.enemies[0].dead,0);
 const star=fixture();star.star=30;star.step();assert.equal(star.enemies[0].dead,1);assert.equal(star.phase,'playing');
});

test('Hammer Bro throws ballistic hazards, jumps and respects invincibility',()=>{
 const g=new World11(10);g.cannons=[];const bro={x:200,y:184,w:14,h:24,vx:.35,vy:0,kind:'hammer-bro',anchor:200,age:0,dead:0};g.enemies=[bro];g.step();assert.equal(g.hammers.length,1);const h=g.hammers[0],vy=h.vy;g.step();assert.ok(h.vy>vy);assert.ok(h.x<200);bro.age=159;bro.grounded=true;g.step();assert.ok(bro.vy<0);
 const hit=new World11(10);hit.cannons=[];hit.enemies=[];hit.hammers=[{x:32,y:192,w:8,h:8,vx:0,vy:0,spin:0}];hit.step();assert.equal(hit.phase,'dead');
 const shield=new World11(10);shield.cannons=[];shield.enemies=[];shield.invincible=20;shield.hammers=[{x:32,y:192,w:8,h:8,vx:0,vy:0,spin:0}];shield.step();assert.equal(shield.phase,'playing');assert.ok(shield.telemetry().enemies.length);shield.hammers[0].y=261;shield.step();assert.equal(shield.hammers.length,0);
});

test('3-2 simulator isolates projectiles and cannon timers',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(10);g.p.x=500;g.camera=404;const before=JSON.stringify(g.snapshot());const future=advance(clone(g),'noop',8);assert.ok(future.cannons[0].timer>0);assert.equal(JSON.stringify(g.snapshot()),before);
});


test('3-3 treetops have reachable platforms, finite enemies and a final flag',()=>{
 const g=new World11(11);assert.deepEqual(courseInfo(11),{world:3,stage:3,label:'3-3'});assert.equal(g.tile(20,12),'platform');assert.equal(g.tile(30,13),undefined);assert.equal(g.tile(32,10),'platform');assert.ok(g.enemies.every(e=>Number.isFinite(e.y)));assert.equal(g.enemies.filter(e=>e.kind==='lakitu').length,1);
 g.p.x=33*16;g.p.y=100;g.p.vy=3;g.enemies=[];for(let i=0;i<20;i++)g.step();assert.equal(g.p.y+g.p.h,160);
 g.enemies.push({x:g.p.x+40,y:40,w:16,h:16,kind:'lakitu',dead:0,active:true,age:0,vx:0,vy:0});g.p.x=198*16;g.p.y=160;g.p.vx=0;g.p.vy=0;g.step();assert.equal(g.phase,'won');assert.ok(!g.enemies.some(e=>e.kind==='lakitu'));for(let i=0;i<g.presentationLength();i++)g.presentationStep();assert.equal(g.peachRescued,true);assert.equal(g.advanceStage(),true);assert.equal(g.stage,12);
});

test('Lakitu follows, drops bounded eggs which become walking Spinies, and expires hazards',()=>{
 const g=new World11(11);const cloud=g.enemies.find(e=>e.kind==='lakitu');g.enemies=[cloud];g.p.x=24*16;g.p.y=170;g.camera=g.p.x-96;g.step();assert.equal(cloud.active,true);assert.ok(cloud.x>g.p.x);const egg=g.enemies.find(e=>e.kind==='spiny-egg');assert.ok(egg);const y=egg.y;g.step();assert.ok(egg.y>y);assert.ok(g.snapshot().enemies.some(e=>e.kind==='spiny-egg'));
 // Ground an egg with the real collision step, without advancing a player into a gap.
 egg.x=32;egg.y=195;egg.vy=2;g.camera=0;g.p.x=160;g.p.y=192;g.step();assert.equal(egg.kind,'spiny');assert.ok(egg.vx<0);
 egg.x=g.camera-31;egg.vx=-2;g.step();g.step();assert.ok(!g.enemies.includes(egg));
 for(let i=0;i<6;i++)g.enemies.push({x:180+i,y:150,w:12,h:12,vx:0,vy:0,kind:'spiny-egg',dead:0});cloud.age=180;g.lakituStep();assert.equal(g.enemies.filter(e=>e.kind==='spiny-egg').length,6);
});

test('spikes hurt even from above; stars and fireballs defeat Spinies, Lakitu can be stomped',()=>{
 const fixture=kind=>{const g=new World11(11);g.enemies=[{x:40,y:192,w:12,h:12,vx:0,vy:0,kind,dead:0,age:0,active:true}];return g;};
 const hit=fixture('spiny');hit.p.y=175;hit.p.vy=2;hit.step();assert.equal(hit.phase,'dead');assert.equal(hit.enemies[0].dead,0);
 const star=fixture('spiny');star.star=30;star.step();assert.equal(star.phase,'playing');assert.equal(star.enemies[0].dead,1);
 const fire=fixture('spiny');fire.p.x=0;fire.shots=[{x:40,y:194,w:4,h:4,vx:1,vy:0}];fire.step();assert.equal(fire.enemies[0].dead,1);
 const cloud=fixture('lakitu');cloud.p.x=40;cloud.p.y=21;cloud.p.vy=4;cloud.step();assert.equal(cloud.enemies[0].dead,1);assert.equal(cloud.phase,'playing');
});

test('life retry resets the current course while preserving earned totals and stopping at zero',()=>{
 for(const stage of [1,2,4,6,8,11,12,13,14,15,16]){const g=new World11(stage);Object.assign(g,{score:1234,coins:37,power:2,star:30});g.p.x=600;g.p.h=28;g.camera=400;g.time=23;g.die();g.die();assert.equal(g.lives,2);assert.equal(g.deaths,1);assert.equal(g.restartLife(),false);
  for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.restartLife(),true);assert.equal(g.stage,stage);assert.equal(g.p.x,32);assert.equal(g.camera,0);assert.equal(g.time,400);assert.equal(g.power,0);assert.equal(g.p.h,16);assert.equal(g.star,0);assert.deepEqual([g.score,g.coins,g.lives,g.deaths],[1234,37,2,1]);assert.deepEqual(g.input,{});
  g.lives=1;g.die();for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.restartLife(),false);assert.equal(g.phase,'dead');assert.equal(g.lives,0);
 }
});

test('flag timer digits launch exact fireworks with score, sound, bounded duration and no repeat',()=>{
 for(const [remaining,count]of [[331,1],[333,3],[336,6],[330,0],[332,0]]){
  const g=new World11(10);g.frames=(400-remaining)*24-1;g.p.x=198*16;g.p.y=160;g.step();assert.equal(g.time,remaining);assert.equal(g.fireworksTotal,count);const score=g.score;let sounds=0,max=0;
  for(let i=0;i<g.presentationLength();i++){g.presentationStep();sounds+=g.drainSounds().filter(x=>x==='firework').length;max=Math.max(max,g.fireworks.length);if(i===178&&count)assert.equal(g.advanceStage(),false);}
  assert.equal(g.fireworksFired,count);assert.equal(sounds,count);assert.ok(max<=2);assert.equal(g.fireworks.length,0);assert.equal(g.score,score+remaining*50+count*500);const end=g.score;g.presentationStep();assert.equal(g.score,end);assert.equal(g.advanceStage(),true);assert.equal(g.stage,11);assert.equal(g.fireworksTotal,0);
 }
 for(const stage of [2,4,6,8,12,14,16]){const g=new World11(stage);g.frames=(400-336)*24-1;g.p.x=196*16;g.p.y=180;g.step();assert.equal(g.phase,'won');assert.equal(g.fireworksTotal,0);}
});

test('3-3 predictions isolate cloud pursuit, eggs and retry counters',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(11);g.p.x=384;g.p.y=170;g.camera=288;const before=JSON.stringify(g.snapshot());const future=advance(clone(g),'noop',8);assert.ok(future.enemies.some(e=>e.kind==='spiny-egg'));assert.equal(JSON.stringify(g.snapshot()),before);
});


test('1-4 and 3-4 have real boss collisions, axe rescue, retry and campaign endpoints',()=>{
 for(const stage of [4,8,12]){
  const g=new World11(stage);assert.equal(g.room,'castle');assert.equal(g.boss.hp,5);assert.equal(g.snapshot().stage,4);
  g.camera=180*16;g.p.x=184*16;g.p.y=176;g.invincible=30;g.step();assert.ok(g.bossFlames.length);
  g.p.x=196*16;g.p.y=176;g.step();assert.equal(g.phase,'won');for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.rescued,true);assert.equal(g.boss.dead,true);assert.equal(g.tile(180,12),undefined);assert.equal(g.peachRescued,false);assert.equal(g.fireworksTotal,0);assert.equal(g.advanceStage(),true);
  g.stage=stage;g.reset();g.boss.hp=1;g.die();for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.restartLife(),true);assert.equal(g.boss.hp,5);assert.equal(g.lives,2);assert.equal(g.rescued,false);
  g.camera=180*16;g.p.x=g.boss.x;g.p.y=g.boss.y;g.step();assert.equal(g.phase,'dead');
 }
 const third=new World11(12);assert.equal(third.tile(28,13),undefined);assert.ok(third.fireBars.some(b=>b.length===5));assert.notDeepEqual(third.lava,new World11(4).lava);
});

test('Buzzy Beetle stomps into a fireproof kickable shell, but star and shells defeat it',()=>{
 assert.equal(new World11(2).enemies.filter(e=>e.kind==='beetle').length,3);
 const fixture=()=>{const g=new World11();g.enemies=[{x:40,y:192,w:14,h:16,vx:0,vy:0,kind:'beetle',armored:true,dead:0}];return g;};
 const hit=fixture();hit.step();assert.equal(hit.phase,'dead');
 const stomp=fixture();stomp.p.y=175;stomp.p.vy=2;stomp.step();assert.equal(stomp.enemies[0].kind,'shell');assert.equal(stomp.enemies[0].vx,0);assert.equal(stomp.enemies[0].armored,true);
 stomp.p.y=192;stomp.p.x=30;stomp.p.vy=0;stomp.step();assert.equal(stomp.enemies[0].vx,4);assert.equal(stomp.phase,'playing');
 for(const kind of ['beetle','shell']){const fire=fixture();fire.p.x=0;fire.enemies[0].kind=kind;fire.shots=[{x:40,y:194,w:4,h:4,vx:1,vy:0}];fire.step();assert.equal(fire.enemies[0].dead,0);assert.equal(fire.shots.length,0);}
 const star=fixture();star.star=30;star.step();assert.equal(star.enemies[0].dead,1);
 const shell=fixture();shell.p.x=0;shell.enemies.push({x:25,y:192,w:14,h:16,vx:4,vy:0,kind:'shell',dead:0});shell.step();assert.equal(shell.enemies[0].dead,1);
});

test('plants emerge from valid pipes, wait nearby, retract, and hide from observations',()=>{
 const g=new World11(5),plants=g.enemies.filter(e=>e.kind==='piranha');assert.equal(plants.length,6);const e=plants[0];g.enemies=[e];g.p.x=e.x;g.p.y=e.pipeY-16;g.camera=e.x-96;g.step();assert.equal(e.age,0);assert.equal(e.hidden,true);assert.equal(g.snapshot().enemies.length,0);assert.equal(g.phase,'playing');
 g.p.x=e.x-70;g.p.y=192;for(let i=0;i<48;i++)g.step();assert.equal(e.h,24);assert.equal(e.y,e.pipeY-24);assert.equal(e.hidden,false);assert.ok(g.snapshot().enemies.some(n=>n.kind==='piranha'));
 for(let i=48;i<240;i++)g.plantStep(e);assert.equal(e.age,0);assert.equal(e.h,0);g.p.x=e.x;g.plantStep(e);assert.equal(e.age,0);
});

test('exposed plants cannot be stomped, while fire and star defeat them',()=>{
 const fixture=()=>{const g=new World11();const e={x:40,y:184,w:16,h:24,vx:0,vy:0,pipeY:208,age:70,hidden:false,kind:'piranha',dead:0};g.enemies=[e];return g;};
 const stomp=fixture();stomp.p.x=40;stomp.p.y=168;stomp.p.vy=2;stomp.step();assert.equal(stomp.phase,'dead');assert.equal(stomp.enemies[0].dead,0);
 const fire=fixture();fire.p.x=0;fire.shots=[{x:40,y:190,w:4,h:4,vx:1,vy:0}];fire.step();assert.equal(fire.enemies[0].dead,1);
 const star=fixture();star.star=30;star.step();assert.equal(star.enemies[0].dead,1);
});

test('plant timers and third castle boss states remain isolated in planner clones',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');
 for(const stage of [2,12]){const g=new World11(stage);g.p.x=stage===2?370:184*16;g.p.y=176;g.camera=g.p.x-96;g.invincible=30;const before=JSON.stringify(g.snapshot());const future=advance(clone(g),'noop',8);assert.equal(JSON.stringify(g.snapshot()),before);assert.equal(future.frames,8);if(stage===2)assert.ok(future.enemies.find(e=>e.kind==='piranha').age>0);else assert.ok(future.boss.active>0);}
});


test('4-1 daytime course has Lakitu, pipe plants, distinct layout and final flag fireworks',()=>{
 const g=new World11(13);assert.deepEqual(courseInfo(13),{world:4,stage:1,label:'4-1'});assert.equal(g.room,'overworld');assert.equal(g.tile(63,13),undefined);assert.equal(g.tile(28,11),'pipe-top');assert.equal(g.enemies.filter(e=>e.kind==='lakitu').length,1);assert.equal(g.enemies.filter(e=>e.kind==='piranha').length,6);assert.equal(g.boss,null);
 g.p.x=384;g.camera=288;g.invincible=300;g.step();assert.ok(g.enemies.some(e=>e.kind==='spiny-egg'));assert.equal(g.telemetry().world,4);assert.equal(g.telemetry().stage,1);
 g.frames=(400-336)*24-1;g.p.x=198*16;g.p.y=160;g.step();assert.equal(g.phase,'won');assert.equal(g.fireworksTotal,6);assert.ok(!g.enemies.some(e=>e.kind==='lakitu'));
 for(let i=0;i<g.presentationLength();i++)g.presentationStep();assert.equal(g.fireworksFired,6);assert.equal(g.peachRescued,false);assert.equal(g.advanceStage(),true);assert.equal(g.stage,14);
 g.stage=13;g.reset();assert.equal(g.frames,0);assert.equal(g.enemies.find(e=>e.kind==='lakitu').active,false);
});

test('all castles lava fireballs rise, turn, sink and wait without leaving lava columns',()=>{
 for(const stage of [4,8,12]){
  const g=new World11(stage),f=g.lavaBubbles[0];assert.equal(g.lavaBubbles.length,5);assert.ok(g.lava.some(([a,b])=>f.x>=a*16&&f.x+f.w<=(b+1)*16));
  g.camera=f.x-100;g.p.x=f.x-80;f.timer=1;const x=f.x;let min=232,falling=false,wasVisible=false;
  for(let i=0;i<90;i++){g.lavaBubbleStep();min=Math.min(min,f.y);falling||=f.active&&f.vy>0;wasVisible||=f.active&&f.y<220;assert.equal(f.x,x);}
  assert.ok(min<120);assert.ok(falling&&wasVisible);assert.equal(f.active,false);assert.equal(f.y,232);assert.ok(f.timer>0);
  const before=JSON.stringify(g.lavaBubbles);g.phase='dead';g.lavaBubbleStep();assert.equal(JSON.stringify(g.lavaBubbles),before);g.reset();assert.equal(g.lavaBubbles[0].timer,30);
 }
});

test('lava fireballs hurt from any direction, respect power and invincibility, and disappear from observations while submerged',()=>{
 const fixture=()=>{const g=new World11(4),f=g.lavaBubbles[0];g.camera=f.x-100;g.p.x=f.x;g.p.y=150;Object.assign(f,{active:true,y:150,vy:0});return [g,f];};
 let [g,f]=fixture();g.lavaBubbleStep();assert.equal(g.phase,'dead');assert.equal(g.lives,2);
 [g,f]=fixture();g.power=1;g.lavaBubbleStep();assert.equal(g.power,0);assert.equal(g.invincible,120);assert.equal(g.phase,'playing');
 for(const key of ['star','invincible']){[g,f]=fixture();g[key]=30;g.lavaBubbleStep();assert.equal(g.phase,'playing');assert.equal(f.active,true);}
 [g,f]=fixture();g.enemies=[];g.boss=null;assert.equal(g.telemetry().enemies.length,1);f.active=false;assert.equal(g.telemetry().enemies.length,0);
});

test('lava fireball clone predictions cannot mutate the live timer or motion; rescue clears hazards',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(12),f=g.lavaBubbles[0];g.p.x=f.x-80;g.camera=g.p.x-96;g.invincible=300;f.timer=1;const before=JSON.stringify(g.snapshot());const a=advance(clone(g),'noop',8),b=advance(clone(g),'noop',8);assert.equal(JSON.stringify(g.snapshot()),before);assert.equal(JSON.stringify(a.snapshot()),JSON.stringify(b.snapshot()));assert.ok(a.lavaBubbles[0].active);
 g.p.x=196*16;g.p.y=176;g.step();assert.equal(g.phase,'won');assert.ok(g.lavaBubbles.every(h=>!h.active));
 for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.rescued,true);assert.equal(g.advanceStage(),true);assert.equal(g.stage,13);assert.deepEqual(g.lavaBubbles,[]);
});


test('4-2 underground has lifts, beetles, plants and winged Koopas with a terminal tunnel',()=>{
 const g=new World11(14);assert.deepEqual(courseInfo(14),{world:4,stage:2,label:'4-2'});assert.equal(g.room,'stage-underground');assert.equal(g.lifts.length,3);assert.equal(g.tile(56,13),undefined);assert.equal(g.tile(10,2),'brick');assert.equal(g.enemies.filter(e=>e.kind==='paratroopa').length,2);assert.equal(g.enemies.filter(e=>e.kind==='beetle').length,3);assert.equal(g.enemies.filter(e=>e.kind==='piranha').length,4);
 g.p.x=196*16;g.p.y=180;g.step();assert.equal(g.phase,'won');assert.equal(g.fireworksTotal,0);assert.ok(g.drainSounds().includes('pipe'));for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.advanceStage(),true);assert.equal(g.stage,15);assert.equal(g.peachRescued,false);g.stage=14;g.reset();assert.equal(g.p.x,32);assert.equal(g.lifts[0].y,176);
});

test('lifts catch a falling player, carry in both directions and release a jump',()=>{
 for(const direction of [-1,1]){
  const g=new World11(14);g.enemies=[];const l=g.lifts[0];l.direction=direction;g.p.x=l.x+8;g.p.y=l.y-18;g.p.vy=3;g.p.grounded=false;g.camera=g.p.x-96;g.step();assert.equal(g.p.liftId,l.id);assert.equal(g.p.y+g.p.h,l.y);assert.equal(g.p.grounded,true);
  const start=g.p.y;for(let i=0;i<10;i++)g.step();assert.equal(g.p.liftId,l.id);assert.equal(g.p.y+g.p.h,l.y);assert.equal(Math.sign(g.p.y-start),direction);
  g.input={jump:true};g.step();assert.equal(g.p.liftId,undefined);assert.ok(g.p.vy<0);assert.ok(g.p.y+g.p.h<l.y);assert.equal(g.p.grounded,false);
 }
});

test('lifts are one-way, walking off falls, and ceiling pressure reverses safely',()=>{
 const g=new World11(14);g.enemies=[];const l=g.lifts[0];g.p.x=l.x+8;g.camera=g.p.x-96;g.p.y=l.y+4;g.p.vy=-2;g.p.grounded=false;g.input={jump:true};g.wasJump=true;g.step();assert.equal(g.p.liftId,undefined);
 Object.assign(g.p,{x:l.x+l.w-1,y:l.y-16,vx:2.6,vy:0,grounded:true,liftId:l.id});g.input={right:true,run:true};g.step();assert.equal(g.p.liftId,undefined);assert.equal(g.p.grounded,false);
 Object.assign(l,{y:80,minY:64,direction:-1});Object.assign(g.p,{x:l.x+8,y:64,vx:0,vy:0,grounded:true,liftId:l.id});g.input={};g.step();assert.equal(l.y,80);assert.equal(l.direction,1);assert.equal(g.p.y,64);assert.equal(g.phase,'playing');
});

test('lift motion is bounded, visible to observations and isolated in prediction clones',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11(14);g.enemies=[];const l=g.lifts[0];g.p.x=l.x+8;g.camera=g.p.x-96;g.p.y=l.y-16;g.p.grounded=true;g.p.liftId=l.id;const before=JSON.stringify(g.snapshot());const a=advance(clone(g),'noop',8),b=advance(clone(g),'noop',8);assert.equal(JSON.stringify(g.snapshot()),before);assert.equal(JSON.stringify(a.snapshot()),JSON.stringify(b.snapshot()));assert.notEqual(a.lifts[0].y,l.y);
 const row=Math.floor(l.y/16)-2;assert.equal(g.telemetry().tiles[row*9+2],84);g.p.x=32;delete g.p.liftId;for(let i=0;i<600;i++)g.liftStep();assert.ok(g.lifts.every(n=>n.y>=n.minY&&n.y<=n.maxY));g.phase='dead';const frozen=JSON.stringify(g.lifts);g.liftStep();assert.equal(JSON.stringify(g.lifts),frozen);
});

test('winged Koopas hop, lose wings on a stomp, then become kickable shells',()=>{
 const g=new World11(14),e=g.enemies.find(n=>n.kind==='paratroopa');g.enemies=[e];g.p.x=e.x-80;g.camera=g.p.x-96;g.step();assert.ok(e.vy<0);const y=e.y;g.step();assert.ok(e.y<y);
 Object.assign(e,{x:640,y:192,vx:0,vy:0});Object.assign(g.p,{x:640,y:175,vy:2,vx:0,grounded:false});g.step();assert.equal(e.kind,'koopa');assert.equal(e.dead,0);assert.ok(g.p.vy<0);
 Object.assign(e,{y:192,vy:0});Object.assign(g.p,{x:e.x,y:175,vy:2,vx:0,grounded:false});g.step();assert.equal(e.kind,'shell');assert.equal(e.vx,0);
 Object.assign(g.p,{x:e.x-10,y:192,vy:0,vx:0});g.step();assert.equal(e.vx,4);assert.equal(g.phase,'playing');
});


test('4-3 high course and 4-4 castle progress with lives retained, final rescue ends campaign',()=>{
 const g=new World11(15);assert.equal(g.lifts.length,2);assert.equal(g.contents.get('12,9'),'vine');assert.equal(g.tile(31,13),undefined);assert.equal(g.enemies.filter(e=>e.kind==='paratroopa').length,3);g.lives=5;g.p.x=198*16;g.p.y=160;g.step();assert.equal(g.phase,'won');for(let i=0;i<g.presentationLength();i++)g.presentationStep();assert.equal(g.advanceStage(),true);assert.equal(g.stage,16);assert.equal(g.lives,5);assert.equal(g.room,'castle');assert.equal(g.boss.hp,5);assert.equal(g.lifts.length,3);assert.equal(g.tile(40,8),'castle');g.camera=180*16;g.p.x=184*16;g.p.y=176;g.invincible=100;g.step();assert.ok(g.bossFlames.length);g.p.x=196*16;g.p.y=176;g.step();assert.equal(g.phase,'won');assert.equal(g.fireworksTotal,0);for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.rescued,true);assert.equal(g.advanceStage(),true);assert.equal(g.stage,17);
});
test('beanstalk grows once, supports up/down climbing and jump release, resets with life',()=>{
 const g=new World11(15);g.enemies=[];g.hitBlock(12,9);g.hitBlock(12,9);assert.equal(g.vines.length,1);assert.equal(g.items.length,0);for(let i=0;i<120;i++)g.vineStep();assert.equal(g.vines[0].top,40);
 Object.assign(g.p,{x:192,y:100,vy:0,vx:0,grounded:false});g.input={up:true};g.step();assert.equal(g.p.climbing,true);assert.ok(g.p.y<100);const y=g.p.y;g.input={down:true};g.step();assert.ok(g.p.y>y);g.input={jump:true,right:true};g.step();assert.equal(g.p.climbing,false);assert.ok(g.p.vy<0);g.die();for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.restartLife(),true);assert.deepEqual(g.vines,[]);assert.equal(g.contents.get('12,9'),'vine');
});
test('stationary shells can be held, follow direction and thrown, moving shells cannot be grabbed',()=>{
 const g=new World11();g.enemies=[{x:48,y:192,w:14,h:16,vx:0,vy:0,kind:'shell',dead:0}];const e=g.enemies[0];g.input={carry:true};g.step();assert.equal(e.carried,true);assert.equal(g.phase,'playing');g.input={carry:true,left:true};g.step();assert.ok(e.x<g.p.x);assert.equal(g.telemetry().enemies.length,0);g.input={};g.step();assert.equal(e.carried,false);assert.equal(e.vx,-4);assert.ok(e.vy<0);assert.equal(g.phase,'playing');assert.ok(e.ownerGrace>0);
 const h=new World11();h.enemies=[{x:48,y:192,w:14,h:16,vx:-4,vy:0,kind:'shell',dead:0}];h.input={carry:true};h.step();assert.ok(!h.enemies[0].carried);
});
test('thrown shell defeats enemies, death releases it and prediction clones do not mutate held shells',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const g=new World11();g.enemies=[{x:48,y:192,w:14,h:16,vx:0,vy:0,kind:'shell',dead:0},{x:68,y:188,w:14,h:16,vx:0,vy:0,kind:'goomba',dead:0}];g.input={carry:true};g.step();const before=JSON.stringify(g.snapshot());advance(clone(g),'right',4);assert.equal(JSON.stringify(g.snapshot()),before);g.input={};for(let i=0;i<5;i++)g.step();assert.equal(g.enemies[1].dead,1);
 const d=new World11();d.enemies=[{x:48,y:192,w:14,h:16,vx:0,vy:0,kind:'shell',carried:true,dead:0}];d.die();assert.equal(d.enemies[0].carried,false);
});
test('item seeking chooses a reachable block and avoids missing terrain; planner actually collects powerups',async()=>{
 const {itemIntent}=await import('../../web/labs/jev-mario/item-goal.mjs');const {plan,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');
 const g=new World11();g.enemies=[];g.p.x=21*16;assert.equal(itemIntent(g),'jump');for(let x=20;x<24;x++)for(let y=13;y<15;y++)g.cells.delete(`${x},${y}`);assert.equal(itemIntent(g),null);
 for(const kind of ['mushroom','flower','life','star']){const h=new World11();h.enemies=[];h.items=[{x:52,y:192,w:14,h:16,vx:0,vy:0,emerging:0,kind}];const start=JSON.stringify(h.snapshot());const choice=plan(h);assert.equal(JSON.stringify(h.snapshot()),start);advance(h,choice.action,32);assert.equal(h.pickups[kind],1,kind);assert.equal(h.phase,'playing');}
});
test('powerup pickups preserve fire power, record 1UP/star and never collect after death',()=>{
 const g=new World11();g.enemies=[];g.power=2;g.items=[{x:32,y:192,w:14,h:16,vx:0,vy:0,emerging:0,kind:'mushroom'}];g.step();assert.equal(g.power,2);assert.equal(g.pickups.mushroom,1);
 const d=new World11();d.enemies=[{x:40,y:192,w:14,h:16,vx:0,vy:0,kind:'goomba',dead:0}];d.items=[{x:32,y:192,w:14,h:16,vx:0,vy:0,emerging:0,kind:'life'}];d.step();assert.equal(d.phase,'dead');assert.equal(d.lives,2);assert.equal(d.pickups.life,0);
});


test('Jev local assistance holds an item jump long enough to open a powerup block',async()=>{
 const {ReactionAssist}=await import('../../web/labs/jev-mario/reaction.mjs');const g=new World11(),a=new ReactionAssist();g.enemies=[];g.p.x=21*16;a.reset();let itemDecision=false;
 for(let i=0;i<35;i++){const d=a.decide(g,'right');itemDecision||=d.reason==='local_item';g.buttons(d.action);g.step();}
 assert.equal(itemDecision,true);assert.equal(g.tile(21,9),'used');assert.ok(g.items.some(i=>i.kind==='mushroom'));
});

test('fifth world maps, enemy roster, retries, castle rescue and final boundary',()=>{
 const layouts=[];
 for(const id of [17,18,19,20]){
  const g=new World11(id);assert.equal(g.telemetry().world,5);assert.equal(g.telemetry().stage,id-16);assert.ok(g.enemies.every(e=>Number.isFinite(e.x)&&Number.isFinite(e.y)));layouts.push(JSON.stringify([...g.cells]));
  g.score=2500;g.die();for(let i=0;i<180;i++)g.presentationStep();assert.equal(g.restartLife(),true);assert.equal(g.stage,id);assert.equal(g.p.x,32);assert.equal(g.lives,2);assert.equal(g.score,2500);
  g.invincible=500;g.p.x=(id===20?196:198)*16;g.p.y=id===20?176:160;g.step();assert.equal(g.phase,'won');for(let i=0;i<220;i++)g.presentationStep();
  if(id===20){assert.equal(g.rescued,true);assert.equal(g.peachRescued,false);assert.equal(g.fireworksTotal,0);assert.equal(g.advanceStage(),true);}else{assert.equal(g.advanceStage(),true);assert.equal(g.stage,id+1);}
 }
 assert.equal(new Set(layouts).size,4);
 const a=new World11(17);for(const kind of ['goomba','koopa','beetle','piranha','paratroopa'])assert.ok(a.enemies.some(e=>e.kind===kind),kind);assert.equal(a.cannons.length,3);
 const b=new World11(18);assert.ok(b.enemies.some(e=>e.kind==='hammer-bro'));assert.equal(b.contents.get('35,9'),'vine');assert.ok(b.lifts.length);
 const c=new World11(19);assert.ok(c.enemies.some(e=>e.kind==='lakitu'));assert.ok(c.enemies.some(e=>e.kind==='paratroopa'));assert.equal(c.lifts.length,3);
 const d=new World11(20);assert.ok(d.boss);assert.ok(d.lavaBubbles.length);assert.ok(d.fireBars.length);
});

test('sixth world has four finite distinct routes and onward progression',()=>{
 const layouts=[];for(const id of [21,22,23,24]){const g=new World11(id);assert.equal(g.stage,id);assert.equal(g.telemetry().world,6);assert.ok(g.enemies.every(e=>Number.isFinite(e.x)&&Number.isFinite(e.y)));layouts.push(JSON.stringify([...g.cells]));g.score=500;g.lives=2;g.phase='won';g.presentation=g.presentationLength();assert.equal(g.advanceStage(),true);if(id<24){assert.equal(g.score,500);assert.equal(g.lives,2);}}
 assert.equal(new Set(layouts).size,4);const g=new World11(24);g.phase='won';for(let i=0;i<100;i++)g.presentationStep();assert.equal(g.peachRescued,false);assert.equal(g.rescued,true);
});
test('seventh world has four finite distinct routes and onward rescue',()=>{
 const layouts=[];for(const id of [25,26,27,28]){const g=new World11(id);assert.equal(g.stage,id);assert.equal(g.telemetry().world,7);assert.ok(g.enemies.every(e=>Number.isFinite(e.x)&&Number.isFinite(e.y)));layouts.push(JSON.stringify([...g.cells]));g.score=500;g.lives=2;g.phase='won';g.presentation=g.presentationLength();assert.equal(g.advanceStage(),true);if(id<28){assert.equal(g.score,500);assert.equal(g.lives,2);}}
 assert.equal(new Set(layouts).size,4);const g=new World11(28);g.phase='won';for(let i=0;i<100;i++)g.presentationStep();assert.equal(g.peachRescued,false);assert.equal(g.rescued,true);
});

test('seventh world uses water physics, fish bridges and active cannon hazards',()=>{
 const g=new World11(25);assert.ok(g.enemies.some(e=>e.kind==='hammer-bro'));assert.ok(g.enemies.some(e=>e.kind==='beetle'));assert.ok(g.cannons.every(c=>Number.isFinite(c.timer)));assert.ok([...g.contents.values()].includes('vine'));
 const w=new World11(26);assert.equal(w.room,'underwater');assert.ok(w.enemies.some(e=>e.kind==='squid'));assert.ok(w.enemies.some(e=>e.kind==='fish'));w.buttons('jump');for(let i=0;i<5;i++)w.step();assert.ok(w.p.y<128);
 const b=new World11(27);assert.ok(b.enemies.every(e=>e.kind==='leaping-fish'));assert.ok(b.lifts.length);const c=new World11(28);assert.ok(c.boss&&c.fireBars.length&&c.lavaBubbles.length);
});


test('world 8 courses preserve retry, stage transitions and final rescue',()=>{
 for(const id of [29,30,31,32]){const g=new World11(id);assert.equal(g.snapshot().label,`8-${id-28}`);assert.ok(g.enemies.every(e=>Number.isFinite(e.x)&&Number.isFinite(e.y)));assert.ok(g.contents.size);g.score=100;g.die();for(let f=0;f<180;f++)g.presentationStep();assert.equal(g.restartLife(),true);assert.equal(g.lives,2);assert.equal(g.score,100);assert.equal(g.stage,id);assert.equal(g.p.x,32);g.p.x=(id===32?196:198)*16;g.p.y=id===32?176:160;g.step();assert.equal(g.phase,'won');for(let f=0;f<300;f++)g.presentationStep();if(id===32){assert.equal(g.peachRescued,true);assert.equal(g.advanceStage(),false);}else{assert.equal(g.advanceStage(),true);assert.equal(g.stage,id+1);}}
 const a=new World11(29),b=new World11(30),c=new World11(31),d=new World11(32);assert.notDeepEqual([...a.cells],[...b.cells]);assert.ok(b.enemies.some(e=>e.kind==='lakitu'));assert.ok(c.enemies.some(e=>e.kind==='hammer-bro'));assert.ok(d.boss&&d.fireBars.length&&d.lavaBubbles.length);
});


// Compare planning labels with the actual block emission, rather than a mock reward.
import {itemTargets} from '../../web/labs/jev-mario/item-goal.mjs';
import {skyLevel} from '../../web/labs/jev-mario/world11.mjs';
test('power-up block targets match the flower actually emitted for a big player',()=>{
 for(const power of [0,1,2]){const g=new World11();g.power=power;g.p.x=21*16;g.camera=0;const target=itemTargets(g).find(t=>t.key==='21,9');assert.ok(target);assert.equal(target.kind,power?'flower':'mushroom');g.hitBlock(21,9);assert.equal(g.items.at(-1).kind,target.kind);}
});
test('first sky jumps progress from a wide landing to a narrower landing',()=>{
 const g=skyLevel(),count=(a,b,y)=>Array.from({length:b-a+1},(_,i)=>g.cells.get(`${a+i},${y}`)).filter(Boolean).length;
 assert.equal(count(20,29,12),10);assert.equal(count(32,41,10),8);assert.equal(g.cells.get('40,10'),undefined);assert.equal(g.cells.get('44,11'),'platform');
});

import {world21Level} from '../../web/labs/jev-mario/world11.mjs';
test('optional gap rewards leave the lower crossing and pit intact',()=>{
 const g=world21Level();for(const x of [44,45,46]){assert.equal(g.contents.get(`${x},8`),'loose');assert.equal(g.cells.get(`${x},8`),undefined);assert.equal(g.cells.get(`${x},13`),undefined);}
 assert.equal(g.cells.get('43,13'),'ground');assert.equal(g.cells.get('47,13'),'ground');
});
test('an exposed flower outranks a nearby unopened power-up block',()=>{
 const g=new World11();g.power=1;g.p.x=21*16;g.camera=0;g.items.push({x:g.p.x+35,y:g.p.y,kind:'flower',taken:false});assert.equal(itemTargets(g)[0].block,false);assert.equal(itemTargets(g)[0].kind,'flower');
});

test('3-3 elevated approach guards a fall beyond the former 24-frame horizon',async()=>{
 const {clone,advance}=await import('../../web/labs/jev-mario/search-assist.mjs');const {LiveGuard}=await import('../../web/labs/jev-mario/live-guard.mjs');
 const g=new World11(11);g.enemies=[];g.contents.clear();Object.assign(g.p,{x:1296,y:144,vx:2.3,vy:0,grounded:true});g.camera=1200;
 assert.equal(advance(clone(g),'right',24).phase,'playing');assert.equal(advance(clone(g),'right',64).phase,'dead');
 const before=JSON.stringify(g.snapshot()),guard=new LiveGuard(),action=guard.decide(g,'right');assert.notEqual(action,'right');assert.equal(JSON.stringify(g.snapshot()),before);assert.equal(advance(clone(g),action,64).phase,'playing');assert.equal(guard.lastReason,'live_collision_guard');
});

import {pipeRoute} from '../../web/labs/jev-mario/pipe-route.mjs';
test('bonus room reward can be collected and the return preserves the main course',async()=>{
 const {advance}=await import('../../web/labs/jev-mario/search-assist.mjs');
 for(const power of [0,1]){
  const g=new World11();g.power=power;g.p.h=power?28:16;Object.assign(g.p,{x:57*16+8,y:144-g.p.h,grounded:true});
  const cells=g.cells,contents=g.contents;assert.equal(g.enterRoom(),true);
  assert.equal(g.items[0].kind,power?'flower':'mushroom');assert.equal(g.contents.size,19);assert.equal(g.tile(0,1),undefined);assert.equal(g.tile(0,4),'brick');assert.equal(g.p.y,80);
  for(let n=0;n<300&&g.room==='underground';n++)advance(g,pipeRoute(g)??'right_jump',8);
  assert.equal(g.pickups[power?'flower':'mushroom'],1);assert.equal(g.room,'overworld');
  assert.equal(g.cells,cells);assert.equal(g.contents,contents);assert.equal(g.phase,'playing');
 }
});
