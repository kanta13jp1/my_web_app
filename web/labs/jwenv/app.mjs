import { requestDevice } from './vendor/jwenv-8263b81/src/gpu/device.js';
import { Qwen3Model } from './vendor/jwenv-8263b81/src/model/qwen3.js';
import { JevClassifier, JevError, LABELS, validate } from './vendor/jwenv-8263b81/src/jev.js';
import { dequantRow } from './vendor/jwenv-8263b81/src/gguf/dequant.js';
import { GGML_TYPE_NAME } from './vendor/jwenv-8263b81/src/gguf/parser.js';
import { blobSource } from './vendor/jwenv-8263b81/browser_source.js';
import {
  ARTICLE_EXAMPLE, ENGINE, EXPENSE_DOMAIN, LOAD_OPTIONS, MODEL, NOUL_THRESHOLD, agreement, expenseRequest,
  isHtmlFallback, limitCheckRequest, median, normalizedEntropyConfidence, pickCategory, rankNoul,
} from './core.mjs';

const byId = (id) => document.getElementById(id);
const fmtMs = (ms) => `${Math.round(ms).toLocaleString('ja-JP')} ms`;
const fmtP = (p) => p.toFixed(4);
const state = { model: null, jev: null, adapterInfo: null, loadMs: null, file: null, ref: null, busy: false };

class UserError extends Error {}

async function fetchJson(url) {
  const res = await fetch(url, { cache: 'no-store' });
  if (res.status === 404) return null;
  if (!res.ok) throw Error(`HTTP ${res.status}`);
  const text = await res.text();
  // Firebase Hosting rewrites missing paths to the Flutter index.html.
  if (isHtmlFallback(text)) return null;
  return JSON.parse(text);
}

async function shaderLoader(name) {
  const res = await fetch(new URL(`./${ENGINE.vendorDir}/shaders/${name}.wgsl`, import.meta.url));
  const text = await res.text();
  if (!res.ok || isHtmlFallback(text)) throw Error(`shader ${name} is missing`);
  return text;
}

// ------------------------------------------------------------ reference samples (from the BERT lab)
async function loadReference() {
  const data = await fetchJson('../expense-comparison/results.json');
  if (!data || Object.keys(data.categories ?? {}).length !== 12 || data.samples?.length !== 14) {
    throw Error('reference samples are unavailable');
  }
  return {
    categories: data.categories,
    samples: data.samples.map((s) => ({
      id: s.id, text: s.text, expected: s.expected, review_required: s.review_required, rule: s.rule,
      bert: s.trials?.[0]?.status === 'ok' ? s.trials[0].answer.choice : null,
    })),
    bertRunId: data.run_id,
  };
}

// ------------------------------------------------------------ environment and model
async function describeGpu() {
  if (!('gpu' in navigator)) return { available: false, reason: 'このブラウザはWebGPUに対応していません。' };
  const adapter = await navigator.gpu.requestAdapter({ powerPreference: 'high-performance' });
  if (!adapter) return { available: false, reason: 'WebGPUのアダプタを取得できません（GPUが無効、または対応外の環境です）。' };
  const i = adapter.info ?? {};
  return { available: true, info: [i.vendor, i.architecture, i.device, i.description].filter(Boolean).join(' / ') || '詳細不明' };
}

async function loadModel(file) {
  if (!/\.gguf$/i.test(file.name)) throw new UserError('GGUFファイル（.gguf）を選んでください。');
  if (!('gpu' in navigator)) throw new UserError('このブラウザはWebGPUに対応していないため、モデルを読み込めません。');
  state.model?.destroy();
  Object.assign(state, { model: null, jev: null, loadMs: null, file: null });
  let device;
  try {
    ({ device, adapterInfo: state.adapterInfo } = await requestDevice(navigator.gpu));
  } catch (e) {
    throw new UserError(`WebGPUを初期化できません：${e.message}`);
  }
  const bar = byId('progress');
  bar.hidden = false;
  const t0 = performance.now();
  const model = await Qwen3Model.load(blobSource(file), device, shaderLoader, {
    ...LOAD_OPTIONS, onProgress: (done, total) => { bar.value = done / total; },
  });
  state.loadMs = performance.now() - t0;
  state.model = model;
  state.jev = new JevClassifier(model, file.name.replace(/\.gguf$/i, ''));
  state.file = { name: file.name, bytes: file.size };
  bar.hidden = true;
}

