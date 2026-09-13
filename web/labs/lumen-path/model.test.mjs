import test from 'node:test';
import assert from 'node:assert/strict';
import { LEVELS,trace,hint,validate } from './model.mjs';
test('all initial puzzles are unsolved and hints reach genuine solutions',()=>{
  for(const level of LEVELS){const state=[...level.initial];assert.equal(trace(level,state).solved,false);
    for(let n=0;n<level.mirrors.length;n++){const next=hint(level,state);if(next===null)break;state[next]^=1;}
    assert.equal(trace(level,state).solved,true);assert.equal(hint(level,state),null);
  }
});
test('first mirror redirects horizontally incident light upwards',()=>{
  const out=trace(LEVELS[0],[0]);assert.deepEqual(out.lit,[0]);assert.deepEqual(out.paths[0].points.at(-1),[2,0]);
});
test('wrong color does not satisfy a target',()=>{
  const level={...LEVELS[0],targets:[[2,0,'rose']]};assert.equal(trace(level,[0]).solved,false);
});
test('all legal states are deterministic, bounded and do not mutate input',()=>{
  for(const l of LEVELS)for(let m=0;m<2**l.mirrors.length;m++){
    const s=l.initial.map((_,i)=>(m>>i)&1),before=[...s],a=trace(l,s);
    assert.deepEqual(a,trace(l,s));assert.deepEqual(s,before);assert.ok(a.paths.every(p=>p.points.length<=257));
  }
});
test('invalid state is rejected',()=>{for(const s of [null,[],[2],['0']])assert.throws(()=>validate(LEVELS[0],s));});
