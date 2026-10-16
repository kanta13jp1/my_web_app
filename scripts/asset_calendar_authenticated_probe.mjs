import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
const dir='.ci-logs/calendar-authenticated-probe';
await mkdir(dir,{recursive:true});
const browser=await chromium.launch({headless:true});
let page;
const results=[];
const blockedExternal=new Map();
const nextName='次のサイクル';
const shareName='今月の返済報告カードを作る（実額を公開）';
const next=()=>page.getByRole('button',{name:nextName,exact:true});
const share=()=>page.getByRole('button',{name:shareName,exact:true});
const popup=()=>page.getByRole('dialog').or(page.getByRole('alertdialog'));
const initial='2026/5/25〜6/24',following='2026/6/25〜7/24';
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

async function twoFrames(){await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));}
async function focusState(){
  return page.evaluate(names=>{
    const next=Array.from(document.querySelectorAll('[role="button"]')).find(e=>(e.getAttribute('aria-label')??e.textContent)===names[0]);
    const chain=[];
    let active=document.activeElement;
    while(active){
      const raw=active.getAttribute('aria-label')??active.textContent??'';
      const name=names.includes(raw)||(active.tagName==='BUTTON'&&raw.startsWith('Browser probe '))?raw:null;
      chain.push({tag:active.tagName,id:active.id,role:active.getAttribute('role'),name,tabIndex:active.tabIndex});
      const deeper=active.shadowRoot?.activeElement;
      if(!deeper||deeper===active)break;
      active=deeper;
    }
    const r=next?.getBoundingClientRect();
    return {chain,targetFocused:!!next&&(active===next||next.matches(':focus')),targetRect:r?{x:r.x,y:r.y,width:r.width,height:r.height}:null};
  },[nextName,shareName]);
}
async function activate(locator,name,input){
  if(input==='pointer'){
    const rect=await locator.boundingBox();if(!rect)throw new Error('Missing pointer rect');
    await page.mouse.click(rect.x+rect.width/2,rect.y+rect.height/2);
  }else if(input==='dom')await locator.evaluate(el=>el.click());
  else{
    // Enter Flutter through a visible, non-actionable date label, not a callback.
    const rect=await locator.boundingBox();
    if(!rect)throw new Error('Missing keyboard entry rect');
    results.push({focusStage:'toolbar-before-entry',focus:await focusState()});
    await page.mouse.click(rect.x-110,rect.y+rect.height/2);
    await twoFrames();
    if(!await hasRange(initial)||await popupCount()!==0)throw new Error('Keyboard entry unexpectedly activated a product action');
    results.push({focusStage:'flutter-date-label-entry',focus:await focusState()});
    let focused=false;
    const trace=[];
    for(let i=0;i<80;i++){
      await page.keyboard.press('Tab');
      await twoFrames();
      const state=await focusState();
      trace.push({tab:i+1,...state});
      if(state.targetFocused){focused=true;break;}
    }
    results.push({focusStage:'bounded-tab-trace',trace});
    if(!focused)throw new Error(`Focus not established after 80 observed Tabs: ${name}`);
    await capture(`keyboard-focus:${name}`);
    await page.keyboard.press('Enter');
  }
}
async function textVisible(value){return page.evaluate(value=>Array.from(document.querySelectorAll('flt-semantics')).some(e=>(e.getAttribute('aria-label')??e.textContent??'').split('\n').includes(value)),value);}
async function waitCard(){await page.waitForFunction(()=>Array.from(document.querySelectorAll('flt-semantics')).some(e=>(e.getAttribute('aria-label')??e.textContent??'').split('\n').includes('貯蓄目標と生活費の計画')),undefined,{timeout:10000});}
async function status(){return page.locator('#probe-public-status').innerText();}
async function audit(stage){
  await page.getByRole('button',{name:'Browser probe audit transport',exact:true}).click();
  const value=await status();
  if(!value.includes('owner=synthetic')||!value.includes('forwarded=0')||!value.includes('dataFrames=settled'))throw new Error(`Invalid fixture transport status ${value}`);
  results.push({transportStage:stage,status:value});
}
async function prepare(mode){
  const context=await browser.newContext({viewport:{width:1440,height:1000},serviceWorkers:'block'});
  await context.route('**/*',async route=>{
    const request=route.request(),url=new URL(request.url());
    if(url.origin==='http://127.0.0.1:4173'&&request.method()==='GET')return route.continue();
    const key=`${request.method()} ${url.origin}${url.pathname}`;
    const previous=blockedExternal.get(key);
    if(previous)previous.count++;
    else blockedExternal.set(key,{method:request.method(),origin:url.origin,path:url.pathname,count:1});
    return route.abort('blockedbyclient');
  });
  page=await context.newPage();
  page.on('pageerror',error=>results.push({pageError:String(error)}));
  const response=await page.goto(`http://127.0.0.1:4173/?semantics=${mode==='early-pointer'||mode==='share-pointer'?'early':'late'}`);
  if(!response?.ok())throw new Error(`Fixture HTTP ${response?.status()}`);
  await page.locator('#probe-public-status').waitFor({state:'visible',timeout:60000});
  await page.locator('#seo-shell').waitFor({state:'hidden',timeout:30000});
  const before=await status();
  if(!before.includes('dataFrames=waiting')||!before.includes('history=0')||!before.includes('loads=0'))throw new Error(`Gate not held ${before}`);
  if(mode.startsWith('late')){
    if(!before.includes('semantics=disabled')||await next().count()!==0)throw new Error('Late semantics was already enabled');
    if(mode==='late-before-card-dom')await page.getByRole('button',{name:'Browser probe enable semantics',exact:true}).click();
  }else{
    await next().waitFor({state:'attached'});
    if(await textVisible('貯蓄目標と生活費の計画'))throw new Error('Real card appeared before synthetic delivery');
  }
  await page.getByRole('button',{name:'Browser probe release data',exact:true}).click();
  await page.waitForFunction(()=>document.getElementById('probe-public-status')?.textContent?.includes('dataFrames=settled'),undefined,{timeout:10000});
  if(mode==='late-after-card-keyboard'){
    if(!(await status()).includes('semantics=disabled')||await next().count()!==0)throw new Error('Late-after-data semantics enabled early');
    await page.screenshot({path:`${dir}/${mode}-before-enable.png`});
    results.push({stage:`${mode}:before-enable`,status:await status(),note:'Synthetic GET and DI completed plus two rendered frames; inspect PNG for actual card before enable.'});
    await page.getByRole('button',{name:'Browser probe enable semantics',exact:true}).click();
  }
  await next().waitFor({state:'attached'});
  await waitCard();
  await audit(`${mode}:ready`);
  await page.evaluate(names=>{
    window.__probeEvents=[];
    for(const type of ['pointerdown','pointerup','click','focusin'])document.addEventListener(type,event=>{
      const nodes=event.composedPath().filter(e=>e instanceof Element&&e.getAttribute('role')==='button'&&names.includes(e.getAttribute('aria-label')??e.textContent));
      if(nodes.length)window.__probeEvents.push({type,trusted:event.isTrusted,x:event.clientX,y:event.clientY,targets:nodes.map(e=>({id:e.id,role:e.getAttribute('role'),label:e.getAttribute('aria-label')??e.textContent}))});
    },true);
  },[nextName,shareName]);
  await visibleNext();
  if(!await hasRange(initial)||await popupCount()!==0)throw new Error('Initial range/counter mismatch');
  await capture(`${mode}:before`);
  return context;
}
let context;
let failures=0;
try{
  for(const [mode,input] of [['early-pointer','pointer'],['late-before-card-dom','dom'],['late-after-card-keyboard','keyboard'],['share-pointer','pointer']]){
    try{
      context=await prepare(mode);
      if(mode==='share-pointer'){
        await activate(share(),shareName,'pointer');
        await popup().waitFor();
        await page.getByText('今月の返済報告を作る',{exact:true}).waitFor({state:'visible'});
        await page.screenshot({path:`${dir}/share-preview.png`});
        await popup().getByRole('button',{name:'閉じる',exact:true}).click();
        await popup().waitFor({state:'detached'});
        if(await popupCount()!==1||!await hasRange(initial))throw new Error('Share control counter/range mismatch');
        results.push({case:mode,result:'success',nextTransitions:0,popupDelta:1,realCardObserved:true});
      }else{
        await activate(next(),nextName,input);
        await page.waitForFunction(value=>Array.from(document.querySelectorAll('[role="group"]')).some(e=>(e.getAttribute('aria-label')??'').split('\n').includes(value)),following,{timeout:5000});
        if(await popup().count()||await popupCount()!==0)throw new Error(`Unexpected popup ${mode}`);
        await page.waitForTimeout(250);
        if(!await hasRange(following))throw new Error(`Range moved more than once ${mode}`);
        results.push({case:mode,result:'success',nextTransitions:1,popupDelta:0,realCardObserved:true});
      }
      await capture(`${mode}:after`);
      await page.screenshot({path:`${dir}/${mode}.png`});
      await audit(`${mode}:after`);
    }catch(error){
      failures++;
      results.push({case:mode,result:'failure',probeFailure:String(error)});
      if(page&&!page.isClosed()){
        await writeFile(`${dir}/${mode}-synthetic-dom.html`,await page.content());
        await capture(`${mode}:failure`);
        await page.screenshot({path:`${dir}/${mode}-failure.png`});
      }
    }finally{
      if(context)await context.close();
      else if(page&&!page.isClosed())await page.context().close();
      context=undefined;
    }
  }
  if(failures||results.some(x=>x.pageError))throw new Error(`Synthetic browser failures: ${failures}`);
}finally{
  const blocked=Array.from(blockedExternal.values());
  results.push({blockedBrowserRequestTotal:blocked.reduce((sum,x)=>sum+x.count,0),blockedBrowserRequestUnique:blocked.length,blockedBrowserRequestSamples:blocked.slice(0,32)});
  await writeFile(`${dir}/evidence.json`,JSON.stringify(results,null,2));
  await browser.close();
}
