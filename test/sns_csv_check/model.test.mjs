import { test } from "node:test";
import assert from "node:assert/strict";
import {
  evaluateArticleCsv,
  evaluateXAnalyticsCsv,
  roundHalfUpPercent4,
  runTwelveCaseSelfCheck,
} from "../../web/labs/sns-csv-check/model.mjs";

test("runTwelveCaseSelfCheck passes all 12 article cases", () => {
  const report = runTwelveCaseSelfCheck();
  assert.equal(report.total, 12);
  assert.equal(report.passed, 12, JSON.stringify(report.results, null, 2));
  assert.equal(report.failed, 0);
});

test("weighted rate differs from simple mean and preserves ROUND_HALF_UP", () => {
  const weighted = evaluateArticleCsv(
    "post_id,views,likes,reposts,replies,bookmarks\na,100,10,0,0,0\nb,900,0,0,0,0",
  );
  assert.equal(weighted.weightedRate, "1.0000");
  assert.equal(weighted.simpleMeanRate, "5.0000");
  assert.equal(roundHalfUpPercent4(1n, 2000000n), "0.0001");
});

test("article mode strips BOM and blank rows before column count check", () => {
  const res = evaluateArticleCsv(
    '\uFEFFlikes,"post_id",note,views,reposts,replies,bookmarks\r\n10,"a","x,y",100,0,0,0\r\n\r\n',
  );
  assert.equal(res.bomStripped, true);
  assert.equal(res.blankRowsSkipped, 1);
  assert.equal(res.posts, 1);
  assert.equal(res.weightedRate, "10.0000");
});

test("article mode rejects fullwidth digits, negative numbers, duplicate IDs and headers", () => {
  assert.throws(
    () => evaluateArticleCsv("post_id,views,likes,reposts,replies,bookmarks\na,１００,10,0,0,0"),
    /全角数字/,
  );
  assert.throws(
    () => evaluateArticleCsv("post_id,views,likes,reposts,replies,bookmarks\na,100,-1,0,0,0"),
    /負数/,
  );
  assert.throws(
    () => evaluateArticleCsv("post_id,views,likes,reposts,replies,bookmarks\na,100,1,0,0,0\n a ,100,1,0,0,0"),
    /重複/,
  );
  assert.throws(
    () => evaluateArticleCsv("post_id,views,views,likes,reposts,replies,bookmarks\na,100,200,1,0,0,0"),
    /重複/,
  );
});

test("evaluateXAnalyticsCsv emits diagnostics for duplicate id, fullwidth, negative, duplicate header", () => {
  const csv = [
    '\uFEFFPost id,Date,Post text,Impressions,Likes,Reposts,Replies,Bookmarks,URL Clicks,Impressions',
    '2074000000000000001,"Tue, Jul 14, 2026",A,100,5,1,0,0,2,999',
    "",
    ' 2074000000000000001 ,"Tue, Jul 14, 2026",Dup,100,5,1,0,0,2,999',
    '2074000000000000002,"Wed, Jul 15, 2026",FW,１００,2,0,0,0,1,0',
    '2074000000000000003,"Thu, Jul 16, 2026",Neg,200,-1,0,0,0,0,0',
  ].join("\n");
  const res = evaluateXAnalyticsCsv(csv);
  assert.equal(res.bomStripped, true);
  assert.equal(res.posts, 3);
  assert.equal(res.duplicatePostIdsSkipped, 1);
  assert.deepEqual(res.duplicateHeadersIgnored, ["impressions"]);
  assert.equal(res.invalidNumericCells, 2);
  assert.equal(res.totalImpressions, "300");
  assert.equal(res.totalUrlClicks, "3");
  assert.ok(res.issues.some((i) => i.code === "duplicate_header"));
  assert.ok(res.issues.some((i) => i.code === "duplicate_post_id"));
  assert.ok(res.issues.some((i) => i.code === "non_ascii_digit"));
  assert.ok(res.issues.some((i) => i.code === "negative_numeric"));
});
