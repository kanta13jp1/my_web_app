const ARTICLE_REQUIRED_HEADERS = [
  "post_id",
  "views",
  "likes",
  "reposts",
  "replies",
  "bookmarks",
];

const ARTICLE_NUMERIC_HEADERS = [
  "views",
  "likes",
  "reposts",
  "replies",
  "bookmarks",
];

const X_HEADER_TO_KEY = {
  "post id": "postId",
  "date": "date",
  "post text": "text",
  "post link": "link",
  "impressions": "impressions",
  "likes": "likes",
  "engagements": "engagements",
  "bookmarks": "bookmarks",
  "shares": "shares",
  "new follows": "newFollows",
  "replies": "replies",
  "reposts": "reposts",
  "profile visits": "profileVisits",
  "detail expands": "detailExpands",
  "url clicks": "urlClicks",
  "hashtag clicks": "hashtagClicks",
  "permalink clicks": "permalinkClicks",
};

const X_NUMERIC_KEYS = [
  "impressions",
  "likes",
  "engagements",
  "bookmarks",
  "shares",
  "newFollows",
  "replies",
  "reposts",
  "profileVisits",
  "detailExpands",
  "urlClicks",
  "hashtagClicks",
  "permalinkClicks",
];

export const PRESETS = {
  weighted_vs_mean: {
    mode: "article",
    label: "重み付け（1% vs 5%）",
    csv: [
      "post_id,views,likes,reposts,replies,bookmarks",
      "a,100,10,0,0,0",
      "b,900,0,0,0,0",
    ].join("\n"),
  },
  blank_and_bom: {
    mode: "article",
    label: "BOM・引用符・空行",
    csv: [
      '\uFEFFlikes,"post_id",note,views,reposts,replies,bookmarks',
      '10,"p1","hello, world",100,0,0,0',
      "",
      "   ,   ,   ,   ,   ,   ,   ",
    ].join("\r\n"),
  },
  fullwidth_digit: {
    mode: "article",
    label: "全角数字 １００",
    csv: [
      "post_id,views,likes,reposts,replies,bookmarks",
      "p1,１００,10,0,0,0",
    ].join("\n"),
  },
  duplicate_id: {
    mode: "article",
    label: "重複 post_id",
    csv: [
      "post_id,views,likes,reposts,replies,bookmarks",
      "p1,100,5,0,0,0",
      " p1 ,200,5,0,0,0",
    ].join("\n"),
  },
  x_analytics_edge: {
    mode: "x_analytics",
    label: "X Analytics 境界例",
    csv: [
      '\uFEFFPost id,Date,Post text,Impressions,Likes,Reposts,Replies,Bookmarks,URL Clicks,Impressions',
      '2074000000000000001,"Tue, Jul 14, 2026",正常投稿A,100,5,1,0,0,2,999',
      "",
      ' 2074000000000000001 ,"Tue, Jul 14, 2026",重複ID投稿,100,5,1,0,0,2,999',
      '2074000000000000002,"Wed, Jul 15, 2026",全角数字あり,１００,2,0,0,0,1,0',
      '2074000000000000003,"Thu, Jul 16, 2026",負数あり,200,-1,0,0,0,0,0',
    ].join("\n"),
  },
};

function gcd(a, b) {
  let x = a < 0n ? -a : a;
  let y = b < 0n ? -b : b;
  while (y !== 0n) {
    const t = x % y;
    x = y;
    y = t;
  }
  return x === 0n ? 1n : x;
}

/**
 * BigInt 整数演算で (numerator / denominator) * 100 を小数 4 桁 ROUND_HALF_UP 文字列にする。
 */
export function roundHalfUpPercent4(numerator, denominator) {
  const num = BigInt(numerator);
  const den = BigInt(denominator);
  if (den <= 0n) return null;
  const scaled = num * 1000000n;
  let q = scaled / den;
  const rem = scaled % den;
  if (rem * 2n >= den) {
    q += 1n;
  }
  const intPart = q / 10000n;
  const fracPart = String(q % 10000n).padStart(4, "0");
  return `${intPart}.${fracPart}`;
}

