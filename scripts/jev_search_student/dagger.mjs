// DAgger: the student plays, the exact-state search labels every visited state,
// and LightGBM is refit on all labels so far. Evaluation runs the student alone.
import fs from 'node:fs';
import os from 'node:os';
import {Worker} from 'node:worker_threads';
import {execFileSync} from 'node:child_process';
import {FEATURE_COUNT,FEATURE_VERSION} from '../../web/labs/jev-mario/student2-features.mjs';
const OUT=process.env.OUT??'out/search_student',SCOPE=process.env.SCOPE??'campaign',ROUNDS=Number(process.env.ROUNDS??8);
const WORKERS=Math.max(1,Math.min(Number(process.env.WORKERS??os.availableParallelism()),8));
fs.mkdirSync(OUT,{recursive:true});
const TRAIN=[0,1,2,3,4,5,6,7,8,9,10,11],HELD_OUT=Array.from({length:20},(_,i)=>101+i),VALIDATION=[201,202,203,204,205,206,207,208];
const trainTasks=SCOPE==='stage1'?TRAIN.map(seed=>({course:1,lastCourse:1,seed}))
 :[...TRAIN.map(seed=>({course:1,lastCourse:2,seed})),...TRAIN.slice(0,6).map(seed=>({course:2,lastCourse:2,seed:seed+50}))];
// Round selection uses separate validation layouts, never the held-out test seeds.
const validationTasks=SCOPE==='stage1'?VALIDATION.map(seed=>({course:1,lastCourse:1,seed})):[...VALIDATION.map(seed=>({course:1,lastCourse:2,seed})),...VALIDATION.slice(0,4).map(seed=>({course:2,lastCourse:2,seed:seed+50}))];
const progress=r=>(r.clear?1e6:0)+(r.final_course-r.course)*4000+r.x;
let best={round:-1,score:-Infinity};
function run(tasks,modelPath){
 return new Promise((resolve,reject)=>{
  const results=new Array(tasks.length);let next=0,done=0;
  const launch=()=>{if(next>=tasks.length)return;const index=next++;
   const w=new Worker(new URL('./worker.mjs',import.meta.url),{workerData:{task:tasks[index],modelPath}});
   w.once('message',m=>{results[index]=m;});w.once('error',reject);
   w.once('exit',code=>{if(code!==0||!results[index])return reject(Error(`episode ${index} exited ${code}`));if(++done===tasks.length)resolve(results);else launch();});};
  for(let i=0;i<Math.min(WORKERS,tasks.length);i++)launch();
 });
}
const summary=rs=>({episodes:rs.length,clears:rs.filter(r=>r.result.clear).length,results:rs.map(r=>r.result)});
const chunks=[],labels=[],rounds=[],modelPath=`${OUT}/model.json`;
for(let round=0;round<=ROUNDS;round++){
 const beta=round===0?1:round<4?.5**round:0,started=performance.now();
 const out=await run(trainTasks.map(t=>({...t,policy:round===0?'teacher':'student',beta,label:true})),round?modelPath:null);
 for(const m of out){if(m.width&&m.width!==FEATURE_COUNT)throw Error('feature width');chunks.push(m.x);labels.push(...m.labels);}
 fs.writeFileSync(`${OUT}/X.f64`,Buffer.concat(chunks.map(c=>Buffer.from(c.buffer,c.byteOffset,c.byteLength))));
 fs.writeFileSync(`${OUT}/y.json`,JSON.stringify(labels));
 const fit=JSON.parse(execFileSync('python',['scripts/jev_search_student/train.py',String(FEATURE_COUNT),OUT],{encoding:'utf8',maxBuffer:1<<26}));
 // The pure student on the training layouts (no labels, no search) tracks progress.
 const probe=await run(trainTasks.map(t=>({...t,policy:'student'})),modelPath);
 const validation=summary(await run(validationTasks.map(t=>({...t,policy:'student'})),modelPath)),score=validation.results.reduce((a,r)=>a+progress(r),0);
 if(score>best.score){best={round,score,clears:validation.clears};for(const f of ['model.json','parity.json'])fs.copyFileSync(`${OUT}/${f}`,`${OUT}/best-${f}`);}
 rounds.push({round,beta,labelled_rollouts:summary(out),rows_total:labels.length,fit,student_only_training_layouts:summary(probe),validation,selected_so_far:best,seconds:+((performance.now()-started)/1000).toFixed(1)});
 fs.writeFileSync(`${OUT}/rounds.json`,JSON.stringify(rounds,null,1));
 console.log(JSON.stringify({round,beta,rows:labels.length,labelled_clears:summary(out).clears,student_clears:summary(probe).clears,of:trainTasks.length,validation_clears:validation.clears,validation_of:validationTasks.length}));
}
// Evaluate the round chosen on validation layouts; keep the last round for reference.
for(const f of ['model.json','parity.json']){fs.copyFileSync(`${OUT}/${f}`,`${OUT}/last-${f}`);fs.copyFileSync(`${OUT}/best-${f}`,`${OUT}/${f}`);}
// Final evaluation. Seeds 101-160 were never labelled; seed 0 is the published layout.
const evalTasks=[{course:1,lastCourse:2,seed:0},...HELD_OUT.map(seed=>({course:1,lastCourse:2,seed})),{course:2,lastCourse:2,seed:0},...HELD_OUT.slice(0,10).map(seed=>({course:2,lastCourse:2,seed:seed+50})),{course:3,lastCourse:3,seed:0}];
const student=summary(await run(evalTasks.map(t=>({...t,policy:'student'})),modelPath));
const teacher=summary(await run(evalTasks.slice(0,11).map(t=>({...t,policy:'teacher'})),null));
fs.writeFileSync(`${OUT}/evaluation.json`,JSON.stringify({scope:SCOPE,feature_version:FEATURE_VERSION,training_seeds:TRAIN,validation_seeds:VALIDATION,held_out_seeds:HELD_OUT,selected_round:best,
 note:'Independent recreation, not the ROM. Seed 0 = published layout (also used for training). Held-out seeds shift each enemy by up to +-4px. Course 3 was never used for training. The evaluated model is the DAgger round with the best student-only progress on separate validation seeds 201-208 (and 251-254 for 1-2 starts). Student = LightGBM alone, deciding every frame, labelled every 4 frames during training; teacher = exact-state search every 6 frames with per-frame jump release (privileged).',
 student,teacher_search_only:teacher},null,1));
fs.writeFileSync(`${OUT}/student2-model.mjs`,`// Search-taught LightGBM student (${SCOPE}); generated by scripts/jev_search_student/dagger.mjs.\nexport default ${fs.readFileSync(modelPath,'utf8')};\n`);
console.log(JSON.stringify({student_clears:student.clears,of:student.episodes,teacher_clears:teacher.clears,teacher_of:teacher.episodes}));
