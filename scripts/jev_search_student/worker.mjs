import fs from 'node:fs';
import {parentPort,workerData} from 'node:worker_threads';
import {runEpisode} from './episode.mjs';
const {task,modelPath}=workerData;
const model=modelPath?JSON.parse(fs.readFileSync(modelPath,'utf8')):null;
const {rows,labels,result}=runEpisode({...task,model});
const width=rows[0]?.length??0,flat=new Float64Array(rows.length*width);
rows.forEach((r,i)=>flat.set(r,i*width));
parentPort.postMessage({x:flat,width,labels,result},[flat.buffer]);
