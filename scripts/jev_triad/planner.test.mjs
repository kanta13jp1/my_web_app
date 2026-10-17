import test from 'node:test';
import assert from 'node:assert/strict';
import {init} from '../jev_distillation/game.mjs';
import {plan,clone,advance,edge} from './planner.mjs';
test('hypothetical search does not change real state or terrain',()=>{
 const g=init(),before=structuredClone(g);plan(g,'right');assert.deepEqual(structuredClone(g),before);
 const copy=clone(g);copy.cells.delete('0,13');advance(copy,'right_run',60);
 assert.deepEqual(structuredClone(g),before);assert.notEqual(copy.p.x,g.p.x);
});
test('jump adapter releases only held jump on ground',()=>{
 const g=init();g.wasJump=true;assert.equal(edge(g,'right_run_jump'),'right_run');assert.equal(edge(g,'right'),'right');g.p.grounded=false;assert.equal(edge(g,'right_run_jump'),'right_run_jump');
});
