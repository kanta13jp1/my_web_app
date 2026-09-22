// Qwen3 forward pass（プリフィル専用、候補トークンのlogitだけを返す）のオーケストレーション。
//  - サンプリングループなし / KVキャッシュなし（リクエストごとに使い捨て）
//  - 複数リクエストを1系列にパッキングして同時に計算できる（アテンションは系列内に限定、RoPE位置は系列内位置）
//  - lm_head は候補トークンの行だけを使う
import { GGMLType, parseGGUF } from "../gguf/parser.js";
import { dequantize, dequantRow, KQUANT, repackKQuant, repackQ8_0 } from "../gguf/dequant.js";
import { BufferPool, readBuffer, UNIFORM, writeBuffer, MAP_READ } from "../gpu/buffers.js";
import { BPETokenizer } from "../tokenizer/bpe.js";
import { PrefixKVCache } from "./kv_cache.js";
const UNIFORM_SLOT = 256;
const MAX_CANDS = 16;
function metaNum(g, key) {
    const v = g.metadata.get(key);
    if (typeof v !== "number")
        throw new Error(`GGUF metadata ${key} missing`);
    return v;
}
function u32params(...vals) {
    const b = new ArrayBuffer(Math.ceil((vals.length * 4) / 16) * 16);
    const u = new Uint32Array(b);
    vals.forEach((v, i) => (u[i] = v));
    return b;
}
function mixedParams(spec) {
    const b = new ArrayBuffer(Math.ceil((spec.length * 4) / 16) * 16);
    const dv = new DataView(b);
    spec.forEach(([t, v], i) => (t === "u" ? dv.setUint32(i * 4, v, true) : dv.setFloat32(i * 4, v, true)));
    return b;
}
export class Qwen3Model {
    cfg;
    gguf;
    tokenizer;
    device;
    weightMode = "q8";
    maxTokens = 2048;
    maxSeqLen = 2048;
    maxSeqs = 64;
    gpuBytes = 0;
    src;
    pool;
    embdInfo;
    embdBytes;
    headInfo;
    candCache = new Map();
    steps = [];
    uniform;
    act = {};
    cosSin;
    kvCache;
    cacheK;
    cacheV;
    cacheLayerBytes = 0;
    cacheRowBytes = 0;
    kvCopyPipeline = null;
    static async load(src, device, loadShader, opts = {}) {
        const m = new Qwen3Model();
        await m.init(src, device, loadShader, opts);
        return m;
    }
    async init(src, device, loadShader, opts) {
        this.src = src;
        this.device = device;
        this.weightMode = opts.weights ?? "q8";
        this.maxTokens = opts.maxTokens ?? 2048;
        this.maxSeqLen = Math.min(opts.maxSeqLen ?? 2048, this.maxTokens);
        this.maxSeqs = opts.maxSeqs ?? 64;
        this.pool = new BufferPool(device);
        const g = (this.gguf = await parseGGUF(src));
        const arch = g.metadata.get("general.architecture");
        if (arch !== "qwen3")
            throw new Error(`unsupported architecture ${arch}`);
        const dim = metaNum(g, "qwen3.embedding_length");
        const nHead = metaNum(g, "qwen3.attention.head_count");
        this.cfg = {
            nLayer: metaNum(g, "qwen3.block_count"),
            dim,
            ffnDim: metaNum(g, "qwen3.feed_forward_length"),
            nHead,
            nKV: metaNum(g, "qwen3.attention.head_count_kv"),
            headDim: g.metadata.get("qwen3.attention.key_length") ?? dim / nHead,
            ropeBase: metaNum(g, "qwen3.rope.freq_base"),
            eps: metaNum(g, "qwen3.attention.layer_norm_rms_epsilon"),
            vocab: g.metadata.get("tokenizer.ggml.tokens").length,
            contextLength: metaNum(g, "qwen3.context_length"),
        };
        this.tokenizer = new BPETokenizer(g.metadata);
        // 埋め込みはCPU側で行参照する（GPUには載せない）。lm_headは候補行だけを必要時に読む（tied embeddingsなら token_embd を使う）
        this.embdInfo = this.tensor("token_embd.weight");
        this.embdBytes = await src.read(this.embdInfo.absOffset, this.embdInfo.nBytes);
        this.headInfo = g.tensors.get("output.weight") ?? this.embdInfo;
        const c = this.cfg;
        const total = c.nLayer * 11 + 1;
        let done = 0;
        const tick = () => opts.onProgress?.(++done, total);
        const layers = [];
        for (let l = 0; l < c.nLayer; l++) {
            const p = `blk.${l}.`;
            const lw = {};
            lw.attnNorm = await this.vector(p + "attn_norm.weight");
            tick();
            lw.q = await this.linear(p + "attn_q.weight");
            tick();
            lw.k = await this.linear(p + "attn_k.weight");
            tick();
            lw.v = await this.linear(p + "attn_v.weight");
            tick();
            lw.o = await this.linear(p + "attn_output.weight");
            tick();
            lw.qNorm = await this.vector(p + "attn_q_norm.weight");
            lw.kNorm = await this.vector(p + "attn_k_norm.weight");
            tick();
            lw.ffnNorm = await this.vector(p + "ffn_norm.weight");
            tick();
            lw.gate = await this.linear(p + "ffn_gate.weight");
            tick();
            lw.up = await this.linear(p + "ffn_up.weight");
            tick();
            lw.down = await this.linear(p + "ffn_down.weight");
            tick();
            layers.push(lw);
        }
        const outNorm = await this.vector("output_norm.weight");
        tick();
        // 活性化バッファ（最大トークン数で確保し使い回す）
        const T = this.maxTokens;
        const qDim = c.nHead * c.headDim;
        const kvDim = c.nKV * c.headDim;
        this.act = {
            x: this.pool.storage(T * c.dim * 4, "x"),
            xn: this.pool.storage(T * c.dim * 4, "xn"),
            q: this.pool.storage(T * qDim * 4, "q"),
            k: this.pool.storage(T * kvDim * 4, "k"),
            v: this.pool.storage(T * kvDim * 4, "v"),
            att: this.pool.storage(T * qDim * 4, "att"),
            gate: this.pool.storage(T * c.ffnDim * 4, "gate"),
            up: this.pool.storage(T * c.ffnDim * 4, "up"),
            a: this.pool.storage(T * c.ffnDim * 4, "a"),
            pos: this.pool.storage(T * 4, "pos"),
            // トークンごとに2つの vec4<u32>: (seg_start, pref_off, pref_len, store_slot), (pref_src, 0, 0, 0)
            info: this.pool.storage(T * 32, "info"),
            rowIdx: this.pool.storage(this.maxSeqs * 4, "rowIdx"),
            cand: this.pool.storage(MAX_CANDS * c.dim * 4, "cand"),
            logits: this.pool.storage(this.maxSeqs * MAX_CANDS * 4, "logits"),
        };
        // RoPEのcos/sinテーブル（HFと同様 inv_freq を f32 で計算し、角度 pos*inv_freq も f32 に丸める）
        const half = c.headDim / 2;
        const cs = new Float32Array(this.maxSeqLen * half * 2);
        for (let i = 0; i < half; i++) {
            const invFreq = Math.fround(1 / Math.fround(Math.pow(c.ropeBase, Math.fround((2 * i) / c.headDim))));
            for (let pos = 0; pos < this.maxSeqLen; pos++) {
                const ang = Math.fround(pos * invFreq);
                cs[(pos * half + i) * 2] = Math.cos(ang);
                cs[(pos * half + i) * 2 + 1] = Math.sin(ang);
            }
        }
        this.cosSin = this.pool.upload(cs, "cos_sin");
        // プレフィックスKVキャッシュのプール（全層分、層ごとに連続領域）
        const cap = opts.kvCacheTokens ?? 0;
        this.cacheRowBytes = kvDim * 4;
        this.cacheLayerBytes = Math.max(cap, 1) * this.cacheRowBytes;
        this.cacheK = this.pool.storage(c.nLayer * this.cacheLayerBytes, "cacheK");
        this.cacheV = this.pool.storage(c.nLayer * this.cacheLayerBytes, "cacheV");
        this.kvCache = new PrefixKVCache(cap); // 容量0でもバッチ内の接頭辞共有には使う
        await this.buildSteps(layers, outNorm, loadShader);
        this.gpuBytes = this.pool.totalBytes;
    }
    tensor(name) {
        const t = this.gguf.tensors.get(name);
        if (!t)
            throw new Error(`tensor ${name} not found`);
        return t;
    }
    async vector(name) {
        const t = this.tensor(name);
        return this.pool.upload(dequantize(t, await this.src.read(t.absOffset, t.nBytes)), name);
    }
    async linear(name) {
        const t = this.tensor(name);
        const [K, N] = t.dims;
        if (K % 32 !== 0 || N % 64 !== 0)
            throw new Error(`${name}: shape ${t.dims} not supported by matmul tiling`);
        const bytes = await this.src.read(t.absOffset, t.nBytes);
        if (this.weightMode === "q8") {
            // 量子化したまま置く（GPU で扱いやすい並びに詰め直す）
            if (t.type === GGMLType.Q8_0) {
                const { scales, quants } = repackQ8_0(bytes, t.nElements);
                return { mode: "q8", N, K, q: this.pool.upload(quants, name + ".q"), s: this.pool.upload(scales, name + ".s") };
            }
            if (KQUANT[t.type]) {
                const { quants, scales, info } = repackKQuant(t.type, bytes, t.nElements);
                return { mode: "kq", N, K, q: this.pool.upload(quants, name + ".q"), s: this.pool.upload(scales, name + ".s"),
                    kq: { bits: info.bits, gshift: Math.log2(info.group), zero: info.zero } };
            }
        }
        return { mode: "f32", N, K, f32: this.pool.upload(dequantize(t, bytes), name) };
    }
    async buildSteps(layers, outNorm, loadShader) {
        const dev = this.device;
        const mk = async (file, entry = "main") => dev.createComputePipeline({ layout: "auto", compute: { module: dev.createShaderModule({ code: await loadShader(file) }), entryPoint: entry } });
        const P = {
            rmsnorm: await mk("rmsnorm"),
            qknorm: await mk("qknorm"),
            rope: await mk("rope"),
            attention: await mk("attention"),
            swiglu: await mk("swiglu"),
            lmhead: await mk("lm_head_slice"),
            kvStore: await mk("kv_store"),
            kvCopy: await mk("kv_copy"),
            mmF32: await mk("matmul", "main_f32"),
            mmQ8: await mk("matmul", "main_q8"),
            mmKQ: await mk("matmul", "main_kq"),
        };
        const mmPipeline = { f32: P.mmF32, q8: P.mmQ8, kq: P.mmKQ };
        const c = this.cfg;
        const A = this.act;
        const steps = [];
        let slot = 0;
        const uniformSize = () => slot * UNIFORM_SLOT;
        // uniformバッファは後で確保するのでバインドは遅延生成
        const pending = [];
        const add = (s, buffers, firstBinding = 1) => {
            const step = { ...s, bind: null, uniformOffset: slot++ * UNIFORM_SLOT };
            pending.push({
                step,
                pipeline: s.pipeline,
                entries: (u) => [
                    { binding: 0, resource: { buffer: u, offset: step.uniformOffset, size: 16 * Math.ceil(s.params(1, 1).byteLength / 16) } },
                    ...buffers.map((b, i) => ({ binding: firstBinding + i, resource: "buffer" in b && !("mapState" in b) ? b : { buffer: b } })),
                ],
            });
            steps.push(step);
        };
        const rows = (T) => [Math.min(T, 65535), Math.ceil(T / 65535)];
        const rmsnorm = (name, x, w, y, dim) => add({ name, pipeline: P.rmsnorm, params: (T) => mixedParams([["u", T], ["u", dim], ["f", c.eps], ["u", 0]]), wg: rows, out: { buf: y, cols: dim } }, [x, w, y]);
        const matmul = (name, a, W, out, accumulate) => {
            const st = {
                name, pipeline: mmPipeline[W.mode],
                params: (T) => u32params(T, W.N, W.K, accumulate ? 1 : 0, W.kq?.bits ?? 0, W.kq?.gshift ?? 0, W.kq?.zero ?? 0, 0),
                wg: (T) => [W.N / 64, Math.ceil(T / 64)],
                out: { buf: out, cols: W.N },
            };
            if (W.mode !== "f32") {
                // 量子化版は binding 3 (f32重み) を使わず、binding 4/5 (quants/scales) を使うので個別にバインドする
                const step = { ...st, bind: null, uniformOffset: slot++ * UNIFORM_SLOT };
                pending.push({ step, pipeline: st.pipeline, entries: (u) => [
                        { binding: 0, resource: { buffer: u, offset: step.uniformOffset, size: 32 } },
                        { binding: 1, resource: { buffer: a } }, { binding: 2, resource: { buffer: out } },
                        { binding: 4, resource: { buffer: W.q } }, { binding: 5, resource: { buffer: W.s } }
                    ] });
                steps.push(step);
            }
            else {
                add(st, [a, out, W.f32]);
            }
        };
        const qkDim = c.headDim;
        const qknorm = (name, x, w, heads) => add({ name, pipeline: P.qknorm, params: (T) => mixedParams([["u", T], ["u", heads], ["u", qkDim], ["f", c.eps]]),
            wg: (T) => rows(T * heads), out: { buf: x, cols: heads * qkDim } }, [x, w]);
        const rope = (name, x, heads) => add({ name, pipeline: P.rope, params: (T) => u32params(T, heads, qkDim, 0),
            wg: (T) => { const n = Math.ceil((T * heads * qkDim) / 2 / 64); return [Math.min(n, 65535), Math.ceil(n / 65535)]; },
            out: { buf: x, cols: heads * qkDim } }, [x, A.pos, this.cosSin]);
        for (let l = 0; l < c.nLayer; l++) {
            const w = layers[l];
            const L = `L${l}.`;
            rmsnorm(L + "attn_norm", A.x, w.attnNorm, A.xn, c.dim);
            matmul(L + "q", A.xn, w.q, A.q, false);
            matmul(L + "k", A.xn, w.k, A.k, false);
            matmul(L + "v", A.xn, w.v, A.v, false);
            qknorm(L + "q_norm", A.q, w.qNorm, c.nHead);
            qknorm(L + "k_norm", A.k, w.kNorm, c.nKV);
            rope(L + "q_rope", A.q, c.nHead);
            rope(L + "k_rope", A.k, c.nKV);
            const ckL = { buffer: this.cacheK, offset: l * this.cacheLayerBytes, size: this.cacheLayerBytes };
            const cvL = { buffer: this.cacheV, offset: l * this.cacheLayerBytes, size: this.cacheLayerBytes };
            {
                const kvDim = c.nKV * c.headDim;
                add({ name: L + "kv_store", pipeline: P.kvStore, params: (T) => u32params(T, kvDim, 0, 0),
                    wg: (T) => { const n = Math.ceil((T * kvDim) / 256); return [Math.min(n, 65535), Math.ceil(n / 65535)]; } }, [A.k, A.v, A.info, ckL, cvL]);
            }
            add({ name: L + "attn", pipeline: P.attention,
                params: (T) => mixedParams([["u", T], ["u", c.nHead], ["u", c.nKV], ["u", c.headDim], ["f", 1 / Math.sqrt(c.headDim)], ["u", 0], ["u", 0], ["u", 0]]),
                wg: (T) => [T, c.nHead], out: { buf: A.att, cols: c.nHead * c.headDim } }, [A.q, A.k, A.v, A.info, ckL, cvL, A.att]);
            matmul(L + "resid_attn", A.att, w.o, A.x, true);
            rmsnorm(L + "ffn_norm", A.x, w.ffnNorm, A.xn, c.dim);
            matmul(L + "gate", A.xn, w.gate, A.gate, false);
            matmul(L + "up", A.xn, w.up, A.up, false);
            add({ name: L + "mlp_act", pipeline: P.swiglu, params: (T) => u32params(T * c.ffnDim, 0, 0, 0),
                wg: (T) => { const n = Math.ceil((T * c.ffnDim) / 256); return [Math.min(n, 65535), Math.ceil(n / 65535)]; },
                out: { buf: A.a, cols: c.ffnDim } }, [A.gate, A.up, A.a]);
            matmul(L + "out", A.a, w.down, A.x, true);
        }
        rmsnorm("final_norm", A.x, outNorm, A.xn, c.dim);
        add({ name: "lm_head", pipeline: P.lmhead, params: (_T, nSeq) => u32params(nSeq, this.nCand, c.dim, 0),
            wg: (_T, nSeq) => [nSeq, this.nCand] }, [A.xn, A.rowIdx, A.cand, A.logits]);
        this.kvCopyPipeline = P.kvCopy;
        this.uniform = dev.createBuffer({ size: uniformSize(), usage: UNIFORM });
        for (const p of pending) {
            p.step.bind = dev.createBindGroup({ layout: p.pipeline.getBindGroupLayout(0), entries: p.entries(this.uniform) });
        }
        this.steps = steps;
    }
    nCand = 0;
    /** 候補トークン（lm_headの行）を読み込む。行は必要時にファイルから読んでキャッシュ */
    async setCandidates(ids) {
        if (ids.length > MAX_CANDS)
            throw new Error(`too many candidate tokens (max ${MAX_CANDS})`);
        const c = this.cfg;
        const buf = new Float32Array(ids.length * c.dim);
        const t = this.headInfo;
        const rowBytes = t.nBytes / t.dims[1];
        for (let i = 0; i < ids.length; i++) {
            let row = this.candCache.get(ids[i]);
            if (!row) {
                const bytes = await this.src.read(t.absOffset + ids[i] * rowBytes, rowBytes);
                row = dequantRow({ ...t, dims: [t.dims[0], 1] }, bytes, 0);
                this.candCache.set(ids[i], row);
            }
            buf.set(row, i * c.dim);
        }
        writeBuffer(this.device, this.act.cand, 0, buf);
        this.nCand = ids.length;
    }
    embed(tokens) {
        const d = this.cfg.dim;
        const out = new Float32Array(tokens.length * d);
        for (let i = 0; i < tokens.length; i++) {
            if (tokens[i] < 0 || tokens[i] >= this.embdInfo.dims[1])
                throw new Error(`token id out of range: ${tokens[i]}`);
            out.set(dequantRow(this.embdInfo, this.embdBytes, tokens[i]), i * d);
        }
        return out;
    }
    /**
     * 複数系列をパッキングして1回で計算し、各系列の最終トークンにおける候補トークンのlogitを返す。
     * 戻り値: logits[seq][cand]
     */
    async forward(seqs, candIds, debug, opts = {}) {
        if (seqs.length === 0)
            return [];
        if (seqs.length > this.maxSeqs)
            throw new Error(`too many sequences in one batch (max ${this.maxSeqs})`);
        for (const s of seqs) {
            if (s.length === 0)
                throw new Error("empty sequence");
            if (s.length > this.maxSeqLen)
                throw new Error(`sequence too long: ${s.length} > ${this.maxSeqLen}`);
        }
        const dev = this.device;
        const nSeq = seqs.length;
        // プレフィックスKVキャッシュ: 再利用できる接頭辞は計算せず、残りだけを計算する
        const plans = this.kvCache.plan(seqs, opts.useCache ?? true);
        const T = seqs.reduce((a, s, i) => a + s.length - plans[i].reuse, 0);
        if (T > this.maxTokens)
            throw new Error(`batch too large: ${T} tokens > ${this.maxTokens}`);
        await this.setCandidates(candIds);
        const tokens = [];
        const pos = new Uint32Array(T);
        const info = new Uint32Array(T * 8);
        const rowStart = [];
        const rowIdx = new Uint32Array(nSeq);
        const NONE = 0xffffffff;
        let off = 0;
        seqs.forEach((s, si) => {
            const pl = plans[si];
            rowStart.push(off);
            // バッチ内共有: 接頭辞は元の系列の行（その系列は位置0から全部計算している）
            const prefOff = pl.srcSeq >= 0 ? rowStart[pl.srcSeq] : pl.prefOff;
            for (let i = pl.reuse; i < s.length; i++) {
                const t = off + i - pl.reuse;
                tokens.push(s[i]);
                pos[t] = i;
                info[t * 8] = off;
                info[t * 8 + 1] = prefOff;
                info[t * 8 + 2] = pl.reuse;
                info[t * 8 + 3] = pl.store ? pl.store.start + i : NONE;
                info[t * 8 + 4] = pl.srcSeq >= 0 ? 1 : 0;
            }
            off += s.length - pl.reuse;
            rowIdx[si] = off - 1;
        });
        writeBuffer(dev, this.act.x, 0, this.embed(tokens));
        writeBuffer(dev, this.act.pos, 0, pos);
        writeBuffer(dev, this.act.info, 0, info);
        writeBuffer(dev, this.act.rowIdx, 0, rowIdx);
        const ub = new Uint8Array(this.uniform.size);
        for (const s of this.steps)
            ub.set(new Uint8Array(s.params(T, nSeq)), s.uniformOffset);
        dev.queue.writeBuffer(this.uniform, 0, ub);
        const enc = dev.createCommandEncoder();
        // 保存先エントリへ、再利用した接頭辞のK/Vを元エントリからコピー（全層）
        const tmp = [];
        const copies = plans.filter((pl) => pl.store && pl.copyFrom >= 0);
        if (copies.length) {
            const kvDim = this.cfg.nKV * this.cfg.headDim;
            const cp = enc.beginComputePass();
            cp.setPipeline(this.kvCopyPipeline);
            for (const pl of copies) {
                const u = dev.createBuffer({ size: 32, usage: UNIFORM });
                tmp.push(u);
                dev.queue.writeBuffer(u, 0, new Uint32Array([pl.copyFrom, pl.store.start, pl.reuse, kvDim, this.cacheLayerBytes / 4, this.cfg.nLayer, 0, 0]));
                cp.setBindGroup(0, dev.createBindGroup({ layout: this.kvCopyPipeline.getBindGroupLayout(0), entries: [
                        { binding: 0, resource: { buffer: u } }, { binding: 1, resource: { buffer: this.cacheK } }, { binding: 2, resource: { buffer: this.cacheV } }
                    ] }));
                const n = Math.ceil((pl.reuse * kvDim * this.cfg.nLayer) / 256);
                cp.dispatchWorkgroups(Math.min(n, 65535), Math.ceil(n / 65535));
            }
            cp.end();
        }
        const dumps = [];
        let pass = enc.beginComputePass();
        for (const s of this.steps) {
            pass.setPipeline(s.pipeline);
            pass.setBindGroup(0, s.bind);
            const [x, y] = s.wg(T, nSeq);
            pass.dispatchWorkgroups(x, y);
            if (debug?.dump?.has(s.name) && s.out) {
                pass.end();
                const size = T * s.out.cols * 4;
                const rb = dev.createBuffer({ size, usage: MAP_READ });
                enc.copyBufferToBuffer(s.out.buf, 0, rb, 0, size);
                dumps.push({ name: s.name, rb, cols: s.out.cols });
                pass = enc.beginComputePass();
            }
        }
        pass.end();
        dev.queue.submit([enc.finish()]);
        for (const u of tmp)
            u.destroy();
        const logits = await readBuffer(dev, this.act.logits, 0, nSeq * this.nCand * 4);
        if (debug) {
            debug.dumps = new Map();
            for (const d of dumps) {
                await d.rb.mapAsync(1);
                debug.dumps.set(d.name, { data: new Float32Array(d.rb.getMappedRange().slice(0)), cols: d.cols });
                d.rb.unmap();
                d.rb.destroy();
            }
        }
        const out = [];
        for (let s = 0; s < nSeq; s++)
            out.push(logits.slice(s * this.nCand, (s + 1) * this.nCand));
        return out;
    }
    destroy() {
        this.pool.destroy();
        this.uniform?.destroy();
    }
}
