import fs from 'node:fs';
import {init,SOURCE} from '../jev_distillation/game.mjs';
import {plan,edge} from './planner.mjs';
const lane=process.env.LANE,cloud=lane==='cloud_jev';
if(!['cloud_jev','localjev'].includes(lane))throw Error('Unknown lane');
const url=cloud?'https://api.typesafe.ai/v1/systemone':'http://127.0.0.1:8080/v1/systemone';
const teacher=JSON.parse(fs.readFileSync('scripts/jev_distillation/teacher.json'));
const out='out/triad';fs.mkdirSync(out,{recursive:true});
const results={source:SOURCE,lane,backend:cloud?'jev-latest':'LocalJev 3f23e36 + Qwen2.5-0.5B-Instruct Q4_K_M + llama.cpp b6000 CPU',timing:'STEP-LOCKED diagnostic. Simulation pauses for API/search; not real-time clear. HTTP is not pure inference.',episodes:[]};
let budget=80;
for(const assisted of [false,true]){
 const g=init();let raw='noop',effective='noop',calls=0,valid=0,accepted=0,overrides=0,releases=0;const trace=[];
 while(g.phase==='playing'&&g.frames<2400&&budget>0){
  if(g.frames%30===0){
   const start=performance.now();calls++;budget--;
   try{
    const response=await fetch(url,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',...(cloud?{Authorization:`Bearer ${process.env.JEV_MARIO_EXPERIMENT_KEY}`}:{})},body:JSON.stringify({model:cloud?'jev-latest':'localjev-latest',state:g.telemetry(),questions:{controller:{type:'choice',criteria:teacher.teacher_criteria,instructions:teacher.teacher_instructions.replace('6 simulation frames (100 ms','30 simulation frames (500 ms')}}}),signal:AbortSignal.timeout(cloud?10000:60000)});
    if(!response.ok)throw Error(`HTTP_${response.status}`);
    const body=await response.json(),a=body.answers?.controller;
    if(!a||!Object.hasOwn(teacher.teacher_criteria,a.choice)||!a.probabilities)throw Error('invalid_response');
    const values=Object.values(a.probabilities);
    if(values.length!==7||values.some(v=>!Number.isFinite(v)||v<0||v>1)||Math.abs(values.reduce((x,y)=>x+y,0)-1)>.02)throw Error('invalid_probabilities');
    raw=a.choice;valid++;trace.push({frame:g.frames,x:g.p.x,raw,model:body.model,probabilities:a.probabilities,http_ms:performance.now()-start});
   }catch(e){raw='noop';trace.push({frame:g.frames,x:g.p.x,error:e.message,http_ms:performance.now()-start});}
  }
  if(g.frames%6===0){
   if(assisted){const p=plan(g,raw);effective=p.action;if(p.accepted)accepted++;else overrides++;}
   else effective=raw;
  }
  const action=assisted?edge(g,effective):effective;if(action!==effective)releases++;
  g.buttons(action);g.step();g.drainSounds();
 }
 const row={assisted,clear:g.phase==='won',phase:g.phase,x:g.p.x,frames:g.frames,calls,valid,accepted,overrides,releases,budget_remaining:budget};results.episodes.push(row);
 fs.writeFileSync(`${out}/${lane}-${assisted?'assisted':'pure'}-trace.json`,JSON.stringify(trace,null,2));fs.writeFileSync(`${out}/${lane}.json`,JSON.stringify(results,null,2));console.log(JSON.stringify(row));
}
