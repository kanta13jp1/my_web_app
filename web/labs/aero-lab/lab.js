import { STAGES } from './aero-engine.js';
import { deriveMetrics } from './simulation.js';
import { createScene } from './scene.js';
import { createRecorder } from './recorder.js';

const byId = (id) => document.getElementById(id);
const state = { throttle: 0.35, explode: 0, cutaway: true, flow: true, running: true, selected: null, fault: false };
let scene;
function render() {
  byId('throttle').value = Math.round(state.throttle * 100);
  byId('power-value').textContent = Math.round(state.throttle * 100);
  byId('explode').value = Math.round(state.explode * 100);
  byId('explode-value').textContent = `${Math.round(state.explode * 100)}%`;
  for (const key of ['cutaway', 'flow', 'fault']) byId(key).checked = state[key];
  byId('pause').textContent = state.running ? 'Ⅱ 回転を止める' : '▶ 回転を再開';
  byId('pause').setAttribute('aria-pressed', String(!state.running));
  byId('running-status').textContent = state.running ? '● RUNNING' : 'Ⅱ PAUSED';
  byId('mode').textContent = state.explode > 0.1 ? 'EXPLODED VIEW' : state.cutaway ? 'CUTAWAY VIEW' : 'ASSEMBLED VIEW';
  const metrics = deriveMetrics({ throttle: state.running ? state.throttle : 0, fault: state.fault });
  for (const [id, value] of [['thrust', metrics.thrustPercent], ['heat', metrics.temperatureIndex]]) {
    byId(id).textContent = value;
    byId(`${id}-bar`).style.width = `${value}%`;
  }
  byId('fault-note').hidden = !state.fault;
  const stage = STAGES.find((item) => item.id === state.selected);
  byId('title').textContent = stage?.name ?? 'エンジンの内側へ。';
  byId('description').textContent = stage?.description ?? '回して、開いて、流れを追う。';
  byId('detail').hidden = !stage;
  byId('detail-name').textContent = stage?.english ?? '';
  byId('detail-text').textContent = stage?.detail ?? '';
  document.querySelectorAll('[data-stage]').forEach((button) => button.setAttribute('aria-pressed', String(button.dataset.stage === state.selected)));
}
for (const key of ['throttle', 'explode']) byId(key).addEventListener('input', (event) => { state[key] = Number(event.target.value) / 100; render(); });
for (const key of ['cutaway', 'flow', 'fault']) byId(key).addEventListener('change', (event) => { state[key] = event.target.checked; render(); });
document.querySelectorAll('[data-power]').forEach((button) => button.addEventListener('click', () => { state.throttle = Number(button.dataset.power) / 100; render(); }));
document.querySelectorAll('[data-view]').forEach((button) => button.addEventListener('click', () => scene?.view(button.dataset.view)));
byId('assemble').onclick = () => { state.explode = 0; render(); };
byId('disassemble').onclick = () => { state.explode = 1; state.cutaway = true; scene?.view('side'); render(); };
byId('pause').onclick = () => { state.running = !state.running; render(); };
byId('clear-stage').onclick = () => { state.selected = null; render(); };
STAGES.forEach((stage, index) => {
  const button = document.createElement('button');
  button.dataset.stage = stage.id;
  const number = document.createElement('span'); number.className = 'stage-number'; number.textContent = `0${index + 1}`;
  const label = document.createElement('span');
  const name = document.createElement('b'); name.textContent = stage.name;
  const english = document.createElement('small'); english.textContent = stage.english;
  label.append(name, english); button.append(number, label);
  button.onclick = () => { state.selected = state.selected === stage.id ? null : stage.id; state.cutaway = true; render(); };
  byId('stages').append(button);
});
render();
try {
  scene = createScene(byId('scene'), state);
  byId('scene-status').hidden = true;
} catch (error) {
  byId('scene-status').setAttribute('role', 'alert');
  byId('scene-status').textContent = '3D表示を開始できません。WebGL対応ブラウザーで再読み込みしてください。';
  console.error('AERO LAB initialization failed', error);
}
const recorder = createRecorder(byId('record'), byId('record-message'), byId('download'));
window.addEventListener('pagehide', () => { recorder.dispose(); scene?.dispose(); }, { once: true });
window.addEventListener('pageshow', (event) => { if (event.persisted) location.reload(); });
