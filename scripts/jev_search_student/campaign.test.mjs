import test from 'node:test';
import assert from 'node:assert/strict';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {tick,finished,cleared} from './campaign.mjs';
import {features2,FEATURE_COUNT} from '../../web/labs/jev-mario/student2-features.mjs';
import {predict2} from '../../web/labs/jev-mario/student2-predict.mjs';

test('a cleared 1-1 presents for 180 frames, then continues on 1-2 with carried state',()=>{
 const g=new World11(1);g.clock=0;g.stageResults=[];g.coins=7;
 // Touch the pole above its solid base.
 Object.assign(g.p,{x:198*16,y:120,vy:0,grounded:false});tick(g,'right',2);assert.equal(g.phase,'won');assert.equal(g.stageResults.length,1);
 assert.equal(finished(g,2),false);
 for(let i=0;i<180;i++)tick(g,'noop',2);
 assert.equal(g.stage,2);assert.equal(g.phase,'playing');assert.equal(g.coins,7);assert.equal(g.clock,181);
 assert.equal(features2(g).length,FEATURE_COUNT);
 g.p.x=196*16;tick(g,'right',2);assert.equal(cleared(g,2),true);assert.equal(finished(g,2),true);
 const dead=new World11(1);dead.p.y=260;tick(dead,'noop',2);assert.equal(finished(dead,2),true);assert.equal(cleared(dead,2),false);
});

test('compact multiclass trees follow <= thresholds and softmax scores',()=>{
 const model={classes:['a','b'],trees:[{n:[[0,.5,-1,-2]],l:[1,-1]},{n:[],l:[.25]}]};
 assert.equal(predict2(model,[0]).action,'a');assert.equal(predict2(model,[1]).action,'b');
 assert.ok(Math.abs(predict2(model,[.5]).probabilities.reduce((a,b)=>a+b,0)-1)<1e-12);
});
