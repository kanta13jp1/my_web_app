// One deterministic 60 Hz run of the independent recreation (not the original ROM).
// "teacher" = exact-state beam search (privileged: it clones the simulator).
// "student" = LightGBM on screen features only; no search, rewind or safety check.
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {plan,edge} from '../../web/labs/jev-mario/search-assist.mjs';
import {features2,ACTIONS} from '../../web/labs/jev-mario/student2-features.mjs';
import {predict2} from '../../web/labs/jev-mario/student2-predict.mjs';
import {tick,finished,cleared} from './campaign.mjs';
export function rng(seed){return ()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};}
// Seed 0 is the published layout. Other seeds shift every enemy by up to +-4px.
export function perturb(g,random){for(const e of g.enemies)e.x+=(random()-.5)*8;}
export function runEpisode({course=1,lastCourse=course,seed=0,policy='student',model=null,beta=0,label=false,cadence=6,maxClock=7200}){
 const g=new World11(course),random=rng(1+seed*7919+course*104729);g.clock=0;g.stageResults=[];
 if(seed)perturb(g,random);
 let stage=g.stage,action='noop',next=0,decisions=0,teacherUsed=0,planMs=0,planCalls=0;
 const rows=[],labels=[];
 while(!finished(g,lastCourse)&&g.clock<maxClock){
  if(g.stage!==stage){stage=g.stage;if(seed)perturb(g,random);next=g.clock;}
  if(g.phase==='playing'&&g.clock>=next){
   next=g.clock+cadence;decisions++;
   let teacher=null;
   if(label||policy==='teacher'||beta>0){const t=performance.now();teacher=edge(g,plan(g).action);planMs+=performance.now()-t;planCalls++;}
   const f=policy==='student'||label?features2(g):null;
   if(label){rows.push(f);labels.push(ACTIONS.indexOf(teacher));}
   if(policy==='teacher')action=teacher;
   else{const own=predict2(model,f).action;if(beta>0&&random()<beta){action=teacher;teacherUsed++;}else action=own;}
  }
  // The search controller releases a held jump on landing every frame;
  // the student gets no such help and must learn to release it itself.
  tick(g,policy==='teacher'&&g.phase==='playing'?edge(g,action):action,lastCourse);g.drainSounds();
 }
 return {rows,labels,result:{course,lastCourse,seed,policy,beta,clear:cleared(g,lastCourse),phase:g.phase,final_course:g.stage,x:+g.p.x.toFixed(2),clock:g.clock,stageResults:g.stageResults,decisions,teacherUsed,planCalls,planMeanMs:planCalls?+(planMs/planCalls).toFixed(1):null}};
}
