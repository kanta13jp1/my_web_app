import { chromium } from 'playwright';
import fs from 'node:fs/promises';
const root = '.ci-logs/cashflow-responsive';
await fs.mkdir(root, {recursive:true});
const browser = await chromium.launch({headless:true});
const report=[];
try {
 for (const [label,width,height] of [['pc',1440,1000],['narrow',390,900]]) {
  for (const scenario of ['paid','unpaid','unknown']) {
   const context=await browser.newContext({viewport:{width,height},serviceWorkers:'block'});
   const page=await context.newPage(); const errors=[]; const pageErrors=[]; const denied=[]; let deniedCount=0;
   page.on('pageerror',error=>pageErrors.push(error.message));
   page.on('console',message=>{if(message.type()==='error' && errors.length<32)errors.push(message.text());});
   await context.route('**/*',route=>{
    const u=new URL(route.request().url());
    if(u.origin==='http://127.0.0.1:4173' && route.request().method()==='GET')return route.continue();
    deniedCount++; if(denied.length<32)denied.push({method:route.request().method(),host:u.host,path:u.pathname});return route.abort();
   });
   try {
   await page.goto('http://127.0.0.1:4173/?scenario='+scenario);
   await page.screenshot({path:`${root}/${label}-${scenario}-boot.png`});
   const details=page.getByRole('button',{name:'月別内訳（月末・月内最低）',exact:true});
   await details.waitFor({state:'visible',timeout:60000});
   await details.click();
   await page.evaluate(async()=>{await Promise.all(document.getAnimations().map(a=>a.finished.catch(()=>{})));});
   const expectedJune=scenario==='paid'?'1000':'-1000';
   const expectedJuly=scenario==='paid'?'-1000':'-3000';
   const expected=['2026/6 月末 ¥'+expectedJune+' / 月内最低 ¥'+expectedJune,'2026/7 月末 ¥'+expectedJuly+' / 月内最低 ¥'+expectedJuly];
   await page.waitForFunction(tokens => {const text=[...document.querySelectorAll('flt-semantics')].map(e=>e.getAttribute('aria-label')||e.textContent||'').join('\n');return tokens.every(token=>text.includes(token));},expected);
   await page.screenshot({path:`${root}/${label}-${scenario}.png`,fullPage:true});
   const otherErrors=errors.filter(e=>!e.startsWith('Failed to load resource: net::ERR_FAILED'));
   const otherDenied=denied.filter(d=>d.method!=='GET'||d.host!=='fonts.gstatic.com');
   if(pageErrors.length || otherErrors.length || otherDenied.length)throw new Error(JSON.stringify({pageErrors,otherErrors,otherDenied}));
   report.push({label,scenario,width,height,expected,pageErrors,errors,denied,deniedCount});
   } catch(error) {
    await page.screenshot({path:`${root}/${label}-${scenario}-failure.png`});
    const nodes=await page.evaluate(()=>[...document.querySelectorAll('flt-semantics')].map(e=>({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),rect:e.getBoundingClientRect().toJSON()})));
    await fs.writeFile(`${root}/${label}-${scenario}-nodes.json`,JSON.stringify(nodes,null,2));
    report.push({label,scenario,failed:String(error),pageErrors,errors,denied,deniedCount});throw error;
   } finally {await context.close();}
  }
 }
} finally {await browser.close();await fs.writeFile(root+'/RESULT.json',JSON.stringify(report,null,2));}
if(report.length!==6)throw new Error('incomplete cases');
