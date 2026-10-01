import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {LiveGuard} from '../../web/labs/jev-mario/live-guard.mjs';
import {clone,advance} from '../../web/labs/jev-mario/search-assist.mjs';

function revive(value){
 if(Array.isArray(value))return value.map(revive);
 if(value&&typeof value==='object'){
  if(Object.keys(value).length===1&&Array.isArray(value.map))return new Map(value.map.map(([key,val])=>[key,revive(val)]));
  if(Object.keys(value).length===1&&Array.isArray(value.set))return new Set(value.set.map(revive));
  return Object.fromEntries(Object.entries(value).map(([key,val])=>[key,revive(val)]));
 }
 return value;
}
function metrics(g,start){return {phase:g.phase,x:g.p.x,y:g.p.y,power:g.power,lives:g.lives,delta:g.p.x-start.p.x,frame:g.frames,grounded:g.p.grounded};}
function sequence(start,commands){let g=clone(start);for(const [action,frames]of commands)g=advance(g,action,frames);return metrics(g,start);}
function guardReplay(start,snapshot){
 const g=clone(start),guard=Object.assign(new LiveGuard(),snapshot.guard),counts={},samples=[];
 for(let i=0;i<360&&g.phase==='playing';i++){
  const action=guard.decide(g,snapshot.latest.action,snapshot.failures,[]);
  counts[action]=(counts[action]??0)+1;g.buttons(action);g.step();g.drainSounds();
  if(i%30===0)samples.push({frame:g.frames,x:g.p.x,y:g.p.y,action,reason:guard.lastReason});
 }
 return {end:metrics(g,start),counts,samples};
}
const root='test-results/source-observation',results=[];
for(const entry of await fs.readdir(root,{recursive:true})){
 if(!entry.endsWith('world84-complete-worker.json'))continue;
 const observation=JSON.parse(await fs.readFile(root+'/'+entry,'utf8'));
 const snapshot=observation.workerObservation?.firstStall;if(!snapshot)continue;
 const g=Object.assign(Object.create(World11.prototype),revive(snapshot.state));
 assert.equal(g.stage,32);assert.equal(g.phase,'playing');assert.ok(g.cells instanceof Map);
 const original=JSON.stringify(snapshot.state);
 const replay=guardReplay(g,snapshot);assert.deepEqual(guardReplay(g,snapshot),replay);
 const single=['right','right_run','right_jump','right_run_jump','jump','noop','left','left_jump'].map(action=>({commands:[[action,72]],...sequence(g,[[action,72]])}));
 const candidates=[];
 for(const approach of ['left','left_run','noop','right_run'])for(const wait of [0,6,12,18,24,36])for(const leap of ['right_jump','right_run_jump'])for(const held of [6,12,18,24,36]){
  const commands=[[approach,wait],[leap,held],['right_run',60]],outcome=sequence(g,commands);
  if(outcome.phase!=='dead'&&outcome.power>=g.power)candidates.push({commands,...outcome});
 }
 candidates.sort((a,b)=>b.delta-a.delta);
 assert.equal(JSON.stringify(snapshot.state),original);
 results.push({source:entry,original_clear:observation.clear,start:{frame:g.frames,p:{...g.p},power:g.power},guardReplay:replay,single,safeSequences:candidates.slice(0,12),safeSequenceCount:candidates.length});
}
assert.equal(results.length,2,'Both actually captured stalled states must be tested');
await fs.mkdir('test-results',{recursive:true});
await fs.writeFile('test-results/issue5661-snapshot-replay.json',JSON.stringify({artifact:11192490505,source_game:'ed033b6f6bec664166a915879087f6f631619df5',scope:'hypothetical clone replay; not real asynchronous worker or normal-start acceptance',results},null,2));
console.log(JSON.stringify(results.map(r=>({source:r.source,start:r.start,guard:r.guardReplay.end,guardActions:r.guardReplay.counts,single:r.single,best:r.safeSequences.slice(0,3)}))));
