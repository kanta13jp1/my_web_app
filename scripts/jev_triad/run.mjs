import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {init,features,predict,SOURCE} from '../jev_distillation/game.mjs';
import {plan,edge} from './planner.mjs';
const mode=process.env.LANE??'planner',out='out/triad';fs.mkdirSync(out,{recursive:true});
const model=mode==='lightgbm'?JSON.parse(fs.readFileSync('out/lightgbm/jev-model.json')):null;
const result={source:SOURCE,mode,description:'Frozen independent recreation; online search with exact simulator access; not pure-model clear or browser real-time benchmark',episodes:[]};
for(const seed of [0,1,2]){
 const g=init(32,seed,seed>0);let raw=null,effective='noop',calls=0,accepted=0,overrides=0,releases=0;const trace=[],times=[];
 while(g.phase==='playing'&&g.frames<3600){
  if(g.frames%6===0){
   raw=model?predict(model,features(g)).action:null;
   const start=performance.now(),p=plan(g,raw);times.push(performance.now()-start);effective=p.action;calls++;
   if(raw!==null){if(p.accepted)accepted++;else overrides++;}
   trace.push({frame:g.frames,x:g.p.x,y:g.p.y,raw,effective,accepted:p.accepted});
  }
  const action=edge(g,effective);if(action!==effective)releases++;
  g.buttons(action);g.step();g.drainSounds();
 }
 times.sort((a,b)=>a-b);
 const row={seed,clear:g.phase==='won',phase:g.phase,x:g.p.x,frames:g.frames,calls,accepted,overrides,releases,planner_ms_median:times[Math.floor(times.length/2)]};result.episodes.push(row);
 fs.writeFileSync(`${out}/${mode}-${seed}-trace.json`,JSON.stringify(trace));fs.writeFileSync(`${out}/${mode}.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(row));
}
