import { StudentSession } from './student-session.mjs?v=student-1';
import { ReactionAssist, hazards, prediction } from './reaction.mjs?v=student-1';
import { GameRecording } from './recording.mjs?v=student-1';
import { GameAudio } from './audio.mjs?v=student-1';
import { World11, drawWorld, playerPose } from './world11.mjs?v=student-1';
import { BUTTONS, DecisionLoop, fixture, readState, summarize, validateRom } from './core.mjs?v=student-1';
const $ = id => document.getElementById(id);
let connected = false, pendingBridge = null, seq = 0, samples = [], nes = null, romBytes = null;
let presentationBudget=0;
let gameRunning = false, lastFrame = 0, frameBudget = 0, lastResponse = 0, frameCount = 0, metadata = {};
const origin = location.origin;
const canvas = $('screen'), context = canvas.getContext('2d'), pixels = context.createImageData(256, 240);
const status = text => { $('status').textContent = text; };
const isRom = () => $('mode').value === 'game';
const isRecreation = () => $('mode').value === 'recreation';
const isGame = () => isRom() || isRecreation();
const world = new World11();
const audio = new GameAudio();
const student = new StudentSession();
const assist=new ReactionAssist();let proposedAction='noop',interventions=[],lastIntervention='';
const assistanceEnabled=()=>isRecreation()&&metadata.controller==='jev_plus_local';
async function unlockAudio() {
  if (!$('sound').checked || !isRecreation()) return;
  const ok = await audio.enable(true);
  $('audio-status').textContent = ok ? '音声ON（プレイ中に再生）' : '音声を開始できません。もう一度ONにしてください。';
  if (!ok) $('sound').checked = false;
}
$('sound').onchange = () => { if ($('sound').checked) void unlockAudio(); else { audio.enable(false); $('audio-status').textContent='ミュート'; } };
$('volume').oninput = () => { audio.setVolume(Number($('volume').value)/100); $('volume-value').textContent=$('volume').value+'%'; };

let recordUrl = null, recordStarting = false, recordEpoch = 0;
const recording = new GameRecording({ canvas,
  changed: () => { $('record-start').disabled = !recording.supported || recording.active || recordStarting || !isGame(); $('record-stop').disabled = !recording.active || recording.finishing; if(recording.finishing)$('record-status').textContent='動画を作成しています…'; },
  failed: message => { $('record-status').textContent=message; },
  ready: (blob,extension,reason) => {
    const old=recordUrl;recordUrl=URL.createObjectURL(blob);
    $('record-preview').src=recordUrl;$('record-preview').load();
    $('record-download').href=recordUrl;$('record-download').download='jev-mario-'+new Date().toISOString().replace(/[:.]/g,'-')+'.'+extension;
    $('record-result').hidden=false;
    $('record-status').textContent=reason+'。再生確認してダウンロードできます。';
    if(old)URL.revokeObjectURL(old);
  }
});
recording.changed();
if(!recording.supported)$('record-status').textContent='このブラウザは録画に対応していません。Chrome / Edgeなどの対応ブラウザでお試しください。';
function stopRecording(reason){recordEpoch++;recording.stop(reason);}
$('record-start').onclick=async()=>{
  if(recordStarting||recording.active||!isGame())return;
  recordStarting=true;const epoch=++recordEpoch;recording.changed();
  try{
    if(isRecreation())await unlockAudio();
    if(epoch!==recordEpoch)return;
    const output=isRecreation()?audio.captureOutput():null;
    if(recording.start(output)){
      $('record-status').textContent='● 録画中（最大60秒）'+(output?'・ゲーム音あり':'・音声なし');
      canvas.focus();
    }
  }catch{ $('record-status').textContent='録画を開始できませんでした。再試行してください。'; }
  finally{recordStarting=false;recording.changed();}
};
$('record-stop').onclick=()=>stopRecording();
for(const id of ['mode','restart-local','reset','rom'])$(id).addEventListener(id==='mode'||id==='rom'?'change':'click',()=>{stopRecording('ゲームを変更したため録画を停止しました');recording.changed();});
window.addEventListener('blur',()=>stopRecording('画面から離れたため録画を停止しました'));
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopRecording('バックグラウンドになったため録画を停止しました');});
window.addEventListener('pagehide',()=>{stopRecording();if(recordUrl)URL.revokeObjectURL(recordUrl);});

