import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildCaptionSrt,
  buildForceStyle,
  type BurnCaptionsRequest,
  burnCaptionsViaTranscoder,
  DEFAULT_CAPTION_STYLE,
  DEFAULT_CAPTION_TIMING,
  extractBurnedVideoUrl,
  formatSrtTimestamp,
  MAX_ROW_UNITS,
  MAX_ROWS_PER_CUE,
  splitAtSentenceBoundaries,
  wrapCaptionText,
} from "./captions.ts";

Deno.test("splitAtSentenceBoundaries splits after 。？！ outside quotes", () => {
  // 実機観測行: cue が「た。今日の話題は…」と文の途中から始まっていた。
  const line =
    "流れてくるニュースを、判断材料に変えるコツを紹介します。今日の話題は「マイクロン、AI需要で広島工場増強へ」です。";
  const segs = splitAtSentenceBoundaries(line);
  assertEquals(segs.length, 2);
  assertEquals(
    segs[0],
    "流れてくるニュースを、判断材料に変えるコツを紹介します。",
  );
  assertEquals(
    segs[1],
    "今日の話題は「マイクロン、AI需要で広島工場増強へ」です。",
  );
  // 「」内の 、や終端記号では割らない。
  const quoted = "話題は「爆速開発。想定より加速せず？」です！続きへ。";
  const qsegs = splitAtSentenceBoundaries(quoted);
  assertEquals(qsegs.length, 2);
  assertEquals(qsegs[0], "話題は「爆速開発。想定より加速せず？」です！");
  // 終端記号なし・空入力の fail-safe。
  assertEquals(splitAtSentenceBoundaries("終端記号なしの一文"), [
    "終端記号なしの一文",
  ]);
});

Deno.test("buildCaptionSrt cues start at sentence boundaries", () => {
  const line =
    "流れてくるニュースを、判断材料に変えるコツを紹介します。今日の話題は「マイクロン、AI需要で広島工場増強へ」です。";
  const blocks = parseSrt(buildCaptionSrt(line, "ja"));
  // 各 cue の先頭は「文頭」か「同一文の折返し継続」— 前文の断片(た。等)で
  // 始まる cue が存在しないこと = どの cue 先頭も 。？！ 直後の文字ではなく
  // 文境界で区切ったセグメント由来であることを、cue 連結の再構成で検証する。
  const joined = blocks.map((b) => b.text.replaceAll("\n", "")).join("");
  assertEquals(joined, line);
  // 2文に分かれているので、2文目の先頭「今日の話題は」で始まる cue が存在する。
  assert(
    blocks.some((b) => b.text.replaceAll("\n", "").startsWith("今日の話題は")),
    "second sentence must start its own cue",
  );
  // どの cue も「た。」のような前文断片で始まらない。
  for (const b of blocks) {
    const head = Array.from(b.text)[0];
    assert(
      !"。？！、".includes(head),
      `cue starts with dangling punctuation: ${b.text}`,
    );
  }
  // 行合計尺は従来どおり文字数比(トリム差は最終 cue が吸収)。
  const total = blocks.reduce((sum, b) => sum + (b.end - b.start), 0);
  const expected = Math.round(
    (Array.from(line).length / DEFAULT_CAPTION_TIMING.jaCharsPerSecond) * 1000,
  );
  assertEquals(total, expected);
});

// 重み付き幅(全角=1.0 / ASCII・半角カナ=0.5)をテスト側でも再現する。
function rowUnits(row: string): number {
  return Array.from(row).reduce((sum, ch) => {
    const cp = ch.codePointAt(0) ?? 0;
    return sum + (cp <= 0xff || (cp >= 0xff61 && cp <= 0xff9f) ? 0.5 : 1);
  }, 0);
}

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