/**
 * RFC4180 準拠の CSV 行分割。空行・空白のみの行は行数カウント対象として除外する。
 */
export function splitCsvRows(input) {
  const raw = typeof input === "string" ? input : "";
  const bomStripped = raw.startsWith("\uFEFF");
  const text = (bomStripped ? raw.slice(1) : raw)
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n");

  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  let blankRowsSkipped = 0;

  if (text === "") {
    return { rows: [], bomStripped, blankRowsSkipped: 0, unclosedQuote: false };
  }

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        field += ch;
      }
      continue;
    }
    if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n") {
      row.push(field);
      field = "";
      if (row.some((cell) => cell.trim() !== "")) {
        rows.push(row);
      } else {
        blankRowsSkipped += 1;
      }
      row = [];
    } else {
      field += ch;
    }
  }

  row.push(field);
  if (row.some((cell) => cell.trim() !== "")) {
    rows.push(row);
  } else if (row.length > 1 || row[0] !== "") {
    blankRowsSkipped += 1;
  }

  return { rows, bomStripped, blankRowsSkipped, unclosedQuote: quoted };
}

function parseAsciiNonNegativeInt(raw, rowIndex, column) {
  const trimmed = String(raw ?? "").trim();
  if (/[０-９]/.test(trimmed)) {
    throw new Error(
      `${rowIndex}行目の列「${column}」に全角数字（${trimmed}）が含まれています。半角の0〜9のみ入力してください。`,
    );
  }
  if (/^-/.test(trimmed)) {
    throw new Error(
      `${rowIndex}行目の列「${column}」が負数（${trimmed}）です。0以上の半角整数を入力してください。`,
    );
  }
  if (!/^[0-9]+$/.test(trimmed)) {
    throw new Error(
      `${rowIndex}行目の列「${column}」の値（${trimmed || "空欄"}）は半角数字0〜9ではありません。`,
    );
  }
  return BigInt(trimmed);
}

/**
 * 記事の 6 列厳密仕様 (post_id,views,likes,reposts,replies,bookmarks) で CSV を検査・集計する。
 */
