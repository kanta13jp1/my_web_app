import {test} from 'node:test';import assert from 'node:assert/strict';import {compare} from '../../web/labs/instruction-check/model.mjs';
test('exact token comparison and absent observations',()=>{assert.deepEqual(compare('A B','A AB',0).rows,[{mark:'A',seen:true},{mark:'B',seen:false}]);assert.equal(compare('A','',0).rows[0].seen,false);});
test('tool activity preserves evidence limitation',()=>{assert.match(compare('A','A',1).scope,/除外できません/);});
test('invalid expectations and counts rejected',()=>{for(const x of ['', 'A A'])assert.throws(()=>compare(x,'A',0));for(const n of [-1,NaN,Infinity,.5])assert.throws(()=>compare('A','A',n));});
