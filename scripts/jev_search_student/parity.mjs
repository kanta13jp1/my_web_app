// Python LightGBM raw scores must match the shared JavaScript predictor.
import fs from 'node:fs';
import {predict2} from '../../web/labs/jev-mario/student2-predict.mjs';
const dir=process.argv[2]??'out/search_student';
const model=JSON.parse(fs.readFileSync(`${dir}/model.json`,'utf8')),{rows,scores}=JSON.parse(fs.readFileSync(`${dir}/parity.json`,'utf8'));
let worst=0;
rows.forEach((x,i)=>predict2(model,x).scores.forEach((v,k)=>{worst=Math.max(worst,Math.abs(v-scores[i][k]));}));
fs.writeFileSync(`${dir}/parity-result.json`,JSON.stringify({rows:rows.length,max_abs_score_difference:worst}));
if(!(worst<1e-9))throw Error(`parity ${worst}`);
console.log(`parity ok: ${rows.length} rows, max diff ${worst}`);