export function evaluateArticleCsv(csvText) {
  const parsed = splitCsvRows(csvText);
  if (parsed.unclosedQuote) {
    throw new Error('閉じられていない二重引用符（"）があります。CSVの引用符を確認してください。');
  }
  if (parsed.rows.length === 0) {
    return {
      mode: "article",
      posts: 0,
      totalViews: "0",
      totalReactions: "0",
      weightedRate: null,
      simpleMeanRate: null,
      bomStripped: parsed.bomStripped,
      blankRowsSkipped: parsed.blankRowsSkipped,
    };
  }

  const headerCells = parsed.rows[0].map((c) => c.trim());
  const headerIndex = new Map();
  for (let i = 0; i < headerCells.length; i += 1) {
    const name = headerCells[i];
    if (name === "") {
      throw new Error(`ヘッダ行の ${i + 1} 列目が空です。`);
    }
    if (headerIndex.has(name)) {
      throw new Error(`ヘッダ名「${name}」が重複しています。`);
    }
    headerIndex.set(name, i);
  }

  for (const required of ARTICLE_REQUIRED_HEADERS) {
    if (!headerIndex.has(required)) {
      throw new Error(`必須ヘッダ「${required}」が見つかりません。`);
    }
  }

  const expectedCols = headerCells.length;
  if (parsed.rows.length === 1) {
    return {
      mode: "article",
      posts: 0,
      totalViews: "0",
      totalReactions: "0",
      weightedRate: null,
      simpleMeanRate: null,
      bomStripped: parsed.bomStripped,
      blankRowsSkipped: parsed.blankRowsSkipped,
    };
  }

  const seenIds = new Set();
  let posts = 0;
  let totalViews = 0n;
  let totalReactions = 0n;
  let meanNum = 0n;
  let meanDen = 1n;
  let positiveViewPosts = 0n;

  for (let r = 1; r < parsed.rows.length; r += 1) {
    const cells = parsed.rows[r];
    const rowIndex = r + 1;
    if (cells.length !== expectedCols) {
      throw new Error(
        `${rowIndex}行目の列数がヘッダ（${expectedCols}列）と一致しません（実測: ${cells.length}列）。`,
      );
    }
    const postId = String(cells[headerIndex.get("post_id")] ?? "").trim();
    if (postId === "") {
      throw new Error(`${rowIndex}行目の post_id が空です。`);
    }
    if (seenIds.has(postId)) {
      throw new Error(`${rowIndex}行目の post_id「${postId}」が重複しています（前後空白除去後に一致）。`);
    }
    seenIds.add(postId);

    const nums = {};
    for (const col of ARTICLE_NUMERIC_HEADERS) {
      nums[col] = parseAsciiNonNegativeInt(cells[headerIndex.get(col)], rowIndex, col);
    }
    const rowReactions = nums.likes + nums.reposts + nums.replies + nums.bookmarks;
    totalViews += nums.views;
    totalReactions += rowReactions;
    posts += 1;

    if (nums.views > 0n) {
      positiveViewPosts += 1n;
      const nextNum = meanNum * nums.views + rowReactions * meanDen;
      const nextDen = meanDen * nums.views;
      const g = gcd(nextNum, nextDen);
      meanNum = nextNum / g;
      meanDen = nextDen / g;
    }
  }

  const weightedRate = roundHalfUpPercent4(totalReactions, totalViews);
  const simpleMeanRate =
    positiveViewPosts > 0n
      ? roundHalfUpPercent4(meanNum, meanDen * positiveViewPosts)
      : null;

  return {
    mode: "article",
    posts,
    totalViews: totalViews.toString(),
    totalReactions: totalReactions.toString(),
    weightedRate,
    simpleMeanRate,
    bomStripped: parsed.bomStripped,
    blankRowsSkipped: parsed.blankRowsSkipped,
  };
}

