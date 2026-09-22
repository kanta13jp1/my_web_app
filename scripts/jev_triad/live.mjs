import fs from 'node:fs';
import {Worker} from 'node:worker_threads';
import {init,features,predict,SOURCE} from '../jev_distillation/game.mjs';
import {edge} from './planner.mjs';
// A real wall clock advances the game while the worker searches. No render cost.
const lane=process.env.LANE??'planner',model=lane==='lightgbm'?JSON.parse(fs.readFileSync('out/lightgbm/jev-model.json')):null;
const worker=new Worker(new URL('./planner-worker.mjs',import.meta.url)),g=init();
let effective='noop',busy=false,decisions=0,accepted=0,overrides=0,releases=0,nextDecision=0,lastAge=100;const ages=[],trace=[];
const start=performance.now();
function advanceClock(){const target=Math.min(3600,Math.floor((performance.now()-start)*.06));while(g.frames<target&&g.phase==='playing'){const a=edge(g,effective);if(a!==effective)releases++;g.buttons(a);g.step();g.drainSounds();}}
worker.on('message',p=>{advanceClock();busy=false;if(g.phase!=='playing')return;effective=p.action;decisions++;if(model){if(p.accepted)accepted++;else overrides++;}lastAge=performance.now()-p.issued;ages.push(lastAge);trace.push({frame:g.frames,x:g.p.x,effective,accepted:p.accepted,age_ms:lastAge});});
await new Promise((resolve,reject)=>{worker.on('error',reject);const timer=setInterval(()=>{advanceClock();if(g.phase!=='playing'||g.frames>=3600){clearInterval(timer);resolve();return;}if(!busy&&g.frames>=nextDecision){busy=true;nextDecision=g.frames+6;worker.postMessage({state:structuredClone(g),raw:model?predict(model,features(g)).action:null,issued:performance.now(),effective,forecastFrames:Math.max(1,Math.min(12,Math.round(lastAge*.06)))});}},4);});
await worker.terminate();ages.sort((a,b)=>a-b);
fs.writeFileSync(`out/triad/${lane}-live.json`,JSON.stringify({source:SOURCE,lane,forecast:'Predict current held input for previous solve age, rounded/clamped to1..12frames',timing:'60Hz wall-clock simulation continues during worker search; Node CPU, no browser/rendering/API',clear:g.phase==='won',phase:g.phase,x:g.p.x,frames:g.frames,wall_ms:performance.now()-start,decisions,accepted,overrides,releases,search_age_median_ms:ages[Math.floor(ages.length/2)],trace},null,2));
