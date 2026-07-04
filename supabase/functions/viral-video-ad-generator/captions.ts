// viral-video-ad-generator: on-screen caption burn-in helpers.
//
// なぜ必要か (H3 / impression audit):
//   X の muted-autoplay 視聴者は音声なしで動画を見るため、字幕が無いと内容が
//   伝わらず即スクロールされる。dwell time はリーチの主要シグナルなので、生成済み
//   presenter 動画へオンスクリーン字幕を焼き込むと視聴維持が伸びる。
//
// 設計:
//   - 読み上げ台本 (TTS に渡した spokenScript) は既知なので ASR/whisper は使わない。
//   - 各行に「文字数比 × 言語別の推定発話レート」で尺を割り当てて SRT を生成する
//     (= 既知の音声長を行ごとに比例配分)。muted 視聴では厳密同期より字幕の存在が重要。
//   - Deno Edge Function は ffmpeg をプロセス内実行できないため、焼き込みは外部の
//     ホスト型 ffmpeg トランスコーダ (Cloud Run / fal.ai ffmpeg-api 等) へ委譲する。
//   - スタイル (下中央・大きめ・高コントラスト・stroke・~540p) は本モジュールで決めて
//     force_style として送るので、見た目の決定はこの PR に閉じる。
//
// 呼び出し側 (index.ts) は VVAG_BURN_CAPTIONS フラグと transcoder URL/KEY が揃った
// ときだけ本経路を使い、あらゆる失敗で素の mp4 へフォールバックする
// (= 既存 fallback_text と同じ graceful-degradation で投稿を絶対にブロックしない)。

export type CaptionLang = "ja" | "en";

export interface CaptionTimingConfig {
  /** 日本語 TTS の推定発話レート (文字/秒)。SRT の行尺推定に使う。 */
  jaCharsPerSecond: number;
  /** 英語 TTS の推定発話レート (文字/秒)。 */
  enCharsPerSecond: number;
  /** 1 字幕あたりの最短表示秒 (点滅防止のガード)。 */
  minLineSeconds: number;
  /** 1 字幕あたりの最長表示秒 (長文が居座り過ぎるのを防ぐガード)。 */
  maxLineSeconds: number;
}

export const DEFAULT_CAPTION_TIMING: CaptionTimingConfig = {
  jaCharsPerSecond: 6.5,
  enCharsPerSecond: 15,
  minLineSeconds: 1.2,
  maxLineSeconds: 7,
};

