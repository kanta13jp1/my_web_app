// デモUI（TypeSafe System One 互換 API）
//  - 静的配信: ローカルのGGUFファイル（Hugging Face からダウンロード）をブラウザで読み込み、navigator.gpu でNode版と同一のWGSLシェーダを実行する（サーバーレス）
//  - Nodeサーバー（src/server.ts）から配信: /health が応答するので「サーバーモード」になり、/v1/systemone を呼ぶ
import { requestDevice } from "../../src/gpu/device.js";
import { Qwen3Model } from "../../src/model/qwen3.js";
import { JevClassifier, JevError } from "../../src/jev.js";
import { validateDraft, draftErrorMessage } from "./request_validation.js";
import { blobSource } from "./browser_source.js";
import { applyStatic, getLang, onLangChange, setLang, t } from "./i18n.js";
const $ = (id) => document.getElementById(id);
const shaderLoader = async (name) => (await fetch(new URL(`./shaders/${name}.wgsl`, import.meta.url))).text();
let jev = null;
let current = null;
let serverMode = false;
let running = false;
let statusMsg = { key: "status.needWebgpu", kind: "info" };
let runMsg = { raw: "", kind: "info" };
function show(id, m) {
    const el = $(id);
    el.textContent = m.key ? t(m.key, m.vars) : (m.raw ?? "");
    el.dataset.kind = m.kind;
}
function setStatus(key, vars = {}, kind = "info") {
    statusMsg = { key, vars, kind };
    show("status", statusMsg);
}
function setRunStatus(m) {
    runMsg = m;
    show("run-status", runMsg);
}
function setProgress(frac) {
    const bar = $("progress");
    bar.hidden = frac === null;
    if (frac !== null)
        bar.value = frac;
}
let modelName = null;
function setModelName(name) {
    modelName = name;
    const el = $("model-name");
    el.textContent = name ?? t("model.none");
    el.dataset.state = name ? "loaded" : "none";
    if (name)
        el.title = name;
}
// ---------------------------------------------------------------- モデル読み込み（サーバーレス）
async function load(src, name) {
    if (!("gpu" in navigator))
        throw new Error(t("status.noWebgpu"));
    $("run").disabled = true;
    current?.destroy();
    current = null;
    jev = null;
    setModelName(null);
    setStatus("status.initGpu");
    const { device, adapterInfo } = await requestDevice(navigator.gpu);
    const t0 = performance.now();
    setStatus("status.loading", { name });
    current = await Qwen3Model.load(src, device, shaderLoader, {
        weights: "q8", maxTokens: 4096, maxSeqLen: 2048, maxSeqs: 64, kvCacheTokens: 2048,
        onProgress: (d, t) => setProgress(d / t),
    });
    jev = new JevClassifier(current, name.replace(/\.gguf$/i, ""));
    setProgress(null);
    const c = current.cfg;
    setStatus("status.loaded", {
        sec: ((performance.now() - t0) / 1000).toFixed(1), layers: c.nLayer, dim: c.dim,
        mb: (current.gpuBytes / 2 ** 20).toFixed(0), t: jev.temperature.toFixed(3), gpu: adapterInfo,
    }, "ok");
    updateRequestJson();
    setModelName(name);
    $("model-panel").open = false; // 読み込みが終わったら畳む
}
const CRITERIA_HELP = {
    noul: { label: "crit.noul.label", placeholder: "crit.noul.ph" },
    choice: { label: "crit.choice.label", placeholder: "crit.choice.ph" },
    score: { label: "crit.score.label", placeholder: "crit.score.ph" },
};
/** 質問カードの criteria 欄の説明を、選んだ type と今の言語に合わせる */
function refreshCard(card) {
    const h = CRITERIA_HELP[card.querySelector(".q-type").value];
    card.querySelector(".q-crit-label").textContent = t(h.label);
    card.querySelector(".q-crit").placeholder = t(h.placeholder);
    card.querySelector(".q-del").title = t("question.delete");
}
function addQuestion(d) {
    const card = document.createElement("div");
    card.className = "qcard";
    card.innerHTML = `
    <div class="qtop">
      <input type="text" class="q-id" aria-label="question id" placeholder="question id">
      <select class="q-type" aria-label="type"><option value="noul">noul</option><option value="choice">choice</option><option value="score">score</option></select>
      <button class="icon q-del" aria-label="delete">×</button>
    </div>
    <label>instructions</label>
    <input type="text" class="q-inst">
    <label class="q-crit-label"></label>
    <textarea class="q-crit" rows="3"></textarea>`;
    const q = (sel) => card.querySelector(sel);
    q(".q-id").value = d.id;
    q(".q-type").value = d.type;
    q(".q-inst").value = d.instructions;
    q(".q-crit").value = d.criteria;
    q(".q-crit").rows = Math.max(2, d.criteria.split("\n").length);
    refreshCard(card);
    q(".q-type").addEventListener("change", () => refreshCard(card));
    q(".q-del").addEventListener("click", () => { card.remove(); updateRequestJson(); });
    card.addEventListener("input", updateRequestJson);
    card.addEventListener("change", updateRequestJson);
    $("questions").append(card);
}
function lines(s) {
    return s.split("\n").map((x) => x.trim()).filter(Boolean);
}
function splitKV(line) {
    const m = /^(.*?)\s*[:：]\s*(.*)$/.exec(line);
    return m ? [m[1].trim(), m[2].trim()] : [line, ""];
}
function buildRequest() {
    const raw = $("state").value.trim();
    let state = raw;
    if (/^[[{]/.test(raw)) {
        try {
            state = JSON.parse(raw);
        }
        catch { /* JSONでなければ文字列のまま */ }
    }
    const questions = Object.create(null);
    document.querySelectorAll(".qcard").forEach((card, i) => {
        const id = card.querySelector(".q-id").value.trim() || `q${i + 1}`;
        const type = card.querySelector(".q-type").value;
        const instructions = card.querySelector(".q-inst").value;
        const crit = lines(card.querySelector(".q-crit").value);
        if (type === "choice") {
            questions[id] = { type, instructions, criteria: Object.fromEntries(crit.map((l) => { const [k, v] = splitKV(l); return [k, v || null]; })) };
        }
        else if (type === "score") {
            questions[id] = { type, instructions, criteria: crit };
        }
        else {
            const c = {};
            for (const l of crit) {
                const [k, v] = splitKV(l);
                if ((k === "true" || k === "false") && v)
                    c[k] = v;
            }
            questions[id] = Object.keys(c).length ? { type, instructions, criteria: c } : { type, instructions };
        }
    });
    const req = { state, model: "jev-latest", questions };
    const calibrated = $("calibrated").checked;
    const debias = $("debias").checked;
    if (!calibrated || debias)
        req.options = { ...(calibrated ? {} : { temperature_scaling: false }), ...(debias ? { permutations: 4 } : {}) };
    return req;
}
const EXAMPLES = [
    {
        label: "ex.support",
        ja: {
            state: "お客様: 3回目の問い合わせです。まだ配送されていません。もう限界です。返金してください。",
            questions: [
                { id: "is_angry", type: "noul", instructions: "この顧客は怒っていますか？", criteria: "" },
                { id: "emotion", type: "choice", instructions: "この顧客の感情はどれに近いですか？", criteria: "喜び\n悲しみ\n怒り\n不安\n驚き" },
                { id: "urgency", type: "score", instructions: "この問い合わせの緊急度", criteria: "急ぎではない\n数日以内に対応\n今日中に対応\nすぐに対応が必要" },
                { id: "department", type: "choice", instructions: "どの部署に回すべきですか？", criteria: "配送: 配送状況・遅延\n経理: 返金・請求\n技術サポート: システムの不具合" },
            ],
        },
        en: {
            state: "Customer: This is my third inquiry. My order still hasn't been delivered. I've had enough. Please refund me.",
            questions: [
                { id: "is_angry", type: "noul", instructions: "Is this customer angry?", criteria: "" },
                { id: "emotion", type: "choice", instructions: "Which emotion is closest to this customer's?", criteria: "joy\nsadness\nanger\nanxiety\nsurprise" },
                { id: "urgency", type: "score", instructions: "How urgent is this inquiry?", criteria: "Not urgent\nHandle within a few days\nHandle today\nNeeds immediate attention" },
                { id: "department", type: "choice", instructions: "Which department should handle this?", criteria: "shipping: Delivery status and delays\naccounting: Refunds and billing\ntech support: System problems" },
            ],
        },
    },
    {
        label: "ex.quickstart",
        ja: {
            state: "Hi, I've been trying to connect my Stripe account for 3 days and it keeps failing. I'm losing sales. Please help ASAP.",
            questions: [
                { id: "department", type: "choice", instructions: "Which team should handle this", criteria: "billing: Payment or subscription issues\ntechnical: Bugs or integration problems\nsales: Pricing or account questions" },
                { id: "frustration", type: "score", instructions: "How frustrated the customer appears", criteria: "Calm, just stating facts\nFrustrated but civil\nVery angry, strong language" },
                { id: "is_urgent", type: "noul", instructions: "The message conveys urgency or time-sensitivity", criteria: "" },
            ],
        },
    },
    {
        label: "ex.review",
        ja: {
            state: JSON.stringify({ review: "第一志望には落ちたけど、滑り止めの大学には受かった。ほっとしたような、悔しいような。", author_age: "18" }, null, 2),
            questions: [
                { id: "emotion", type: "choice", instructions: "この発言者の感情として最も近いものはどれですか？", criteria: "喜び\n悲しみ\n怒り\n不安\n驚き" },
                { id: "relieved", type: "noul", instructions: "この人は安心していますか？", criteria: "" },
                { id: "anger_level", type: "score", instructions: "怒りの強さ", criteria: "まったく怒っていない\n少しいらだっている\nかなり怒っている\n激怒している" },
            ],
        },
        en: {
            state: JSON.stringify({ review: "I didn't get into my first-choice university, but I got into my backup. I feel relieved, and frustrated at the same time.", author_age: "18" }, null, 2),
            questions: [
                { id: "emotion", type: "choice", instructions: "Which emotion is closest to the speaker's?", criteria: "joy\nsadness\nanger\nanxiety\nsurprise" },
                { id: "relieved", type: "noul", instructions: "Does this person feel relieved?", criteria: "" },
                { id: "anger_level", type: "score", instructions: "How angry is this person?", criteria: "Not angry at all\nA little irritated\nQuite angry\nFurious" },
            ],
        },
    },
];
// 最後に入れた例と、そのときの入力内容（言語切り替え時に、編集されていなければ入れ替える）
let currentExample = null;
let exampleSnapshot = "";
const inputSnapshot = () => JSON.stringify({ state: buildRequest().state, questions: buildRequest().questions });
function applyExample(ex) {
    const c = (getLang() === "en" && ex.en) || ex.ja;
    $("state").value = c.state;
    $("questions").innerHTML = "";
    c.questions.forEach(addQuestion);
    updateRequestJson();
    currentExample = ex;
    exampleSnapshot = inputSnapshot();
}
for (const ex of EXAMPLES) {
    const b = document.createElement("button");
    b.className = "secondary";
    b.dataset.i18n = ex.label;
    b.addEventListener("click", () => applyExample(ex));
    $("examples").append(b);
}
// ---------------------------------------------------------------- 結果表示
function bars(entries, top) {
    const frag = document.createDocumentFragment();
    for (const [label, p] of entries) {
        const row = document.createElement("div");
        row.className = "bar-row" + (label === top ? " top" : "");
        const name = document.createElement("span");
        name.className = "bar-label";
        name.textContent = label;
        name.title = label;
        const line = document.createElement("div");
        line.className = "bar-line";
        const track = document.createElement("span");
        track.className = "bar-track";
        const fill = document.createElement("span");
        fill.className = "bar-fill";
        fill.style.width = `${(p * 100).toFixed(1)}%`;
        track.append(fill);
        const val = document.createElement("span");
        val.className = "bar-value";
        val.textContent = `${(p * 100).toFixed(1)}%`;
        line.append(track, val);
        row.append(name, line);
        frag.append(row);
    }
    return frag;
}
function renderAnswer(id, a) {
    const box = document.createElement("div");
    box.className = "ans";
    const head = document.createElement("div");
    head.className = "ans-head";
    head.innerHTML = `<span class="ans-id"></span><span class="ans-type">${a.type}</span>`;
    head.querySelector(".ans-id").textContent = id;
    box.append(head);
    const meta = document.createElement("div");
    meta.className = "ans-meta";
    if (a.type === "noul") {
        meta.textContent = `noul = ${a.noul.toFixed(3)}`;
        box.append(meta, bars([["yes", a.noul], ["no", 1 - a.noul]], a.noul >= 0.5 ? "yes" : "no"));
    }
    else if (a.type === "choice") {
        meta.textContent = `confidence ${a.confidence.toFixed(3)}`;
        box.append(meta, bars(Object.entries(a.probabilities), a.choice));
    }
    else {
        meta.textContent = `score ${a.score.toFixed(2)} / confidence ${a.confidence.toFixed(3)}`;
        const entries = Object.entries(a.probabilities).map(([k, p]) => [`${k}: ${a.legend[k]}`, p]);
        const top = entries.reduce((m, e) => (e[1] > m[1] ? e : m), entries[0])[0];
        box.append(meta, bars(entries, top));
    }
    return box;
}
function render(res) {
    const out = $("result");
    out.innerHTML = "";
    for (const [id, a] of Object.entries(res.answers))
        out.append(renderAnswer(id, a));
    $("json").textContent = JSON.stringify(res, null, 2);
}
// ---------------------------------------------------------------- 実行
async function runOnServer(req) {
    const r = await fetch("v1/systemone", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(req) });
    const j = await r.json();
    if (!r.ok || j.error)
        throw new JevError(j.error?.code ?? "http_error", j.error?.message ?? `HTTP ${r.status}`, j.error?.field, r.status);
    return j;
}
async function run() {
    if (!jev && !serverMode)
        return;
    const req = updateRequestJson();
    if (!req) return;
    running = true;
    const btn = $("run");
    btn.disabled = true;
    const t0 = performance.now();
    try {
        const res = serverMode ? await runOnServer(req) : await jev.systemOne(req);
        render(res);
        setRunStatus({ key: "run.ok", vars: { ms: Math.round(performance.now() - t0), n: Object.keys(res.answers).length, tokens: res.usage.input_tokens }, kind: "ok" });
    }
    catch (e) {
        const err = e instanceof JevError ? e : new JevError("internal_error", e.message, undefined, 500);
        $("result").innerHTML = "";
        $("json").textContent = JSON.stringify(err.body(), null, 2);
        setRunStatus({ raw: `${err.code}: ${err.message}${err.field ? ` (${err.field})` : ""}`, kind: "error" });
    }
    finally {
        running = false;
        updateRequestJson();
    }
}
// リクエスト/レスポンスのタブ切り替え。リクエストJSONは入力の変更に合わせて更新する
function updateRequestJson() {
    const req = buildRequest();
    const feedback = $("input-check");
    const cards = [...document.querySelectorAll(".qcard")].map(card => ({
        id: card.querySelector(".q-id").value,
        type: card.querySelector(".q-type").value,
        criteria: card.querySelector(".q-crit").value,
    }));
    try {
        validateDraft(req, cards);
        $("json-req").textContent = JSON.stringify(req, null, 2);
        feedback.dataset.kind = "ok";
        feedback.textContent = t("input.valid", { n: cards.length });
        $("run").disabled = running || (!jev && !serverMode);
        return req;
    } catch (error) {
        // Do not display silently collapsed duplicate inputs as a valid request.
        $("json-req").textContent = JSON.stringify({ error: { code: error.code, message: error.message, field: error.field } }, null, 2);
        feedback.dataset.kind = "error";
        feedback.textContent = draftErrorMessage(error, getLang());
        $("run").disabled = true;
        return null;
    }
}
function selectTab(which) {
    $("tab-request").setAttribute("aria-selected", String(which === "request"));
    $("tab-response").setAttribute("aria-selected", String(which === "response"));
    $("json-req").hidden = which !== "request";
    $("json").hidden = which !== "response";
}
$("tab-request").addEventListener("click", () => selectTab("request"));
$("tab-response").addEventListener("click", () => selectTab("response"));
for (const id of ["state", "calibrated", "debias"]) {
    $(id).addEventListener("input", updateRequestJson);
    $(id).addEventListener("change", updateRequestJson);
}
$("add-question").addEventListener("click", () => {
    addQuestion({ id: `q${document.querySelectorAll(".qcard").length + 1}`, type: "choice", instructions: "", criteria: "" });
    updateRequestJson();
});
$("run").addEventListener("click", run);
$("model-file").addEventListener("change", async (ev) => {
    const f = ev.target.files?.[0];
    if (!f)
        return;
    try {
        await load(blobSource(f), f.name);
    }
    catch (e) {
        setProgress(null);
        setStatus("status.loadFailed", { msg: e.message }, "error");
    }
});
// ---------------------------------------------------------------- 言語
for (const b of document.querySelectorAll("[data-lang]")) {
    b.addEventListener("click", () => setLang(b.dataset.lang));
}
let serverModelVars = null;
onLangChange(() => {
    show("status", statusMsg);
    show("run-status", runMsg);
    updateRequestJson();
    setModelName(modelName);
    document.querySelectorAll(".qcard").forEach(refreshCard);
    if (serverModelVars)
        $("server-model-name").textContent = t("model.server", serverModelVars);
    // 例を入れたまま編集していなければ、同じ例の別言語版に入れ替える
    if (currentExample && inputSnapshot() === exampleSnapshot)
        applyExample(currentExample);
});
applyStatic();
setStatus("status.needWebgpu");
setModelName(null);
applyExample(EXAMPLES[0]);
async function detectServer() {
    try {
        const r = await fetch("health");
        if (!r.ok)
            return null;
        const h = await r.json();
        return h?.status === "ok" && typeof h.model === "string" ? h : null;
    }
    catch {
        return null;
    }
}
const health = await detectServer();
if (health) {
    serverMode = true;
    $("model-panel").hidden = true;
    $("server-model").hidden = false;
    serverModelVars = { model: health.model, t: health.temperature.toFixed(3) };
    $("server-model-name").textContent = t("model.server", serverModelVars);
    $("lead").dataset.i18n = "lead.server";
    $("api-note").hidden = false; // API の形式はサーバーで使うときだけ案内する
    applyStatic();
    updateRequestJson();
}
else if (!("gpu" in navigator)) {
    setStatus("status.noWebgpu", {}, "error");
}
