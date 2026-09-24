// GGUFテンソルの逆量子化（CPU側）と、GPU用の再配置。
// 対応: F32 / F16 / BF16 / Q8_0 / Q2_K / Q3_K / Q4_K / Q5_K / Q6_K（Q2_K〜Q6_K の各 GGUF はこの組み合わせ）
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
        default:
            if (KQUANT[t.type])
                return dequantKQuant(t.type, bytes, t.nElements);
            throw new Error(`dequantize: unsupported type ${t.type} (${t.name})`);
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
        default: {
            const k = KQUANT[t.type];
            if (!k)
                throw new Error(`dequantRow: unsupported type ${t.type}`);
            const rb = (cols / QK_K) * k.bytes;
            return dequantKQuant(t.type, bytes.subarray(row * rb, (row + 1) * rb), cols);
        }
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
// ---------------------------------------------------------------- K-quant（Q2_K〜Q6_K、256要素のスーパーブロック）
// どの型も「サブブロック（16 or 32要素）ごとの scale / min と、小さい整数の値」で表せる:
//   x = scale * (code - zero) - min      code は 0 以上の整数（負の値を持つ型は zero だけずらして格納）
// scale / min は ggml と同じく f32 で d * sc を計算した値（丸めも同じ）なので、逆量子化は ggml と完全に一致する。
//
//   型    byte/256  サブブロック  code の範囲     scale / min
//   Q2_K     84        16          0..3          d*sc, dmin*m   （sc, m は4bit）
//   Q3_K    110        16          0..7 (q+4)    d*(sc-32)      （sc は6bit、min なし）
//   Q4_K    144        32          0..15         d*sc, dmin*m   （sc, m は6bit）
//   Q5_K    176        32          0..31         d*sc, dmin*m   （sc, m は6bit）
//   Q6_K    210        16          0..63 (q+32)  d*sc           （sc は int8、min なし）
export const QK_K = 256;
export const KQUANT = {
    [GGMLType.Q2_K]: { bytes: 84, group: 16, bits: 2, zero: 0 },
    [GGMLType.Q3_K]: { bytes: 110, group: 16, bits: 4, zero: 4 },
    [GGMLType.Q4_K]: { bytes: 144, group: 32, bits: 4, zero: 0 },
    [GGMLType.Q5_K]: { bytes: 176, group: 32, bits: 8, zero: 0 },
    [GGMLType.Q6_K]: { bytes: 210, group: 16, bits: 8, zero: 32 },
};
const f32 = Math.fround;
/** Q4_K / Q5_K の 6bit scale / min（ggml の get_scale_min_k4） */
function scaleMinK4(bytes, sc, j) {
    if (j < 4)
        return [bytes[sc + j] & 63, bytes[sc + j + 4] & 63];
    return [(bytes[sc + j + 4] & 0xf) | ((bytes[sc + j - 4] >> 6) << 4), (bytes[sc + j + 4] >> 4) | ((bytes[sc + j] >> 6) << 4)];
}
function decodeBlockQ2_K(bytes, o, out, y, g) {
    const d = f16Table[bytes[o + 80] | (bytes[o + 81] << 8)];
    const dmin = f16Table[bytes[o + 82] | (bytes[o + 83] << 8)];
    let is = 0;
    for (let half = 0; half < 2; half++) {
        const q = o + 16 + half * 32;
        for (let j = 0; j < 4; j++) {
            const shift = 2 * j;
            for (let k = 0; k < 2; k++) {
                const sc = bytes[o + is];
                out.scale[g + is] = f32(d * (sc & 0xf));
                out.min[g + is] = f32(dmin * (sc >> 4));
                const base = y + is * 16;
                for (let l = 0; l < 16; l++)
                    out.codes[base + l] = (bytes[q + k * 16 + l] >> shift) & 3;
                is++;
            }
        }
    }
}
function decodeBlockQ3_K(bytes, o, out, y, g) {
    const hm = o;
    const qs = o + 32;
    const sc = o + 96;
    const d = f16Table[bytes[o + 108] | (bytes[o + 109] << 8)];
    // 12byte に詰まった 6bit のスケール16個を取り出す（ggml の kmask1/kmask2 の処理と同じ）
    const u32 = (i) => (bytes[sc + i] | (bytes[sc + i + 1] << 8) | (bytes[sc + i + 2] << 16) | (bytes[sc + i + 3] << 24)) >>> 0;
    const a0 = u32(0), a1 = u32(4), tmp = u32(8);
    const k1 = 0x03030303, k2 = 0x0f0f0f0f;
    const aux = [
        ((a0 & k2) | (((tmp >>> 0) & k1) << 4)) >>> 0,
        ((a1 & k2) | (((tmp >>> 2) & k1) << 4)) >>> 0,
        (((a0 >>> 4) & k2) | (((tmp >>> 4) & k1) << 4)) >>> 0,
        (((a1 >>> 4) & k2) | (((tmp >>> 6) & k1) << 4)) >>> 0,
    ];
    for (let i = 0; i < 16; i++) {
        const s = (aux[i >> 2] >>> (8 * (i & 3))) & 0xff;
        out.scale[g + i] = f32(d * (s - 32));
        out.min[g + i] = 0;
    }
    let is = 0;
    let m = 1;
    for (let half = 0; half < 2; half++) {
        const q = qs + half * 32;
        for (let j = 0; j < 4; j++) {
            const shift = 2 * j;
            for (let k = 0; k < 2; k++) {
                const base = y + is * 16;
                for (let l = 0; l < 16; l++) {
                    const low = (bytes[q + k * 16 + l] >> shift) & 3;
                    const high = bytes[hm + k * 16 + l] & m ? 0 : 4;
                    out.codes[base + l] = low - high + 4; // q+4
                }
                is++;
            }
            m <<= 1;
        }
    }
}
function decodeBlockQ45_K(bytes, o, out, y, g, five) {
    const d = f16Table[bytes[o] | (bytes[o + 1] << 8)];
    const dmin = f16Table[bytes[o + 2] | (bytes[o + 3] << 8)];
    const sc = o + 4;
    const qh = o + 16; // Q5_K のみ
    const qs = five ? o + 48 : o + 16;
    for (let j = 0; j < 8; j++) {
        const [s, m] = scaleMinK4(bytes, sc, j);
        out.scale[g + j] = f32(d * s);
        out.min[g + j] = f32(dmin * m);
        // 64要素ごとに、下位4bitが前半32要素、上位4bitが後半32要素
        const q = qs + (j >> 1) * 32;
        const hi = j & 1;
        const base = y + j * 32;
        for (let l = 0; l < 32; l++) {
            let c = hi ? bytes[q + l] >> 4 : bytes[q + l] & 0xf;
            if (five && bytes[qh + l] & (1 << j))
                c += 16;
            out.codes[base + l] = c;
        }
    }
}
function decodeBlockQ6_K(bytes, o, out, y, g) {
    const d = f16Table[bytes[o + 208] | (bytes[o + 209] << 8)];
    for (let i = 0; i < 16; i++) {
        const s = bytes[o + 192 + i];
        out.scale[g + i] = f32(d * (s > 127 ? s - 256 : s));
        out.min[g + i] = 0;
    }
    for (let h = 0; h < 2; h++) {
        const ql = o + h * 64;
        const qh = o + 128 + h * 32;
        const yy = y + h * 128;
        for (let l = 0; l < 32; l++) {
            const H = bytes[qh + l];
            out.codes[yy + l] = (bytes[ql + l] & 0xf) | ((H & 3) << 4); // q+32
            out.codes[yy + l + 32] = (bytes[ql + l + 32] & 0xf) | (((H >> 2) & 3) << 4);
            out.codes[yy + l + 64] = (bytes[ql + l] >> 4) | (((H >> 4) & 3) << 4);
            out.codes[yy + l + 96] = (bytes[ql + l + 32] >> 4) | (((H >> 6) & 3) << 4);
        }
    }
}
/** K-quant の生バイト列 → code / scale / min */
export function decodeKQuant(type, bytes, n) {
    const info = KQUANT[type];
    if (!info)
        throw new Error(`not a K-quant type: ${type}`);
    if (n % QK_K !== 0)
        throw new Error("K-quant: n must be a multiple of 256");
    const ng = n / info.group;
    const out = { codes: new Uint8Array(n), scale: new Float32Array(ng), min: new Float32Array(ng) };
    const perBlock = QK_K / info.group;
    for (let b = 0; b < n / QK_K; b++) {
        const o = b * info.bytes, y = b * QK_K, g = b * perBlock;
        switch (type) {
            case GGMLType.Q2_K:
                decodeBlockQ2_K(bytes, o, out, y, g);
                break;
            case GGMLType.Q3_K:
                decodeBlockQ3_K(bytes, o, out, y, g);
                break;
            case GGMLType.Q4_K:
                decodeBlockQ45_K(bytes, o, out, y, g, false);
                break;
            case GGMLType.Q5_K:
                decodeBlockQ45_K(bytes, o, out, y, g, true);
                break;
            case GGMLType.Q6_K:
                decodeBlockQ6_K(bytes, o, out, y, g);
                break;
        }
    }
    return out;
}
export function dequantKQuant(type, bytes, n) {
    const info = KQUANT[type];
    const { codes, scale, min } = decodeKQuant(type, bytes, n);
    const out = new Float32Array(n);
    for (let i = 0; i < n; i++) {
        const g = (i / info.group) | 0;
        out[i] = f32(scale[g] * (codes[i] - info.zero)) - min[g];
    }
    return out;
}
/**
 * GPU用に K-quant を再配置する（全型共通の形。matmul.wgsl の main_kq が読む）
 *   quants: code を bits ビットずつ u32 に詰めたもの（元の並び順）
 *   scales: サブブロックごとの (scale, min) の交互
 */
export function repackKQuant(type, bytes, n) {
    const info = KQUANT[type];
    const { codes, scale, min } = decodeKQuant(type, bytes, n);
    const per = 32 / info.bits;
    const quants = new Uint32Array(n / per);
    for (let w = 0; w < quants.length; w++) {
        let v = 0;
        for (let k = 0; k < per; k++)
            v |= codes[w * per + k] << (info.bits * k);
        quants[w] = v >>> 0;
    }
    const scales = new Float32Array(scale.length * 2);
    for (let i = 0; i < scale.length; i++) {
        scales[2 * i] = scale[i];
        scales[2 * i + 1] = min[i];
    }
    return { quants, scales, info };
}