Deno.test("buildCaptionSrt floors short lines but no longer caps long ones", () => {
  const srt = buildCaptionSrt("hi\n" + "x".repeat(600), "en", {
    jaCharsPerSecond: 6.5,
    enCharsPerSecond: 15,
    minLineSeconds: 1.2,
    maxLineSeconds: 7,
  });
  const blocks = parseSrt(srt);
  // 短行は従来どおり minLineSeconds を床とする。
  assertEquals(blocks[0].end - blocks[0].start, 1200);
  // 長行は複数 cue に分割され、行合計は文字数比 (600/15=40s) を保つ。
  // 旧実装の 7 秒天井は比例配分を歪めるため廃止(cue 単体は分割で十分短い)。
  const longTotal = blocks.slice(1)
    .reduce((sum, b) => sum + (b.end - b.start), 0);
  assertEquals(longTotal, 40000);
  assert(blocks.length > 2, "long line must split into multiple cues");
  for (const b of blocks) {
    assert(
      b.text.split("\n").length <= MAX_ROWS_PER_CUE,
      "every cue renders at most 2 rows",
    );
  }
});

Deno.test("buildCaptionSrt returns empty string for blank input", () => {
  assertEquals(buildCaptionSrt("", "ja"), "");
  assertEquals(buildCaptionSrt("   \n \n\t", "en"), "");
});

Deno.test("buildCaptionSrt preserves the spoken text (modulo row breaks)", () => {
  const line = "AI大学では、最新ニュースとプロンプト活用を学べます。";
  const srt = buildCaptionSrt(line, "ja");
  // 折返しで \n が入るため、改行を除去した連結が原文と一致することを確認。
  const blocks = parseSrt(srt);
  const joined = blocks.map((b) => b.text.replaceAll("\n", "")).join("");
  assertEquals(joined, line);
});

Deno.test("wrapCaptionText keeps every row within the width budget", () => {
  const line =
    "流れてくるニュースを、判断材料に変えるコツを紹介します。今日の話題は「Meta、AIで『爆速開発』のはずが『想定より加速せず』」です。";
  const rows = wrapCaptionText(line);
  assert(rows.length >= 4, "70+ char ja line must wrap into several rows");
  for (const row of rows) {
    assert(
      rowUnits(row) <= MAX_ROW_UNITS + 0.5,
      `row exceeds width budget: ${row} (${rowUnits(row)})`,
    );
  }
  // 連結すると原文に戻る(文字は一切失われない)。
  assertEquals(rows.join(""), line.trim());
  // 行頭禁則: 句読点・閉じ括弧などで行が始まらない(ベストエフォート)。
  for (const row of rows.slice(1)) {
    assert(
      !"、。ー」』）".includes(Array.from(row)[0]),
      `row starts with kinsoku char: ${row}`,
    );
  }
});

Deno.test("wrapCaptionText prefers breaking after punctuation near the edge", () => {
  // 実機観測:「不正プログラム自|作」の語中割れ。行末近く(6文字以内)に読点が
  // あればそこで折り、語のまとまりを保つ。
  const line =
    "Nintendo Switch 2、不正プログラム自作の疑いで再逮捕されたと報道";
  const rows = wrapCaptionText(line);
  for (const row of rows) {
    assert(
      rowUnits(row) <= MAX_ROW_UNITS + 0.5,
      `row exceeds width budget: ${row}`,
    );
    // 「不正プログラム自作」という語が行境界で分断されない。
    assert(
      !row.endsWith("自") || row.endsWith("自作"),
      `word split mid-token: ${row}`,
    );
  }
  assertEquals(rows.join(""), line.trim());
});

Deno.test("wrapCaptionText keeps a kanji compound intact across a row break", () => {
  // 実機観測(2026-07-07 投稿):「後で使える判断材|料」で漢字熟語 判断材料 が
  // 行境界(=cue境界)で語中割れした。句読点が無い連なりでも、書記素クラス境界
  // (仮名↔漢字)や助詞の直後へ戻して折り、熟語を割らないこと。
  const line =
    "こうした話題も、AI仕事OSに残しておけば、後で使える判断材料になります。";
  const rows = wrapCaptionText(line);
  for (const row of rows) {
    assert(
      rowUnits(row) <= MAX_ROW_UNITS + 0.5,
      `row exceeds width budget: ${row}`,
    );
    // 「判断材料」が 判断材|料 のように分断されない(行末が熟語の途中で終わらない)。
    for (const frag of ["判断材", "判断", "材"]) {
      assert(
        !(row.endsWith(frag) && !row.endsWith("判断材料")),
        `kanji compound split mid-token: ${row}`,
      );
    }
  }
  assertEquals(rows.join(""), line.trim());
});

