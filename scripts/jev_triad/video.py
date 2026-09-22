"""Record an explicitly labelled replay of measured controls, not live inference."""
import base64,http.server,threading,json
from pathlib import Path
from playwright.sync_api import sync_playwright
class Quiet(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Quiet);threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright()as pw:
  browser=pw.chromium.launch(args=['--autoplay-policy=no-user-gesture-required']);page=browser.new_page()
  page.goto(f'http://127.0.0.1:{server.server_port}/')
  result=page.evaluate('''async()=>{
    const {World11,drawWorld}=await import('/out/lightgbm/frozen/world11.mjs');
    const {GameAudio}=await import('/out/lightgbm/frozen/audio.mjs');
    const trace=await (await fetch('/out/triad/lightgbm-0-trace.json')).json();
    const expected=(await (await fetch('/out/triad/lightgbm.json')).json()).episodes[0];
    const canvas=document.createElement('canvas');canvas.width=512;canvas.height=520;document.body.replaceChildren(canvas);const ctx=canvas.getContext('2d');
    const game=new World11(),audio=new GameAudio();await audio.enable(true);const audioCapture=audio.captureOutput();
    const stream=canvas.captureStream(30);for(const t of audioCapture.stream.getAudioTracks())stream.addTrack(t);
    const chunks=[],recorder=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp8,opus',videoBitsPerSecond:1400000});recorder.ondataavailable=e=>chunks.push(e.data);const finished=new Promise(r=>recorder.onstop=r);recorder.start();
    let index=0,action='noop';
    for(let frame=0;frame<expected.frames+200;frame++){
      if(trace[index]?.frame===game.frames)action=trace[index++].effective;
      const edge=game.p.grounded&&game.wasJump&&action.includes('jump')?(action==='jump'?'noop':action.replace('_jump','')):action;
      game.buttons(edge);game.step();for(const name of game.drainSounds())audio.effect(name);
      if(game.phase==='playing')audio.tick(game.room,{star:game.star>0,hurry:game.time<100});
      ctx.fillStyle='#101827';ctx.fillRect(0,0,512,520);ctx.fillStyle='#fff';ctx.font='14px monospace';ctx.fillText('LightGBM + search | ACTION TRACE REPLAY',8,17);ctx.fillText('Recorded controls; not live API / inference',8,35);
      ctx.save();ctx.translate(0,40);ctx.scale(2,2);drawWorld(ctx,game);ctx.restore();
      await new Promise(requestAnimationFrame);
    }
    recorder.stop();await finished;audio.stop();audioCapture.release();stream.getTracks().forEach(t=>t.stop());
    const blob=new Blob(chunks,{type:'video/webm'});const data=await new Promise(r=>{const reader=new FileReader();reader.onload=()=>r(reader.result.split(',')[1]);reader.readAsDataURL(blob);});
    return {data,phase:game.phase,expectedClear:expected.clear,frames:expected.frames,mime:blob.type};
  }''')
  assert result['phase']=='won' and result['expectedClear']
  Path('out/triad/lightgbm-clear-replay.webm').write_bytes(base64.b64decode(result.pop('data')))
  Path('out/triad/video.json').write_text(json.dumps(result,indent=2));page.screenshot(path='out/triad/clear-replay.png');browser.close()
finally:server.shutdown()
