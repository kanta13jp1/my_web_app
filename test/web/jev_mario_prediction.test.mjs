import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {prediction,ReactionAssist} from '../../web/labs/jev-mario/reaction.mjs';
function arrival(){const g=new World11();Object.assign(g.p,{x:207.98,y:192,vx:1.55,vy:0,grounded:true});g.camera=111.98;g.frames=178;g.enemies=[{x:339,y:192,w:14,h:16,vx:-.5,vy:0,kind:'goomba',dead:0}];return g;}
test('latest supplied dash collision is reproduced and counterfactuals are separately recorded',()=>{
 const results=[];
 for(const mode of ['held_run','immediate_run_jump','assisted_run']){const g=arrival(),assist=new ReactionAssist();
  for(let i=0;i<120&&g.phase==='playing';i++){const action=mode==='assisted_run'?assist.decide(g,'right_run').action:mode==='immediate_run_jump'&&i<35?'right_run_jump':'right_run';g.buttons(action);g.step();}
  results.push({mode,phase:g.phase,x:g.p.x,frame:g.frames});
 }
 assert.equal(results[0].phase,'dead');assert.equal(results[0].frame,218);assert.ok(Math.abs(results[0].x-308.26)<.01);
 mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-prediction-comparison.json',JSON.stringify({kind:'deterministic_replay_and_counterfactual_not_new_Jev',start:arrival().snapshot(),prediction:prediction(arrival(),971.2),results},null,2));
});
test('prediction reports bounded constant-velocity risk and unavailable enemies honestly',()=>{
 const g=arrival(),s=prediction(g,971.2);assert.ok(Math.abs(s.contact_ms-967.642)<.01);assert.ok(s.run_contact_ms<s.contact_ms);assert.ok(s.projected_gap<0);assert.equal(s.horizon_ms,971.2);
 g.enemies=[];assert.equal(prediction(g).contact_ms,null);assert.equal(prediction(g).projected_gap,null);assert.equal(prediction(g).horizon_ms,1000);assert.equal(prediction(g,99999).horizon_ms,3000);
});
test('assistance retains running intent during jump and release',()=>{
 const g=arrival(),a=new ReactionAssist();g.enemies[0].x=g.p.x+30;assert.equal(a.decide(g,'right_run').action,'right_run_jump');g.p.grounded=false;assert.equal(a.decide(g,'right_run').action,'right_run_jump');g.p.grounded=true;assert.equal(a.decide(g,'right_run').action,'right_run');
});
test('powerup emerges before moving or being collected, and skid sound is edge-triggered',()=>{
 const g=new World11();g.hitBlock(21,9);const item=g.items[0],x=item.x;assert.equal(item.y,144);for(let i=0;i<16;i++)g.step();assert.equal(item.y,128);assert.equal(item.x,x);assert.equal(item.emerging,0);g.step();assert.ok(item.x>x);
 g.reset();g.p.vx=2.6;g.input={left:true};g.step();assert.ok(g.drainSounds().includes('skid'));g.step();assert.ok(!g.drainSounds().includes('skid'));
});
