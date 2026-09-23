import {clone,advance,plan} from './search-assist.mjs?v=student-1';
import {features,ACTIONS} from './student-features.mjs?v=student-1';
import {predict} from './student-predict.mjs?v=student-1';
import model from './student-model.mjs?v=student-1';
self.postMessage({type:'ready'});
self.onmessage=({data})=>{
 try{
  const state=clone(data.state),start=performance.now(),prediction=predict(model,features(state)),raw=ACTIONS[prediction.index],inferenceMs=performance.now()-start;
  const future=advance(clone(state),data.effective,data.forecastFrames);
  const result=plan(future.phase==='playing'?future:state,raw);
  self.postMessage({type:'decision',...result,raw,probabilities:prediction.probabilities,inferenceMs,issued:data.issued,frame:data.state.frames});
 }catch{self.postMessage({type:'error'});}
};
