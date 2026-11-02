// UI の日本語・英語対応。
//   data-i18n="key"        → textContent を置き換える
//   data-i18n-html="key"   → innerHTML を置き換える（リンクを含む固定文言だけに使う）
// 言語はブラウザの設定から決め、切り替えたら localStorage に覚える。
const HF_REPO = "https://huggingface.co/kishida/jwenv-0.6b-poc-gguf";
const HF_FILE = `${HF_REPO}/resolve/main/jwenv-0.6b-poc-q8_0.gguf`;
const TYPESAFE_API = "https://docs.typesafe.ai/api";
const ja = {
    "lead.serverless": "1つの state に対する複数の質問（Noul / Choice / Score）に、選択肢ごとの確率で答える分類モデル（Qwen3 + KL蒸留 + 温度校正）を、サーバーなしでブラウザのWebGPU上で実行します。",
    "lead.server": "1つの state に対する複数の質問（Noul / Choice / Score）に、選択肢ごとの確率で答える分類モデル（Qwen3 + KL蒸留 + 温度校正）。Node.js + WebGPU の推論サーバーで実行します。",
    "model.title": "モデル",
    "model.none": "未読み込み",
    "model.step1": `Hugging Face の <a href="${HF_REPO}" target="_blank" rel="noopener">kishida/jwenv-0.6b-poc-gguf</a> から <a href="${HF_FILE}" download><code>jwenv-0.6b-poc-q8_0.gguf</code></a>（約610MB）をダウンロードします。`,
    "model.step2": "ダウンロードした GGUF ファイルを選択します。ファイルはブラウザ内で読み込まれ、どこにも送信されません。",
    "model.server": "{model}（サーバー / T={t}）",
    "status.needWebgpu": "WebGPU 対応ブラウザが必要です。",
    "status.noWebgpu": "このブラウザはWebGPUに対応していません（Chrome / Edge 113 以降などを使ってください）",
    "status.initGpu": "GPUを初期化中…",
    "status.loading": "{name} を読み込み中…",
    "status.loaded": "読み込み完了 {sec}s — {layers}層 / hidden {dim} / GPU {mb}MB / T={t} / {gpu}",
    "status.loadFailed": "読み込み失敗: {msg}",
    "input.title": "入力",
        "input.limits": "入力形式はモデルなしで確認できます。選択肢・段階は2〜8個、質問は最大64問。判定の正しさや処理時間は、モデルを読み込んで確認してください。",
        "input.valid": "入力形式OK（{n}問）。実行にはモデルの読み込みが必要です。",
    "state.label": "state（テキスト。{ } や [ ] で始めると JSON として送る）",
    "questions.title": "questions（すべて同じ state に対して評価）",
    "questions.add": "＋ 質問を追加",
    "question.delete": "この質問を削除",
    "opt.calibrated": "温度スケーリング（事後校正）",
    "opt.debias": "提示順を入れ替えて平均（位置バイアス緩和）",
    "run": "評価する",
    "run.ok": "{ms} ms / {n}問 / {tokens} tokens",
    "result.title": "結果",
    "result.empty": "まだ結果はありません",
    "tab.request": "リクエスト",
    "tab.response": "レスポンス",
    "apiNote": `API は TypeSafe System One（<a href="${TYPESAFE_API}" target="_blank" rel="noopener">docs.typesafe.ai/api</a>）と同じ形式です。「リクエスト」の JSON を <code>POST /v1/systemone</code> に送ると「レスポンス」の JSON が返ります。`,
    "crit.noul.label": "criteria（任意）: true: … / false: … の2行",
    "crit.noul.ph": "true: はっきり怒りを表している\nfalse: 怒りは表れていない",
    "crit.choice.label": "criteria: 1行に1つ。「選択肢: 説明」または「選択肢」だけ（2〜8個）",
    "crit.choice.ph": "billing: 支払い・請求\ntechnical: 不具合・連携\nsales",
    "crit.score.label": "criteria: 1行に1レベル。低い → 高い の順（2〜8レベル）",
    "crit.score.ph": "落ち着いている\nやや不満\n強く怒っている",
    "ex.support": "問い合わせ（4問）",
    "ex.quickstart": "Quickstart（英語・3問）",
    "ex.review": "感想（JSON state）",
};
const en = {
    "lead.serverless": "A classifier that answers several questions (Noul / Choice / Score) about one state with a probability for each option (Qwen3 + KL distillation + temperature calibration). It runs entirely in your browser on WebGPU, with no server.",
    "lead.server": "A classifier that answers several questions (Noul / Choice / Score) about one state with a probability for each option (Qwen3 + KL distillation + temperature calibration). Running on the Node.js + WebGPU inference server.",
    "model.title": "Model",
    "model.none": "Not loaded",
    "model.step1": `Download <a href="${HF_FILE}" download><code>jwenv-0.6b-poc-q8_0.gguf</code></a> (about 610 MB) from <a href="${HF_REPO}" target="_blank" rel="noopener">kishida/jwenv-0.6b-poc-gguf</a> on Hugging Face.`,
    "model.step2": "Select the downloaded GGUF file. It is read inside your browser and never uploaded.",
    "model.server": "{model} (server / T={t})",
    "status.needWebgpu": "Requires a WebGPU-capable browser.",
    "status.noWebgpu": "This browser does not support WebGPU (use Chrome / Edge 113 or later, for example).",
    "status.initGpu": "Initializing GPU…",
    "status.loading": "Loading {name}…",
    "status.loaded": "Loaded in {sec}s — {layers} layers / hidden {dim} / GPU {mb} MB / T={t} / {gpu}",
    "status.loadFailed": "Failed to load: {msg}",
    "input.title": "Input",
        "input.limits": "Check input format without a model: 2–8 options or levels, up to 64 questions. Load a model to check classification results and runtime.",
        "input.valid": "Input format OK ({n} questions). Running requires a loaded model.",
    "state.label": "state (text; starting with { or [ sends it as JSON)",
    "questions.title": "questions (all evaluated against the same state)",
    "questions.add": "+ Add question",
    "question.delete": "Remove this question",
    "opt.calibrated": "Temperature scaling (calibration)",
    "opt.debias": "Average over shuffled option order (reduces position bias)",
    "run": "Evaluate",
    "run.ok": "{ms} ms / {n} questions / {tokens} tokens",
    "result.title": "Results",
    "result.empty": "No results yet",
    "tab.request": "Request",
    "tab.response": "Response",
    "apiNote": `The API uses the same format as TypeSafe System One (<a href="${TYPESAFE_API}" target="_blank" rel="noopener">docs.typesafe.ai/api</a>). POST the "Request" JSON to <code>/v1/systemone</code> and you get the "Response" JSON back.`,
    "crit.noul.label": "criteria (optional): two lines, true: … / false: …",
    "crit.noul.ph": "true: clearly expresses anger\nfalse: no sign of anger",
    "crit.choice.label": "criteria: one option per line, \"option: description\" or just \"option\" (2–8)",
    "crit.choice.ph": "billing: payments and invoices\ntechnical: bugs and integrations\nsales",
    "crit.score.label": "criteria: one level per line, from low to high (2–8 levels)",
    "crit.score.ph": "Calm\nSomewhat frustrated\nVery angry",
    "ex.support": "Support ticket (4 questions)",
    "ex.quickstart": "Quickstart (3 questions)",
    "ex.review": "Feelings (JSON state)",
};
const STRINGS = { ja, en };
const listeners = [];
function initialLang() {
    try {
        const saved = localStorage.getItem("jev-lang");
        if (saved === "ja" || saved === "en")
            return saved;
    }
    catch { /* localStorage が使えない環境では無視 */ }
    return navigator.language.toLowerCase().startsWith("ja") ? "ja" : "en";
}
let lang = initialLang();
export function getLang() {
    return lang;
}
export function t(key, vars = {}) {
    return STRINGS[lang][key].replace(/\{(\w+)\}/g, (m, k) => (k in vars ? String(vars[k]) : m));
}
/** 固定文言（data-i18n / data-i18n-html）を今の言語で書き換える */
export function applyStatic(root = document) {
    document.documentElement.lang = lang;
    root.querySelectorAll("[data-i18n]").forEach((el) => (el.textContent = t(el.dataset.i18n)));
    root.querySelectorAll("[data-i18n-html]").forEach((el) => (el.innerHTML = t(el.dataset.i18nHtml)));
    document.querySelectorAll("[data-lang]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.lang === lang)));
}
export function setLang(l) {
    lang = l;
    try {
        localStorage.setItem("jev-lang", l);
    }
    catch { /* 保存できなくても表示は切り替える */ }
    applyStatic();
    listeners.forEach((f) => f());
}
/** 言語が切り替わったときに動的な表示を描き直すための登録 */
export function onLangChange(f) {
    listeners.push(f);
}
