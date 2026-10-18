const {chromium}=require('playwright');
const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});const runs=[];
 try {for(let sample=1;sample<=3;sample++){
  const context=await browser.newContext({viewport:{width:1365,height:900},serviceWorkers:'block'});
  const page=await context.newPage();await page.addInitScript(()=>{window.__auditFrame=false;addEventListener('flutter-first-frame',()=>window.__auditFrame=true);});
  const client=await context.newCDPSession(page);await client.send('Network.enable');let rows=new Map();
  client.on('Network.requestWillBeSent',e=>{const u=new URL(e.request.url);rows.set(e.requestId,{resource:u.origin+u.pathname,type:e.type,bytes:0,cached:false});});
  client.on('Network.requestServedFromCache',e=>{if(rows.has(e.requestId))rows.get(e.requestId).cached=true;});
  client.on('Network.responseReceived',e=>{const r=rows.get(e.requestId);if(r){r.status=e.response.status;r.cached ||= Boolean(e.response.fromDiskCache||e.response.fromServiceWorker);r.mime=e.response.mimeType;}});
  client.on('Network.loadingFinished',e=>{if(rows.has(e.requestId))rows.get(e.requestId).bytes=e.encodedDataLength;});
  for(const visit of ['cold','warm']){
   rows=new Map();const start=Date.now();
   await page.goto('https://my-web-app-b67f4.web.app/',{waitUntil:'domcontentloaded',timeout:60000});
   let firstFrameMs=null;try{await page.waitForFunction(()=>window.__auditFrame,null,{timeout:90000});firstFrameMs=Date.now()-start;}catch{}
   await page.waitForTimeout(8000);
   const resources=[...rows.values()].sort((a,b)=>b.bytes-a.bytes);
   runs.push({sample,visit,firstFrameMs,windowMs:Date.now()-start,totalEncodedBytes:resources.reduce((n,r)=>n+r.bytes,0),resources});
   console.log(JSON.stringify({sample,visit,firstFrameMs,totalEncodedBytes:runs.at(-1).totalEncodedBytes,top:resources.slice(0,5)}));
  }await context.close();
 }}finally{await browser.close();fs.mkdirSync('transfer-results',{recursive:true});fs.writeFileSync('transfer-results/measurements.json',JSON.stringify({url:'https://my-web-app-b67f4.web.app/',method:'CDP loadingFinished encodedDataLength; service workers blocked; same context warm navigation; no cache-disabling routes; 8 second post-first-frame window',runs},null,2));}
 if(runs.length!==6)throw Error('Incomplete samples');
})().catch(e=>{console.error(e);process.exitCode=1;});