drawWorld(context, world);
function showPose(){const pose=playerPose(world);$('posture').textContent='姿勢: '+(pose==='dead'?'ミス':pose==='climb'?'旗を降りる':pose==='skid'?'ブレーキ':pose==='crouch'?'しゃがみ':pose==='jump'?'上昇':pose==='fall'?'下降':pose==='idle'?'待機':world.input.run?'走る':'歩く')+' ／ '+((world.p.facing??1)<0?'左向き':'右向き');}
showPose();
$('progress').textContent = '1-1 再現ゲーム · 手動またはJev操作で開始';
function controls(action) {
  proposedAction=action;world.buttons(action);
  if (nes) {
    for (let i = 0; i < 8; i++) nes.buttonUp(1, i);
    for (const b of BUTTONS[action] ?? []) nes.buttonDown(1, b);
  }
  $('action').textContent = `操作: ${action}`;
}
function stop(reason = '停止しました') { if(student.active)metadata.student_result={phase:world.phase,x:world.p.x,frames:world.frames,...student.stats};student.stop();audio.stop(); loop.stop(reason); gameRunning = false; controls('noop'); status(reason); }
function state() {
  const value = isRecreation() ? world.telemetry(lastResponse) : isRom() ? readState(nes.cpu.mem, lastResponse) : fixture();
  if(isRecreation()&&metadata.input_profile==='prediction_v1')value.prediction=prediction(world,lastResponse);
  $('state').textContent = JSON.stringify(value, null, 2); return value;
}
function metric(id, values) {
  const s = summarize(values); $(id).textContent = s.count ? `${s.median.toFixed(1)} / ${s.p95.toFixed(1)} ms` : '—';
}
function update() {
  const ok = samples.filter(s => s.ok);
  $('counts').textContent = `${ok.length} / ${samples.filter(s=>!s.ok&&!s.cancelled).length} / ${ok.filter(s => s.stale).length}`;
  $ ('sample-detail').textContent=`操作適用 ${ok.filter(s=>s.applied).length}件 / 停止時キャンセル ${samples.filter(s=>s.cancelled).length}件`;
  const stale = ok.filter(s => s.stale).length;
  $('response-warning').textContent = stale ? `${stale}件の応答は有効期限（${metadata.max_age_ms} ms）を超えたため操作に適用していません。停止後に有効期限を変更して再測定できます。` : '';
  metric('rtt', ok.map(s => s.rtt_ms)); metric('upstream', ok.map(s => s.upstream_http_ms));
  metric('age', isGame() ? ok.filter(s => s.applied).map(s => s.observation_to_input_ms) : []);
}
function request(value) {
  if (!connected || pendingBridge) return Promise.reject(new Error('アプリへ戻ってログイン状態を確認してください。'));
  return new Promise((resolve, reject) => {
    const id = ++seq;
    const timer = setTimeout(() => {
      if (pendingBridge?.id === id) { pendingBridge = null; reject(new Error('応答が時間内に届きませんでした。停止後に再試行してください。')); }
    }, 8000);
    pendingBridge = { id, resolve, reject, timer };
    parent.postMessage({ type: 'jev-mario-request', id, state: value, consent: true }, origin);
  });
}
window.addEventListener('message', e => {
  if (e.origin !== origin || e.source !== parent) return;
  if (e.data?.type === 'jev-mario-ready') { connected = true; if(!student.active)status('準備完了。モードを選び、送信に同意して測定してください。'); }
  if (e.data?.type !== 'jev-mario-response' || !pendingBridge || e.data.id !== pendingBridge.id) return;
  const p = pendingBridge; pendingBridge = null; clearTimeout(p.timer);
  if (e.data.error) p.reject(new Error(e.data.error)); else p.resolve(e.data.result);
});
const loop = new DecisionLoop({ request, state, observe:()=>isRecreation()?{...world.snapshot(),hazards:hazards(world)}:null, apply: controls,
  record: s => { samples.push({ index: samples.length + 1, ...s }); lastResponse = s.rtt_ms;
    if (!s.ok) $('last-error').textContent = s.error; update(); },
  done: reason => { audio.stop(); gameRunning = false; status(reason); },
});
parent.postMessage({ type: 'jev-mario-hello' }, origin);
setTimeout(() => { if (!connected&&!student.active) status('my_web_appの「Jev Mario Lab」から開いてください。このページ単独ではAPIを呼び出せません。'); }, 3000);
$('input-profile').onchange=()=>stop('入力条件を変更しました。最初からに戻して比較してください');
$('mode').addEventListener('change', () => { stop('モードを変更しました'); $('rom-controls').hidden = !isRom(); $('recreation-controls').hidden = !isRecreation(); $('touch-controls').hidden = !isRecreation();
  if (isRecreation()) {drawWorld(context,world);showPose();} else context.clearRect(0,0,256,240);
  $('mode-note').textContent = isRecreation() ? '初代1-1を参考に一から実装した再現ゲームです。原作ROMの実行や完全一致ではありません。手動プレイはAPI不要です。' : isRom() ? '手元のROMで手動プレイを開始し、1-1の操作可能な場面から測定します。' : '合成したゲーム状態を繰り返し送ります。実ゲームのプレイ結果ではありません。';
  samples = []; update(); $('state').textContent = ''; });
