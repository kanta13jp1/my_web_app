import { letters, advance } from './model.mjs';

const $ = id => document.getElementById(id);
const board = $('board');
const track = $('track');
const ns = 'http://www.w3.org/2000/svg';
let points = [], next = 0, active = null, stroke = null, pointCount = 0;
let showNumbers = false;
function svg(tag, attributes) {
  const node = document.createElementNS(ns, tag);
  for (const [key, value] of Object.entries(attributes)) node.setAttribute(key, value);
  return node;
}
function stop() {
  const pointer = active;
  active = null;
  stroke = null;
  if (pointer !== null && board.hasPointerCapture(pointer)) board.releasePointerCapture(pointer);
}
function drawCursor() {
  $('cursor').setAttribute('transform', `translate(${points[Math.min(next, points.length - 1)].x} ${points[Math.min(next, points.length - 1)].y})`);
  $('cursor').style.display = $('mode').value === 'trace' && next < points.length ? '' : 'none';
}
function reset() {
  stop(); next = 0; pointCount = 0;
  const letter = $('letter').value;
  track.setAttribute('d', letters[letter]);
  const length = track.getTotalLength();
  // Sample the rendered guide once; pointer positions use the same SVG space.
  const count = Math.ceil(length / 5) + 1;
  points = Array.from({ length: count }, (_, i) => {
    const p = track.getPointAtLength(length * i / (count - 1));
    return { x: p.x, y: p.y };
  });
  $('progress').setAttribute('d', '');
  $('ink').replaceChildren();
  $('current').textContent = letter;
  $('board-title').textContent = `${letter} の練習用紙`;
  $('mode-label').textContent = $('mode').selectedOptions[0].textContent;
  const free = $('mode').value === 'free';
  $('status').textContent = free ? 'お手本を見ながら、じゆうに書こう。' : '1の丸から、はじめよう。';
  $('help').textContent = free ? 'お手本の上に自由に書けます。消したいときは「もういちど」。採点はしません。' : '1の丸から、線にそって指を動かします。途中で離しても、続きからなぞれます。';
  $('board-desc').textContent = $('help').textContent;
  showNumbers = false;
  $('guide').setAttribute('aria-pressed', 'false');
  $('numbers').replaceChildren();
  drawCursor();
}
function position(event) {
  const matrix = board.getScreenCTM();
  if (!matrix) return null;
  return new DOMPoint(event.clientX, event.clientY).matrixTransform(matrix.inverse());
}
function move(event) {
  if (active !== event.pointerId) return;
  const p = position(event);
  if (!p || p.x < 0 || p.x > 400 || p.y < 0 || p.y > 400) return;
  if ($('mode').value === 'free') {
    if (++pointCount > 10000) { stop(); $('status').textContent = 'たくさん書けたね。「もういちど」で消して続けよう。'; return; }
    stroke.setAttribute('d', `${stroke.getAttribute('d')} L${p.x.toFixed(1)} ${p.y.toFixed(1)}`);
    return;
  }
  if (next >= points.length) return;
  const before = next;
  next = advance(points, next, p);
  if (next === before) { $('status').textContent = '1の丸のところから、ゆっくり続けよう。'; return; }
  $('progress').setAttribute('d', points.slice(0, next).map((v, i) => `${i ? 'L' : 'M'}${v.x} ${v.y}`).join(' '));
  drawCursor();
  if (next === points.length) $('status').textContent = 'さいごまで線をたどれたね！もういちど、または別のもじへ。';
  else $('status').textContent = 'そのまま、丸の先へ進もう。';
}
board.addEventListener('pointerdown', event => {
  if (active !== null || !event.isPrimary || event.button !== 0) return;
  const p = position(event);
  if (!p) return;
  active = event.pointerId;
  board.setPointerCapture(active);
  if ($('mode').value === 'free') {
    stroke = svg('path', { d: `M${p.x.toFixed(1)} ${p.y.toFixed(1)}` });
    $('ink').append(stroke);
  }
  move(event);
});
board.addEventListener('pointermove', move);
for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) board.addEventListener(event, e => { if (active === e.pointerId) stop(); });
window.addEventListener('blur', stop);
$('reset').addEventListener('click', reset);
$('letter').addEventListener('change', reset);
$('mode').addEventListener('change', reset);
$('guide').addEventListener('click', () => {
  showNumbers = !showNumbers;
  $('guide').setAttribute('aria-pressed', String(showNumbers));
  $('numbers').replaceChildren();
  if (showNumbers) {
    for (let i = 0; i < 5; i++) {
      const p = points[Math.round(i * (points.length - 1) / 4)];
      const g = svg('g', { transform: `translate(${p.x} ${p.y})` });
      const text = svg('text', { 'text-anchor': 'middle', dy: '6' }); text.textContent = String(i + 1);
      g.append(svg('circle', { r: '16' }), text); $('numbers').append(g);
    }
    $('status').textContent = '数字の1から5へ、一本の線でつながります。これはお手本の表示です。';
  } else $('status').textContent = 'お手本の数字を隠しました。';
});
reset();
$('settings').disabled = false;
$('fallback').hidden = true;
