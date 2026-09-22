export const LABELS = ["A", "B", "C", "D", "E", "F", "G", "H"];
export const MAX_OPTIONS = LABELS.length; // このモデルが扱える選択肢数の上限（TypeSafe は Choice 255 / Score 10）
export const MAX_QUESTIONS = 64;
export const MODEL_ALIASES = ["jev-latest"];
/** HTTP ステータス付きのエラー（422: 検証エラー、401: 認証、529: 過負荷） */
export class JevError extends Error {
    code;
    status;
    field;
    constructor(code, message, field, status = 422) {
        super(message);
        this.code = code;
        this.field = field;
        this.status = status;
    }
    body() {
        return { error: { code: this.code, message: this.message, ...(this.field ? { field: this.field } : {}) } };
    }
}
/** Python側 jev/prompt.py の build_prompt（＝llama-server の /v1/systemone）と完全一致させること */
export function buildPrompt(question, labelMap, context, system) {
    const sysPart = system ? `<|im_start|>system\n${system}<|im_end|>\n` : "";
    const opts = labelMap.map(([l, c]) => `${l}: ${c}`).join("\n");
    return (`${sysPart}<|im_start|>user\nContext:\n${context || "(none)"}\n\n` +
        "Answer the question with only the label of the best option (the character before the colon), nothing else.\n" +
        `Question: ${question}\nOptions:\n${opts}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n`);
}
// ---------------------------------------------------------------- 検証
const isObj = (v) => typeof v === "object" && v !== null && !Array.isArray(v);
const isStructured = (v) => (typeof v === "string" && v.trim() !== "") || Array.isArray(v) || isObj(v);
/** string はそのまま、object / array は JSON 文字列にしてプロンプトへ入れる */
function asText(v, pretty = false) {
    return typeof v === "string" ? v : JSON.stringify(v, null, pretty ? 2 : undefined);
}
export function validate(raw, acceptedModels) {
    if (!isObj(raw))
        throw new JevError("invalid_request", "request body must be a JSON object");
    const r = raw;
    if (!isStructured(r.state))
        throw new JevError("invalid_state", "state must be a non-empty string, object, or array", "state");
    if (typeof r.model !== "string" || !r.model)
        throw new JevError("missing_field", "model is required", "model");
    if (!acceptedModels.includes(r.model))
        throw new JevError("unknown_model", `unknown model "${r.model}" (available: ${acceptedModels.join(", ")})`, "model");
    if (!isObj(r.questions))
        throw new JevError("invalid_questions", "questions must be a map of question id to question", "questions");
    const ids = Object.keys(r.questions);
    if (ids.length === 0)
        throw new JevError("invalid_questions", "questions must contain at least one question", "questions");
    if (ids.length > MAX_QUESTIONS)
        throw new JevError("too_many_questions", `at most ${MAX_QUESTIONS} questions per request`, "questions");
    for (const id of ids) {
        const q = r.questions[id];
        const f = `questions.${id}`;
        if (!isObj(q))
            throw new JevError("invalid_question", "question must be an object", f);
        if (!isStructured(q.instructions))
            throw new JevError("invalid_instructions", "instructions must be a non-empty string, object, or array", `${f}.instructions`);
        if (q.type === "noul") {
            if (q.criteria !== undefined) {
                if (!isObj(q.criteria))
                    throw new JevError("invalid_criteria", "noul criteria must be an object with optional true / false", `${f}.criteria`);
                for (const k of Object.keys(q.criteria)) {
                    if (k !== "true" && k !== "false")
                        throw new JevError("invalid_criteria", `unknown noul criteria key "${k}"`, `${f}.criteria.${k}`);
                    if (!isStructured(q.criteria[k]))
                        throw new JevError("invalid_criteria", "noul criteria values must be non-empty", `${f}.criteria.${k}`);
                }
            }
        }
        else if (q.type === "choice") {
            if (!isObj(q.criteria))
                throw new JevError("invalid_criteria", "choice criteria must be a map of option to description (or null)", `${f}.criteria`);
            const opts = Object.keys(q.criteria);
            if (opts.length < 2)
                throw new JevError("too_few_options", "choice criteria must contain at least 2 options", `${f}.criteria`);
            if (opts.length > MAX_OPTIONS)
                throw new JevError("too_many_options", `this model supports at most ${MAX_OPTIONS} options per choice`, `${f}.criteria`);
            for (const o of opts) {
                if (!o.trim())
                    throw new JevError("invalid_criteria", "option names must be non-empty", `${f}.criteria`);
                const d = q.criteria[o];
                if (d !== null && !isStructured(d))
                    throw new JevError("invalid_criteria", "option description must be a string, object, array, or null", `${f}.criteria.${o}`);
            }
        }
        else if (q.type === "score") {
            if (!Array.isArray(q.criteria))
                throw new JevError("invalid_criteria", "score criteria must be an ordered array of level descriptions", `${f}.criteria`);
            if (q.criteria.length < 2)
                throw new JevError("too_few_levels", "score criteria must contain at least 2 levels", `${f}.criteria`);
            if (q.criteria.length > MAX_OPTIONS)
                throw new JevError("too_many_levels", `this model supports at most ${MAX_OPTIONS} levels per score`, `${f}.criteria`);
            q.criteria.forEach((d, i) => {
                if (!isStructured(d))
                    throw new JevError("invalid_criteria", "level description must be a non-empty string, object, or array", `${f}.criteria.${i}`);
            });
        }
        else {
            throw new JevError("invalid_type", 'type must be "noul", "choice", or "score"', `${f}.type`);
        }
    }
    const o = r.options;
    if (o !== undefined) {
        if (!isObj(o))
            throw new JevError("invalid_options", "options must be an object", "options");
        if (o.temperature_scaling !== undefined && typeof o.temperature_scaling !== "boolean")
            throw new JevError("invalid_options", "options.temperature_scaling must be a boolean", "options.temperature_scaling");
        if (o.permutations !== undefined && (!Number.isInteger(o.permutations) || o.permutations < 1 || o.permutations > MAX_OPTIONS))
            throw new JevError("invalid_options", `options.permutations must be an integer in [1, ${MAX_OPTIONS}]`, "options.permutations");
    }
    return r;
}
// ---------------------------------------------------------------- 確率 → 回答
const round = (x, d = 4) => Math.round(x * 10 ** d) / 10 ** d;
/** confidence = 1 - 正規化エントロピー（一様分布で0、1点集中で1） */
export function confidenceOf(p) {
    const n = p.length;
    let h = 0;
    for (const x of p)
        if (x > 0)
            h -= x * Math.log(x);
    return Math.max(0, 1 - h / Math.log(n));
}
export class JevClassifier {
    model;
    modelName;
    temperature;
    candIds;
    constructor(model, modelName, temperature) {
        this.model = model;
        this.modelName = modelName;
        this.temperature = temperature ?? model.gguf.metadata.get("jev.temperature") ?? 1.0;
        this.candIds = LABELS.map((l) => {
            const ids = model.tokenizer.encode(l);
            if (ids.length !== 1)
                throw new Error(`label ${l} is not a single token`);
            return ids[0];
        });
    }
    get acceptedModels() {
        return [...MODEL_ALIASES, this.modelName];
    }
    /** 検証して、質問ごとのプロンプト（トークン列）を作る */
    prepare(raw) {
        const req = validate(raw, this.acceptedModels);
        const context = asText(req.state, true);
        const K = req.options?.permutations ?? 1;
        const seqs = [];
        const questions = [];
        for (const [id, q] of Object.entries(req.questions)) {
            const question = asText(q.instructions);
            let keys;
            let texts;
            if (q.type === "noul") {
                keys = ["true", "false"];
                const t = q.criteria?.true, f = q.criteria?.false;
                texts = [t !== undefined ? `yes: ${asText(t)}` : "yes", f !== undefined ? `no: ${asText(f)}` : "no"];
            }
            else if (q.type === "choice") {
                keys = Object.keys(q.criteria);
                texts = keys.map((k) => (q.criteria[k] == null ? k : `${k}: ${asText(q.criteria[k])}`));
            }
            else {
                keys = q.criteria.map((_, i) => String(i));
                texts = q.criteria.map((d) => asText(d));
            }
            const n = keys.length;
            const k = Math.min(K, n);
            const pq = { id, q, keys, seqStart: seqs.length, perms: [] };
            for (let s = 0; s < k; s++) {
                const shift = Math.round((s * n) / k);
                const perm = Array.from({ length: n }, (_, i) => (i + shift) % n);
                const labelMap = perm.map((ci, pos) => [LABELS[pos], texts[ci]]);
                const ids = this.model.tokenizer.encode(buildPrompt(question, labelMap, context));
                if (ids.length > this.model.maxSeqLen)
                    throw new JevError("context_too_long", `prompt for question "${id}" is ${ids.length} tokens (max ${this.model.maxSeqLen})`, "state");
                seqs.push(ids);
                pq.perms.push(perm);
            }
            questions.push(pq);
        }
        return { req, seqs, questions };
    }
    /** forward の結果（各系列の候補 logit）から回答を作る */
    finish(p, logits) {
        const T = (p.req.options?.temperature_scaling ?? true) ? this.temperature : 1.0;
        const answers = {};
        for (const pq of p.questions) {
            const n = pq.keys.length;
            const acc = new Array(n).fill(0);
            pq.perms.forEach((perm, s) => {
                const lg = logits[pq.seqStart + s];
                const z = Array.from(lg.subarray(0, n), (v) => v / T);
                const m = Math.max(...z);
                const e = z.map((v) => Math.exp(v - m));
                const sum = e.reduce((a, b) => a + b, 0);
                e.forEach((v, pos) => (acc[perm[pos]] += v / sum / pq.perms.length));
            });
            if (pq.q.type === "noul") {
                answers[pq.id] = { type: "noul", noul: round(acc[0]) };
            }
            else if (pq.q.type === "choice") {
                let best = 0;
                acc.forEach((v, i) => { if (v > acc[best])
                    best = i; });
                answers[pq.id] = {
                    type: "choice",
                    choice: pq.keys[best],
                    probabilities: Object.fromEntries(pq.keys.map((k, i) => [k, round(acc[i])])),
                    confidence: round(confidenceOf(acc)),
                };
            }
            else {
                const crit = pq.q.criteria;
                answers[pq.id] = {
                    type: "score",
                    score: round(acc.reduce((a, v, i) => a + i * v, 0)),
                    legend: Object.fromEntries(crit.map((d, i) => [String(i), asText(d)])),
                    probabilities: Object.fromEntries(acc.map((v, i) => [String(i), round(v)])),
                    confidence: round(confidenceOf(acc)),
                };
            }
        }
        return {
            model: this.modelName,
            answers,
            // 生成はしないので output_tokens は常に0（候補ラベルの次トークン確率を読むだけ）
            usage: { input_tokens: p.seqs.reduce((a, s) => a + s.length, 0), output_tokens: 0 },
        };
    }
    /** 単発（バッチングなし）で評価する */
    async systemOne(raw) {
        const p = this.prepare(raw);
        const logits = await this.model.forward(p.seqs, this.candIds);
        return this.finish(p, logits);
    }
}
