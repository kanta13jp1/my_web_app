// Qwen2/Qwen3 用 byte-level BPE トークナイザ（GGUFメタデータから構築）。
//   1. 特殊トークン（token_type 3=CONTROL, 4=USER_DEFINED）を文字列一致で切り出す
//   2. NFC正規化
//   3. qwen2 pre-tokenizer 正規表現で分割
//   4. 各断片をUTF-8バイト → GPT-2のbyte→unicode写像 → BPEマージ
const QWEN2_PRETOKENIZE = /'(?:[sS]|[tT]|[rR][eE]|[vV][eE]|[mM]|[lL][lL]|[dD])|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+/gu;
function bytesToUnicode() {
    const bs = [];
    for (let i = 33; i <= 126; i++)
        bs.push(i);
    for (let i = 161; i <= 172; i++)
        bs.push(i);
    for (let i = 174; i <= 255; i++)
        bs.push(i);
    const cs = [...bs];
    let n = 0;
    for (let b = 0; b < 256; b++) {
        if (!bs.includes(b)) {
            bs.push(b);
            cs.push(256 + n);
            n++;
        }
    }
    const table = new Array(256);
    bs.forEach((b, i) => (table[b] = String.fromCodePoint(cs[i])));
    return table;
}
export class BPETokenizer {
    vocab;
    tokenToId = new Map();
    mergeRank = new Map();
    specials = [];
    byteMap = bytesToUnicode();
    enc = new TextEncoder();
    cache = new Map();
    constructor(metadata) {
        const model = metadata.get("tokenizer.ggml.model");
        const pre = metadata.get("tokenizer.ggml.pre");
        if (model !== "gpt2")
            throw new Error(`unsupported tokenizer model ${model}`);
        if (pre !== "qwen2")
            throw new Error(`unsupported pre-tokenizer ${pre}`);
        this.vocab = metadata.get("tokenizer.ggml.tokens");
        const types = metadata.get("tokenizer.ggml.token_type");
        const merges = metadata.get("tokenizer.ggml.merges");
        this.vocab.forEach((t, i) => this.tokenToId.set(t, i));
        merges.forEach((m, i) => this.mergeRank.set(m, i));
        for (let i = 0; i < this.vocab.length; i++) {
            if (types[i] === 3 || types[i] === 4)
                this.specials.push({ text: this.vocab[i], id: i });
        }
        this.specials.sort((a, b) => b.text.length - a.text.length); // 最長一致
    }
    tokenId(tok) {
        return this.tokenToId.get(tok);
    }
    encode(text) {
        const out = [];
        let i = 0;
        let plainStart = 0;
        while (i < text.length) {
            if (text.charCodeAt(i) === 60 /* '<' */ || text.charCodeAt(i) === 91 /* '[' */) {
                const sp = this.specials.find((s) => text.startsWith(s.text, i));
                if (sp) {
                    if (i > plainStart)
                        this.encodePlain(text.slice(plainStart, i), out);
                    out.push(sp.id);
                    i += sp.text.length;
                    plainStart = i;
                    continue;
                }
            }
            i++;
        }
        if (plainStart < text.length)
            this.encodePlain(text.slice(plainStart), out);
        return out;
    }
    decode(ids) {
        const inv = new Map();
        this.byteMap.forEach((c, b) => inv.set(c, b));
        const bytes = [];
        for (const id of ids) {
            const t = this.vocab[id];
            for (const ch of t) {
                const b = inv.get(ch);
                if (b === undefined)
                    bytes.push(...this.enc.encode(ch));
                else
                    bytes.push(b);
            }
        }
        return new TextDecoder().decode(new Uint8Array(bytes));
    }
    encodePlain(text, out) {
        text = text.normalize("NFC");
        for (const m of text.matchAll(QWEN2_PRETOKENIZE)) {
            const piece = m[0];
            const cached = this.cache.get(piece);
            if (cached) {
                out.push(...cached);
                continue;
            }
            let mapped = "";
            for (const b of this.enc.encode(piece))
                mapped += this.byteMap[b];
            const ids = this.bpe(mapped);
            if (this.cache.size < 100000)
                this.cache.set(piece, ids);
            out.push(...ids);
        }
    }
    bpe(word) {
        const direct = this.tokenToId.get(word);
        if (direct !== undefined)
            return [direct];
        let parts = Array.from(word);
        while (parts.length > 1) {
            let best = -1;
            let bestRank = Infinity;
            for (let i = 0; i < parts.length - 1; i++) {
                const r = this.mergeRank.get(parts[i] + " " + parts[i + 1]);
                if (r !== undefined && r < bestRank) {
                    bestRank = r;
                    best = i;
                }
            }
            if (best < 0)
                break;
            const a = parts[best];
            const b = parts[best + 1];
            const merged = [];
            for (let i = 0; i < parts.length;) {
                if (i < parts.length - 1 && parts[i] === a && parts[i + 1] === b) {
                    merged.push(a + b);
                    i += 2;
                }
                else {
                    merged.push(parts[i]);
                    i++;
                }
            }
            parts = merged;
        }
        return parts.map((p) => {
            const id = this.tokenToId.get(p);
            if (id === undefined)
                throw new Error(`BPE: unknown token ${JSON.stringify(p)}`);
            return id;
        });
    }
}
