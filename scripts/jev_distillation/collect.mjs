import fs from 'node:fs';
import {init,features,rule,prediction,rng,SOURCE,ACTIONS} from './game.mjs';
const starts=[32,180,280,400,520,640,800,960,1020,1120,1230,1320,1420,1540,1680,1800,1960,2080,2240,2340,2400,2570,2740,2840];
const rows=[];
for(let group=0;group<starts.length;group++)for(let episode=0;episode<2;episode++){
 const g=init(starts[group]),random=rng(1000+group*2+episode),split=group%6===4?'validation':group%6===5?'test':'train';
 for(let frame=0;frame<=80&&g.phase==='playing';frame++){
  if([0,12,30,52,80].includes(frame)){
   const state=g.telemetry();state.prediction=prediction(g,100);
   rows.push({id:`g${group}-e${episode}-f${frame}`,group,episode,split,checkpoint:starts[group],features:features(g),state,rule_action:rule(g)});
  }
  if(frame%6===0){let action=rule(g);if(episode===1&&random()<.35)action=ACTIONS[1+Math.floor(random()*4)];g.buttons(action);}
  g.step();g.drainSounds();
 }
}
// Protect held-out splits from exact-feature duplicates, including flat starts.
const priority={test:0,validation:1,train:2},seen=new Set(),unique=[];
for(const row of [...rows].sort((a,b)=>priority[a.split]-priority[b.split])){const key=JSON.stringify(row.features);if(!seen.has(key)){seen.add(key);unique.push(row);}}
fs.writeFileSync('out/lightgbm/candidates.json',JSON.stringify({source:SOURCE,feature_version:1,split:'checkpoint group; exact-feature duplicates removed with test then validation priority',excluded_duplicates:rows.length-unique.length,rows:unique},null,2));
console.log(JSON.stringify({rows:unique.length,splits:Object.fromEntries(['train','validation','test'].map(s=>[s,unique.filter(r=>r.split===s).length]))}));