/** SRT の `HH:MM:SS,mmm` タイムスタンプへ整形する。 */
export function formatSrtTimestamp(ms: number): string {
  const clamped = Math.max(0, Math.round(ms));
  const totalSeconds = Math.floor(clamped / 1000);
  const millis = clamped % 1000;
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const pad = (value: number, width = 2) => String(value).padStart(width, "0");
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)},${pad(millis, 3)}`;
}

/**
 * 読み上げ台本から SRT を生成する。行ごとに `文字数 / 発話レート` 秒を割り当てる
 * (= 推定音声長 `総文字数 / 発話レート` を文字数比で比例配分したのと等価)。
 * 各行は [minLineSeconds, maxLineSeconds] にクランプして極端な尺を避ける。
 * 台本が空なら空文字列を返す (呼び出し側は焼き込みをスキップする)。
 */
export function buildCaptionSrt(
  spokenText: string,
  lang: CaptionLang,
  timing: CaptionTimingConfig = DEFAULT_CAPTION_TIMING,
): string {
  const lines = spokenText
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  if (lines.length === 0) return "";

  const charsPerSecond = lang === "ja"
    ? timing.jaCharsPerSecond
    : timing.enCharsPerSecond;
  const safeCps = Number.isFinite(charsPerSecond) && charsPerSecond > 0
    ? charsPerSecond
    : DEFAULT_CAPTION_TIMING.enCharsPerSecond;

  let cursorMs = 0;
  const blocks: string[] = [];
  lines.forEach((line, index) => {
    const rawSeconds = line.length / safeCps;
    const durationSeconds = Math.min(
      timing.maxLineSeconds,
      Math.max(timing.minLineSeconds, rawSeconds),
    );
    const startMs = cursorMs;
    const endMs = startMs + Math.round(durationSeconds * 1000);
    cursorMs = endMs;
    blocks.push(
      `${index + 1}\n${formatSrtTimestamp(startMs)} --> ${
        formatSrtTimestamp(endMs)
      }\n${line}`,
    );
  });
  return blocks.join("\n\n") + "\n";
}

export interface CaptionStyle {
  /** CJK グリフを含むフォント名。実際の可用性はトランスコーダ側の fontconfig 次第。 */
  fontName: string;
  /** ~540p 想定のフォントサイズ (px)。 */
  fontSizePx: number;
  /** 本文色 (ASS の &HAABBGGRR)。既定は白。 */
  primaryColour: string;
  /** 縁取り色。既定は黒。 */
  outlineColour: string;
  /** 縁取り (stroke) の太さ。 */
  outline: number;
  /** 影の太さ。 */
  shadow: number;
  /** ASS Alignment。2 = 下中央。 */
  alignment: number;
  /** 下端からの余白 (px)。 */
  marginV: number;
}

// 下中央・白文字・黒 stroke・影付きの高コントラスト字幕。~540p 短尺向け。
export const DEFAULT_CAPTION_STYLE: CaptionStyle = {
  fontName: "Noto Sans CJK JP",
  fontSizePx: 22,
  primaryColour: "&H00FFFFFF",
  outlineColour: "&H00000000",
  outline: 3,
  shadow: 1,
  alignment: 2,
  marginV: 40,
};

/**
 * ffmpeg の `subtitles=...:force_style='<...>'` にそのまま渡せる force_style 文字列。
 * トランスコーダは style オブジェクトか、この完成済み文字列のどちらでも使える。
 */
export function buildForceStyle(style: CaptionStyle): string {
  return [
    `FontName=${style.fontName}`,
    `FontSize=${style.fontSizePx}`,
    `PrimaryColour=${style.primaryColour}`,
    `OutlineColour=${style.outlineColour}`,
    "BorderStyle=1",
    `Outline=${style.outline}`,
    `Shadow=${style.shadow}`,
    "Bold=1",
    `Alignment=${style.alignment}`,
    `MarginV=${style.marginV}`,
  ].join(",");
}

export interface BurnCaptionsRequest {
  /** 焼き込み対象の mp4 (Hedra 生成 URL)。 */
  videoUrl: string;
  /** 互換用エイリアス (サービスによっては mp4Url を期待する)。 */
  mp4Url: string;
  /** SRT 本文。 */
  srt: string;
  subtitleFormat: "srt";
  format: "mp4";
  resolution: string;
  style: CaptionStyle;
  forceStyle: string;
}

export type BurnResult =
  | { ok: true; url: string }
  | { ok: false; reason: string };

/** 焼き込み済み動画 URL を返しうるレスポンス形のいずれからも URL を取り出す。 */
export function extractBurnedVideoUrl(payload: unknown): string | null {
  const visit = (value: unknown, depth: number): string | null => {
    if (depth > 4 || value == null) return null;
    if (typeof value === "string") {
      const trimmed = value.trim();
      return isHttpUrl(trimmed) ? trimmed : null;
    }
    if (typeof value !== "object") return null;
    const record = value as Record<string, unknown>;
    const preferredKeys = [
      "url",
      "videoUrl",
      "video_url",
      "outputUrl",
      "output_url",
      "downloadUrl",
      "download_url",
      "result",
      "output",
      "data",
      "video",
    ];
    for (const key of preferredKeys) {
      if (key in record) {
        const found = visit(record[key], depth + 1);
        if (found) return found;
      }
    }
    return null;
  };
  return visit(payload, 0);
}

function isHttpUrl(value: string): boolean {
  if (!value || value.length > 2083) return false;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" || parsed.protocol === "http:";
  } catch {
    return false;
  }
}

/**
 * ホスト型 ffmpeg トランスコーダへ {videoUrl, srt, style} を POST し、焼き込み済み
 * mp4 の URL を得る。HTTP エラー・タイムアウト・URL 欠落は例外にせず
 * `{ ok: false, reason }` で返し、呼び出し側が素の mp4 へフォールバックできるようにする。
 * タイムアウトは AbortController で必ず設定する (このEFの既知の fetch-timeout 脆弱性対策)。
 */
export async function burnCaptionsViaTranscoder(params: {
  endpoint: string;
  apiKey?: string | null;
  request: BurnCaptionsRequest;
  timeoutMs: number;
  fetchImpl?: typeof fetch;
}): Promise<BurnResult> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), params.timeoutMs);
  try {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };
    const apiKey = params.apiKey?.trim();
    if (apiKey) {
      // サービスの認証方式に依存しないよう両ヘッダを送る (どちらか一方が一致すれば良い)。
      headers["Authorization"] = `Bearer ${apiKey}`;
      headers["x-api-key"] = apiKey;
    }
    const doFetch = params.fetchImpl ?? fetch;
    const response = await doFetch(params.endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(params.request),
      signal: controller.signal,
    });
    const rawText = await response.text();
    if (!response.ok) {
      return {
        ok: false,
        reason: `transcoder ${response.status}: ${rawText.slice(0, 200)}`,
      };
    }
    let parsed: unknown = {};
    if (rawText.trim().length > 0) {
      try {
        parsed = JSON.parse(rawText) as unknown;
      } catch {
        parsed = rawText;
      }
    }
    const url = extractBurnedVideoUrl(parsed);
    if (!url) {
      return {
        ok: false,
        reason: `transcoder response had no video url: ${rawText.slice(0, 200)}`,
      };
    }
    return { ok: true, url };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const reason = controller.signal.aborted
      ? `transcoder timed out after ${params.timeoutMs}ms`
      : message;
    return { ok: false, reason: reason.slice(0, 300) };
  } finally {
    clearTimeout(timer);
  }
}
