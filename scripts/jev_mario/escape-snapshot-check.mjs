import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {findEscapeSequence,evaluateEscapeSequence} from '../../web/labs/jev-mario/escape-plan.mjs';
function revive(v){
 if(Array.isArray(v))return v.map(revive);
 if(v&&typeof v==='object'){
  if(Object.keys(v).length===1&&Array.isArray(v.map))return new Map(v.map.map(([k,x])=>[k,revive(x)]));
  if(Object.keys(v).length===1&&Array.isArray(v.set))return new Set(v.set.map(revive));
  return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,revive(x)]));
 }return v;
}
const root='test-results/source-observation',results=[];
for(const entry of await fs.readdir(root,{recursive:true})){
 if(!entry.endsWith('world84-complete-worker.json'))continue;
 const observation=JSON.parse(await fs.readFile(root+'/'+entry,'utf8'));
 const snapshot=observation.workerObservation?.firstStall;if(!snapshot)continue;
 const g=Object.assign(Object.create(World11.prototype),revive(snapshot.state));
 const before=structuredClone(g),started=performance.now();
 const plan=findEscapeSequence(g,snapshot.failures),elapsedMs=performance.now()-started;
 assert.ok(plan,'saved actual stall must have a safe plan');
 assert.ok(plan.grounded&&plan.progress>=48);
 assert.deepEqual(findEscapeSequence(g,snapshot.failures),plan,'deterministic result');
 assert.deepEqual(evaluateEscapeSequence(g,plan.commands),{progress:plan.progress,grounded:plan.grounded});
 assert.deepEqual(structuredClone(g),before,'actual source state must not change');
 assert.equal(findEscapeSequence(g,[]),null,'do not activate without repeated stall');
 results.push({source:entry,frame:g.frames,plan,elapsedMs});
}
assert.equal(results.length,2);
console.log(JSON.stringify({scope:'captured-state clone planner only; not async controller acceptance',results}));
