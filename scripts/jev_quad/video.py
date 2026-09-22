"""2x2 replay of actual parallel trials, aligned by elapsed simulation frame."""
import base64,http.server,threading,json,subprocess
from pathlib import Path
from playwright.sync_api import sync_playwright
class Quiet(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Quiet)
threading.Thread(target=server.serve_forever,daemon=True).start()
out=Path('out/quad/video');out.mkdir(exist_ok=True)
try:
 with sync_playwright() as pw:
  browser=pw.chromium.launch(args=['--autoplay-policy=no-user-gesture-required'])
  for mode in ['assisted','raw']:
   page=browser.new_page(viewport={'width':1024,'height':1240})
   page.goto(f'http://127.0.0.1:{server.server_port}/')
   result=page.evaluate('''async mode=>{
    const {World11,drawWorld}=await import('/out/lightgbm/frozen/world11.mjs');
    const {GameAudio}=await import('/out/lightgbm/frozen/audio.mjs');
    const names=['cloud_jev','localjev','lightgbm','laya'];
    const titles=['Cloud Jev API','LocalJev / Qwen 0.5B','Jev-distilled LightGBM','Laya / English 421M CPU'];
    const runs=await Promise.all(names.map(n=>fetch(`/out/quad/${n}-${mode}.json`).then(r=>r.json())));
    const lanes=runs.map(run=>({run,game:new World11(),index:0,action:'noop',accepted:0,overrides:0,fallback:0,shield:0,parity:false}));
    const canvas=document.createElement('canvas');canvas.width=1024;canvas.height=1240;document.body.replaceChildren(canvas);
    const ctx=canvas.getContext('2d');
    const audio=new GameAudio();await audio.enable(true);const capture=audio.captureOutput();
    const stream=canvas.captureStream(30);for(const track of capture.stream.getAudioTracks())stream.addTrack(track);
    const chunks=[],rec=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp8,opus',videoBitsPerSecond:2400000});
    rec.ondataavailable=e=>chunks.push(e.data);const done=new Promise(r=>rec.onstop=r);rec.start();
    const frames=Math.max(...runs.map(r=>r.frames));
    for(let frame=0;frame<=frames+180;frame++){
     ctx.fillStyle='#0c1525';ctx.fillRect(0,0,1024,1240);ctx.fillStyle='#fff';ctx.font='bold 24px sans-serif';
     ctx.fillText(`FOUR-LANE MARIO LAB | ${mode==='assisted'?'WITH SEARCH':'MODEL ONLY'}`,20,30);
     ctx.font='16px sans-serif';ctx.fillStyle='#b9c8dc';ctx.fillText('ACTUAL TRIAL LOG REPLAY | aligned t=0; not a live screen capture',20,56);
     ctx.fillText('Independent CPUs; no inference pause. Audio: LightGBM. Shield shown below.',20,80);
     for(let i=0;i<4;i++){
      const l=lanes[i],g=l.game,r=l.run,x=(i%2)*512,y=100+Math.floor(i/2)*560;
      while(l.index<r.trace.length&&r.trace[l.index].frame===g.frames){const d=r.trace[l.index++];l.action=d.effective;if(d.source==='survival-shield')l.shield++;else if(d.raw===null)l.fallback++;else if(d.accepted)l.accepted++;else l.overrides++;}
      if(g.frames<r.frames&&g.phase==='playing'){
       const a=mode==='assisted'&&g.p.grounded&&g.wasJump&&l.action.includes('jump')?(l.action==='jump'?'noop':l.action.replace('_jump','')):l.action;
       g.buttons(a);g.step();
      }
      if(!l.parity&&g.frames===r.frames){
       if(g.phase!==r.phase||Math.abs(g.p.x-r.x)>.00001)throw Error(`Replay mismatch ${r.lane}: ${g.phase}/${g.p.x} expected ${r.phase}/${r.x}`);
       l.parity=true;
      }
      // Preserve the verified terminal game state; all four retain their actual finish result.
      const sounds=g.drainSounds();if(i===2){for(const name of sounds)audio.effect(name);if(g.phase==='playing'&&frame<r.frames)audio.tick(g.room,{star:g.star>0,hurry:g.time<100});}
      ctx.fillStyle=['#59d5e4','#c5a0ff','#70dfac','#ffbf75'][i];ctx.font='bold 21px sans-serif';ctx.fillText(titles[i]+(r.mode==='assisted'&&r.shieldChanges!==undefined?` | shield ${l.shield}`:''),x+12,y+24);
      ctx.save();ctx.beginPath();ctx.rect(x+16,y+34,480,450);ctx.clip();ctx.translate(x+16,y+34);ctx.scale(1.875,1.875);drawWorld(ctx,g);ctx.restore();
      const returned=r.apiTrace.filter(a=>(a.received_frame??a.frame)<=g.frames&&!a.error);const a=returned.at(-1);
      ctx.fillStyle='#fff';ctx.font='16px monospace';ctx.fillText(`t=${(Math.min(frame,r.frames)/60).toFixed(2)}s x=${g.p.x.toFixed(0)} ${g.phase}`,x+12,y+507);
      ctx.fillText(`accepted ${l.accepted} / override ${l.overrides}`,x+12,y+529);
      ctx.font='14px monospace';ctx.fillStyle='#b9c8dc';ctx.fillText(`response ${a?Math.round(a.http_ms)+'ms':r.lane==='lightgbm'?'local trees':'waiting'} | fallback ${l.fallback}`,x+12,y+550);
     }
     await new Promise(requestAnimationFrame);
    }
    rec.stop();await done;audio.stop();capture.release();stream.getTracks().forEach(t=>t.stop());
    if(!lanes.every(l=>l.parity))throw Error('Missing terminal parity');
    const blob=new Blob(chunks,{type:'video/webm'}),data=await new Promise(r=>{const f=new FileReader();f.onload=()=>r(f.result.split(',')[1]);f.readAsDataURL(blob);});
    return {data,mode,frames,replayParity:true,results:runs.map(r=>({lane:r.lane,clear:r.clear,x:r.x,wall_ms:r.wall_ms,accepted:r.accepted,overrides:r.overrides,apiCalls:r.apiCalls})),label:'Measured parallel trials aligned to t=0; action replay, not live capture'};
   }''',mode)
   (out/f'four-lane-{mode}.webm').write_bytes(base64.b64decode(result.pop('data')))
   subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(out/f'four-lane-{mode}.webm'),'-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-movflags','+faststart',str(out/f'four-lane-{mode}.mp4')],check=True)
   (out/f'{mode}.json').write_text(json.dumps(result,indent=2))
   page.locator('canvas').screenshot(path=str(out/f'{mode}.png'));page.close()
  browser.close()
finally:server.shutdown()
