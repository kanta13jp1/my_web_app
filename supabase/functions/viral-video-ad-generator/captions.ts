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
  // 実測の ElevenLabs 日本語話速は ~7.5-9 文字/秒。8.0 でリスケール前の推定
  // 誤差を最小化する(最終同期はトランスコーダの実測動画長リスケールが担う)。
  jaCharsPerSecond: 8.0,
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

// --- 行折返し (overflow fix) ------------------------------------------------
// 実機で字幕がフレーム横幅からはみ出た(libass の自動折返しに任せると行幅が
// 出力解像度を超えて見切れる)。折返しは自前で決定的に行う。
// 幾何: scale=-2:540 の 16:9 出力 = 960x540。SRT→ASS の libass 既定 PlayRes は
// 384x288 → フォント倍率 540/288=1.875。FontSize 20 → 全角 ~37.5px。
// MarginL/R 30(PlayRes 単位)=75px/側 → 実効幅 810px。14 全角 ≈ 525px で余裕。

/** 1 行の最大幅(重み付き単位)。全角=1.0 / ASCII・半角カナ=0.5 (英語 ~28字)。 */
export const MAX_ROW_UNITS = 14;
/** 1 字幕(cue)の最大行数。下部中央で高く積まない。 */
export const MAX_ROWS_PER_CUE = 2;

// 行頭禁則(行の先頭に来てはならない)と行末禁則(行の末尾に置けない開き括弧)。
const KINSOKU_NO_START =
  "、。，．・：；？！ー〜…」』）】〕｝〉》’”ゝゞ々ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮんン";
const KINSOKU_NO_END = "「『（【〔｛〈《‘“";

function charUnits(ch: string): number {
  const cp = ch.codePointAt(0) ?? 0;
  // ASCII と半角カナは 0.5、それ以外(CJK 等)は 1.0 として幅を見積もる。
  return cp <= 0xff || (cp >= 0xff61 && cp <= 0xff9f) ? 0.5 : 1;
}

function isAsciiWordChar(ch: string): boolean {
  return /[A-Za-z0-9]/.test(ch);
}

/**
 * 字幕テキストを最大 [maxUnitsPerRow] 幅の行へ折り返す。コードポイント単位で
 * 走査するのでサロゲートペア(絵文字)は割れない。禁則(行頭/行末)と ASCII 単語
 * 分断の回避は最大3文字のバックトラックによるベストエフォートで、行幅の上限が
 * 不変条件。失敗時は入力をそのまま1行で返す(呼び出し側の fail-safe を維持)。
 */
