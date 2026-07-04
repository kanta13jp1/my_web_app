import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCaptionSrt,
  buildForceStyle,
  burnCaptionsViaTranscoder,
  type BurnCaptionsRequest,
  DEFAULT_CAPTION_STYLE,
  DEFAULT_CAPTION_TIMING,
  extractBurnedVideoUrl,
  formatSrtTimestamp,
} from "./captions.ts";

function timestampToMs(stamp: string): number {
  const [hms, millis] = stamp.split(",");
  const [h, m, s] = hms.split(":").map(Number);
  return ((h * 60 + m) * 60 + s) * 1000 + Number(millis);
}

// SRT を [index, startMs, endMs, text] のブロック配列へパースする最小パーサ。
function parseSrt(
  srt: string,
): Array<{ index: number; start: number; end: number; text: string }> {
  return srt
    .split("\n\n")
    .map((block) => block.trim())
    .filter((block) => block.length > 0)
    .map((block) => {
      const [indexLine, timeLine, ...rest] = block.split("\n");
      const [start, end] = timeLine.split(" --> ");
      return {
        index: Number(indexLine),
        start: timestampToMs(start),
        end: timestampToMs(end),
        text: rest.join("\n"),
      };
    });
}

Deno.test("formatSrtTimestamp formats ms into HH:MM:SS,mmm", () => {
  assertEquals(formatSrtTimestamp(0), "00:00:00,000");
  assertEquals(formatSrtTimestamp(1500), "00:00:01,500");
  assertEquals(formatSrtTimestamp(61_234), "00:01:01,234");
  assertEquals(formatSrtTimestamp(3_661_007), "01:01:01,007");
  // 負値は 0 にクランプする。
  assertEquals(formatSrtTimestamp(-10), "00:00:00,000");
});

Deno.test("buildCaptionSrt emits one contiguous block per non-empty line", () => {
  const srt = buildCaptionSrt(
    "First line here.\nSecond line is a bit longer than first.\n\n  \nThird.",
    "en",
  );
  const blocks = parseSrt(srt);
  assertEquals(blocks.length, 3);
  // 連番で、最初は 0 開始、隣接ブロックは端が接する (start_{i+1} == end_i)。
  assertEquals(blocks.map((b) => b.index), [1, 2, 3]);
  assertEquals(blocks[0].start, 0);
  assertEquals(blocks[1].start, blocks[0].end);
  assertEquals(blocks[2].start, blocks[1].end);
  for (const block of blocks) {
    assert(block.end > block.start, "each caption must have positive duration");
  }
});

Deno.test("buildCaptionSrt allocates duration proportional to char length", () => {
  // クランプに掛からない中程度の長さの2行で、長い行がより長い尺になることを確認。
  const short = "A".repeat(30);
  const long = "B".repeat(60);
  const srt = buildCaptionSrt(`${short}\n${long}`, "en", {
    ...DEFAULT_CAPTION_TIMING,
    minLineSeconds: 0.1,
    maxLineSeconds: 100,
  });
  const [b0, b1] = parseSrt(srt);
  const d0 = b0.end - b0.start;
  const d1 = b1.end - b1.start;
  // 2倍の文字数はおおよそ2倍の尺 (丸め誤差を許容)。
  const ratio = d1 / d0;
  assert(ratio > 1.8 && ratio < 2.2, `expected ~2x, got ${ratio}`);
});

Deno.test("buildCaptionSrt clamps degenerate short/long lines", () => {
  const srt = buildCaptionSrt("hi\n" + "x".repeat(5000), "en", {
    jaCharsPerSecond: 6.5,
    enCharsPerSecond: 15,
    minLineSeconds: 1.2,
    maxLineSeconds: 7,
  });
  const [b0, b1] = parseSrt(srt);
  assertEquals(b0.end - b0.start, 1200); // min floor
  assertEquals(b1.end - b1.start, 7000); // max ceiling
});

Deno.test("buildCaptionSrt returns empty string for blank input", () => {
  assertEquals(buildCaptionSrt("", "ja"), "");
  assertEquals(buildCaptionSrt("   \n \n\t", "en"), "");
});

Deno.test("buildCaptionSrt preserves the spoken text verbatim", () => {
  const line = "AI大学では、最新ニュースとプロンプト活用を学べます。";
  const srt = buildCaptionSrt(line, "ja");
  assertStringIncludes(srt, line);
});

