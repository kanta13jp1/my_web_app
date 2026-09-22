import {clone,advance,plan} from './search-assist.mjs';
import {features,ACTIONS} from './student-features.mjs';
import {predict} from './student-predict.mjs';
import model from './student-model.mjs';
self.postMessage({type:'ready'});
self.onmessage=({data})=>{
 try{
  const state=clone(data.state),start=performance.now(),raw=ACTIONS[predict(model,features(state)).index],inferenceMs=performance.now()-start;
  const future=advance(clone(state),data.effective,data.forecastFrames);
  const result=plan(future.phase==='playing'?future:state,raw);
  self.postMessage({type:'decision',...result,raw,inferenceMs,issued:data.issued,frame:data.state.frames});
 }catch{self.postMessage({type:'error'});}
};
