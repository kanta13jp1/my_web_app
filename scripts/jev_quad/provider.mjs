import fs from 'node:fs';
import {compactRequest} from './compact.mjs';
const teacher=JSON.parse(fs.readFileSync('scripts/jev_distillation/teacher.json'));
export async function query(lane,state,signal){
 const cloud=lane==='cloud_jev';if(cloud&&!process.env.JEV_MARIO_EXPERIMENT_KEY)throw Error('Missing experiment credential');
 const response=await fetch(cloud?'https://api.typesafe.ai/v1/systemone':lane==='laya'?'http://127.0.0.1:8081/v1/systemone':'http://127.0.0.1:8080/v1/systemone',{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',...(cloud?{Authorization:`Bearer ${process.env.JEV_MARIO_EXPERIMENT_KEY}`}:{})},body:JSON.stringify({...((process.env.INPUT_FORMAT==='compact')?compactRequest(state):{state,questions:{controller:{type:'choice',criteria:teacher.teacher_criteria,instructions:teacher.teacher_instructions.replace('6 simulation frames (100 ms','30 simulation frames (500 ms')}}}),model:cloud?'jev-latest':'localjev-latest'}),signal:AbortSignal.any([signal,AbortSignal.timeout(cloud?10000:60000)])});
 if(!response.ok)throw Error(`HTTP_${response.status}`);
 const body=await response.json(),a=body.answers?.controller;
 if(!a||!Object.hasOwn(teacher.teacher_criteria,a.choice)||!a.probabilities||Object.keys(a.probabilities).sort().join('|')!==Object.keys(teacher.teacher_criteria).sort().join('|'))throw Error('invalid_response');
 const values=Object.values(a.probabilities);if(values.some(v=>!Number.isFinite(v)||v<0||v>1)||Math.abs(values.reduce((x,y)=>x+y,0)-1)>.02)throw Error('invalid_probabilities');
 return {choice:a.choice,probabilities:a.probabilities,model:body.model,uniform:new Set(values).size===1,usage:body.usage,laya_input:body.laya_input,laya_compute_ms:body.laya_compute_ms};
}