function modelSnapshot() {
  const m = state.model;
  if (!m) return null;
  const head = m.headInfo;
  const metadata = {};
  for (const [k, v] of m.gguf.metadata) {
    if (/^(general|jev|qwen3)\./.test(k) && ['string', 'number', 'boolean'].includes(typeof v)) metadata[k] = v;
  }
  let parameters = 0;
  for (const t of m.gguf.tensors.values()) parameters += t.nElements;
  const embd = m.embdInfo;
  return {
    metadata, tensor_count: m.gguf.tensors.size, parameter_count: parameters,
    token_embd: { dims: embd.dims, type: GGML_TYPE_NAME[embd.type] ?? embd.type, bytes: embd.nBytes },
    file: state.file, adapter: state.adapterInfo, load_ms: state.loadMs, gpu_bytes: m.gpuBytes,
    config: m.cfg, temperature: state.jev.temperature,
    head: { tensor: head.name, dims: head.dims, type: GGML_TYPE_NAME[head.type] ?? head.type, bytes: head.nBytes,
            tied_to_token_embd: head === m.embdInfo },
    token_embd_bytes_on_cpu: m.embdBytes.byteLength,
    candidate_token_ids: state.jev.candIds, labels: LABELS,
  };
}

// ------------------------------------------------------------ experiments
async function runExample() {
  const request = structuredClone(ARTICLE_EXAMPLE);
  const t0 = performance.now();
  const response = await state.jev.systemOne(request);
  const ms = performance.now() - t0;
  const probabilities = Object.values(response.answers.category.probabilities);
  return {
    request, response, ms,
    confidence_recomputed_from_rounded: normalizedEntropyConfidence(probabilities),
    max_probability: Math.max(...probabilities),
  };
}

function runLimit() {
  const request = limitCheckRequest(state.ref.categories);
  try {
    // Loaded classifier validates with its model name too; without a model the same validator runs.
    if (state.jev) state.jev.prepare(request); else validate(request, ['jev-latest']);
    return { options: Object.keys(request.questions.category.criteria).length, rejected: false };
  } catch (e) {
    if (!(e instanceof JevError)) throw e;
    return { options: Object.keys(request.questions.category.criteria).length, rejected: true,
             code: e.code, status: e.status, field: e.field, message: e.message };
  }
}

async function runExpense(passes = 2, onProgress = () => {}) {
  const ids = Object.keys(state.ref.categories);
  const runs = [];
  for (let pass = 1; pass <= passes; pass++) {
    const rows = [];
    for (const s of state.ref.samples) {
      const request = expenseRequest(s.text, state.ref.categories, EXPENSE_DOMAIN);
      const t0 = performance.now();
      const res = await state.jev.systemOne(request);
      const ms = performance.now() - t0;
      const ranked = rankNoul(res.answers, ids);
      const pick = pickCategory(ranked);
      rows.push({ ...s, jwenv: pick.choice, p_yes: pick.p, review: pick.review, top3: ranked.slice(0, 3),
                  ms, input_tokens: res.usage.input_tokens });
      onProgress(pass, rows.length);
    }
    runs.push({ pass, rows, median_ms: median(rows.map((r) => r.ms)), total_ms: rows.reduce((a, r) => a + r.ms, 0) });
  }
  const first = runs[0].rows;
  return {
    question_type: 'noul', questions_per_request: ids.length, threshold: NOUL_THRESHOLD, bert_run_id: state.ref.bertRunId,
    runs,
    agreement: { jwenv: agreement(first, 'jwenv'), rule: agreement(first, 'rule'), bert: agreement(first, 'bert') },
    same_choice_every_pass: first.every((r, i) => runs.every((run) => run.rows[i].jwenv === r.jwenv)),
  };
}

