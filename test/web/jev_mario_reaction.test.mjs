import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {ReactionAssist,hazards} from '../../web/labs/jev-mario/reaction.mjs';

function measuredState(){
 const g=new World11();Object.assign(g.p,{x:203.33,y:192,vx:1.55,vy:0,grounded:true});
 g.camera=107.33;g.frames=288;g.enemies=[{x:340.5,y:192,w:14,h:16,vx:-.5,vy:0,kind:'goomba',dead:0}];return g;
}
test('replay the supplied collision state with held right, then compare local assistance',()=>{
 const results=[];
 for(const assisted of [false,true]){
  const g=measuredState(),a=new ReactionAssist(),events=[];
  for(let i=0;i<120&&g.phase==='playing';i++){
   const d=assisted?a.decide(g,'right'):{action:'right',reason:null};
   if(d.reason&&events.at(-1)?.reason!==d.reason)events.push({frame:g.frames,reason:d.reason,action:d.action});
   g.buttons(d.action);g.step();
  }
  results.push({controller:assisted?'local_rules_with_held_right':'held_right',phase:g.phase,x:g.p.x,frame:g.frames,events});
 }
 mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-reaction-comparison.json',JSON.stringify({kind:'deterministic_counterfactual_not_new_Jev_run',start:measuredState().snapshot(),results},null,2));
 assert.equal(results[0].phase,'dead');assert.ok(Math.abs(results[0].x-299.43)<.01);
 assert.equal(results[1].phase,'playing');assert.ok(results[1].x>results[0].x);assert.ok(results[1].events.length>0);
});
test('contact time is explicit and assistance leaves idle, left and ended games alone',()=>{
 const g=measuredState(),a=new ReactionAssist();assert.ok(Math.abs(hazards(g).contact_ms-1017.64)<1);
 assert.equal(a.decide(g,'noop').action,'noop');assert.equal(a.decide(g,'left').action,'left');
 g.phase='dead';assert.equal(a.decide(g,'right').reason,null);
});
test('gap and wall assistance is local, resets and releases jump on landing',()=>{
 const g=new World11(),a=new ReactionAssist();g.enemies=[];g.p.x=69*16-22;g.p.vx=1.55;
 assert.equal(a.decide(g,'right').reason,'local_gap');
 g.p.grounded=false;assert.equal(a.decide(g,'right').action,'right_jump');
 g.p.grounded=true;assert.equal(a.decide(g,'right').reason,'local_jump_release');
 a.reset();g.p.x=28*16-14;assert.equal(a.decide(g,'right').reason,'local_wall');
});
test('one hundred coins award one life and a bumped block defeats the enemy above once',()=>{
 const g=new World11();g.coins=99;g.collectCoin();assert.equal(g.coins,0);assert.equal(g.lives,4);assert.ok(g.drainSounds().includes('life'));
 g.enemies=[{x:256,y:128,w:14,h:16,vx:-.5,vy:0,dead:0}];g.hitBlock(16,9);
 assert.equal(g.enemies[0].dead,1);const score=g.score;g.hitBlock(16,9);assert.equal(g.score,score);
 g.hitBlock(21,9);assert.ok(g.drainSounds().includes('appear'));
});
