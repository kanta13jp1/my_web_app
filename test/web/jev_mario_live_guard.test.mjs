import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {LiveGuard} from '../../web/labs/jev-mario/live-guard.mjs';
import {plan} from '../../web/labs/jev-mario/search-assist.mjs';
import {StudentSession} from '../../web/labs/jev-mario/student-session.mjs';

test('live guard corrects repeated stale right commands before first enemy without changing world state',()=>{
 const run=guard=>{const g=new World11();let furthest=g.p.x;for(let i=0;i<240&&g.phase==='playing';i++){const before=JSON.stringify(g.snapshot()),action=guard?guard.decide(g,'right'):'right';assert.equal(JSON.stringify(g.snapshot()),before);g.buttons(action);g.step();g.drainSounds();furthest=Math.max(furthest,g.p.x);}return {phase:g.phase,x:g.p.x,furthest,frames:g.frames,interventions:guard?.interventions??0};};
 const baseline=run(null),assisted=run(new LiveGuard());mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-live-guard.json',JSON.stringify({scenario:'1-1 first enemy, repeated right command, 240-frame budget; deterministic assistance, no measured worker inference',baseline,assisted},null,2));
 assert.equal(baseline.phase,'dead');assert.ok(assisted.furthest>baseline.furthest+40);assert.ok(assisted.interventions>0);
});
test('worker retries receive failure memory and manual new run can clear it',()=>{
 const messages=[],worker={terminate(){},postMessage(m){messages.push(m);}};const s=new StudentSession(()=>worker,()=>100);const g=new World11();g.p.x=299;g.phase='dead';s.noteFailure(g);s.start({ready(){},update(){},error(){assert.fail();}});worker.onmessage({data:{type:'ready'}});g.reset();s.tick(g);assert.equal(messages[0].failures[0].x,299);assert.equal(s.stats.failures.length,1);s.stop();s.clearFailures();assert.deepEqual(s.failures,[]);
});
test('guard preserves safe commands and bounded intervention history',()=>{const g=new World11(),guard=new LiveGuard();assert.equal(guard.decide(g,'right'),'right');assert.equal(guard.interventions,0);g.phase='won';assert.equal(guard.decide(g,'noop'),'noop');});


test('normal 3-3 treetop ledge looks past the fall before takeoff',()=>{const g=new World11(11),guard=new LiveGuard();g.power=1;Object.assign(g.p,{x:832,y:148,h:28,vx:0,vy:0,grounded:true});g.camera=736;let furthest=g.p.x;for(let i=0;i<150&&g.phase==='playing'&&furthest<=1000;i++){g.buttons(guard.decide(g,plan(g,'right_run').action));g.step();g.drainSounds();furthest=Math.max(furthest,g.p.x);}assert.ok(furthest>1000,JSON.stringify({furthest,phase:g.phase,x:g.p.x,y:g.p.y}));assert.equal(g.phase,'playing');});
