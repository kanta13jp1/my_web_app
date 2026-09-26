import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {ReactionAssist} from '../../web/labs/jev-mario/reaction.mjs';
test('bounded stage comparison records failure as evidence, not a Jev benchmark',()=>{
 const results=[];
 for(const mode of ['held_right','held_right_run','local_right','local_right_run']){
  const g=new World11(),assist=new ReactionAssist();let interventions=0;
  while(g.phase==='playing'&&g.frames<7200){
   const raw=mode.endsWith('_run')?'right_run':'right';
   const decision=mode.startsWith('local')?assist.decide(g,raw):{action:raw};
   if(decision.reason)interventions++;g.buttons(decision.action);g.step();
  }
  results.push({mode,phase:g.phase,x:g.p.x,frames:g.frames,intervention_frames:interventions,last_state:g.snapshot()});
 }
 mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-course-comparison.json',JSON.stringify({kind:'fixed_intent_simulation_no_API',max_frames:7200,results},null,2));
 assert.ok(results.every(r=>Number.isFinite(r.x)&&r.frames<=7200));
 assert.equal(results[0].phase,'dead');
});
