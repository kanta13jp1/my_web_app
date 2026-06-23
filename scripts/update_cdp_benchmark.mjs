// 立憲民主党の都道府県別 地方議員数 (member-local_prefecture) を cdp-japan.jp から
// スクレイプし assets/data/cdp_local_members.json を更新する。
//
// 週次 cron (.github/workflows/cdp-benchmark-update.yml) から実行される。
// 全 47 都道府県を inline で取得すると 110 秒超でクライアント側 90 秒タイムアウトを
// 超えるため、edge function 経由ではなく GHA runner 上のこのスクリプトで取得・保存し、
// Flutter アプリは保存済み JSON (assets) を読む (= 取得をページ読み込みから切り離す)。
//
// 出力 JSON はタイムスタンプを含めず、件数が変化したときだけ diff が出る (= 無駄な
// 週次デプロイを避ける)。スクレイプ失敗の都道府県は出力から除外し、Flutter 側は seed を
// 維持する。明らかな取得失敗 (大量 0) では書き込まず exit 1 して既存データを守る。

import { writeFile, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const BASE_URL = "https://cdp-japan.jp/members/prefecture/";
const USER_AGENT =
  "my_web_app cdp-benchmark/1.0 (+https://my-web-app-b67f4.web.app/)";
const MAX_PAGES = 24;
const CONCURRENCY = 6;
const FETCH_TIMEOUT_MS = 20000;
const FETCH_RETRIES = 2;

// 取得失敗 (サイト構造変化やダウン) で良データを 0 で潰さないためのサニティ下限。
const MIN_PREFECTURES = 40;
const MIN_TOTAL_MEMBERS = 500;

const PREFECTURES = [
  "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
  "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
  "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
  "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
  "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
  "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
  "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
];

function prefectureSlug(prefecture) {
  return prefecture === "北海道" ? prefecture : prefecture.replace(/[都府県]$/u, "");
}

function countCdpLocalAuthorityCards(html) {
  return [
    ...html.matchAll(
      /class="[^"]*\bcard\b[^"]*\bmember\b[^"]*\bmember-local_[^"]*"/gi,
    ),
  ].length;
}

function parseMaxPaginationPage(html) {
  let maxPage = 1;
  for (const match of html.matchAll(/\?page=(\d+)/g)) {
    maxPage = Math.max(maxPage, Number.parseInt(match[1] ?? "1", 10) || 1);
  }
  return maxPage;
}

async function fetchText(url) {
  let lastError = null;
  for (let attempt = 1; attempt <= FETCH_RETRIES; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      const response = await fetch(url, {
        headers: { "User-Agent": USER_AGENT },
        redirect: "follow",
        signal: controller.signal,
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status} for ${url}`);
      }
      return await response.text();
    } catch (error) {
      lastError = error;
      if (attempt < FETCH_RETRIES) {
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
    } finally {
      clearTimeout(timeout);
    }
  }
  throw lastError ?? new Error(`Failed to fetch ${url}`);
}

async function fetchPrefectureLocalMembers(prefecture) {
  const baseUrl = BASE_URL + encodeURIComponent(prefectureSlug(prefecture));
  let total = 0;
  let maxPage = 1;
  for (let page = 1; page <= Math.min(maxPage, MAX_PAGES); page += 1) {
    const url = page === 1 ? baseUrl : `${baseUrl}?page=${page}`;
    const html = await fetchText(url);
    total += countCdpLocalAuthorityCards(html);
    if (page === 1) {
      maxPage = Math.max(1, parseMaxPaginationPage(html));
    }
  }
  return total;
}

async function mapWithConcurrency(items, limit, task) {
  const results = new Array(items.length);
  let cursor = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await task(items[index], index);
    }
  });
  await Promise.all(workers);
  return results;
}

async function main() {
  const scraped = await mapWithConcurrency(
    PREFECTURES,
    CONCURRENCY,
    async (prefecture) => {
      try {
        const localMembers = await fetchPrefectureLocalMembers(prefecture);
        return { prefecture, localMembers };
      } catch (error) {
        console.error(`Failed to scrape ${prefecture}:`, error.message ?? error);
        return { prefecture, localMembers: null };
      }
    },
  );

  // Key by the short prefecture name (都/府/県 を除いた名称) to match the plan's
  // seed naming (例: '東京' / '大阪' / '北海道')。
  const byPrefecture = {};
  let total = 0;
  let okCount = 0;
  for (const prefecture of PREFECTURES) {
    const entry = scraped.find((item) => item.prefecture === prefecture);
    if (entry && entry.localMembers != null && entry.localMembers > 0) {
      byPrefecture[prefectureSlug(prefecture)] = entry.localMembers;
      total += entry.localMembers;
      okCount += 1;
    }
  }

  console.log(`Scraped ${okCount}/${PREFECTURES.length} prefectures, total ${total} members.`);

  if (okCount < MIN_PREFECTURES || total < MIN_TOTAL_MEMBERS) {
    console.error(
      `Sanity check failed (prefectures=${okCount} < ${MIN_PREFECTURES} or total=${total} < ${MIN_TOTAL_MEMBERS}); refusing to overwrite existing data.`,
    );
    process.exit(1);
  }

  const outputPath = join(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "assets",
    "data",
    "cdp_local_members.json",
  );
  const payload = { source: BASE_URL, prefectures: byPrefecture };
  const json = `${JSON.stringify(payload, null, 2)}\n`;

  let previous = "";
  try {
    previous = await readFile(outputPath, "utf8");
  } catch {
    previous = "";
  }
  if (previous === json) {
    console.log("No change in CDP local member counts.");
    return;
  }
  await writeFile(outputPath, json, "utf8");
  console.log(`Wrote ${outputPath}`);
}

await main();