Deno.test("buildForceStyle encodes bottom-center high-contrast stroked style", () => {
  const style = buildForceStyle(DEFAULT_CAPTION_STYLE);
  assertStringIncludes(style, "Alignment=2"); // bottom center
  assertStringIncludes(style, "Outline=3"); // stroke width
  assertStringIncludes(style, "PrimaryColour=&H00FFFFFF"); // white text
  assertStringIncludes(style, "OutlineColour=&H00000000"); // black outline
  assertStringIncludes(style, "Bold=1");
  assertStringIncludes(style, "FontSize=22");
});

Deno.test("extractBurnedVideoUrl reads common response shapes", () => {
  assertEquals(
    extractBurnedVideoUrl({ url: "https://cdn.example.com/out.mp4" }),
    "https://cdn.example.com/out.mp4",
  );
  assertEquals(
    extractBurnedVideoUrl({ video_url: "https://x.test/a.mp4" }),
    "https://x.test/a.mp4",
  );
  assertEquals(
    extractBurnedVideoUrl({ data: { output_url: "https://x.test/b.mp4" } }),
    "https://x.test/b.mp4",
  );
  assertEquals(
    extractBurnedVideoUrl({ result: { video: { url: "https://x.test/c.mp4" } } }),
    "https://x.test/c.mp4",
  );
});

Deno.test("extractBurnedVideoUrl rejects non-http and missing urls", () => {
  assertEquals(extractBurnedVideoUrl({ url: "ftp://x.test/a.mp4" }), null);
  assertEquals(extractBurnedVideoUrl({ url: "not a url" }), null);
  assertEquals(extractBurnedVideoUrl({ status: "queued" }), null);
  assertEquals(extractBurnedVideoUrl(null), null);
  assertEquals(extractBurnedVideoUrl("plain string"), null);
});

const SAMPLE_REQUEST: BurnCaptionsRequest = {
  videoUrl: "https://hedra.test/raw.mp4",
  mp4Url: "https://hedra.test/raw.mp4",
  srt: "1\n00:00:00,000 --> 00:00:01,200\nhi\n",
  subtitleFormat: "srt",
  format: "mp4",
  resolution: "540p",
  style: DEFAULT_CAPTION_STYLE,
  forceStyle: buildForceStyle(DEFAULT_CAPTION_STYLE),
};

Deno.test("burnCaptionsViaTranscoder returns ok with url on 200", async () => {
  let seenAuth: string | null = null;
  const fetchImpl = ((_url: string | URL | Request, init?: RequestInit) => {
    seenAuth =
      new Headers(init?.headers).get("authorization");
    return Promise.resolve(
      new Response(JSON.stringify({ url: "https://cdn.test/captioned.mp4" }), {
        status: 200,
      }),
    );
  }) as typeof fetch;
  const result = await burnCaptionsViaTranscoder({
    endpoint: "https://transcoder.test/burn",
    apiKey: "secret-key",
    timeoutMs: 5000,
    request: SAMPLE_REQUEST,
    fetchImpl,
  });
  assert(result.ok);
  if (result.ok) assertEquals(result.url, "https://cdn.test/captioned.mp4");
  assertEquals(seenAuth, "Bearer secret-key");
});

Deno.test("burnCaptionsViaTranscoder returns not-ok on HTTP error", async () => {
  const fetchImpl = (() =>
    Promise.resolve(
      new Response("boom", { status: 500 }),
    )) as typeof fetch;
  const result = await burnCaptionsViaTranscoder({
    endpoint: "https://transcoder.test/burn",
    timeoutMs: 5000,
    request: SAMPLE_REQUEST,
    fetchImpl,
  });
  assert(!result.ok);
  if (!result.ok) assertStringIncludes(result.reason, "500");
});

Deno.test("burnCaptionsViaTranscoder returns not-ok when url missing", async () => {
  const fetchImpl = (() =>
    Promise.resolve(
      new Response(JSON.stringify({ status: "queued" }), { status: 200 }),
    )) as typeof fetch;
  const result = await burnCaptionsViaTranscoder({
    endpoint: "https://transcoder.test/burn",
    timeoutMs: 5000,
    request: SAMPLE_REQUEST,
    fetchImpl,
  });
  assert(!result.ok);
  if (!result.ok) assertStringIncludes(result.reason, "no video url");
});

Deno.test("burnCaptionsViaTranscoder never throws when fetch rejects", async () => {
  const fetchImpl = (() =>
    Promise.reject(new Error("network down"))) as typeof fetch;
  const result = await burnCaptionsViaTranscoder({
    endpoint: "https://transcoder.test/burn",
    timeoutMs: 5000,
    request: SAMPLE_REQUEST,
    fetchImpl,
  });
  assert(!result.ok);
  if (!result.ok) assertStringIncludes(result.reason, "network down");
});
