// プレフィックスKVキャッシュのスロット管理（CPU側）。
// 因果アテンションでは先頭Lトークンの K/V はその L トークンだけで決まるので、
// 共通の接頭辞を持つ系列どうしは、その部分の K/V をそのまま使い回せる。
//
// 使い回しの元は2種類:
//  1. リクエストをまたぐキャッシュ: 過去に計算した系列の K/V を GPU のプールに保持（エントリ = 連続スロット）
//     空きがなければ LRU で追い出す（同じforwardで参照中のエントリは追い出さない）
//  2. 同じバッチ内の共有: 同じ state に複数の質問を投げたときなど、バッチ内の別の系列が今まさに計算する
//     接頭辞の K/V を参照する（各層で K/V はアテンションより先に全トークン分計算されるので参照できる）
// どちらの場合も、最大 len-1 トークンまで再利用する（最後の1トークンは必ず計算）。
export class PrefixKVCache {
    capacity;
    entries = [];
    clock = 0;
    stats = { lookups: 0, hits: 0, batchShared: 0, reusedTokens: 0, computedTokens: 0, evictions: 0 };
    constructor(capacity) {
        this.capacity = capacity;
    }
    clear() {
        this.entries = [];
    }
    lcp(a, b) {
        const n = Math.min(a.length, b.length);
        let i = 0;
        while (i < n && a[i] === b[i])
            i++;
        return i;
    }
    /**
     * 1バッチ分の計画を立てる。
     * useCache=false ならリクエストをまたぐキャッシュは使わない（バッチ内共有は行う）。
     */
    plan(seqs, useCache = true) {
        const tick = ++this.clock;
        const pinned = new Set();
        const plans = [];
        for (let si = 0; si < seqs.length; si++) {
            const seq = seqs[si];
            this.stats.lookups++;
            // 1. キャッシュ
            let best = null;
            let bestL = 0;
            if (useCache) {
                for (const e of this.entries) {
                    if (e.created === tick)
                        continue; // 同じバッチで作ったエントリはバッチ内共有で扱う
                    const l = this.lcp(seq, e.tokens);
                    if (l > bestL) {
                        bestL = l;
                        best = e;
                    }
                }
            }
            // 2. バッチ内の先行系列（接頭辞を自分で全部計算するもの）
            let src = -1;
            let srcL = 0;
            for (let p = 0; p < si; p++) {
                if (plans[p].reuse !== 0)
                    continue;
                const l = this.lcp(seq, seqs[p]);
                if (l > srcL) {
                    srcL = l;
                    src = p;
                }
            }
            if (src >= 0 && srcL > bestL) {
                const reuse = Math.min(srcL, seq.length - 1);
                this.stats.batchShared++;
                this.stats.reusedTokens += reuse;
                this.stats.computedTokens += seq.length - reuse;
                // バッチ内共有した系列はキャッシュに保存しない（接頭辞の K/V が別の系列の行にあるため）
                plans.push({ reuse, prefOff: 0, srcSeq: src, store: null, copyFrom: -1 });
                continue;
            }
            const reuse = Math.min(bestL, seq.length - 1);
            if (best && reuse > 0) {
                best.lastUsed = tick;
                pinned.add(best);
                this.stats.hits++;
            }
            this.stats.reusedTokens += reuse;
            this.stats.computedTokens += seq.length - reuse;
            // 同一系列が既にあれば保存しない
            const exists = best !== null && bestL === seq.length && best.len === seq.length;
            let store = null;
            if (!exists && seq.length <= this.capacity) {
                const start = this.allocate(seq.length, pinned);
                if (start >= 0) {
                    store = { tokens: seq.slice(), start, len: seq.length, lastUsed: tick, created: tick };
                    this.entries.push(store);
                    pinned.add(store);
                }
            }
            plans.push({
                reuse,
                prefOff: reuse > 0 ? best.start : 0,
                srcSeq: -1,
                store,
                copyFrom: store && reuse > 0 ? best.start : -1,
            });
        }
        return plans;
    }
    /** 連続 len スロットを確保（first-fit、足りなければLRU追い出し）。失敗時 -1 */
    allocate(len, pinned) {
        for (;;) {
            const sorted = [...this.entries].sort((a, b) => a.start - b.start);
            let cur = 0;
            for (const e of sorted) {
                if (e.start - cur >= len)
                    return cur;
                cur = e.start + e.len;
            }
            if (this.capacity - cur >= len)
                return cur;
            const victims = this.entries.filter((e) => !pinned.has(e)).sort((a, b) => a.lastUsed - b.lastUsed);
            if (victims.length === 0)
                return -1;
            this.entries.splice(this.entries.indexOf(victims[0]), 1);
            this.stats.evictions++;
        }
    }
}
