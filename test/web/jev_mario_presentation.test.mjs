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
