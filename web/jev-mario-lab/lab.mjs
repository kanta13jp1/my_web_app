import { BUTTONS, DecisionLoop, fixture, readState, summarize, validateRom } from './core.mjs';
const $ = id => document.getElementById(id);
let connected = false, pendingBridge = null, seq = 0, samples = [], nes = null, romBytes = null;
let gameRunning = false, lastFrame = 0, frameBudget = 0, lastResponse = 0, frameCount = 0, metadata = {};
const origin = location.origin;
const canvas = $('screen'), context = canvas.getContext('2d'), pixels = context.createImageData(256, 240);
const status = text => { $('status').textContent = text; };
const isGame = () => $('mode').value === 'game';
function controls(action) {
  if (nes) {
    for (let i = 0; i < 8; i++) nes.buttonUp(1, i);
    for (const b of BUTTONS[action] ?? []) nes.buttonDown(1, b);
  }
  $('action').textContent = `操作: ${action}`;
}
function stop(reason = '停止しました') { loop.stop(reason); gameRunning = false; controls('noop'); status(reason); }
function state() {
  const value = isGame() ? readState(nes.cpu.mem, lastResponse) : fixture();
  $('state').textContent = JSON.stringify(value, null, 2); return value;
}
function metric(id, values) {
  const s = summarize(values); $(id).textContent = s.count ? `${s.median.toFixed(1)} / ${s.p95.toFixed(1)} ms` : '—';
}
function update() {
  const ok = samples.filter(s => s.ok);
  $('counts').textContent = `${ok.length} / ${samples.length - ok.length} / ${ok.filter(s => s.stale).length}`;
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
  if (e.data?.type === 'jev-mario-ready') { connected = true; status('準備完了。モードを選び、送信に同意して測定してください。'); }
  if (e.data?.type !== 'jev-mario-response' || !pendingBridge || e.data.id !== pendingBridge.id) return;
  const p = pendingBridge; pendingBridge = null; clearTimeout(p.timer);
  if (e.data.error) p.reject(new Error(e.data.error)); else p.resolve(e.data.result);
});
const loop = new DecisionLoop({ request, state, apply: controls,
  record: s => { samples.push({ index: samples.length + 1, ...s }); lastResponse = s.rtt_ms;
    if (!s.ok) $('last-error').textContent = s.error; update(); },
  done: reason => { gameRunning = false; status(reason); },
});
parent.postMessage({ type: 'jev-mario-hello' }, origin);
setTimeout(() => { if (!connected) status('my_web_appの「Jev Mario Lab」から開いてください。このページ単独ではAPIを呼び出せません。'); }, 3000);
$('mode').addEventListener('change', () => { stop('モードを変更しました'); $('rom-controls').hidden = !isGame();
  $('mode-note').textContent = isGame() ? '手元のROMで手動プレイを開始し、1-1の操作可能な場面から測定します。' : '合成したゲーム状態を繰り返し送ります。実ゲームのプレイ結果ではありません。';
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
$('start').onclick = () => {
  $('last-error').textContent = '';
  if (!$('consent').checked) return status('ゲーム状態の送信に同意してください');
  if (!connected) return status('アプリから開いてログインしてください');
  if (loop.active || loop.pending || pendingBridge) return status('現在の測定を停止し、応答が終了するまでお待ちください');
  if (isGame() && (!nes || nes.cpu.mem[0x770] !== 1 || nes.cpu.mem[0x75f] !== 0 || nes.cpu.mem[0x75c] !== 0 || nes.cpu.mem[0xe] !== 8)) return status('対応ROMを読み込み、手動で1-1の操作可能な場面まで進めてください');
  samples = []; lastResponse = 0; update(); metadata = { started_at: new Date().toISOString(), mode: $('mode').value,
    cadence_ms: Number($('cadence').value), max_calls: Number($('count').value), max_duration_ms: 60000,
    emulator: 'jsnes@2.1.0', timing: 'browser RTT includes proxy/auth/quota; upstream HTTP is not pure inference', user_agent: navigator.userAgent };
  gameRunning = isGame(); status(isGame() ? 'Jev操作を計測中。通信待ち中もゲームは進みます。' : '固定状態でAPI往復を測定中（実プレイではありません）');
  loop.start({ count: metadata.max_calls, cadence: metadata.cadence_ms });
};
$('stop').onclick = () => stop();
$('consent').onchange = () => { if (!$('consent').checked) stop('送信同意を解除しました'); };
$('export').onclick = () => {
  const data = { ...metadata, samples, counts: { attempts: samples.length, failures: samples.filter(s => !s.ok).length },
    browser_rtt: summarize(samples.filter(s => s.ok).map(s => s.rtt_ms)) };
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
  const a = document.createElement('a'); a.href = url; a.download = 'jev-mario-measurement.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
};
const keys = { ArrowRight: 7, ArrowLeft: 6, KeyX: 0, KeyZ: 1, Enter: 3 };
window.addEventListener('keydown', e => { if (e.target.matches('input,select,button') || !gameRunning || loop.active || !(e.code in keys)) return;
  e.preventDefault(); nes?.buttonDown(1, keys[e.code]); });
window.addEventListener('keyup', e => { if (!loop.active && e.code in keys) nes?.buttonUp(1, keys[e.code]); });
window.addEventListener('blur', () => stop('画面から離れたため停止しました'));
document.addEventListener('visibilitychange', () => { if (document.hidden) stop('バックグラウンドになったため停止しました'); });
window.addEventListener('pagehide', () => stop());
function frame(now) {
  const delta = lastFrame ? Math.min(100, now - lastFrame) : 0; lastFrame = now;
  if (gameRunning && nes) {
    frameBudget += delta;
    try {
      while (frameBudget >= 1000 / 60 && gameRunning) {
        nes.frame(); frameCount++; frameBudget -= 1000 / 60;
        if (loop.active && ([6, 11].includes(nes.cpu.mem[0xe]) || nes.cpu.mem[0xb5] >= 2 || nes.cpu.mem[0x770] === 2 || nes.cpu.mem[0x1d] === 3)) stop('死亡またはコース終了で停止しました');
      }
      const s = readState(nes.cpu.mem); $('progress').textContent = `World ${s.world}-${s.stage} · x=${s.player.x} · ${frameCount} frames`;
    } catch { stop('エミュレーターを継続できません。対応ROMを確認してください。'); }
  } else frameBudget = 0;
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