export function wrapCaptionText(
  text: string,
  maxUnitsPerRow: number = MAX_ROW_UNITS,
): string[] {
  try {
    const chars = Array.from(text.trim());
    if (chars.length === 0) return [];
    const rows: string[] = [];
    let row: string[] = [];
    let units = 0;
    for (const ch of chars) {
      const u = charUnits(ch);
      if (row.length > 0 && units + u > maxUnitsPerRow) {
        let carry: string[] = [];
        const last = row[row.length - 1];
        if (isAsciiWordChar(last) && isAsciiWordChar(ch)) {
          // ASCII 単語の途中では折らない: 行内の最後の非単語文字(空白等)まで
          // 戻って折る。1 単語が行より長い場合のみハードブレーク。
          let cut = -1;
          for (let i = row.length - 1; i >= 0; i -= 1) {
            if (!isAsciiWordChar(row[i])) {
              cut = i + 1;
              break;
            }
          }
          if (cut > 0) {
            carry = row.slice(cut);
            row = row.slice(0, cut);
            // 行末の空白は描画不要なので落とす。
            while (row.length > 0 && row[row.length - 1] === " ") row.pop();
          }
        } else if (
          KINSOKU_NO_START.includes(ch) || KINSOKU_NO_END.includes(last)
        ) {
          // 禁則(行頭に句読点/閉じ括弧・行末に開き括弧)は最大 3 文字戻して
          // 回避するベストエフォート。幅上限が不変条件で、禁則は妥協可。
          for (let back = 1; back <= 3 && row.length - back > 0; back += 1) {
            const cut = row.length - back;
            const cutLast = row[cut - 1];
            const cutNext = row[cut];
            const compliant = !KINSOKU_NO_START.includes(cutNext) &&
              !KINSOKU_NO_END.includes(cutLast) &&
              !(isAsciiWordChar(cutLast) && isAsciiWordChar(cutNext));
            if (compliant) {
              carry = row.slice(cut);
              row = row.slice(0, cut);
              break;
            }
          }
        } else {
          // 実機観測:「不正プログラム自|作」のように語の途中で行が割れると
          // 読みにくい。行末から 6 文字以内に読点/中黒/閉じ括弧等の「好ましい
          // 折返し点」があればそこまで戻して折る(残り幅 >= 8 units のときのみ。
          // 見つからなければ従来どおり幅上限で折る = 幅不変条件は維持)。
          const preferredBreaks = "、。・！？：…」』）";
          for (let back = 1; back <= 6 && row.length - back > 0; back += 1) {
            const cut = row.length - back;
            const cutLast = row[cut - 1];
            const cutNext = row[cut];
            if (!preferredBreaks.includes(cutLast)) continue;
            const remainingUnits = row
              .slice(0, cut)
              .reduce((sum, c) => sum + charUnits(c), 0);
            const compliant = remainingUnits >= 8 &&
              !KINSOKU_NO_START.includes(cutNext) &&
              !KINSOKU_NO_END.includes(cutLast) &&
              !(isAsciiWordChar(cutLast) && isAsciiWordChar(cutNext));
            if (compliant) {
              carry = row.slice(cut);
              row = row.slice(0, cut);
              break;
            }
          }
        }
        rows.push(row.join(""));
        row = [...carry, ch];
        // 次行頭の空白も落とす(英語の折返し位置直後)。
        while (row.length > 0 && row[0] === " ") row.shift();
        units = row.reduce((sum, c) => sum + charUnits(c), 0);
      } else {
        row.push(ch);
        units += u;
      }
    }
    if (row.length > 0) rows.push(row.join(""));
    return rows.length > 0 ? rows : [text];
  } catch (_error) {
    return [text];
  }
}

/**
 * 台本行を文境界(。？！ の直後)で分割する。cue が文の途中(実機観測:
 * 「た。今日の話題は…」)から始まらないようにするための前処理。
 * 「」『』（） 内の終端記号では分割しない(引用ニュースタイトルを割らない)。
 * 失敗時は [line] を返す fail-safe(wrapCaptionText と同型)。
 */
export function splitAtSentenceBoundaries(line: string): string[] {
  try {
    const openers = "「『（";
    const closers = "」』）";
    const enders = "。？！";
    const segments: string[] = [];
    let current = "";
    let depth = 0;
    for (const ch of Array.from(line)) {
      current += ch;
      if (openers.includes(ch)) depth += 1;
      else if (closers.includes(ch)) depth = Math.max(0, depth - 1);
      else if (depth === 0 && enders.includes(ch)) {
        segments.push(current);
        current = "";
      }
    }
    if (current.trim().length > 0) segments.push(current);
    const cleaned = segments
      .map((seg) => seg.trim())
      .filter((seg) => seg.length > 0);
    return cleaned.length > 0 ? cleaned : [line];
  } catch (_error) {
    return [line];
  }
}

