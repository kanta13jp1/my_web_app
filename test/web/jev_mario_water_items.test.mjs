import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {plan,edge,advance} from '../../web/labs/jev-mario/search-assist.mjs';
import {features,ACTIONS} from '../../web/labs/jev-mario/student-features.mjs';
import {predict} from '../../web/labs/jev-mario/student-predict.mjs';
import model from '../../web/labs/jev-mario/student-model.mjs';
const results=[];
function run(g,limit=4000,failures=[]){let action='noop',decisions=0;while(g.phase==='playing'&&g.frames<limit){if(g.frames%8===0){const raw=ACTIONS[predict(model,features(g)).index];action=plan(g,raw,failures).action;decisions++;}g.buttons(edge(g,action));g.step();g.drainSounds();}const result={stage:g.stage,phase:g.phase,x:g.p.x,y:g.p.y,frames:g.frames,pickups:g.pickups,decisions};results.push(result);mkdirSync('test-results',{recursive:true});writeFileSync('test-results/jev-water-items.json',JSON.stringify(results,null,2));return result;}
test('LightGBM plus search clears both complete underwater courses',()=>{for(const stage of [6,26]){const g=new World11(stage);const r=run(g);assert.equal(r.phase,'won',JSON.stringify(r));}});
test('water search recovers the reported overshot exit instead of continuing offscreen',()=>{const g=new World11(6);g.p.x=4339;g.p.y=77;g.camera=g.width-256;const r=run(g,300);assert.equal(r.phase,'won',JSON.stringify(r));assert.ok(g.p.x<=g.width-g.p.w);});
test('LightGBM plus search reveals and collects an actual 1-1 mushroom',()=>{const g=new World11();g.p.x=280;g.camera=184;const r=run(g,700);assert.ok(r.pickups.mushroom>0,JSON.stringify(r));});
test('search collects reachable flower, 1UP and star instead of ignoring them',()=>{for(const kind of ['flower','life','star']){const g=new World11();g.enemies=[];g.p.x=64;g.camera=0;g.contents.clear();g.items=[{kind,x:96,y:192,w:14,h:16,emerging:0,vx:kind==='flower'?0:1,vy:0}];const r=run(g,100);assert.ok(r.pickups[kind]>0,JSON.stringify(r));}});
import {StudentSession} from '../../web/labs/jev-mario/student-session.mjs';
test('stationary or backtracking assisted play learns a stall even without right input',()=>{
 const worker={postMessage(){},terminate(){}};const storage={getItem(){return null;},setItem(){},removeItem(){}};
 const session=new StudentSession(()=>worker,()=>0,storage);session.start({ready(){},update(){},error(){assert.fail('worker');}});worker.onmessage({data:{type:'ready'}});
 const g=new World11();g.enemies=[];g.p.x=300;session.tick(g);
 for(let i=1;i<=2;i++){g.frames=i*180;g.p.x=i===1?292:300;session.action=i===1?'left':'noop';session.tick(g);}
 assert.equal(session.failures.length,1);assert.equal(session.failures[0].kind,'stalled');assert.equal(session.failures[0].count,2);session.stop();
});

test('saved stalled experience still permits a new attempt to collect the mushroom',()=>{const g=new World11();g.p.x=280;g.camera=184;const old=[{stage:1,room:g.room,x:300,y:192,kind:'stalled',count:12}];const r=run(g,700,old);assert.ok(r.pickups.mushroom>0,JSON.stringify(r));});

test('item detour avoidance expires and is reset by a new attempt',()=>{const worker={postMessage(){},terminate(){}};const session=new StudentSession(()=>worker,()=>0,null);const callbacks={ready(){},update(){},error(){assert.fail('worker');}};session.start(callbacks);worker.onmessage({data:{type:'ready'}});const g=new World11();g.enemies=[];session.tick(g);g.frames=180;session.tick(g);assert.equal(session.itemAvoidance.length,1);g.p.x+=20;g.frames=421;session.tick(g);assert.equal(session.itemAvoidance.length,0);g.frames=601;session.tick(g);assert.equal(session.itemAvoidance.length,1);session.start(callbacks);assert.equal(session.itemAvoidance.length,0);session.stop();});

// Reported 4-4 position: fire Mario underneath an item block, beside a ledge.
test('castle item alcove permits retreating jump rather than permanent right input',()=>{
 const g=new World11(16);g.power=2;Object.assign(g.p,{x:676,y:180,h:28,grounded:true});g.camera=580;g.invincible=5000;
 const trace=[];for(let i=0;i<75&&g.phase==='playing'&&g.p.x<760;i++){const result=plan(g,'right');advance(g,result.action,8);if(i%5===0)trace.push([i,result.action,Math.round(g.p.x),Math.round(g.p.y)]);}
 assert.ok(g.p.x>736,`alcove remained blocked: ${g.p.x}, ${g.p.y}; ${JSON.stringify(trace)}`);
});

test('2-4 stopped crouching players exit the low tunnel in either power state',()=>{
 for(const power of [1,2])for(const vx of [-.4,0,.4]){const g=new World11(8);g.power=power;Object.assign(g.p,{x:367,y:192,h:16,vx,crouching:true,grounded:true});g.camera=271;g.invincible=1200;
  for(let i=0;i<40&&g.p.x<432;i++)advance(g,plan(g,'right_run',[{stage:8,room:'castle',x:367,y:192,count:12,kind:'stalled'}]).action,8);
  assert.ok(g.p.x>400,`2-4 still blocked: ${g.p.x}`);assert.equal(g.p.h,28);assert.equal(g.power,power);
 }
});
test('manual release under a ceiling allows slow movement without standing through tiles',()=>{const g=new World11(8);g.power=1;Object.assign(g.p,{x:367,y:192,h:16,crouching:true,grounded:true});g.invincible=1200;g.buttons('right');g.step();assert.equal(g.p.h,16);assert.ok(g.p.x>367);for(let i=0;i<60;i++)g.step();assert.ok(g.p.x>384);assert.equal(g.p.h,28);});

test("running crouch crawls into a castle ledge without alternating standing",()=>{const g=new World11(16);g.power=2;Object.assign(g.p,{x:676,y:180,h:28,grounded:true});g.invincible=5000;g.buttons("right_run_down");for(let i=0;i<100;i++)g.step();assert.ok(g.p.x>736);assert.equal(g.p.h,16);});
