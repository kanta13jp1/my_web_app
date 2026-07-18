import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildMediaLiftLine,
  classifyPostMediaType,
  normalizeMediaBucket,
} from "./x_media_type.ts";

Deno.test("normalizeMediaBucket maps MIME, semantic, and legacy values", () => {
  // MIME(旧行 = uploadMediaFromUrl の実 MIME)。
  assertEquals(normalizeMediaBucket("video/mp4"), "video");
  assertEquals(normalizeMediaBucket("image/png"), "image");
  assertEquals(normalizeMediaBucket("image/gif"), "image");
  // 意味値(R13 新規行)。
  assertEquals(normalizeMediaBucket("video"), "video");
  assertEquals(normalizeMediaBucket("image"), "image");
  assertEquals(normalizeMediaBucket("text"), "text");
  // 判定不能・欠損は unknown(過去データを捨てない)。
  assertEquals(normalizeMediaBucket(""), "unknown");
  assertEquals(normalizeMediaBucket("weird"), "unknown");
});

Deno.test("classifyPostMediaType prefers explicit hint, then URL extension", () => {
  // 実 MIME ヒントが最優先。
  assertEquals(classifyPostMediaType("", "video/mp4"), "video");
  assertEquals(classifyPostMediaType("", "image/png"), "image");
  // ヒントが無ければ URL 拡張子(AI 動画経路 = .mp4)。
  assertEquals(
    classifyPostMediaType("https://x/y/site_tour.mp4", ""),
    "video",
  );
  assertEquals(classifyPostMediaType("https://x/y/ogp.png", ""), "image");
  // media が無ければ text。
  assertEquals(classifyPostMediaType("", ""), "text");
  // media 有りだが拡張子不明 → image 既定(動画は常に .mp4)。
  assertEquals(classifyPostMediaType("https://x/y/asset", ""), "image");
});

Deno.test("buildMediaLiftLine is silent until >=2 samples in a bucket", () => {
  const rows = [
    { mediaType: "video/mp4", score: 100 },
    { mediaType: "image/png", score: 40 },
  ];
  // 各バケット n=1 のみ → 沈黙(sample ガード = default-off)。
  assertEquals(
    buildMediaLiftLine(rows, (r) => r.mediaType, (r) => r.score),
    null,
  );
});

Deno.test("buildMediaLiftLine ranks buckets and recommends the winner", () => {
  const rows = [
    { mediaType: "video", score: 120 },
    { mediaType: "video/mp4", score: 100 },
    { mediaType: "image", score: 50 },
    { mediaType: "image/png", score: 30 },
    { mediaType: "text", score: 20 },
    { mediaType: "text", score: 10 },
  ];
  const line = buildMediaLiftLine(rows, (r) => r.mediaType, (r) => r.score);
  assert(line !== null);
  assert(line!.includes("Media lift (by type):"));
  // video 平均 110, image 平均 40, text 平均 15 の順で並ぶ。
  assert(line!.includes("video avg=110 (n=2)"));
  assert(line!.includes("image avg=40 (n=2)"));
  assert(line!.includes("text avg=15 (n=2)"));
  // 比較可能 3 バケット → 勝ちメディア(video)を推奨。
  assert(line!.includes("prefer video media"));
});

Deno.test("buildMediaLiftLine keeps legacy rows in an unknown bucket", () => {
  const rows = [
    { mediaType: "video", score: 100 },
    { mediaType: "video", score: 90 },
    { mediaType: "", score: 5 }, // 旧行 = media_type 欠損
    { mediaType: "weird", score: 5 },
  ];
  const line = buildMediaLiftLine(rows, (r) => r.mediaType, (r) => r.score);
  assert(line !== null);
  // unknown バケットは表示されるが、比較対象からは除外される。
  assert(line!.includes("unknown avg=5 (n=2)"));
  // 比較可能なのは video のみ(1 種)→ 強制せず「サンプル不足」。
  assert(line!.includes("insufficient distinct-media samples"));
});
