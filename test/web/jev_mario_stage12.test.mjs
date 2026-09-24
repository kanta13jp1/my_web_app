import test from 'node:test';
import assert from 'node:assert/strict';
import {World11,undergroundLevel} from '../../web/labs/jev-mario/world11.mjs';
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
 g.phase='won';g.presentation=180;assert.equal(g.advanceStage(),false);assert.equal(g.stage,3);
});
test('sky course has elevated platforms, gaps, collectibles and a distinct finish',()=>{
 const g=new World11(3);assert.equal(g.telemetry().stage,3);assert.equal(g.tile(20,12),'platform');assert.equal(g.tile(30,13),undefined);
 assert.ok(g.contents.size>30);assert.ok(g.enemies.every(e=>Number.isFinite(e.y)));
 g.p.x=32*16;g.p.y=100;g.p.vy=3;for(let i=0;i<30;i++)g.step();assert.equal(g.p.y+g.p.h,160);
 const fall=new World11(3);fall.p.x=30*16;fall.p.y=240;for(let i=0;i<20;i++)fall.step();assert.equal(fall.phase,'dead');
 const win=new World11(3);win.p.x=198*16;win.step();assert.equal(win.phase,'won');
});
