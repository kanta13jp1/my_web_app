const { chromium } = require('@playwright/test');
const { spawn } = require('node:child_process');
const fs = require('node:fs/promises');
async function main(){
 const root=process.env.LAB_BASE_URL;
 const server=root?null:spawn('python3',['-m','http.server','7394','--directory','web'],{stdio:'ignore'});
 const base=root||'http://127.0.0.1:7394/labs/blender-valve/';
 const browser=await chromium.launch({args:['--use-angle=swiftshader','--enable-webgl']});
 const results=[];
 await fs.mkdir('blender-browser',{recursive:true});
 try{
  if(server)for(let i=0;i<30;i++){try{if((await fetch(base)).ok)break;}catch{}await new Promise(r=>setTimeout(r,200));}
  for(const [name,width,height,fail] of [['desktop',1280,900,false],['mobile',390,844,false],['missing-model',390,844,true]]){
   const page=await browser.newPage({viewport:{width,height},reducedMotion:'reduce'});
   const errors=[];page.on('pageerror',e=>errors.push(e.message));
   if(fail)await page.route('**/valve.glb',r=>r.abort());
   await page.goto(base);
   await page.waitForFunction(()=>['3d','fallback'].includes(document.body.dataset.mode));
   const mode=await page.locator('body').getAttribute('data-mode');
   if(mode!==(fail?'fallback':'3d'))throw new Error(`${name}: unexpected ${mode}`);
   await page.getByRole('button',{name:'ハンドルを回す',exact:true}).click({clickCount:1});
   for(let i=0;i<2;i++)await page.getByRole('button',{name:'ハンドルを回す',exact:true}).click();
   if(!await page.getByRole('status').textContent().then(t=>t.includes('開きました')))throw new Error('valve did not open');
   if(!await page.getByRole('button',{name:'ハンドルを回す',exact:true}).isDisabled())throw new Error('over-rotation allowed');
   await page.screenshot({path:`blender-browser/${name}.png`,fullPage:true});
   await page.getByRole('button',{name:'やり直す',exact:true}).click();
   if(await page.locator('body').getAttribute('data-turns')!=='0')throw new Error('reset failed');
   if(!fail)await page.getByRole('button',{name:'左から見る',exact:true}).click();
   if(fail){await page.unroute('**/valve.glb');await page.getByRole('button',{name:'3Dを再読込'}).click();await page.waitForFunction(()=>document.body.dataset.mode==='3d');}
   if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw new Error('horizontal overflow');
   if(errors.length)throw new Error(errors.join('\n'));
   results.push({name,width,height,mode,open:true,reset:true,recovery:fail,errors});await page.close();
  }
 }finally{await browser.close();server?.kill();await fs.writeFile('blender-browser/results.json',JSON.stringify(results,null,2));}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
