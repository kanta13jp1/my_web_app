"""Cloud headless Chromium inference benchmark, not user's PC or gameplay."""
import json,platform
from pathlib import Path
from playwright.sync_api import sync_playwright
out=Path('out/lightgbm');report={'scope':'cloud headless Chromium; tree inference only, no features/render/network; 200 warmup and 1000 measured calls','models':{},'machine':platform.machine()}
with sync_playwright() as p:
 browser=p.chromium.launch();page=browser.new_page();page.set_content('<title>Frozen model benchmark</title>')
 page.add_script_tag(content=Path('scripts/jev_distillation/predict.mjs').read_text().replace('export function predict','function predict')+'\nwindow.infer=predict;')
 report['browser']=browser.version
 for kind in ['jev','rule']:
  model=json.loads((out/(kind+'-model.json')).read_text());rows=json.loads((out/(kind+'-parity.json')).read_text())
  value=page.evaluate('''({model,rows})=>{
   let error=0;for(const row of rows){const result=window.infer(model,row.features);for(let i=0;i<7;i++)error=Math.max(error,Math.abs(result.raw[i]-row.raw[i]));}
   for(let i=0;i<200;i++)window.infer(model,rows[i%rows.length].features);
   const times=[];for(let i=0;i<1000;i++){const start=performance.now();window.infer(model,rows[i%rows.length].features);times.push(performance.now()-start);}times.sort((a,b)=>a-b);
   return {n:times.length,median_ms:times[500],p95_ms:times[949],max_ms:times[999],parity_max_error:error,zero_timer_samples:times.filter(t=>t===0).length};
  }''',{'model':model,'rows':rows})
  assert value['parity_max_error']<1e-8;report['models'][kind]=value
 browser.close()
(out/'browser.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
