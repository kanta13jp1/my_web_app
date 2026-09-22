import { TRACKS, preset, validate, toggle, frequency, activeAt } from './pattern.mjs';
const $ = id => document.getElementById(id);
let state = preset(), history = [], playing = false, context, master, timer, nextTime = 0, step = 0;
let pulses = [], frame = 0, events = [], lastTime = 0;
const voices = new Set(), seeds = [], canvas = $('garden'), ctx = canvas.getContext('2d');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
function message(text) { $('status').textContent = text; }
function remember() { history.push(JSON.stringify(state)); if (history.length > 30) history.shift(); }
function update() {
  const selected = [0, 1, 2].find(i => JSON.stringify(preset(i)) === JSON.stringify(state));
  $('scene-label').textContent = selected === undefined ? 'YOUR GARDEN / CUSTOM' : ['01 / DEW', '02 / SUNLIGHT', '03 / NIGHT GLOW'][selected];
  document.querySelectorAll('[data-preset]').forEach(b => b.setAttribute('aria-pressed', String(Number(b.dataset.preset) === selected)));
  seeds.forEach((row, t) => row.forEach((button, s) => button.setAttribute('aria-pressed', String(state.notes[t][s]))));
  TRACKS.forEach((_, t) => { const b = $(`mute-${t}`); b.textContent = state.muted[t] ? '音を戻す' : '消音'; b.setAttribute('aria-pressed', String(state.muted[t])); });
  $('tempo').value = state.tempo; $('tempo-value').textContent = state.tempo; $('undo').disabled = !history.length;
}
TRACKS.forEach((track, t) => {
  const row = [];
  for (let s = 0; s < 16; s++) {
    const button = document.createElement('button'); button.className = 'seed';
    button.style.setProperty('--tone', track.color); button.setAttribute('aria-label', `${track.name} ${s + 1}番目の音`);
    button.addEventListener('click', () => { remember(); state = toggle(state, t, s); update(); message(`${track.name}・${s + 1}番目を${state.notes[t][s] ? '追加' : '削除'}しました。`); });
    $('rings').append(button); row.push(button);
  }
  seeds.push(row);
  const trackRow = document.createElement('div'); trackRow.className = 'track'; trackRow.style.setProperty('--tone', track.color);
  const name = document.createElement('span'); name.textContent = `0${t + 1} ${track.name}`;
  const button = document.createElement('button'); button.id = `mute-${t}`; button.setAttribute('aria-label', `${track.name}の消音切替`);
  button.addEventListener('click', () => { remember(); state.muted[t] = !state.muted[t]; update(); });
  trackRow.append(name, button); $('tracks').append(trackRow);
});
function layout() {
  const bounds = canvas.getBoundingClientRect(), scale = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.round(bounds.width * scale); canvas.height = Math.round(bounds.height * scale);
  ctx?.setTransform(scale, 0, 0, scale, 0, 0);
  const radius = Math.min(bounds.width * .43, bounds.height * .40);
  seeds.forEach((row, t) => row.forEach((button, s) => { const a = s * Math.PI / 8 - Math.PI / 2, r = radius * (1 - t * .19); button.style.left = `${bounds.width / 2 + Math.cos(a) * r}px`; button.style.top = `${bounds.height / 2 + Math.sin(a) * r}px`; }));
}
const observer = new ResizeObserver(layout); observer.observe(canvas);
function voice(t, s, when) {
  const oscillator = context.createOscillator(), gain = context.createGain();
  oscillator.type = TRACKS[t].wave; oscillator.frequency.setValueAtTime(frequency(t, s), when);
  const duration = t === 3 ? .18 : t === 2 ? .55 : .85;
  if (t === 3) oscillator.frequency.exponentialRampToValueAtTime(35, when + .15);
  gain.gain.setValueAtTime(0, when); gain.gain.linearRampToValueAtTime(t === 3 ? .35 : .18, when + .008); gain.gain.exponentialRampToValueAtTime(.0001, when + duration);
  oscillator.connect(gain); gain.connect(master); voices.add(oscillator);
  oscillator.onended = () => { voices.delete(oscillator); oscillator.disconnect(); gain.disconnect(); };
  oscillator.start(when); oscillator.stop(when + duration + .01);
}
function schedule() {
  if (!playing) return;
  while (nextTime < context.currentTime + .12) {
    const tracks = activeAt(state, step);
    tracks.forEach(t => voice(t, step, nextTime)); events.push({ when: nextTime, step, tracks });
    nextTime += 60 / state.tempo / 4; step = (step + 1) % 16;
  }
}
function stop() {
  playing = false; clearInterval(timer); events = []; pulses = []; step = 0;
  for (const v of voices) { try { v.stop(); } catch { /* already ended */ } }
  context?.suspend().catch(() => {});
  seeds.flat().forEach(b => b.classList.remove('firing')); $('beat').textContent = '✳';
  $('play').textContent = '▶ 音を咲かせる'; $('play-state').textContent = 'READY TO BLOOM';
}
$('play').addEventListener('click', async () => {
  if (playing) { stop(); message('演奏を停止しました。'); return; }
  $('play').disabled = true;
  try {
    if (!context) { context = new AudioContext(); master = context.createGain(); master.gain.value = Number($('volume').value) / 100; master.connect(context.destination); }
    await context.resume(); playing = true; step = 0; nextTime = context.currentTime + .05;
    schedule(); timer = setInterval(schedule, 25); $('play').textContent = '■ 演奏を止める'; $('play-state').textContent = 'LIVE / AUDIO SYNTHESIS'; message('点を押すと次の周回から演奏が変わります。');
  } catch { stop(); message('音声を開始できません。このブラウザーの音声設定を確認してください。'); }
  finally { $('play').disabled = false; }
});
$('tempo').addEventListener('change', () => { remember(); state.tempo = Number($('tempo').value); update(); });
$('volume').addEventListener('input', () => { if (master) master.gain.setTargetAtTime(Number($('volume').value) / 100, context.currentTime, .02); });
document.querySelectorAll('[data-preset]').forEach(button => button.addEventListener('click', () => {
  remember(); state = preset(Number(button.dataset.preset));
  document.querySelectorAll('[data-preset]').forEach(b => b.setAttribute('aria-pressed', String(b === button)));
  $('scene-label').textContent = ['01 / DEW', '02 / SUNLIGHT', '03 / NIGHT GLOW'][Number(button.dataset.preset)]; update(); message('シーンを切り替えました。音の配置とテンポが変わります。');
}));
$('undo').addEventListener('click', () => { if (history.length) { state = validate(JSON.parse(history.pop())); update(); message('ひとつ前の構成に戻しました。'); } });
$('clear').addEventListener('click', () => { remember(); state.notes = state.notes.map(row => row.map(() => false)); update(); message('空の庭になりました。点を押して音を植えてください。'); });
$('save').addEventListener('click', () => {
  const url = URL.createObjectURL(new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' }));
  const a = document.createElement('a'); a.href = url; a.download = 'sound-bloom.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); message('構成ファイルを保存しました。');
});
$('load').addEventListener('change', async event => {
  try { const file = event.target.files?.[0]; if (!file) return; if (file.size > 4096) throw new Error('構成ファイルは4KB以内にしてください。'); const next = validate(JSON.parse(await file.text())); remember(); state = next; update(); message('保存した構成を復元しました。'); }
  catch { message('構成ファイルを読み込めません。SOUND BLOOMで保存したJSONを選んでください。'); }
  finally { event.target.value = ''; }
});
function draw(time) {
  frame = requestAnimationFrame(draw); if (time - lastTime < 32) return; lastTime = time;
  if (playing) while (events.length && events[0].when <= context.currentTime) {
    const event = events.shift(); seeds.flat().forEach(b => b.classList.remove('firing')); $('beat').textContent = String(event.step + 1).padStart(2, '0');
    event.tracks.forEach(t => { seeds[t][event.step].classList.add('firing'); pulses.push({ t, start: time, angle: event.step * Math.PI / 8 }); });
  }
  if (!ctx) return;
  const w = canvas.clientWidth, h = canvas.clientHeight, r = Math.min(w * .43, h * .4);
  ctx.clearRect(0, 0, w, h); ctx.save(); ctx.translate(w / 2, h / 2);
  for (let t = 0; t < 4; t++) { ctx.strokeStyle = `${TRACKS[t].color}25`; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(0, 0, r * (1 - t * .19), 0, Math.PI * 2); ctx.stroke(); }
  const phase = reducedMotion ? 0 : time / 18000;
  for (let n = 0; n < 12; n++) {
    const a = n * Math.PI / 6 + phase; ctx.save(); ctx.rotate(a); ctx.strokeStyle = '#9ceec920';
    ctx.beginPath(); ctx.ellipse(r * .3, 0, r * .55, r * .15, Math.sin(phase) * .4, 0, Math.PI * 2); ctx.stroke(); ctx.restore();
  }
  pulses = pulses.filter(p => time - p.start < 1200);
  for (const p of pulses) { const life = (time - p.start) / 1200; ctx.globalAlpha = (1 - life) * .6; ctx.strokeStyle = TRACKS[p.t].color; ctx.lineWidth = 2; ctx.beginPath(); ctx.ellipse(0, 0, r * (.14 + life * .7), r * (.08 + life * .38), p.angle, 0, Math.PI * 2); ctx.stroke(); }
  ctx.restore();
}
document.addEventListener('visibilitychange', () => { if (document.hidden) { stop(); cancelAnimationFrame(frame); frame = 0; } else if (!frame) frame = requestAnimationFrame(draw); });
window.addEventListener('pagehide', () => { stop(); observer.disconnect(); cancelAnimationFrame(frame); context?.close().catch(() => {}); });
update(); layout(); frame = requestAnimationFrame(draw);
