// GGUFテンソルの逆量子化（CPU側）。
// Q8_0: 32要素ブロック = f16スケール(2byte) + int8×32 = 34byte/block。 x = d * q
import { GGMLType } from "./parser.js";
const f16Table = (() => {
    const t = new Float32Array(65536);
    for (let h = 0; h < 65536; h++) {
        const s = h & 0x8000 ? -1 : 1;
        const e = (h >> 10) & 0x1f;
        const m = h & 0x3ff;
        if (e === 0)
            t[h] = s * m * 2 ** -24;
        else if (e === 31)
            t[h] = m ? NaN : s * Infinity;
        else
            t[h] = s * (1 + m / 1024) * 2 ** (e - 15);
    }
    return t;
})();
export function f16ToF32(h) {
    return f16Table[h];
}
export const Q8_0_BLOCK = 32;
export const Q8_0_BYTES = 34;
/** Q8_0の生バイト列 → Float32Array（n要素） */
export function dequantQ8_0(bytes, n, out, outOffset = 0) {
    if (n % Q8_0_BLOCK !== 0)
        throw new Error("Q8_0: n must be a multiple of 32");
    const nb = n / Q8_0_BLOCK;
    if (bytes.byteLength < nb * Q8_0_BYTES)
        throw new Error("Q8_0: not enough bytes");
    const res = out ?? new Float32Array(n);
    const u8 = bytes;
    for (let b = 0; b < nb; b++) {
        const o = b * Q8_0_BYTES;
        const d = f16Table[u8[o] | (u8[o + 1] << 8)];
        const base = outOffset + b * Q8_0_BLOCK;
        for (let i = 0; i < Q8_0_BLOCK; i++) {
            const q = u8[o + 2 + i];
            res[base + i] = d * (q > 127 ? q - 256 : q);
        }
    }
    return res;
}
export function dequantF16(bytes, n) {
    const res = new Float32Array(n);
    for (let i = 0; i < n; i++)
        res[i] = f16Table[bytes[2 * i] | (bytes[2 * i + 1] << 8)];
    return res;
}
export function dequantBF16(bytes, n) {
    const res = new Float32Array(n);
    const u32 = new Uint32Array(res.buffer);
    for (let i = 0; i < n; i++)
        u32[i] = (bytes[2 * i] | (bytes[2 * i + 1] << 8)) << 16;
    return res;
}
export function asF32(bytes, n) {
    // アライメントが保証されないのでコピーする
    const res = new Float32Array(n);
    new Uint8Array(res.buffer).set(bytes.subarray(0, n * 4));
    return res;
}
/** 任意の対応型 → Float32Array */
export function dequantize(t, bytes) {
    switch (t.type) {
        case GGMLType.F32: return asF32(bytes, t.nElements);
        case GGMLType.F16: return dequantF16(bytes, t.nElements);
        case GGMLType.BF16: return dequantBF16(bytes, t.nElements);
        case GGMLType.Q8_0: return dequantQ8_0(bytes, t.nElements);
        default: throw new Error(`dequantize: unsupported type ${t.type} (${t.name})`);
    }
}
/** 行 [row] だけを逆量子化（埋め込み参照・lm_head slice用）。dims[0] = 行の長さ */
export function dequantRow(t, bytes, row) {
    const cols = t.dims[0];
    switch (t.type) {
        case GGMLType.F32: return asF32(bytes.subarray(row * cols * 4), cols);
        case GGMLType.F16: return dequantF16(bytes.subarray(row * cols * 2), cols);
        case GGMLType.BF16: return dequantBF16(bytes.subarray(row * cols * 2), cols);
        case GGMLType.Q8_0: {
            const rb = (cols / Q8_0_BLOCK) * Q8_0_BYTES;
            return dequantQ8_0(bytes.subarray(row * rb, (row + 1) * rb), cols);
        }
        default: throw new Error(`dequantRow: unsupported type ${t.type}`);
    }
}
/**
 * GPU用にQ8_0を再配置する（34byteブロックは4byte境界に揃わないため）。
 *   scales: Float32Array[nBlocks]
 *   quants: Uint32Array[nBlocks*8]   （int8を4個ずつリトルエンディアンで詰める）
 */
export function repackQ8_0(bytes, n) {
    const nb = n / Q8_0_BLOCK;
    const scales = new Float32Array(nb);
    const quants = new Uint32Array(nb * 8);
    const q8 = new Uint8Array(quants.buffer);
    for (let b = 0; b < nb; b++) {
        const o = b * Q8_0_BYTES;
        scales[b] = f16Table[bytes[o] | (bytes[o + 1] << 8)];
        q8.set(bytes.subarray(o + 2, o + 34), b * 32);
    }
    return { scales, quants };
}