/**
 * 読み上げ台本から SRT を生成する。各行を [wrapCaptionText] で折り返し、
 * 最大 [MAX_ROWS_PER_CUE] 行ずつの cue に分割。行の尺は `文字数 / 発話レート`
 * を cue の文字数比で比例配分する(単一 cue の行のみ minLineSeconds を床とし、
 * maxLineSeconds の天井は廃止 — 分割後の cue は十分短く、天井は比例配分を
 * 歪めて実測長リスケール後も残る誤差の原因だった)。末尾の極小 cue は幅が
 * 許す場合のみ直前の cue へ併合する。台本が空なら空文字列を返す。
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
  let cueIndex = 0;
  const blocks: string[] = [];
  const joiner = lang === "ja" ? "" : " ";
  for (const line of lines) {
    // 文境界(。？！)で区切ってから折り返す。cue が前文の断片(「た。今日の…」)
    // から始まらず、必ず文頭 or 同一文の折返し継続で始まるようにする。
    const segments = splitAtSentenceBoundaries(line);
    const cues: string[][] = [];
    for (const segment of segments) {
      const rows = wrapCaptionText(segment);
      for (let i = 0; i < rows.length; i += MAX_ROWS_PER_CUE) {
        cues.push(rows.slice(i, i + MAX_ROWS_PER_CUE));
      }
    }
    // 末尾の極小 cue (推定 < minLineSeconds) は、直前 cue の最終行に足しても
    // 行幅の上限を破らない場合のみ併合する(タイムライン全体は膨らませない)。
    if (cues.length >= 2) {
      const tail = cues[cues.length - 1];
      const tailText = tail.join(joiner);
      const tailChars = Array.from(tailText).length;
      if (tailChars / safeCps < timing.minLineSeconds) {
        const prev = cues[cues.length - 2];
        const mergedRow = prev[prev.length - 1] + joiner + tailText;
        const mergedUnits = Array.from(mergedRow)
          .reduce((sum, c) => sum + charUnits(c), 0);
        if (mergedUnits <= MAX_ROW_UNITS) {
          prev[prev.length - 1] = mergedRow;
          cues.pop();
        }
      }
    }
    const lineChars = Array.from(line).length;
    const lineDurationMs = cues.length === 1
      ? Math.round(
        Math.max(timing.minLineSeconds, lineChars / safeCps) * 1000,
      )
      : Math.round((lineChars / safeCps) * 1000);
    let allocatedMs = 0;
    for (let i = 0; i < cues.length; i += 1) {
      const cueChars = Array.from(cues[i].join("")).length;
      const durMs = i === cues.length - 1
        ? lineDurationMs - allocatedMs
        : Math.round(lineDurationMs * (cueChars / Math.max(1, lineChars)));
      allocatedMs += durMs;
      const startMs = cursorMs;
      const endMs = startMs + durMs;
      cursorMs = endMs;
      cueIndex += 1;
      blocks.push(
        `${cueIndex}\n${formatSrtTimestamp(startMs)} --> ${
          formatSrtTimestamp(endMs)
        }\n${cues[i].join("\n")}`,
      );
    }
  }
  return blocks.join("\n\n") + "\n";
}

export interface CaptionStyle {
  /** CJK グリフを含むフォント名。実際の可用性はトランスコーダ側の fontconfig 次第。 */
  fontName: string;
  /** libass PlayRes 単位 (SRT 既定 PlayRes 384x288)。出力 px = 値 × 高さ/288 (540p で ×1.875)。 */
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
  /** 下端からの余白 (PlayRes 単位 / × 高さ/288)。 */
  marginV: number;
  /** 左余白 (PlayRes 単位 / × 幅/384。30 → 960w で ~75px)。折返し幅を拘束する。 */
  marginL: number;
  /** 右余白 (PlayRes 単位)。 */
  marginR: number;
}

// 下中央・白文字・黒 stroke・影付きの高コントラスト字幕。~540p 短尺向け。
// FontSize 20 × 1.875 = 37.5px/全角。MAX_ROW_UNITS=14 全角 ≈ 525px << 実効幅
// 810px(960 - 75px×2) で、はみ出しない余裕を持つ。
export const DEFAULT_CAPTION_STYLE: CaptionStyle = {
  fontName: "Noto Sans CJK JP",
  fontSizePx: 20,
  primaryColour: "&H00FFFFFF",
  outlineColour: "&H00000000",
  outline: 3,
  shadow: 1,
  alignment: 2,
  marginV: 40,
  marginL: 30,
  marginR: 30,
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
    `MarginL=${style.marginL}`,
    `MarginR=${style.marginR}`,
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
  /** トランスコーダに実測動画長への SRT リスケールを指示 (旧版は無視する)。 */
  stretchToVideo: boolean;
  /** 全 cue 開始を後ろへずらすリード (ms)。Hedra の頭出し余白補正用。 */
  leadInMs?: number;
  /** 最終 cue を動画末尾より手前で終わらせる余白 (ms)。 */
  tailPadMs?: number;
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