$('rom').addEventListener('change', async e => {
  stop(); const file = e.target.files[0]; if (!file) return;
  try {
    if (file.size > 42000) throw new Error('対応するSMB1の .nes ファイルを選んでください。');
    const bytes = new Uint8Array(await file.arrayBuffer()); validateRom(bytes);
    if (!window.jsnes) throw new Error('エミュレーターを読み込めませんでした。ページを再読み込みしてください。');
    nes = new window.jsnes.NES({ emulateSound: false, onFrame: frame => {
      for (let i = 0; i < frame.length; i++) {
        pixels.data[i * 4] = frame[i] & 255; pixels.data[i * 4 + 1] = (frame[i] >> 8) & 255;
        pixels.data[i * 4 + 2] = (frame[i] >> 16) & 255; pixels.data[i * 4 + 3] = 255;
      }
      context.putImageData(pixels, 0, 0);
    } });
    nes.loadROM(bytes); romBytes = bytes; frameCount = 0;
    $('progress').textContent = 'ROM読込済み（ゲーム識別は未検証）。手動プレイで1-1へ進んでください。'; status('ROMをブラウザ内に読み込みました');
  } catch(e) { nes = null; romBytes = null; $('last-error').textContent = e.message; status('ROMを読み込めませんでした'); }
});
$('manual').onclick = () => { stop(); if (!nes) return status('先にROMを選んでください'); gameRunning = true; status('手動操作中。EnterでSTART、Xでジャンプ、Zでダッシュ。'); };
$('reset').onclick = () => { stop(); if (nes && romBytes) { nes.loadROM(romBytes); frameCount = 0; status('リセットしました'); } };
$('play-local').onclick = () => { stop(); if(world.phase !== 'playing') world.reset(); gameRunning=true; void unlockAudio(); canvas.focus(); status('手動プレイ中（API呼び出しなし）'); };
$('restart-local').onclick = () => { stop(); world.reset(); {drawWorld(context,world);showPose();} $('progress').textContent='1-1をリセットしました'; };
$('play-student').onclick=()=>{
  if(!isRecreation())return status('1-1再現ゲームを選んでください');
  if(loop.pending||pendingBridge)return status('API応答の終了を待ってから開始してください');
  stop();world.reset();frameCount=0;samples=[];interventions=[];metadata={lab_revision:'student-1',controller:'lightgbm_plus_search',mode:'recreation',started_at:new Date().toISOString(),timing:'Browser rendering and asynchronous local search; no API requests'};update();
  $('last-error').textContent='';void unlockAudio();status('学習済みモデルを読み込んでいます…');
  student.start({ready:()=>{gameRunning=true;frameBudget=0;canvas.focus();status('LightGBM＋探索でプレイ中（API呼び出しなし）');},update:stats=>{$('student-status').textContent=`モデル案採用 ${stats.accepted} / 探索変更 ${stats.overrides} / ジャンプ押し直し ${stats.jump_releases}。JSONに内訳を保存できます。`;},error:()=>{gameRunning=false;audio.stop();controls('noop');status('ローカルモデルを開始・継続できませんでした。再読み込みして再試行してください。');}});
};
$('start').onclick = () => {
  if(student.active)return status('ローカルプレイを停止してからJev測定を開始してください');
  $('last-error').textContent = '';
  if (!$('consent').checked) return status('ゲーム状態の送信に同意してください');
  if (!connected) return status('アプリから開いてログインしてください');
  if (loop.active || loop.pending || pendingBridge) return status('現在の測定を停止し、応答が終了するまでお待ちください');
  if (isRecreation() && world.phase !== 'playing') return status('1-1を最初からやり直してください');
  if (isRom() && (!nes || nes.cpu.mem[0x770] !== 1 || nes.cpu.mem[0x75f] !== 0 || nes.cpu.mem[0x75c] !== 0 || nes.cpu.mem[0xe] !== 8)) return status('対応ROMを読み込み、手動で1-1の操作可能な場面まで進めてください');
  samples = []; lastResponse = 0; interventions=[];lastIntervention='';assist.reset();update(); metadata = { lab_revision: 'feedback-1', controller:isRecreation()?$('controller').value:'jev_only', input_profile:isRecreation()?$('input-profile').value:'baseline', started_at: new Date().toISOString(), mode: $('mode').value,
    cadence_ms: Number($('cadence').value), max_calls: Number($('count').value), max_duration_ms: 60000, max_age_ms: Number($('max-age').value),
    emulator: isRecreation() ? 'independent-world11-v5' : 'jsnes@2.1.0', timing: 'browser RTT includes proxy/auth/quota; upstream HTTP is not pure inference', user_agent: navigator.userAgent };
  gameRunning = isGame(); status(isGame() ? 'Jev操作を計測中。通信待ち中もゲームは進みます。' : '固定状態でAPI往復を測定中（実プレイではありません）');
  if (isRecreation()) void unlockAudio();
  loop.start({ count: metadata.max_calls, cadence: metadata.cadence_ms, maxAge: metadata.max_age_ms });
};
$('stop').onclick = () => {stop();stopRecording();};
$('controller').onchange=()=>{stop('操作方式を変更しました。測定を再開してください。');assist.reset();};
$('max-age').onchange = () => stop('応答の有効期限を変更しました。測定を再開してください。');
$('consent').onchange = () => { if (!$('consent').checked) stop('送信同意を解除しました'); };
$('export').onclick = () => {
  const data = { ...metadata, samples, local_interventions:interventions, student:metadata.controller==='lightgbm_plus_search'?student.stats:undefined, counts: { attempts: samples.length, failures: samples.filter(s => !s.ok&&!s.cancelled).length, cancelled: samples.filter(s=>s.cancelled).length, applied: samples.filter(s=>s.applied).length, stale: samples.filter(s=>s.stale).length },
    browser_rtt: summarize(samples.filter(s => s.ok).map(s => s.rtt_ms)) };
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
  const a = document.createElement('a'); a.href = url; a.download = 'jev-mario-measurement.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
};
const keys = { ArrowRight: 7, ArrowLeft: 6, KeyX: 0, Space: 0, KeyZ: 1, Enter: 3, ArrowDown: 5 };
const inputNames = {7:'right',6:'left',0:'jump',1:'run',5:'down'};
function manualKey(code,pressed) { if(loop.active||student.active) return; if(isRecreation()) { const key=inputNames[code]; if(key) world.input[key]=pressed; } else if(nes) nes[pressed?'buttonDown':'buttonUp'](1,code); }
window.addEventListener('keydown', e => { if (e.target.matches('input,select,button') || !gameRunning || loop.active || student.active || !(e.code in keys)) return; e.preventDefault(); manualKey(keys[e.code],true); });
window.addEventListener('keyup', e => { if(e.code in keys) manualKey(keys[e.code],false); });
for(const button of document.querySelectorAll('[data-key]')) {
  button.addEventListener('pointerdown', e => { if(!gameRunning||loop.active||student.active)return; e.preventDefault(); button.setPointerCapture(e.pointerId);world.input[button.dataset.key]=true; });
  for(const event of ['pointerup','pointercancel','lostpointercapture']) button.addEventListener(event,()=>{world.input[button.dataset.key]=false;});
}
window.addEventListener('blur', () => stop('画面から離れたため停止しました'));
document.addEventListener('visibilitychange', () => { if (document.hidden) stop('バックグラウンドになったため停止しました'); });
window.addEventListener('pagehide', () => stop());
function frame(now) {
  const delta = lastFrame ? Math.min(100, now - lastFrame) : 0; lastFrame = now;
  if (gameRunning && (isRecreation() || nes)) {
    frameBudget += delta;
    if(student.active&&performance.now()-student.started>=60000)stop('ローカルプレイの60秒上限に達しました');
    try {
      while (frameBudget >= 1000 / 60 && gameRunning) {
        if(isRecreation()) {
          if(student.active){const action=student.tick(world);world.buttons(action);$('action').textContent=`操作: ${action}`;}
          if(loop.active&&assistanceEnabled()){
            const decision=assist.decide(world,proposedAction);world.buttons(decision.action);
            const key=decision.reason+':'+decision.action;
            if(key!==lastIntervention){
              if(decision.reason&&interventions.length<600)interventions.push({frame:world.frames,proposed:proposedAction,...decision});
              lastIntervention=key;
              $('assist-status').textContent=decision.reason?'ローカル補助: '+decision.reason+' → '+decision.action:'Jevの操作を適用中';
            }
          }
          world.step();
        } else nes.frame(); frameCount++; frameBudget -= 1000 / 60;
        if(isRecreation() && world.phase !== 'playing') stop(world.phase === 'won' ? '1-1クリア！' : 'ミス！「1-1を最初から」で再挑戦できます');
        if(isRecreation()) for(const sound of world.drainSounds()) audio.effect(sound);
        if (isRom() && loop.active && ([6, 11].includes(nes.cpu.mem[0xe]) || nes.cpu.mem[0xb5] >= 2 || nes.cpu.mem[0x770] === 2 || nes.cpu.mem[0x1d] === 3)) stop('死亡またはコース終了で停止しました');
      }
      if(gameRunning && isRecreation()) audio.tick(world.room,{star:world.star>0,hurry:world.time<=100});
      const s = isRecreation() ? world.telemetry() : readState(nes.cpu.mem); if(isRecreation()) {drawWorld(context,world);showPose();} $('progress').textContent = `World ${s.world}-${s.stage} · x=${Math.round(s.player.x)} · ${frameCount} frames${isRecreation() ? ' · 再現ゲーム · '+world.phase : ''}`;
    } catch { stop('エミュレーターを継続できません。対応ROMを確認してください。'); }
  } else {frameBudget=0;if(!document.hidden&&isRecreation()&&world.phase!=='playing'&&world.presentation<180){presentationBudget+=delta;while(presentationBudget>=1000/60){world.presentationStep();for(const sound of world.drainSounds())audio.effect(sound);presentationBudget-=1000/60;}drawWorld(context,world);showPose();}}
  if(isRecreation()&&world.phase!=='playing'&&world.presentation>=180)recording.stop('ゲーム終了で録画を停止しました');
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