function topK(values, k) {
  const best = [];
  for (let i = 0; i < values.length; i++) {
    if (best.length < k || values[i] > values[best[best.length - 1]]) {
      best.push(i);
      best.sort((a, b) => values[b] - values[a]);
      if (best.length > k) best.pop();
    }
  }
  return best;
}

/** Recomputes the candidate logits against every vocabulary row on the CPU from the dumped final hidden state. */
async function verifySlice(request = ARTICLE_EXAMPLE) {
  const { model, jev } = state;
  const prepared = jev.prepare(structuredClone(request));
  const seq = prepared.seqs[0];
  const debug = { dump: new Set(['final_norm']) };
  const t0 = performance.now();
  const [engineLogits] = await model.forward([seq], jev.candIds, debug, { useCache: false });
  const forwardMs = performance.now() - t0;
  const dump = debug.dumps.get('final_norm');
  const dim = model.cfg.dim;
  const rows = dump.data.length / dump.cols;
  const h = dump.data.subarray((rows - 1) * dim, rows * dim);
  const head = model.headInfo;
  const tied = head === model.embdInfo;
  const bytes = tied ? model.embdBytes : await model.src.read(head.absOffset, head.nBytes);
  const vocabRows = head.dims[1];
  const t1 = performance.now();
  const full = new Float32Array(vocabRows);
  for (let v = 0; v < vocabRows; v++) {
    const w = dequantRow(head, bytes, v);
    let s = 0;
    for (let i = 0; i < dim; i++) s += h[i] * w[i];
    full[v] = s;
  }
  const cpuMs = performance.now() - t1;
  const cand = jev.candIds;
  const engine = Array.from(engineLogits.subarray(0, cand.length));
  const cpu = cand.map((id) => full[id]);
  const diffs = cand.map((_, c) => Math.abs(cpu[c] - engine[c]));
  const bestC = engine.indexOf(Math.max(...engine));
  let rank = 1;
  for (let v = 0; v < vocabRows; v++) if (full[v] > full[cand[bestC]]) rank++;
  return {
    question: prepared.questions[0].id, prompt_tokens: seq.length, vocab_rows: vocabRows, dim,
    head_tensor: head.name, head_type: GGML_TYPE_NAME[head.type] ?? head.type, tied_to_token_embd: tied,
    labels: LABELS, candidate_token_ids: cand, engine_logits: engine, cpu_logits_at_candidates: cpu,
    max_abs_diff: Math.max(...diffs), best_label: LABELS[bestC], best_label_rank_in_full_vocab: rank,
    full_vocab_top10: topK(full, 10).map((id) => ({ id, token: model.tokenizer.decode([id]), logit: full[id],
                                                     is_candidate: cand.includes(id) })),
    forward_ms: forwardMs, cpu_full_vocab_ms: cpuMs,
  };
}

// ------------------------------------------------------------ rendering
function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
  node.append(...children.map((c) => (c instanceof Node ? c : document.createTextNode(String(c)))));
  return node;
}
const label = (id) => state.ref?.categories[id]?.label ?? (id ? id : '候補なし');

function expenseTable(result, pass = 0, prefix = 'live') {
  const run = result.runs[pass];
  const head = el('tr', {}, ...['メモ', '参照', '辞書', 'BERT', 'Jwenv（yes確率）', '時間'].map((h) => el('th', { scope: 'col' }, h)));
  const body = run.rows.map((r) => el('tr', {},
    el('td', {}, r.text), el('td', {}, r.expected ? label(r.expected) : '参照なし'), el('td', {}, label(r.rule)),
    el('td', {}, label(r.bert)),
    el('td', { class: r.review ? 'review' : '' }, `${label(r.jwenv)}（${fmtP(r.p_yes)}）${r.review ? ' 要確認' : ''}`),
    el('td', { class: 'num' }, fmtMs(r.ms))));
  const a = result.agreement;
  return el('div', { class: 'result', id: `${prefix}-expense-${run.pass}` },
    el('h3', {}, `支出メモ14件（${run.pass}回目）`),
    el('p', {}, `参照あり${a.jwenv.referenced}件で参照と一致：Jwenv ${a.jwenv.matches}件 / 辞書 ${a.rule.matches}件 / BERT ${a.bert.matches}件（1回目）。1要求あたりの時間の中央値 ${fmtMs(run.median_ms)}。`),
    el('div', { class: 'table-wrap' }, el('table', {}, el('thead', {}, head), el('tbody', {}, ...body))));
}

