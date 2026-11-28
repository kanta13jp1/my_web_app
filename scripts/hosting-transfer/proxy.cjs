const http=require('node:http');const https=require('node:https');const zlib=require('node:zlib');
const FONT_PRELOAD=/<link\b[^>]*rel="preload"[^>]*href="assets\/web\/assets\/fonts\/NotoSansJP-Regular\.ttf"[^>]*>\s*/;
async function startProxy(){let variant='baseline';const server=http.createServer((req,res)=>{
 const headers={};for(const name of ['accept','accept-encoding','if-none-match','if-modified-since','range'])if(req.headers[name])headers[name]=req.headers[name];
 const upstream=https.request({hostname:'my-web-app-b67f4.web.app',path:req.url,method:'GET',headers},response=>{
  const h={...response.headers};delete h['transfer-encoding'];
  if(req.url==='/'&&response.statusCode===200){const chunks=[];response.on('data',x=>chunks.push(x));response.on('end',()=>{try{let body=Buffer.concat(chunks);if(h['content-encoding']==='br')body=zlib.brotliDecompressSync(body);else if(h['content-encoding']==='gzip')body=zlib.gunzipSync(body);let html=body.toString();if(!FONT_PRELOAD.test(html))throw Error('Baseline font preload missing');if(variant==='optimized')html=html.replace(FONT_PRELOAD,'');delete h['content-encoding'];delete h.etag;h['cache-control']='no-cache';h['content-length']=Buffer.byteLength(html);res.writeHead(200,h);res.end(html);}catch(e){res.writeHead(500);res.end(e.message);}});
  }else{res.writeHead(response.statusCode,h);response.pipe(res);}
 });upstream.on('error',()=>{res.writeHead(502);res.end();});upstream.end();
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));return {url:`http://127.0.0.1:${server.address().port}/`,setVariant:v=>variant=v,close:()=>new Promise(r=>server.close(r))};}
module.exports={startProxy,FONT_PRELOAD};