function parseXNumericCell(raw, rowIndex, column, postId, issues) {
  const trimmed = String(raw ?? "").trim();
  if (trimmed === "") return { value: 0n, invalid: false };
  if (/[０-９]/.test(trimmed)) {
    issues.push({
      code: "non_ascii_digit",
      rowIndex,
      column,
      postId,
      rawValue: trimmed,
      message: `${rowIndex}行目「${column}」に全角数字（${trimmed}）を検出（0扱いへフォールバック）`,
    });
    return { value: 0n, invalid: true };
  }
  const compact = trimmed.replace(/[",\s]/g, "");
  if (/^-\d+$/.test(compact)) {
    issues.push({
      code: "negative_numeric",
      rowIndex,
      column,
      postId,
      rawValue: trimmed,
      message: `${rowIndex}行目「${column}」に負数（${trimmed}）を検出（0扱いへフォールバック）`,
    });
    return { value: 0n, invalid: true };
  }
  if (/^\d+$/.test(compact)) {
    return { value: BigInt(compact), invalid: false };
  }
  issues.push({
    code: "invalid_numeric",
    rowIndex,
    column,
    postId,
    rawValue: trimmed,
    message: `${rowIndex}行目「${column}」に不正な数値（${trimmed}）を検出（0扱いへフォールバック）`,
  });
  return { value: 0n, invalid: true };
}

/**
 * X Analytics CSV の診断モード。重複ヘッダ・重複 Post id・全角数字・負数を警告として列挙する。
 */
export function evaluateXAnalyticsCsv(csvText) {
  const parsed = splitCsvRows(csvText);
  if (parsed.unclosedQuote) {
    throw new Error('閉じられていない二重引用符（"）があります。CSVの引用符を確認してください。');
  }
  const issues = [];
  const duplicateHeadersIgnored = [];

  if (parsed.rows.length < 2) {
    return {
      mode: "x_analytics",
      posts: 0,
      totalImpressions: "0",
      totalReactions: "0",
      totalUrlClicks: "0",
      weightedRate: null,
      bomStripped: parsed.bomStripped,
      blankRowsSkipped: parsed.blankRowsSkipped,
      duplicatePostIdsSkipped: 0,
      duplicateHeadersIgnored,
      invalidNumericCells: 0,
      issues,
    };
  }

  const header = parsed.rows[0].map((c) => c.trim().toLowerCase());
  const indexByKey = new Map();
  header.forEach((name, index) => {
    const key = X_HEADER_TO_KEY[name];
    if (!key) return;
    if (indexByKey.has(key)) {
      duplicateHeadersIgnored.push(name);
      issues.push({
        code: "duplicate_header",
        rowIndex: 1,
        column: name,
        rawValue: parsed.rows[0][index] ?? name,
        message: `1行目ヘッダ「${name}」が重複しています（先頭列のみ採用）`,
      });
      return;
    }
    indexByKey.set(key, index);
  });

  if (!indexByKey.has("postId")) {
    throw new Error("必須ヘッダ「Post id」が見つかりません。");
  }

  const cell = (cells, key) => {
    const idx = indexByKey.get(key);
    return idx === undefined ? "" : String(cells[idx] ?? "").trim();
  };

  const seenIds = new Set();
  let posts = 0;
  let totalImpressions = 0n;
  let totalReactions = 0n;
  let totalUrlClicks = 0n;
  let duplicatePostIdsSkipped = 0;
  let invalidNumericCells = 0;

  for (let i = 1; i < parsed.rows.length; i += 1) {
    const cells = parsed.rows[i];
    const rowIndex = i + 1;
    const postId = cell(cells, "postId");
    if (!/^\d{5,}$/.test(postId)) continue;
    if (seenIds.has(postId)) {
      duplicatePostIdsSkipped += 1;
      issues.push({
        code: "duplicate_post_id",
        rowIndex,
        column: "postId",
        postId,
        rawValue: postId,
        message: `${rowIndex}行目の Post id「${postId}」が重複しているためスキップしました`,
      });
      continue;
    }
    seenIds.add(postId);

    const vals = {};
    for (const key of X_NUMERIC_KEYS) {
      const checked = parseXNumericCell(cell(cells, key), rowIndex, key, postId, issues);
      vals[key] = checked.value;
      if (checked.invalid) invalidNumericCells += 1;
    }
    posts += 1;
    totalImpressions += vals.impressions;
    totalReactions += vals.likes + vals.reposts + vals.replies + vals.bookmarks;
    totalUrlClicks += vals.urlClicks;
  }

  return {
    mode: "x_analytics",
    posts,
    totalImpressions: totalImpressions.toString(),
    totalReactions: totalReactions.toString(),
    totalUrlClicks: totalUrlClicks.toString(),
    weightedRate: roundHalfUpPercent4(totalReactions, totalImpressions),
    bomStripped: parsed.bomStripped,
    blankRowsSkipped: parsed.blankRowsSkipped,
    duplicatePostIdsSkipped,
    duplicateHeadersIgnored,
    invalidNumericCells,
    issues,
  };
}

export const ARTICLE_TWELVE_CASES = [
  {
    id: "01_weighted_not_mean",
    title: "表示数100と900の重み付け",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,100,10,0,0,0\nb,900,0,0,0,0",
    expect: { ok: true, posts: 2, totalViews: "1000", totalReactions: "10", weightedRate: "1.0000" },
  },
  {
    id: "02_all_reactions",
    title: "4種類の反応を加算",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,200,2,3,4,5",
    expect: { ok: true, posts: 1, totalViews: "200", totalReactions: "14", weightedRate: "7.0000" },
  },
  {
    id: "03_empty_input",
    title: "空文字列",
    csv: "",
    expect: { ok: true, posts: 0, totalViews: "0", totalReactions: "0", weightedRate: null },
  },
  {
    id: "04_header_only",
    title: "ヘッダーだけ",
    csv: "post_id,views,likes,reposts,replies,bookmarks",
    expect: { ok: true, posts: 0, totalViews: "0", totalReactions: "0", weightedRate: null },
  },
  {
    id: "05_zero_views",
    title: "表示0・反応1",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,0,1,0,0,0",
    expect: { ok: true, posts: 1, totalViews: "0", totalReactions: "1", weightedRate: null },
  },
  {
    id: "06_bom_quoted_reorder_blank",
    title: "BOM・引用符・列順変更・追加列・空行（失敗1の修正確認）",
    csv: '\uFEFFlikes,"post_id",note,views,reposts,replies,bookmarks\r\n10,"a","x,y",100,0,0,0\r\n\r\n',
    expect: { ok: true, posts: 1, totalViews: "100", totalReactions: "10", weightedRate: "10.0000" },
  },
  {
    id: "07_duplicate_trimmed_id",
    title: "前後空白除去後に重複するID",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,100,1,0,0,0\n a ,100,1,0,0,0",
    expect: { ok: false, errorIncludes: "重複" },
  },
  {
    id: "08_negative_number",
    title: "負数",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,100,-1,0,0,0",
    expect: { ok: false, errorIncludes: "負数" },
  },
  {
    id: "09_fullwidth_digit",
    title: "全角数字 １００（失敗2の修正確認）",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,１００,10,0,0,0",
    expect: { ok: false, errorIncludes: "全角数字" },
  },
  {
    id: "10_missing_header",
    title: "必須ヘッダー欠落",
    csv: "post_id,views,likes,reposts,replies\na,100,1,0,0",
    expect: { ok: false, errorIncludes: "必須ヘッダ" },
  },
  {
    id: "11_duplicate_header",
    title: "ヘッダー名重複",
    csv: "post_id,views,views,likes,reposts,replies,bookmarks\na,100,200,1,0,0,0",
    expect: { ok: false, errorIncludes: "重複" },
  },
  {
    id: "12_rounding_half_up",
    title: "1反応÷200万表示の丸め（0.0001%）",
    csv: "post_id,views,likes,reposts,replies,bookmarks\na,2000000,1,0,0,0",
    expect: { ok: true, posts: 1, totalViews: "2000000", totalReactions: "1", weightedRate: "0.0001" },
  },
];

export function runTwelveCaseSelfCheck() {
  const results = ARTICLE_TWELVE_CASES.map((tc) => {
    try {
      const actual = evaluateArticleCsv(tc.csv);
      if (!tc.expect.ok) {
        return {
          id: tc.id,
          title: tc.title,
          passed: false,
          summary: `エラーを期待しましたが受理されました (posts=${actual.posts})`,
        };
      }
      const matched =
        actual.posts === tc.expect.posts &&
        actual.totalViews === tc.expect.totalViews &&
        actual.totalReactions === tc.expect.totalReactions &&
        actual.weightedRate === tc.expect.weightedRate;
      const rateText = actual.weightedRate === null ? "None" : `${actual.weightedRate}%`;
      return {
        id: tc.id,
        title: tc.title,
        passed: matched,
        summary: `投稿${actual.posts} / 表示${actual.totalViews} / 反応${actual.totalReactions} / 率${rateText}`,
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (tc.expect.ok) {
        return { id: tc.id, title: tc.title, passed: false, summary: `予期しない失敗: ${msg}` };
      }
      const matched = !tc.expect.errorIncludes || msg.includes(tc.expect.errorIncludes);
      return {
        id: tc.id,
        title: tc.title,
        passed: matched,
        summary: `仕様通り拒否: ${msg}`,
      };
    }
  });
  const passed = results.filter((r) => r.passed).length;
  return { total: results.length, passed, failed: results.length - passed, results };
}