function exampleBlock(r) {
  const a = r.response.answers.category;
  return el('div', { class: 'result', id: 'example-result' },
    el('h3', {}, '記事の入力例'),
    el('p', {}, `回答：${a.choice} / confidence ${fmtP(a.confidence)}（最大確率 ${fmtP(r.max_probability)}） / ${fmtMs(r.ms)}`),
    el('pre', {}, JSON.stringify(r.response, null, 2)));
}

function limitBlock(r) {
  return el('div', { class: 'result', id: 'limit-result' },
    el('h3', {}, `${r.options}択のchoice`),
    el('p', {}, r.rejected ? `拒否されました：${r.code}（status ${r.status}）「${r.message}」` : '受理されました'));
}

function sliceBlock(r) {
  return el('div', { class: 'result', id: 'slice-result' },
    el('h3', {}, '候補スライスと全語彙の一致'),
    el('p', {}, `全${r.vocab_rows.toLocaleString('ja-JP')}行 × ${r.dim}次元をCPUで計算し、候補${r.candidate_token_ids.length}行のlogitと比較。最大差 ${r.max_abs_diff.toExponential(2)}。最有力ラベル ${r.best_label} の全語彙内の順位：${r.best_label_rank_in_full_vocab}位。`),
    el('p', {}, `全語彙の上位：${r.full_vocab_top10.slice(0, 5).map((t) => `${JSON.stringify(t.token)}${t.is_candidate ? '*' : ''}`).join(' ')}（*は候補ラベル）`));
}

function show(block, id) {
  byId(id)?.remove();
  byId('live').append(block);
}

async function guarded(name, fn) {
  if (state.busy) return;
  state.busy = true;
  setButtons();
  byId('run-status').textContent = `${name}を実行しています…`;
  try {
    await fn();
    byId('run-status').textContent = `${name}が完了しました。`;
  } catch (e) {
    byId('run-status').textContent = `${name}に失敗しました：${e.message}`;
    console.error(e);
  } finally {
    state.busy = false;
    setButtons();
  }
}

function setButtons() {
  const loaded = !!state.jev && !state.busy;
  byId('run-example').disabled = !loaded;
  byId('verify-slice').disabled = !loaded;
  byId('run-expense').disabled = !loaded || !state.ref;
  byId('run-limit').disabled = state.busy || !state.ref;
}

// ------------------------------------------------------------ saved CI measurement
function validateSaved(d) {
  if (d?.schema_version !== 1 || d.mode !== 'saved_browser_webgpu_measurement' || d.synthetic !== true ||
      !/^\d+$/.test(String(d.run_id)) || d.model?.sha256 !== MODEL.sha256 || d.engine?.revision !== ENGINE.revision ||
      !Array.isArray(d.expense?.runs) || d.expense.runs.some((r) => r.rows?.length !== 14)) {
    throw Error('invalid record');
  }
  return d;
}

