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
