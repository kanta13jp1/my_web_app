import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {clone,advance} from '../../web/labs/jev-mario/search-assist.mjs';
import {itemIntent} from '../../web/labs/jev-mario/item-goal.mjs';
function revive(v){if(Array.isArray(v))return v.map(revive);if(v&&typeof v==='object'){
 if(Object.keys(v).length===1&&Array.isArray(v.map))return new Map(v.map.map(([k,x])=>[k,revive(x)]));
 if(Object.keys(v).length===1&&Array.isArray(v.set))return new Set(v.set.map(revive));
 return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,revive(x)]));}return v;}
const root='test-results/source-observation',results=[];
for(const entry of await fs.readdir(root,{recursive:true})){
 if(!entry.endsWith('world84-complete-worker.json'))continue;
 const data=JSON.parse(await fs.readFile(root+'/'+entry,'utf8'));
 for(const snap of data.workerObservation.rewardSnapshots){
  const g=Object.assign(Object.create(World11.prototype),revive(snap.state)),intent=itemIntent(g);
  if(!intent||!g.p.grounded)continue;
  const original=structuredClone(g);
  function outcome(commands){const s=clone(g);for(const [a,n]of commands)advance(s,a,n);return {phase:s.phase,x:s.p.x,power:s.power,lives:s.lives,pickups:s.pickups,opened:g.contents.size-s.contents.size};}
  const baseline=outcome([[snap.latest.action,90]]),candidates=[];
  for(const held of [1,6,12,24,36])for(const finish of ['noop','right','right_run','left']){
   const commands=[[intent,held],[finish,90-held]],r=outcome(commands);
   if(r.phase==='playing'&&r.lives===g.lives&&r.power>=g.power)candidates.push({commands,...r});
  }
  candidates.sort((a,b)=>b.pickups.mushroom-a.pickups.mushroom||b.opened-a.opened);
  assert.deepEqual(structuredClone(g),original);
  results.push({frame:snap.frame,intent,baseline,best:candidates.slice(0,3)});
 }
}
assert.ok(results.length,'grounded reward snapshot required');console.log(JSON.stringify(results));
