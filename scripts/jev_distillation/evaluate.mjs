import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {init,features,rule,predict,SOURCE} from './game.mjs';
const models=Object.fromEntries(['jev','rule'].map(k=>[k,JSON.parse(fs.readFileSync(`out/lightgbm/${k}-model.json`))]));
let parity=0;
for(const [k,model] of Object.entries(models))for(const row of JSON.parse(fs.readFileSync(`out/lightgbm/${k}-parity.json`))){const out=predict(model,row.features);for(let i=0;i<7;i++){const error=Math.abs(out.raw[i]-row.raw[i]);parity=Math.max(parity,error);if(error>1e-8)throw Error('Python/JS model parity mismatch');}}
const result={source:SOURCE,runtime:process.version,timing:'Node CPU synchronous features + exported-tree evaluation; not browser benchmark',max_frames:7200,action_hold_frames:6,parity_max_error:parity,episodes:[],timings:{}};
for(const controller of ['always_right','local_rule','jev_student','rule_student']){
 const times=[];
 for(let seed=0;seed<21;seed++){
  const g=init(32,seed,seed>0);let action='noop',calls=0,maxX=g.p.x;const trace=[];
  while(g.phase==='playing'&&g.frames<7200){
   if(g.frames%6===0){const start=performance.now();action=controller==='always_right'?'right':controller==='local_rule'?rule(g):predict(models[controller==='jev_student'?'jev':'rule'],features(g)).action;times.push(performance.now()-start);calls++;if(seed===0)trace.push({frame:g.frames,x:g.p.x,y:g.p.y,vx:g.p.vx,vy:g.p.vy,grounded:g.p.grounded,jump_was_pressed:g.wasJump,action});g.buttons(action);}
   g.step();g.drainSounds();maxX=Math.max(maxX,g.p.x);
  }
  result.episodes.push({controller,seed,condition:seed===0?'canonical':'enemy positions perturbed +/-4px; robustness only',phase:g.phase,clear:g.phase==='won',frames:g.frames,x:g.p.x,max_x:maxX,decisions:calls,last_action:action,death_context:g.phase==='dead'?{y:g.p.y,nearest_enemy_dx:Math.min(...g.enemies.filter(e=>!e.dead).map(e=>Math.abs(e.x-g.p.x)))}:null});
  if(seed===0)fs.writeFileSync(`out/lightgbm/${controller}-trace.json`,JSON.stringify(trace,null,2));
 }
 // Deliberately include cold calls; hardware/Node benchmark is not browser latency.
 times.sort((a,b)=>a-b);result.timings[controller]={n:times.length,median:times[Math.floor(times.length/2)],p95:times[Math.ceil(times.length*.95)-1]};
}
result.summary=Object.fromEntries(['always_right','local_rule','jev_student','rule_student'].map(k=>{const rows=result.episodes.filter(r=>r.controller===k),robust=rows.slice(1);return[k,{canonical:rows[0],robustness_clears:robust.filter(r=>r.clear).length,robustness_n:robust.length,robustness_max_x_median:robust.map(r=>r.max_x).sort((a,b)=>a-b)[10]}];}));
// Secondary sensitivity analysis; same already-frozen models, no refitting/tuning.
result.every_frame_sensitivity=[];
for(const controller of ['local_rule','jev_student','rule_student']){
 const g=init();let maxX=g.p.x;
 while(g.phase==='playing'&&g.frames<7200){g.buttons(controller==='local_rule'?rule(g):predict(models[controller==='jev_student'?'jev':'rule'],features(g)).action);g.step();g.drainSounds();maxX=Math.max(maxX,g.p.x);}
 result.every_frame_sensitivity.push({controller,action_hold_frames:1,phase:g.phase,clear:g.phase==='won',frames:g.frames,max_x:maxX});
}
// Post-diagnosis ablation, NOT pure student inference or an unseen final test.
// Releasing held jump for one frame on landing only changes button edge handling.
result.jump_edge_ablation=[];
for(let seed=0;seed<21;seed++){
 const g=init(32,seed,seed>0);let raw='noop',maxX=g.p.x,releases=0;
 while(g.phase==='playing'&&g.frames<7200){
  if(g.frames%6===0)raw=predict(models.jev,features(g)).action;
  let effective=raw;
  if(g.p.grounded&&g.wasJump&&raw.includes('jump')){effective=raw==='jump'?'noop':raw.replace('_jump','');releases++;}
  g.buttons(effective);g.step();g.drainSounds();maxX=Math.max(maxX,g.p.x);
 }
 result.jump_edge_ablation.push({controller:'jev_student_plus_jump_edge_release',seed,condition:seed===0?'canonical':'enemy positions perturbed +/-4px',phase:g.phase,clear:g.phase==='won',frames:g.frames,max_x:maxX,releases});
}
fs.writeFileSync('out/lightgbm/gameplay.json',JSON.stringify(result,null,2));console.log(JSON.stringify({summary:result.summary,timings:result.timings,parity},null,2));
