// Python LightGBM raw scores must match the shared JavaScript predictor.
import fs from 'node:fs';
import {predict2} from '../../web/labs/jev-mario/student2-predict.mjs';
const dir=process.argv[2]??'out/search_student';
if(!fs.existsSync(`${dir}/model.json`)||!fs.existsSync(`${dir}/parity.json`)){if(process.argv.includes('--require'))throw Error('required parity evidence is missing');console.log('no trained model with parity data in this run (evaluation-only mode)');process.exit(0);}
const model=JSON.parse(fs.readFileSync(`${dir}/model.json`,'utf8')),{rows,scores}=JSON.parse(fs.readFileSync(`${dir}/parity.json`,'utf8'));
if(!Array.isArray(model.classes)||model.classes.length===0||!Number.isInteger(model.features)||model.features<=0||
   !Array.isArray(rows)||rows.length===0||!Array.isArray(scores)||scores.length!==rows.length){
 throw Error('invalid or empty parity data');
}
let worst=0;
rows.forEach((x,i)=>{
 if(!Array.isArray(x)||x.length!==model.features||!x.every(Number.isFinite)||
    !Array.isArray(scores[i])||scores[i].length!==model.classes.length||!scores[i].every(Number.isFinite)){
  throw Error(`invalid parity row ${i}`);
 }
 const actual=predict2(model,x).scores;
 if(actual.length!==model.classes.length||!actual.every(Number.isFinite))throw Error(`invalid prediction ${i}`);
 actual.forEach((v,k)=>{worst=Math.max(worst,Math.abs(v-scores[i][k]));});
});
if(!(worst<1e-9))throw Error(`parity ${worst}`);
fs.writeFileSync(`${dir}/parity-result.json`,JSON.stringify({rows:rows.length,max_abs_score_difference:worst}));
console.log(`parity ok: ${rows.length} rows, max diff ${worst}`);
