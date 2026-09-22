import {parentPort} from 'node:worker_threads';
import {clone,plan} from './planner.mjs';
parentPort.on('message',({state,raw,issued})=>{
 const result=plan(clone(state),raw);
 parentPort.postMessage({...result,issued});
});
