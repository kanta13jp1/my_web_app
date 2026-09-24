// GGUF (v2/v3) のヘッダ・メタデータKV・テンソル情報テーブルを読む。
// ファイル全体をメモリに載せないよう、ByteSource（Node: fs / ブラウザ: File・fetch Range）経由で読む。
export const GGMLType = {
    F32: 0,
    F16: 1,
    Q4_0: 2,
    Q4_1: 3,
    Q5_0: 6,
    Q5_1: 7,
    Q8_0: 8,
    Q2_K: 10,
    Q3_K: 11,
    Q4_K: 12,
    Q5_K: 13,
    Q6_K: 14,
    BF16: 30,
};
export const GGML_TYPE_NAME = {
    0: "F32", 1: "F16", 2: "Q4_0", 3: "Q4_1", 6: "Q5_0", 7: "Q5_1", 8: "Q8_0", 10: "Q2_K", 11: "Q3_K", 12: "Q4_K", 13: "Q5_K", 14: "Q6_K", 30: "BF16",
};
export function tensorBytes(type, n) {
    switch (type) {
        case GGMLType.F32: return n * 4;
        case GGMLType.F16: return n * 2;
        case GGMLType.BF16: return n * 2;
        case GGMLType.Q8_0: return (n / 32) * 34;
        case GGMLType.Q4_0: return (n / 32) * 18;
        case GGMLType.Q4_1: return (n / 32) * 20;
        case GGMLType.Q5_0: return (n / 32) * 22;
        case GGMLType.Q5_1: return (n / 32) * 24;
        case GGMLType.Q2_K: return (n / 256) * 84;
        case GGMLType.Q3_K: return (n / 256) * 110;
        case GGMLType.Q4_K: return (n / 256) * 144;
        case GGMLType.Q5_K: return (n / 256) * 176;
        case GGMLType.Q6_K: return (n / 256) * 210;
        default: throw new Error(`unsupported ggml type ${type} (supported: F32, F16, BF16, Q8_0, Q2_K, Q3_K, Q4_K, Q5_K, Q6_K)`);
    }
}
class OutOfData extends Error {
}
class Reader {
    pos = 0;
    buf;
    view;
    dec = new TextDecoder("utf-8");
    constructor(buf) {
        this.buf = buf;
        this.view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    }
    need(n) {
        if (this.pos + n > this.buf.byteLength)
            throw new OutOfData();
    }
    u8() { this.need(1); return this.view.getUint8(this.pos++); }
    i8() { this.need(1); return this.view.getInt8(this.pos++); }
    u16() { this.need(2); const v = this.view.getUint16(this.pos, true); this.pos += 2; return v; }
    i16() { this.need(2); const v = this.view.getInt16(this.pos, true); this.pos += 2; return v; }
    u32() { this.need(4); const v = this.view.getUint32(this.pos, true); this.pos += 4; return v; }
    i32() { this.need(4); const v = this.view.getInt32(this.pos, true); this.pos += 4; return v; }
    f32() { this.need(4); const v = this.view.getFloat32(this.pos, true); this.pos += 4; return v; }
    f64() { this.need(8); const v = this.view.getFloat64(this.pos, true); this.pos += 8; return v; }
    u64() {
        this.need(8);
        const v = this.view.getBigUint64(this.pos, true);
        this.pos += 8;
        if (v > BigInt(Number.MAX_SAFE_INTEGER))
            throw new Error("u64 too large");
        return Number(v);
    }
    i64() { this.need(8); const v = this.view.getBigInt64(this.pos, true); this.pos += 8; return Number(v); }
    str() {
        const n = this.u64();
        this.need(n);
        const s = this.dec.decode(this.buf.subarray(this.pos, this.pos + n));
        this.pos += n;
        return s;
    }
    value(type) {
        switch (type) {
            case 0: return this.u8();
            case 1: return this.i8();
            case 2: return this.u16();
            case 3: return this.i16();
            case 4: return this.u32();
            case 5: return this.i32();
            case 6: return this.f32();
            case 7: return this.u8() !== 0;
            case 8: return this.str();
            case 9: {
                const et = this.u32();
                const n = this.u64();
                // 数値配列は型付き配列で返す（語彙の token_type など巨大になりうる）
                if (et === 5) {
                    const a = new Int32Array(n);
                    for (let i = 0; i < n; i++)
                        a[i] = this.i32();
                    return a;
                }
                if (et === 4) {
                    const a = new Uint32Array(n);
                    for (let i = 0; i < n; i++)
                        a[i] = this.u32();
                    return a;
                }
                if (et === 6) {
                    const a = new Float32Array(n);
                    for (let i = 0; i < n; i++)
                        a[i] = this.f32();
                    return a;
                }
                const arr = new Array(n);
                for (let i = 0; i < n; i++)
                    arr[i] = this.value(et);
                return arr;
            }
            case 10: return this.u64();
            case 11: return this.i64();
            case 12: return this.f64();
            default: throw new Error(`unknown gguf value type ${type}`);
        }
    }
}
function parseHeader(buf) {
    const r = new Reader(buf);
    const magic = r.u32();
    if (magic !== 0x46554747)
        throw new Error("not a GGUF file");
    const version = r.u32();
    if (version < 2)
        throw new Error(`GGUF v${version} not supported`);
    const nTensors = r.u64();
    const nKV = r.u64();
    const metadata = new Map();
    for (let i = 0; i < nKV; i++) {
        const key = r.str();
        const type = r.u32();
        metadata.set(key, r.value(type));
    }
    const tensors = new Map();
    for (let i = 0; i < nTensors; i++) {
        const name = r.str();
        const nd = r.u32();
        const dims = [];
        for (let d = 0; d < nd; d++)
            dims.push(r.u64());
        const type = r.u32();
        const offset = r.u64();
        const nElements = dims.reduce((a, b) => a * b, 1);
        tensors.set(name, { name, dims, type, offset, absOffset: 0, nElements, nBytes: tensorBytes(type, nElements) });
    }
    const alignment = metadata.get("general.alignment") ?? 32;
    return { version, metadata, tensors, alignment, headerEnd: r.pos };
}
export async function parseGGUF(src) {
    // ヘッダ長は事前にわからない（語彙が大きい）ので、足りなければ倍々で読み直す
    let len = Math.min(src.size, 16 << 20);
    for (;;) {
        const buf = await src.read(0, len);
        try {
            const h = parseHeader(buf);
            const dataOffset = Math.ceil(h.headerEnd / h.alignment) * h.alignment;
            for (const t of h.tensors.values()) {
                t.absOffset = dataOffset + t.offset;
                if (t.absOffset + t.nBytes > src.size)
                    throw new Error(`tensor ${t.name} exceeds file size`);
            }
            return { version: h.version, metadata: h.metadata, tensors: h.tensors, alignment: h.alignment, dataOffset };
        }
        catch (e) {
            if (e instanceof OutOfData && len < src.size) {
                len = Math.min(src.size, len * 2);
                continue;
            }
            throw e;
        }
    }
}
export async function readTensorBytes(src, t) {
    return src.read(t.absOffset, t.nBytes);
}
