import {findEscapeSequence} from './escape-plan.mjs?v=student-1';
import {clone,advance,plan} from './search-assist.mjs?v=student-1';
import {features,ACTIONS} from './student-features.mjs?v=student-1';
import {predict} from './student-predict.mjs?v=student-1';
import model from './student-model.mjs?v=student-1';
self.postMessage({type:'ready'});
self.onmessage=({data})=>{
 try{
  const state=clone(data.state),start=performance.now(),prediction=predict(model,features(state)),raw=ACTIONS[prediction.index],inferenceMs=performance.now()-start;
  const future=advance(clone(state),data.effective,data.forecastFrames);
  const escape=null; // Diagnostic ablation only; never product source
  const result=escape?{action:escape.commands[0].action,accepted:false,retry_level:3,search_depth:0,escapeSequence:escape.commands,escapeOrigin:{stage:state.stage,room:state.room,frame:state.frames,x:state.p.x,power:state.power,lives:state.lives}}:plan(future.phase==='playing'?future:state,raw,data.failures??[],data.itemAvoidance??[]);
  self.postMessage({type:'decision',requestId:data.requestId,...result,raw,probabilities:prediction.probabilities,inferenceMs,issued:data.issued,frame:data.state.frames});
 }catch{self.postMessage({type:'error'});}
};
