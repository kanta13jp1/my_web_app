import {test} from 'node:test';import assert from 'node:assert/strict';import {score} from '../../web/labs/abstention-score/model.mjs';
test('denominators and penalty',()=>{const x=[...Array(22).fill('C'),...Array(26).fill('E'),...Array(52).fill('A')].join(' ');assert.equal(score(x,1).score,-.04);assert.equal(score(x,0).score,.22);assert.equal(score(x,1).answeredError,26/48);});
test('empty and abstention do not fabricate answered accuracy',()=>{assert.equal(score('',1).error,null);assert.equal(score('A A',1).answeredError,null);assert.equal(score('A A',1).error,0);assert.equal(score('C C',1).accuracy,1);});
test('invalid labels and penalty rejected',()=>{assert.throws(()=>score('C ?',1));for(const p of [-1,NaN,Infinity,'1',null])assert.throws(()=>score('C',p));});
