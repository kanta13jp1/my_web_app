import test from 'node:test';
import assert from 'node:assert/strict';
import {decisionView} from '../../web/labs/jev-mario/presentation.mjs';
test('unmeasured or incomplete model output never becomes fake confidence',()=>{
 assert.equal(decisionView().probabilities,null);
 assert.equal(decisionView({probabilities:{right:1}}).probabilities,null);
 assert.equal(decisionView({latency:NaN}).latency,null);
 const p=[.1,.2,.1,.2,.1,.2,.1];
 assert.deepEqual(decisionView({probabilities:p,latency:0}).probabilities,p);
 assert.equal(decisionView({latency:0}).latency,0);
});

test('presentation labels the second world consistently without altering game state',async()=>{
 const {drawPresentation}=await import('../../web/labs/jev-mario/presentation.mjs');const {World11}=await import('../../web/labs/jev-mario/world11.mjs');const g=new World11(5),texts=[],ctx={fillRect(){},drawImage(){},fillText(s){texts.push(s);}};
 drawPresentation(ctx,{width:256,height:240},{world:g});assert.ok(texts.some(t=>t.startsWith('World 2-1')));assert.ok(!texts.some(t=>t.includes('World 1-5')));assert.equal(g.frames,0);
});

test('success feedback is visual-only, emits once and expires while rewards remain',async()=>{
 const {World11}=await import('../../web/labs/jev-mario/world11.mjs');const g=new World11();
 g.collectCoin();assert.equal(g.effects.filter(f=>f.kind==='feedback').length,1);assert.deepEqual(g.drainSounds(),['coin']);
 for(let i=0;i<20;i++)g.step();assert.equal(g.effects.filter(f=>f.kind==='feedback').length,0);assert.equal(g.coins,1);assert.equal(g.score,200);assert.equal(g.lives,3);
 const e={x:100,y:100,w:14,h:16,dead:0};g.defeat(e);g.defeat(e);assert.equal(g.effects.filter(f=>f.kind==='feedback').length,1);assert.equal(g.score,300);
 g.hitBlock(21,9);assert.equal(g.items.length,1);assert.equal(g.phase,'playing');
});
