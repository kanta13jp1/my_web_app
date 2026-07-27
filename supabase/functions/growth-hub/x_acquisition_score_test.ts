import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildAcquisitionRankingLine,
  computeAcquisitionScore,
  IMPRESSION_CAP,
  IMPRESSION_MAX_POINTS,
  impressionTerm,
} from "./x_acquisition_score.ts";

// 実測サンプル (account_analytics_content 2026-04-27〜2026-07-25)。
// A: 国民民主党 地方議員集計 2026/07/14 — 到達も獲得も 1 位。
const DATA_REPORT = {
  impressions: 122978,
  urlClicks: 66,
  profileClicks: 129,
  likeCount: 12,
  repostCount: 0,
  replyCount: 0,
  bookmarkCount: 0,
};
// B: 女系天皇 — 到達 57K・いいね 2.5K だが URL クリック 0。
const HIGH_ENGAGEMENT_ZERO_CLICK = {
  impressions: 57000,
  urlClicks: 0,
  profileClicks: 0,
  likeCount: 2500,
  repostCount: 575,
  replyCount: 44,
  bookmarkCount: 0,
};
// C: AIコーディングツール定点観測 — 同じ data_report 型だが 176 imp / 0 クリック。
const LOW_REACH_ZERO_CLICK = {
  impressions: 176,
  urlClicks: 0,
  profileClicks: 0,
  likeCount: 0,
  repostCount: 0,
  replyCount: 0,
  bookmarkCount: 0,
};

Deno.test("impressionTerm caps reach so 130K is not 13x more valuable than 10K", () => {
  assertEquals(impressionTerm(0), 0);
  assertEquals(impressionTerm(null), 0);
  assertEquals(impressionTerm(IMPRESSION_CAP), IMPRESSION_MAX_POINTS);
  // キャップ超過は頭打ち。122,978 も 983,216 も満点で同じ。
  assertEquals(impressionTerm(122978), IMPRESSION_MAX_POINTS);
  assertEquals(impressionTerm(983216), IMPRESSION_MAX_POINTS);
  assertEquals(impressionTerm(5000), 50);
});

Deno.test("computeAcquisitionScore puts url clicks above everything else", () => {
  // 1 クリック(=1000) は、いいね 100 件(=200)・リポスト 100 件(=800) より重い。
  const oneClick = computeAcquisitionScore({ urlClicks: 1 });
  assertEquals(oneClick, 1000);
  assert(oneClick > computeAcquisitionScore({ likeCount: 100 }));
  assert(oneClick > computeAcquisitionScore({ repostCount: 100 }));
});

Deno.test("computeAcquisitionScore ranks the measured cohorts click-first", () => {
  const a = computeAcquisitionScore(DATA_REPORT);
  const b = computeAcquisitionScore(HIGH_ENGAGEMENT_ZERO_CLICK);
  const c = computeAcquisitionScore(LOW_REACH_ZERO_CLICK);
  // 66 クリック + 129 プロフィールクリックの実データレポートが最上位。
  assert(a > b, `data report ${a} must outrank zero-click viral ${b}`);
  // 共感は大きいがクリック 0 の投稿でも、到達ゼロの投稿よりは上に残る。
  assert(b > c, `viral ${b} must outrank low-reach zero-click ${c}`);
  assertEquals(a, 66 * 1000 + 129 * 60 + 12 * 2 + 100);
});

Deno.test("computeAcquisitionScore ignores negative and non-finite inputs", () => {
  assertEquals(computeAcquisitionScore({}), 0);
  assertEquals(
    computeAcquisitionScore({ urlClicks: -5, impressions: Number.NaN }),
    0,
  );
});

type Row = {
  acq: number;
  reach: number | null;
  hook: string;
  clicks: number;
};
const line = (rows: Row[]) =>
  buildAcquisitionRankingLine(
    rows,
    (r) => r.acq,
    (r) => r.reach,
    (r) => r.hook,
    (r) => r.clicks,
  );

Deno.test("buildAcquisitionRankingLine stays silent on sparse or click-free data", () => {
  assertEquals(line([]), null);
  assertEquals(line([{ acq: 5, reach: 100, hook: "a", clicks: 1 }]), null);
  // 全件が獲得スコア 0 = 学習材料なし。断定しない。
  assertEquals(
    line([
      { acq: 0, reach: 100, hook: "a", clicks: 0 },
      { acq: 0, reach: 200, hook: "b", clicks: 0 },
    ]),
    null,
  );
});

Deno.test("buildAcquisitionRankingLine warns when reach winner is not the acquisition winner", () => {
  const out = line([
    { acq: 100, reach: 130000, hook: "reach winner", clicks: 0 },
    { acq: 3000, reach: 500, hook: "click winner", clicks: 3 },
  ]);
  assert(out !== null);
  assert(out!.includes('hook="click winner"'));
  assert(out!.includes("Divergence warning"));
  assert(out!.includes("reach without clicks did not put anyone on the site"));
  assert(out!.includes("Click coverage: 1/2"));
});

Deno.test("buildAcquisitionRankingLine omits the warning when both winners agree", () => {
  const out = line([
    { acq: 66100, reach: 122978, hook: "data report", clicks: 66 },
    { acq: 1000, reach: 500, hook: "other", clicks: 1 },
  ]);
  assert(out !== null);
  assert(!out!.includes("Divergence warning"));
  assert(out!.includes("Click coverage: 2/2"));
});
