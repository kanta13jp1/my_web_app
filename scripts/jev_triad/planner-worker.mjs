import {parentPort} from 'node:worker_threads';
import {clone,plan,advance} from './planner.mjs';
parentPort.on('message',({state,raw,issued,effective,forecastFrames=0})=>{
 const predicted=advance(clone(state),effective,forecastFrames);
 const result=plan(predicted.phase==='playing'?predicted:clone(state),raw);
 parentPort.postMessage({...result,issued});
});
