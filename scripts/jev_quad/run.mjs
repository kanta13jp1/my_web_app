import fs from 'node:fs';
import {Worker} from 'node:worker_threads';
import {World11,features,predict,SOURCE} from '../jev_distillation/game.mjs';
import {edge} from '../jev_triad/planner.mjs';
import {query} from './provider.mjs';
import {survival} from './survival.mjs';
import {tick,finished,cleared} from '../jev_search_student/campaign.mjs';
// A real wall clock advances the game while the worker searches. No render cost.
// STAGE=campaign runs 1-1 then 1-2 with the lab's 180-frame clear presentation between them.
const lane=process.env.LANE??'planner',mode=process.env.CONTROL_MODE??'assisted';
const campaign=process.env.STAGE==='campaign',firstCourse=campaign?1:process.env.STAGE==='2'?2:1,lastCourse=campaign?2:firstCourse;
const searchStudent=lane==='lightgbm'&&process.env.STUDENT==='search';
let model=null,studentAction=null;
if(lane==='lightgbm'&&searchStudent){
 const [{default:m},{features2},{predict2}]=await Promise.all([import('../../web/labs/jev-mario/student2-model.mjs'),import('../../web/labs/jev-mario/student2-features.mjs'),import('../../web/labs/jev-mario/student2-predict.mjs')]);
 studentAction=g=>predict2(m,features2(g)).action;
}else if(lane==='lightgbm'){model=JSON.parse(fs.readFileSync('out/lightgbm/jev-model.json'));studentAction=g=>predict(model,features(g)).action;}
const MAX_FRAMES=campaign?5400:3600,MAX_API=campaign?120:60;
const apiLane=['cloud_jev','localjev','laya'].includes(lane),abort=new AbortController(),apiTrace=[];
let apiBusy=false,rawApi=null,apiPromise=null,apiCalls=0,nextApi=0,fallbackDecisions=0,epoch=0,course=firstCourse;
fs.mkdirSync('out/quad',{recursive:true});
const worker=new Worker(new URL('../jev_triad/planner-worker.mjs',import.meta.url)),g=new World11(firstCourse);g.clock=0;g.stageResults=[];
let shieldChanges=0,applyShieldChanges=0,staleDiscarded=0;
let effective='noop',busy=false,decisions=0,accepted=0,overrides=0,releases=0,nextDecision=0,lastAge=100;const ages=[],trace=[];
const started_at=new Date().toISOString(),start=performance.now();
function advanceClock(){
 const target=Math.min(MAX_FRAMES,Math.floor((performance.now()-start)*.06));
 while(g.clock<target&&!finished(g,lastCourse)){
  if(g.phase==='playing'){
   if(mode==='assisted'&&process.env.SURVIVAL_SHIELD==='true'&&g.clock%6===0){const safe=survival(g,effective);if(safe!==effective){shieldChanges++;effective=safe;trace.push({frame:g.clock,x:g.p.x,raw:null,effective,accepted:false,age_ms:0,source:'survival-shield'});}}
   const a=mode==='assisted'?edge(g,effective):effective;if(a!==effective)releases++;tick(g,a,lastCourse);
  }else tick(g,'noop',lastCourse);
  g.drainSounds();
  // A new course invalidates every decision computed on the previous one.
  if(g.stage!==course){course=g.stage;epoch++;effective='noop';rawApi=null;nextDecision=g.clock;trace.push({frame:g.clock,x:g.p.x,raw:null,effective,accepted:false,age_ms:0,source:'course-start',course});}
 }
}
worker.on('message',p=>{advanceClock();busy=false;if(g.phase!=='playing')return;if(p.epoch!==epoch){staleDiscarded++;return;}effective=p.action;if(process.env.SURVIVAL_SHIELD==='true'){const safe=survival(g,effective);if(safe!==effective){shieldChanges++;applyShieldChanges++;effective=safe;}}decisions++;if(p.raw!==null){if(p.accepted&&effective===p.action)accepted++;else overrides++;}else fallbackDecisions++;lastAge=performance.now()-p.issued;ages.push(lastAge);trace.push({frame:g.clock,x:g.p.x,raw:p.raw,effective,accepted:p.accepted&&effective===p.action,applyShield:effective!==p.action,age_ms:lastAge});});
await new Promise((resolve,reject)=>{worker.on('error',reject);const timer=setInterval(()=>{advanceClock();if(finished(g,lastCourse)||g.clock>=MAX_FRAMES){clearInterval(timer);resolve();return;}
 if(g.phase!=='playing')return;
 if(apiLane&&!apiBusy&&performance.now()>=nextApi&&apiCalls<MAX_API){apiBusy=true;apiCalls++;const issued=performance.now(),frame=g.clock,asked=epoch;nextApi=issued+500;apiPromise=query(lane,g.telemetry(),abort.signal).then(a=>{if(asked===epoch)rawApi=a.choice;apiTrace.push({frame,received_frame:g.clock,course:g.stage,stale_course:asked!==epoch,...a,http_ms:performance.now()-issued});}).catch(e=>{if(asked===epoch)rawApi=null;apiTrace.push({frame,error:abort.signal.aborted?'cancelled':e.message,http_ms:performance.now()-issued});}).finally(()=>apiBusy=false);}
 if(!busy&&g.clock>=nextDecision){nextDecision=g.clock+(searchStudent&&mode==='raw'?1:6);const t=performance.now(),raw=studentAction?studentAction(g):rawApi;if(mode==='raw'){effective=raw??'noop';decisions++;if(raw!==null)accepted++;else fallbackDecisions++;trace.push({frame:g.clock,x:g.p.x,raw,effective,accepted:raw!==null,age_ms:performance.now()-t});}else{busy=true;worker.postMessage({state:structuredClone(g),raw,issued:performance.now(),effective,epoch,forecastFrames:Math.max(1,Math.min(12,Math.round(lastAge*.06)))});}}},4);});
abort.abort();if(apiPromise)await apiPromise;
await worker.terminate();ages.sort((a,b)=>a-b);
fs.writeFileSync(`out/quad/${lane}-${mode}.json`,JSON.stringify({source:process.env.GAME_SHA??SOURCE,stage:firstCourse,campaign,last_course:lastCourse,stage_results:g.stageResults,lane,mode,student:lane==='lightgbm'?(searchStudent?'search-taught-dagger':'jev-166'):null,started_at,api_min_start_ms:500,max_api_calls:MAX_API,max_frames:MAX_FRAMES,model_input:process.env.INPUT_FORMAT==='compact'?'compact-v1: same telemetry with binary map and short instructions; no new features':'Original full telemetry; Laya truncation measured separately',forecast:'Predict current held input for previous solve age, rounded/clamped to1..12frames',timing:'60Hz wall-clock simulation continues during worker search, API waits and the 180-frame clear presentation; Node CPU, no browser/rendering',shieldChanges,applyShieldChanges,staleDiscarded,shield:process.env.SURVIVAL_SHIELD==='true'?'30-frame exact-simulator death check every6frames AND at worker-result application; separate from model and worker search':'off',clear:cleared(g,lastCourse),phase:g.phase,final_course:g.stage,x:g.p.x,frames:g.clock,wall_ms:performance.now()-start,decisions,accepted,overrides,fallbackDecisions,releases,search_age_median_ms:ages[Math.floor(ages.length/2)],apiCalls,apiTrace,trace},null,2));
