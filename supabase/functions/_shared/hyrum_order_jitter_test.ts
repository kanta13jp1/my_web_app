import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function seededShuffle<T>(items: readonly T[], seed: number): T[] {
  const out = [...items];
  let state = seed >>> 0;
  for (let i = out.length - 1; i > 0; i--) {
    state = (state * 1664525 + 1013904223) >>> 0;
    const j = state % (i + 1);
    const tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}

interface RowItem {
  readonly category: string;
  readonly amount: number;
}

function summarizeByCategory(rows: readonly RowItem[]): Record<string, number> {
  const totals: Record<string, number> = {};
  for (const row of rows) {
    totals[row.category] = (totals[row.category] ?? 0) + row.amount;
  }
  const ordered: Record<string, number> = {};
  for (const key of Object.keys(totals).sort()) {
    ordered[key] = totals[key];
  }
  return ordered;
}

Deno.test(
  "summarizeByCategory is invariant under seeded row permutations",
  () => {
    const base: RowItem[] = [
      { category: "food", amount: 1200 },
      { category: "books", amount: 2400 },
      { category: "food", amount: 800 },
      { category: "transit", amount: 540 },
    ];
    const expected = summarizeByCategory(base);

    for (const seed of [11, 29, 47, 83, 131]) {
      const permuted = seededShuffle(base, seed);
      assertEquals(summarizeByCategory(permuted), expected);
    }
  },
);