Deno.test("wrapCaptionText does not split ASCII words or surrogate pairs", () => {
  const en = "Practical productivity insights for developers everywhere today";
  for (const row of wrapCaptionText(en)) {
    assert(rowUnits(row) <= MAX_ROW_UNITS + 0.5);
  }
  // 単語の途中で割れていない: 境界の空白は落ちるので、空白1つで連結し直すと
  // 原文と一致する(=どの単語も分断されていない)ことを検証する。
  const rows = wrapCaptionText(en);
  assert(rows.length >= 2, "long en line must wrap");
  assertEquals(rows.join(" "), en);
  // サロゲートペア(絵文字)は割れず、例外も投げない。
  const emoji = "🚀".repeat(20);
  const emojiRows = wrapCaptionText(emoji);
  assertEquals(emojiRows.join(""), emoji);
  for (const row of emojiRows) {
    assert(!row.includes("�"), "no broken surrogate halves");
  }
});

Deno.test("buildCaptionSrt merges a tiny tail cue when width allows", () => {
  // 30 全角 = 14+14+2 行 → 末尾 2 文字( <1.2s 相当)は前 cue の最終行(2文字)…
  // ではなく幅上限を超えない場合のみ併合される。ここでは 16 文字 + 14 文字の
  // 2 行に収まるケースで、cue 数が減ることを確認する。
  const line = "あ".repeat(15); // 14 + 1 → tail 1 文字は前行(14)に足すと 15 > 14 で不可
  const srt15 = buildCaptionSrt(line, "ja");
  const blocks15 = parseSrt(srt15);
  // 幅が許さないので tail cue は残る(2 cue) — かつ各行は幅上限以内。
  for (const b of blocks15) {
    for (const row of b.text.split("\n")) {
      assert(rowUnits(row) <= MAX_ROW_UNITS + 0.5);
    }
  }
  // 450 字の最悪ケースでも全 cue が 2 行以内・連番・連続タイムスタンプ。
  const worst =
    ("今日の注目トピックを、AI仕事OS開発者の視点でまとめました。".repeat(10))
      .slice(0, 450);
  const blocks = parseSrt(buildCaptionSrt(worst, "ja"));
  let prevEnd = 0;
  blocks.forEach((b, i) => {
    assertEquals(b.index, i + 1);
    assertEquals(b.start, prevEnd);
    prevEnd = b.end;
    assert(b.text.split("\n").length <= MAX_ROWS_PER_CUE);
  });
});

Deno.test("buildForceStyle encodes bottom-center high-contrast stroked style", () => {
  const style = buildForceStyle(DEFAULT_CAPTION_STYLE);
  assertStringIncludes(style, "Alignment=2"); // bottom center
  assertStringIncludes(style, "Outline=3"); // stroke width
  assertStringIncludes(style, "PrimaryColour=&H00FFFFFF"); // white text
  assertStringIncludes(style, "OutlineColour=&H00000000"); // black outline
  assertStringIncludes(style, "Bold=1");
  assertStringIncludes(style, "FontSize=20");
  // 折返し幅を拘束する左右マージン(PlayRes 単位 / 960w で ~75px per side)。
  assertStringIncludes(style, "MarginL=30");
  assertStringIncludes(style, "MarginR=30");
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
    extractBurnedVideoUrl({
      result: { video: { url: "https://x.test/c.mp4" } },
    }),
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
  stretchToVideo: true,
  leadInMs: 0,
  tailPadMs: 300,
};

Deno.test("burnCaptionsViaTranscoder returns ok with url on 200", async () => {
  let seenAuth: string | null = null;
  const fetchImpl = ((_url: string | URL | Request, init?: RequestInit) => {
    seenAuth = new Headers(init?.headers).get("authorization");
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
  const fetchImpl =
    (() => Promise.reject(new Error("network down"))) as typeof fetch;
  const result = await burnCaptionsViaTranscoder({
    endpoint: "https://transcoder.test/burn",
    timeoutMs: 5000,
    request: SAMPLE_REQUEST,
    fetchImpl,
  });
  assert(!result.ok);
  if (!result.ok) assertStringIncludes(result.reason, "network down");
});
