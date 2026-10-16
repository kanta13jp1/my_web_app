import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
const dir='.ci-logs/calendar-action-probe';
await mkdir(dir,{recursive:true});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1440,height:1000}});
const results=[];
const nextName='次のサイクル';
const shareName='今月の返済報告カードを作る（実額を公開）';
const next=()=>page.getByRole('button',{name:nextName,exact:true});
const share=()=>page.getByRole('button',{name:shareName,exact:true});
const popup=()=>page.getByRole('dialog').or(page.getByRole('alertdialog'));
const initial='2026/5/25〜6/24',following='2026/6/25〜7/24';
page.on('pageerror',e=>results.push({pageError:String(e)}));
async function hasRange(range){return page.evaluate(value=>Array.from(document.querySelectorAll('[role="group"]')).some(el=>(el.getAttribute('aria-label')??'').split('\n').includes(value)),range);}
async function popupCount(){return page.evaluate(()=>{const labels=Array.from(document.querySelectorAll('flt-semantics')).map(e=>e.getAttribute('aria-label')??e.textContent??'');const text=labels.join('\n').match(/fixture-popup-pushes:(\d+)/);if(!text)throw new Error('Missing popup counter');return Number(text[1]);});}
async function capture(stage){
  const snapshot=await page.evaluate(names=>{
    const buttons=Array.from(document.querySelectorAll('[role="button"]')).filter(e=>names.includes(e.getAttribute('aria-label')??e.textContent));
    const data=e=>{if(!e)return null;const r=e.getBoundingClientRect();return {id:e.id,identifier:e.getAttribute('flt-semantics-identifier'),role:e.getAttribute('role'),label:e.getAttribute('aria-label')??e.textContent,rect:{x:r.x,y:r.y,width:r.width,height:r.height}};};
    const ids=buttons.map(e=>e.id).filter(Boolean);
    return {generation:performance.timeOrigin,buttons:buttons.map(data),active:buttons.includes(document.activeElement)?data(document.activeElement):null,duplicateButtonIds:ids.filter((id,index)=>ids.indexOf(id)!==index),viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,offsetLeft:visualViewport?.offsetLeft,offsetTop:visualViewport?.offsetTop,scale:visualViewport?.scale},events:window.__probeEvents??[]};
  },[nextName,shareName]);
  if(snapshot.duplicateButtonIds.length)throw new Error('Duplicate button semantic IDs');
  results.push({stage,...snapshot});
  return snapshot;
}
async function visibleNext(){
  for(let i=0;i<40;i++){
    const rect=await next().boundingBox();
    if(rect&&rect.y>=180&&rect.y+rect.height<850)return rect;
    await page.mouse.move(700,650);await page.mouse.wheel(0,rect&&rect.y<180?-500:500);await page.waitForTimeout(80);
  }
  throw new Error('Next button not visibly placed');
}
async function prepare(scenario){
  await page.setViewportSize({width:1440,height:1000});
  const response=await page.goto('http://127.0.0.1:4173/');
  if(!response?.ok())throw new Error(`Fixture HTTP ${response?.status()}`);
  await next().waitFor({state:'attached',timeout:60000});
  await page.getByText('fixture-popup-pushes:0',{exact:true}).waitFor({state:'visible',timeout:5000});
  await page.waitForFunction(()=>Array.from(document.querySelectorAll('flt-semantics')).some(e=>/fixture-popup-pushes:0/.test(e.getAttribute('aria-label')??e.textContent??'')),undefined,{timeout:5000});
  await page.locator('#seo-shell').waitFor({state:'hidden',timeout:30000});
  await page.evaluate(names=>{
    window.__probeEvents=[];
    for(const type of ['pointerdown','pointerup','click','focusin'])document.addEventListener(type,event=>{
      const nodes=event.composedPath().filter(e=>e instanceof Element&&e.getAttribute('role')==='button'&&names.includes(e.getAttribute('aria-label')??e.textContent));
      if(nodes.length)window.__probeEvents.push({type,trusted:event.isTrusted,x:event.clientX,y:event.clientY,targets:nodes.map(e=>({id:e.id,role:e.getAttribute('role'),label:e.getAttribute('aria-label')??e.textContent}))});
    },true);
  },[nextName,shareName]);
  await visibleNext();await capture(`${scenario}:before-change`);
  if(scenario==='delayed-banner'){await page.getByRole('button',{name:'合成：遅延カード',exact:true}).click();await page.waitForFunction(()=>Array.from(document.querySelectorAll('flt-semantics')).some(el=>(el.getAttribute('aria-label')??el.textContent??'').split('\n').includes('合成：追加カード表示済み')));}
  if(scenario==='hide-show'){await page.getByRole('button',{name:'合成：非表示と再表示',exact:true}).click();await next().waitFor({state:'detached'});await next().waitFor({state:'attached'});}
  if(scenario==='modal'){await page.getByRole('button',{name:'合成：モーダル',exact:true}).click();await page.getByRole('button',{name:'合成モーダルを閉じる',exact:true}).click();}
  if(scenario==='viewport')await page.setViewportSize({width:980,height:900});
  await visibleNext();await page.waitForTimeout(150);
  if(!await hasRange(initial))throw new Error('Initial range mismatch');
  return popupCount();
}
async function activate(locator,name,input){
  if(input==='pointer'){
    const rect=await locator.boundingBox();if(!rect)throw new Error('Missing pointer rect');
    await page.mouse.click(rect.x+rect.width/2,rect.y+rect.height/2);
  }else if(input==='dom')await locator.evaluate(el=>el.click());
  else{
    let focused=false;
    for(let i=0;i<350;i++){
      await page.keyboard.press('Tab');
      const label=await page.evaluate(()=>(document.activeElement?.getAttribute('aria-label')??document.activeElement?.textContent));
      if(label===name){focused=true;break;}
    }
    if(!focused)throw new Error(`Focus not established: ${name}`);
    await capture(`keyboard-focus:${name}`);
    await page.keyboard.press('Enter');
  }
}
try{
  for(const scenario of ['baseline','delayed-banner','hide-show','modal','viewport'])for(const input of ['pointer','dom','keyboard']){
    const before=await prepare(scenario);const stage=`${scenario}:${input}`;
    await capture(`${stage}:immediately-before`);
    await activate(next(),nextName,input);
    await page.waitForFunction(value=>Array.from(document.querySelectorAll('[role="group"]')).some(el=>(el.getAttribute('aria-label')??'').split('\n').includes(value)),following,{timeout:5000});
    if(await popup().count()||await popupCount()!==before)throw new Error(`Unexpected popup: ${stage}`);
    await page.waitForTimeout(250);
    if(!await hasRange(following))throw new Error(`Range shifted more than once: ${stage}`);
    results.push({case:stage,nextTransitions:1,popupDelta:0,result:'expected single range change; no share dialog'});
    await capture(`${stage}:after`);
    await page.screenshot({path:`${dir}/${scenario}-${input}.png`});
  }
  for(const input of ['pointer','dom','keyboard']){
    const before=await prepare('baseline');
    await activate(share(),shareName,input);
    await popup().waitFor();
    await page.getByText('今月の返済報告を作る',{exact:true}).waitFor({state:'visible'});
    await popup().getByRole('button',{name:'閉じる',exact:true}).click();
    await popup().waitFor({state:'detached'});
    await page.waitForFunction(value=>Array.from(document.querySelectorAll('flt-semantics')).some(el=>(el.getAttribute('aria-label')??el.textContent??'').includes(`fixture-popup-pushes:${value}`)),before+1);
    if(await popupCount()!==before+1)throw new Error(`Share control popup count: ${input}`);
    if(!await hasRange(initial))throw new Error('Share control unexpectedly shifted cycle');
    results.push({case:`share-control:${input}`,nextTransitions:0,popupDelta:1,result:'share entry opens one preview; no publish action'});
  }
  if(results.some(result=>result.pageError))throw new Error('Fixture emitted a browser runtime error');
}catch(error){
  results.push({probeFailure:String(error)});
  await writeFile(`${dir}/synthetic-dom.html`,await page.content());
  await capture('probe-failure');
  await page.screenshot({path:`${dir}/probe-failure.png`});
  throw error;
}finally{
  await writeFile(`${dir}/evidence.json`,JSON.stringify(results,null,2));
  await browser.close();
}
