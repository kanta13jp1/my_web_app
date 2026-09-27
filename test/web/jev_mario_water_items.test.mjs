import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {plan,edge} from '../../web/labs/jev-mario/search-assist.mjs';
import {features,ACTIONS} from '../../web/labs/jev-mario/student-features.mjs';
import {predict} from '../../web/labs/jev-mario/student-predict.mjs';
import model from '../../web/labs/jev-mario/student-model.mjs';
const results=[];
function run(g,limit=4000){let action='noop',decisions=0;while(g.phase==='playing'&&g.frames<limit){if(g.frames%8===0){const raw=ACTIONS[predict(model,features(g)).index];action=plan(g,raw).action;decisions++;}g.buttons(edge(g,action));g.step();g.drainSounds();}const result={stage:g.stage,phase:g.phase,x:g.p.x,y:g.p.y,frames:g.frames,pickups:g.pickups,decisions};results.push(result);mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-water-items.json',JSON.stringify(results,null,2));return result;}
test('LightGBM plus search clears both complete underwater courses',()=>{for(const stage of [6,26]){const g=new World11(stage);const r=run(g);assert.equal(r.phase,'won',JSON.stringify(r));}});
test('water search recovers the reported overshot exit instead of continuing offscreen',()=>{const g=new World11(6);g.p.x=4339;g.p.y=77;g.camera=g.width-256;const r=run(g,300);assert.equal(r.phase,'won',JSON.stringify(r));assert.ok(g.p.x<=g.width-g.p.w);});
test('LightGBM plus search reveals and collects an actual 1-1 mushroom',()=>{const g=new World11();g.p.x=280;g.camera=184;const r=run(g,700);assert.ok(r.pickups.mushroom>0,JSON.stringify(r));});
test('search collects reachable flower, 1UP and star instead of ignoring them',()=>{for(const kind of ['flower','life','star']){const g=new World11();g.enemies=[];g.p.x=64;g.camera=0;g.contents.clear();g.items=[{kind,x:96,y:192,w:14,h:16,emerging:0,vx:kind==='flower'?0:1,vy:0}];const r=run(g,100);assert.ok(r.pickups[kind]>0,JSON.stringify(r));}});