function renderSaved(d) {
  const env = d.environment;
  byId('saved-status').textContent = `GitHub Actions 実行 ${d.run_id}（${d.recorded_at}）の記録です。`;
  const run = el('a', { href: `https://github.com/kanta13jp1/my_web_app/actions/runs/${d.run_id}`, target: '_blank', rel: 'noopener' }, '実行記録');
  byId('saved').replaceChildren(
    el('ul', { class: 'facts' },
      el('li', {}, `WebGPUアダプタ：${env.adapter}`),
      el('li', {}, `ブラウザ：${env.browser}`),
      el('li', {}, `モデル読込：${fmtMs(d.load_ms)}（${MODEL.file}、sha256確認済み）`),
      el('li', {}, `記事の入力例：${d.article_example.response.answers.category.choice}（confidence ${fmtP(d.article_example.response.answers.category.confidence)}、${fmtMs(d.article_example.ms)}）`),
      el('li', {}, `12択：${d.limit_check.rejected ? `${d.limit_check.code}（status ${d.limit_check.status}）で拒否` : '受理'}`),
      el('li', {}, `候補スライスと全語彙の最大差：${Math.max(...d.slice_checks.map((s) => s.max_abs_diff)).toExponential(2)}`)),
    expenseTable(d.expense, 0, 'saved'),
    el('p', {}, run, ' · ', el('a', { href: 'results.json', download: '' }, '記録を保存')));
}

// ------------------------------------------------------------ boot
async function boot() {
  byId('model-link').href = MODEL.page;
  byId('model-file-name').textContent = MODEL.file;
  byId('model-size').textContent = `${(MODEL.bytes / 2 ** 20).toFixed(0)} MiB`;
  setButtons();

  describeGpu().then((g) => {
    byId('gpu-status').textContent = g.available ? `WebGPUを利用できます：${g.info}` : g.reason;
    byId('gpu-status').dataset.state = g.available ? 'ok' : 'unavailable';
  }).catch((e) => { byId('gpu-status').textContent = `WebGPUの確認に失敗しました：${e.message}`; });

  try {
    state.ref = await loadReference();
  } catch {
    byId('run-status').textContent = '支出メモの参照データを読み込めません。支出メモの検証は実行できません。';
  }
  setButtons();

  byId('model-file').addEventListener('change', async (ev) => {
    const file = ev.target.files?.[0];
    if (!file) return;
    const status = byId('model-status');
    status.dataset.state = 'loading';
    status.textContent = `${file.name} を読み込んでいます…`;
    state.busy = true;
    setButtons();
    try {
      await loadModel(file);
      const c = state.model.cfg;
      status.dataset.state = 'loaded';
      status.textContent = `読込完了：${file.name}（${fmtMs(state.loadMs)}、${c.nLayer}層・${c.dim}次元）／ ${state.adapterInfo}`;
    } catch (e) {
      byId('progress').hidden = true;
      status.dataset.state = 'error';
      status.textContent = e instanceof UserError ? e.message : `モデルを読み込めません：${e.message}`;
      console.error(e);
    } finally {
      state.busy = false;
      setButtons();
    }
  });
  byId('run-example').addEventListener('click', () => guarded('記事の入力例', async () => show(exampleBlock(await runExample()), 'example-result')));
  byId('run-limit').addEventListener('click', () => guarded('12択の確認', async () => show(limitBlock(runLimit()), 'limit-result')));
  byId('verify-slice').addEventListener('click', () => guarded('一致確認', async () => show(sliceBlock(await verifySlice()), 'slice-result')));
  byId('run-expense').addEventListener('click', () => guarded('支出メモの検証', async () => {
    const r = await runExpense(1, (_, n) => { byId('run-status').textContent = `支出メモの検証中… ${n}/14`; });
    show(expenseTable(r), 'live-expense-1');
  }));

  try {
    const saved = await fetchJson('results.json');
    if (!saved) byId('saved-status').textContent = '保存済みの実測はまだありません。';
    else renderSaved(validateSaved(saved));
  } catch {
    byId('saved-status').textContent = '保存済みの実測を読み込めません（記録の形式が正しくありません）。';
  }
}

// Automation hook for scripts/jwenv_lab/run_lab.py; it drives the same functions as the buttons.
window.jwenvLab = {
  ready: boot(),
  snapshot: modelSnapshot,
  runExample, runLimit, runExpense, verifySlice,
  expenseRequestFor: (i) => expenseRequest(state.ref.samples[i].text, state.ref.categories, EXPENSE_DOMAIN),
  render: { exampleBlock, limitBlock, sliceBlock, expenseTable, show },
};
