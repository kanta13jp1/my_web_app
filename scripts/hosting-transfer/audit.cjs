const {chromium}=require('playwright');
const fs=require('node:fs');const {startProxy}=require('./proxy.cjs');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});const runs=[];const proxy=await startProxy();
 try {for(const variant of ['baseline','optimized']){proxy.setVariant(variant);for(let sample=1;sample<=4;sample++){
  const context=await browser.newContext({viewport:sample===4?{width:390,height:844}:{width:1365,height:900},isMobile:sample===4,serviceWorkers:'block'});
  const page=await context.newPage();const pageErrors=[];page.on('pageerror',e=>pageErrors.push(e.message.slice(0,300)));await page.addInitScript(()=>{window.__auditFrameAt=null;addEventListener('flutter-first-frame',()=>window.__auditFrameAt=performance.now());});
  const client=await context.newCDPSession(page);await client.send('Network.enable');let rows=new Map();
  client.on('Network.requestWillBeSent',e=>{const u=new URL(e.request.url);rows.set(e.requestId,{resource:u.origin+u.pathname,type:e.type,bytes:0,cached:false});});
  client.on('Network.requestServedFromCache',e=>{if(rows.has(e.requestId))rows.get(e.requestId).cached=true;});
  client.on('Network.responseReceived',e=>{const r=rows.get(e.requestId);if(r){r.status=e.response.status;r.cached ||= Boolean(e.response.fromDiskCache||e.response.fromServiceWorker);r.mime=e.response.mimeType;}});
  client.on('Network.loadingFinished',e=>{if(rows.has(e.requestId))rows.get(e.requestId).bytes=e.encodedDataLength;});
  for(const visit of ['cold','warm']){
   if(visit==='warm')await page.goto('about:blank');rows=new Map();const start=Date.now();
   await page.goto(proxy.url,{waitUntil:'domcontentloaded',timeout:60000});
   await page.waitForTimeout(30000);const firstFrameMs=await page.evaluate(()=>window.__auditFrameAt);fs.mkdirSync('transfer-results',{recursive:true});if(sample===1||sample===4)await page.screenshot({path:`transfer-results/${variant}-${sample===4?'mobile':'desktop'}-${visit}.png`});
   const resources=[...rows.values()].sort((a,b)=>b.bytes-a.bytes);
   runs.push({variant,sample,viewport:sample===4?'mobile':'desktop',visit,pageErrors:[...pageErrors],firstFrameMs,windowMs:Date.now()-start,totalEncodedBytes:resources.reduce((n,r)=>n+r.bytes,0),resources});
   console.log(JSON.stringify({variant,sample,visit,firstFrameMs,totalEncodedBytes:runs.at(-1).totalEncodedBytes,top:resources.slice(0,5)}));
  }await context.close();
 }}}finally{await browser.close();await proxy.close();fs.mkdirSync('transfer-results',{recursive:true});fs.writeFileSync('transfer-results/measurements.json',JSON.stringify({url:'https://my-web-app-b67f4.web.app/',method:'Paired loopback reverse proxy to same public deployment. Only document font preload removed in optimized variant; asset responses passed through unchanged. CDP encoded bytes, same-context cold/warm via about:blank before return, service workers blocked, no routing/cache disable, fixed 30 second observation after DOMContentLoaded. This isolates preload change; not a post-deployment measurement.',runs},null,2));}
 if(runs.length!==16)throw Error('Incomplete samples');
 const assert=require('node:assert/strict');
 for(const optimized of runs.filter(r=>r.variant==='optimized')){
  const fonts=optimized.resources.filter(r=>r.resource.includes('/NotoSansJP-Regular.ttf'));
  assert(fonts.some(r=>r.type==='Fetch'&&r.status===200),'Japanese font must remain available to Flutter');
  assert(!fonts.some(r=>r.type==='Font'),'Duplicate CSS-font preload must be absent');
  if(optimized.visit==='cold'){
   const baseline=runs.find(r=>r.variant==='baseline'&&r.sample===optimized.sample&&r.visit==='cold');
   assert(optimized.totalEncodedBytes<baseline.totalEncodedBytes*.85,'Cold transfer must fall by at least 15 percent');
  }
 }
 console.log('PASS: Japanese font preserved, duplicate removed, cold transfer reduced in desktop and mobile samples');
})().catch(e=>{console.error(e);process.exitCode=1;});
