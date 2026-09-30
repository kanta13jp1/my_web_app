import test from 'node:test';import assert from 'node:assert/strict';import {compactRequest} from './compact.mjs';
test('terrain packing preserves every row and column and observation objects',()=>{
 const state={player:{x:32,y:192,vx:1,vy:0,grounded:true},enemies:[{dx:42,y:192,type:6}],tiles:Array.from({length:117},(_,i)=>i%3?84:0)};
 const copy=structuredClone(state),r=compactRequest(state);
 assert.deepEqual(r.state.map.flatMap(row=>[...row].map(n=>n==='1'?84:0)),state.tiles);
 assert.deepEqual(r.state.player,state.player);assert.deepEqual(r.state.enemies,state.enemies);assert.deepEqual(state,copy);
 assert.equal(Object.keys(r.questions.controller.criteria).length,7);
});
test('unknown tile encoding is rejected rather than silently discarded',()=>{
 assert.throws(()=>compactRequest({tiles:Array(117).fill(2)}));assert.throws(()=>compactRequest({tiles:[]}));
});
