import {parse, compare} from './model.mjs';
import {sample, source} from './sample.mjs';
const $ = id => document.getElementById(id);
const fmt = n => n.toLocaleString('ja-JP', {maximumFractionDigits:5});
let rows, report, provenance = '利用者が入力した記録';
function invalidate() { rows = null; report = null; $('ready').hidden = true; $('results').hidden = true; $('error').textContent = ''; }
$('data').addEventListener('input', () => {invalidate(); provenance = '利用者が入力した記録'; $('origin').textContent = provenance;});
$('sample').onclick = () => {invalidate(); $('data').value = JSON.stringify(sample, null, 2); provenance = source; $('origin').textContent = '2026年9月公開の保存済み18試行です。新しいAI試行ではありません。';};
$('read').onclick = () => {invalidate(); try {rows = parse($('data').value); $('baseline').replaceChildren(...[...new Set(rows.map(r => r.condition))].map(name => {const o = document.createElement('option'); o.textContent = name; o.value = name; return o;})); $('ready').hidden = false;} catch(e) {$('error').textContent = e.message;}};
$('baseline').onchange = () => {report = null; $('results').hidden = true;};
$('calculate').onclick = () => {
  if (!rows) return;
  const summary = compare(rows, $('baseline').value);
  report = {schema:1, provenance, baseline:$('baseline').value, rows, summary, causalEffect:null, generatedAt:new Date().toISOString()};
  $('summary').replaceChildren(...summary.map(g => {const tr = document.createElement('tr');
    for (const value of [g.condition,g.n,fmt(g.meanInput),g.ratio === null ? '基準0のため保留' : fmt(g.ratio) + '倍',fmt(g.perTurn),fmt(g.output),fmt(g.modelUSD),fmt(g.runUSD)]) {const td = document.createElement('td'); td.textContent = value; tr.append(td);} return tr;}));
  $('breakdown').replaceChildren(...summary.map(g => {const p = document.createElement('p'); p.textContent = `${g.condition}：通常入力 ${fmt(g.input)} ＋ 作成 ${fmt(g.cacheWrite)} ＋ 読込 ${fmt(g.cacheRead)} ＝ ${fmt(g.totalInput)} トークン、要求 ${fmt(g.turns)} 回`; return p;}));
  $('results').hidden = false;
};
$('save').onclick = () => {if (!report) return; const url = URL.createObjectURL(new Blob([JSON.stringify(report,null,2)],{type:'application/json'})); const a = document.createElement('a'); a.href = url; a.download = 'ai-usage-comparison.json'; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000);};
