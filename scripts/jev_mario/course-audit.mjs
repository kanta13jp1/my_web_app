// Independent-stage, accelerated physics audit. Not live API latency or a continuous campaign.
import {mkdirSync,writeFileSync} from 'node:fs';
import {World11,courseInfo} from '../../web/labs/jev-mario/world11.mjs';
import {StudentSession} from '../../web/labs/jev-mario/student-session.mjs';
import {clone,advance,plan} from '../../web/labs/jev-mario/search-assist.mjs';
import {features,ACTIONS} from '../../web/labs/jev-mario/student-features.mjs';
import {predict} from '../../web/labs/jev-mario/student-predict.mjs';
import model from '../../web/labs/jev-mario/student-model.mjs';
const group=Number(process.argv[2]);if(!Number.isInteger(group)||group<1||group>8)throw Error('group must be 1..8');
const rows=[];
for(let stage=(group-1)*4+1;stage<=group*4;stage++){
 const g=new World11(stage);let worker,steps=0,furthest=32,previous={...g.pickups};const pickups={mushroom:0,flower:0,life:0,star:0},trace=[];
 const session=new StudentSession(()=>worker={terminate(){},postMessage(data){const state=clone(data.state),prediction=predict(model,features(state)),raw=ACTIONS[prediction.index],future=advance(clone(state),data.effective,data.forecastFrames),result=plan(future.phase==='playing'?future:state,raw,data.failures,data.itemAvoidance);this.onmessage({data:{type:'decision',requestId:data.requestId,...result,raw,probabilities:prediction.probabilities,inferenceMs:null,issued:data.issued,frame:state.frames}});}},()=>steps*1000/60,null);
 session.start({ready(){},update(){},error(){throw Error('audit worker failed');}});worker.onmessage({data:{type:'ready'}});
 while(steps<6000){
  if(g.phase==='won')break;
  if(g.phase==='dead'){session.noteFailure(g);if(g.lives<=0)break;while(g.presentation<g.presentationLength())g.presentationStep();g.restartLife();previous={...g.pickups};continue;}
  g.buttons(session.tick(g));g.step();g.drainSounds();steps++;furthest=Math.max(furthest,g.p.x);for(const k of Object.keys(pickups)){pickups[k]+=Math.max(0,g.pickups[k]-previous[k]);previous[k]=g.pickups[k];}
  if(steps%120===0)trace.push({steps,frame:g.frames,x:g.p.x,y:g.p.y,room:g.room,phase:g.phase,lives:g.lives,power:g.power,action:session.guard.action});
 }
 const row={stage,label:courseInfo(stage).label,phase:g.phase,clear:g.phase==='won',steps,furthest,x:g.p.x,y:g.p.y,lives:g.lives,deaths:g.deaths,pickups,visited:[...g.visitedPipes],failures:session.failures,decisions:session.stats.decisions,overrides:session.stats.overrides,retry_assists:session.stats.retry_assists,trace};rows.push(row);session.stop();console.log(JSON.stringify({...row,trace:undefined}));
 mkdirSync('test-results',{recursive:true});writeFileSync(`test-results/jev-course-audit-${group}.json`,JSON.stringify({kind:'independent stages, real LightGBM weights + search + guard, synchronous worker protocol, accelerated simulation',max_steps_per_stage:6000,initial_lives:3,initial_form:'small',seeded_memory:false,continuous_campaign:false,rows},null,2));
}
