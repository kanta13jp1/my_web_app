// One deterministic 60 Hz run of the independent recreation (not the original ROM).
// "teacher" = exact-state beam search (privileged: it clones the simulator); it
//   decides every 6 frames and releases a held jump on landing every frame.
// "student" = LightGBM on screen features only, deciding every frame; no search,
//   rewind, safety check or automatic jump release.
import {World11} from '../../web/labs/jev-mario/world11.mjs';
import {plan,edge} from '../../web/labs/jev-mario/search-assist.mjs';
import {features2,ACTIONS} from '../../web/labs/jev-mario/student2-features.mjs';
import {predict2} from '../../web/labs/jev-mario/student2-predict.mjs';
import {tick,finished,cleared} from './campaign.mjs';
export function rng(seed){return ()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};}
// Seed 0 is the published layout. Other seeds shift every enemy by up to +-4px.
export function perturb(g,random){for(const e of g.enemies)e.x+=(random()-.5)*8;}
const teach=g=>edge(g,plan(g).action);
export function runEpisode({course=1,lastCourse=course,seed=0,policy='student',model=null,beta=0,label=false,labelEvery=4,maxClock=7200}){
 const g=new World11(course),random=rng(1+seed*7919+course*104729);g.clock=0;g.stageResults=[];
 if(seed)perturb(g,random);
 let stage=g.stage,action='noop',next=0,nextLabel=0,held=null,heldUntil=0,decisions=0,teacherUsed=0,planMs=0,planCalls=0;
 const rows=[],labels=[],timed=()=>{const t=performance.now(),a=teach(g);planMs+=performance.now()-t;planCalls++;return a;};
 while(!finished(g,lastCourse)&&g.clock<maxClock){
  if(g.stage!==stage){stage=g.stage;if(seed)perturb(g,random);next=nextLabel=g.clock;held=null;}
  if(g.phase==='playing'){
   if(policy==='teacher'){
    if(g.clock>=next){next=g.clock+6;decisions++;action=timed();if(label){rows.push(features2(g));labels.push(ACTIONS.indexOf(action));}}
   }else{
    const f=features2(g);
    if((label||beta>0)&&g.clock>=nextLabel){
     nextLabel=g.clock+labelEvery;const teacher=timed();
     if(label){rows.push(f);labels.push(ACTIONS.indexOf(teacher));}
     if(beta>0&&random()<beta){held=teacher;heldUntil=g.clock+labelEvery;teacherUsed++;}
    }
    decisions++;action=held&&g.clock<heldUntil?held:predict2(model,f).action;
   }
  }
  tick(g,policy==='teacher'&&g.phase==='playing'?edge(g,action):action,lastCourse);g.drainSounds();
 }
 return {rows,labels,result:{course,lastCourse,seed,policy,beta,clear:cleared(g,lastCourse),phase:g.phase,final_course:g.stage,x:+g.p.x.toFixed(2),clock:g.clock,stageResults:g.stageResults,decisions,teacherUsed,planCalls,planMeanMs:planCalls?+(planMs/planCalls).toFixed(1):null}};
}
