import { expect, test, type Locator, type Page } from '@playwright/test';

const origin = 'http://127.0.0.1:7361';
const sourceUrl = 'https://new-kokumin.jp/local-election-list';
const newerSourceUrl = 'https://example.invalid/official-endorsements-newer';
const originalAnnouncementUrl = 'https://x.com/tamakiyuichiro/status/2119639251365294529';
const officialAnnouncementSite = 'https://tamakinet.jp/';
const cacheKey = 'election_intelligence_snapshot_v6_local';

type Diagnostics = {
  blockedRequests: string[];
  pageErrors: string[];
  consoleErrors: string[];
  popups: number;
};
const diagnostics = new WeakMap<Page, Diagnostics>();

test.beforeEach(async ({ context, page }, info) => {
  const observed: Diagnostics = { blockedRequests: [], pageErrors: [], consoleErrors: [], popups: 0 };
  diagnostics.set(page, observed);
  page.on('pageerror', error => observed.pageErrors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') observed.consoleErrors.push(message.text());
  });
  context.on('page', () => observed.popups++);
  await context.route('**/*', async route => {
    const url = new URL(route.request().url());
    if (url.origin === origin || url.protocol === 'data:' || url.protocol === 'blob:') {
      await route.continue();
    } else {
      observed.blockedRequests.push(url.origin);
      await route.abort('blockedbyclient');
    }
  });
  await context.routeWebSocket('**/*', socket => {
    observed.blockedRequests.push('websocket');
    socket.close();
  });
  await page.goto('/');
  expect(await page.evaluate(() => window.innerWidth))
    .toBe(info.project.name === 'mobile-390' ? 390 : 1440);
  await expect(label(page, /^合成データ専用・localhost画面試験$/)).toBeInViewport();
  await expect(label(page, /^キャッシュ読取: 1回（合成412件）$/)).toBeVisible();
});

test.afterEach(async ({ page }, info) => {
  const observed = diagnostics.get(page);
  if (observed && (observed.popups > 0 || observed.blockedRequests.length > 0 ||
      observed.pageErrors.length > 0 || observed.consoleErrors.length > 0)) {
    await info.attach('browser-diagnostics', {
      body: JSON.stringify(observed, null, 2),
      contentType: 'application/json',
    });
  }
  expect(observed).toEqual({ blockedRequests: [], pageErrors: [], consoleErrors: [], popups: 0 });
  expect(new URL(page.url()).origin).toBe(origin);
});

function label(page: Page, name: RegExp): Locator {
  return page.getByLabel(name).or(page.getByText(name)).first();
}

// Move Flutter's actual scroll viewport, rather than relying on DOM scrolling.
async function reveal(page: Page, item: Locator, preferredDirection = 1): Promise<void> {
  const viewport = page.viewportSize()!;
  await page.mouse.move(viewport.width / 2, viewport.height * 0.7);
  for (let i = 0; i < 70; i++) {
    const rect = await item.count() ? await item.boundingBox() : null;
    if (rect && rect.y >= 8 && rect.y + rect.height <= viewport.height - 8) {
      await expect(item).toBeInViewport();
      expect(rect.x).toBeGreaterThanOrEqual(0);
      expect(rect.x + rect.width).toBeLessThanOrEqual(viewport.width + 1);
      return;
    }
    const direction = rect ? (rect.y < 8 ? -1 : 1) : preferredDirection;
    await page.mouse.wheel(0, direction * Math.min(280, viewport.height / 3));
    await page.evaluate(() => new Promise<void>(resolve =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  }
  throw new Error('Could not reveal ' + item.toString());
}

async function clickButton(page: Page, name: string, direction = 1): Promise<void> {
  const button = page.getByRole('button', { name, exact: true });
  await reveal(page, button, direction);
  await button.click();
}

async function baselineCard(page: Page): Promise<void> {
  await reveal(page, label(page, /^合成データ専用・localhost画面試験$/), -1);
  await reveal(page, label(page, /^公認掲載 430件$/));
  for (const text of [
    /^掲載内の現職 177件$/,
    /^掲載内の新人 242件$/,
    /^掲載内の元職 11件$/,
    /^掲載地域 42\/47都道府県$/,
    /^都道府県議 117件$/,
    /^市区町村議 313件$/,
    /推薦15件は公認の集計から除いています。推薦件数の集計対象には首長選挙も含まれます。/,
  ]) {
    await reveal(page, label(page, text));
  }
  await expect(label(page, /^公認掲載 412件$/)).toHaveCount(0);
  await reveal(page, page.getByRole('button', {
    name: /都道府県別の公認掲載件数[\s\S]*\D42都道府県(?:\D|$)/,
  }));
  const source = page.getByRole('button', {
    name: '党公式の公認予定候補一覧を開く(2026/11/04現在)', exact: true,
  });
  await reveal(page, source);
}

function exactText(page: Page, text: string): Locator {
  return page.getByLabel(text, { exact: true }).or(page.getByText(text, { exact: true })).first();
}

async function announcementCard(page: Page): Promise<void> {
  await reveal(page, label(page, /^合成データ専用・localhost画面試験$/), -1);
  for (const text of [
    /^党代表発表（2026\/11\/09）$/,
    /^現職 420人$/,
    /^新人擁立数 243人$/,
    /^全国自治体議員 700人目標$/,
    /公認予定候補の掲載件数や議員名簿の集計、アプリの計画値とは別の指標です。/,
    /^発表時点の固定値です。最新の状況は出典をご確認ください。$/,
  ]) {
    await reveal(page, label(page, text));
  }
}

async function captureAnnouncement(page: Page, button: string, url: string): Promise<void> {
  await clickButton(page, button);
  await reveal(page, exactText(page, '捕捉した発表出典URL: ' + url));
  expect(new URL(page.url()).origin).toBe(origin);
}

async function captureCandidate(page: Page, date: string, url: string): Promise<void> {
  await clickButton(page, '党公式の公認予定候補一覧を開く(' + date + '現在)');
  await reveal(page, exactText(page, '捕捉した公認出典URL: ' + url));
  expect(new URL(page.url()).origin).toBe(origin);
}

async function legacyStorage(page: Page): Promise<{ key: string; raw: string }> {
  const rows = await page.evaluate(key => Object.entries(localStorage)
    .filter(([name]) => name.endsWith(key)), cacheKey);
  expect(rows).toHaveLength(1);
  expect(rows[0][1]).toContain('412');
  expect(rows[0][1]).toContain('2026-10-21');
  expect(rows[0][1]).not.toContain('sourceCountsComplete');
  return { key: rows[0][0], raw: rows[0][1] };
}

test('旧412件キャッシュを読み、実カードの430件・出典・地域を再読込後も維持する', async ({ page }, info) => {
  const stored = await legacyStorage(page);
  await announcementCard(page);
  await captureAnnouncement(page, '党代表の元投稿を開く', originalAnnouncementUrl);
  await announcementCard(page);
  await captureAnnouncement(page, '党代表公式サイトの掲載を開く', officialAnnouncementSite);
  await page.screenshot({ path: info.outputPath('representative-announcement.png') });
  await baselineCard(page);
  await reveal(page, label(page, /^公認掲載 430件$/), -1);
  await page.screenshot({ path: info.outputPath('legacy-cache-summary.png') });

  const regions = page.getByRole('button', { name: /都道府県別の公認掲載件数/ });
  await reveal(page, regions);
  await regions.click();
  for (const region of [
    /^北海道 7件 \(現職2 \/ 新人5\) \[市区町村議7\]$/,
    /^青森 6件 \(現職2 \/ 新人3 \/ 元職1\) \[都道府県議2 \/ 市区町村議4\]$/,
    /^東京 49件 \(現職31 \/ 新人16 \/ 元職2\) \[市区町村議49\]$/,
  ]) {
    await reveal(page, label(page, region));
  }
  await reveal(page, label(page, /^北海道 7件 /), -1);
  await page.screenshot({ path: info.outputPath('expanded-prefectures.png') });
  await reveal(page, regions, -1);
  await regions.click();

  await captureCandidate(page, '2026/11/04', sourceUrl);
  await page.screenshot({ path: info.outputPath('captured-source.png') });

  await clickButton(page, 'キャッシュを再読込', -1);
  await expect(label(page, /^キャッシュ読取: 2回（合成412件）$/)).toBeVisible();
  await baselineCard(page);
  expect(await legacyStorage(page)).toEqual(stored);
  await page.reload();
  await expect(label(page, /^キャッシュ読取: 1回（合成412件）$/)).toBeVisible();
  await baselineCard(page);
  expect(await legacyStorage(page)).toEqual(stored);
  await announcementCard(page);
  await baselineCard(page);
  await reveal(page, label(page, /^公認掲載 430件$/), -1);
  await page.screenshot({ path: info.outputPath('reloaded-legacy-cache.png') });
});

test('検証済みでも古いEdgeは退け、新しい完全な合成Edgeへカード全体を更新する', async ({ page }, info) => {
  await clickButton(page, '旧Edgeを反映');
  await expect(label(page, /^入力: 旧Edge（合成412件・検証済み・2026-10-21）$/)).toBeVisible();
  await baselineCard(page);
  await reveal(page, label(page, /^公認掲載 430件$/), -1);
  await page.screenshot({ path: info.outputPath('verified-stale-edge.png') });

  await announcementCard(page);
  await clickButton(page, '新しい合成Edgeを反映', -1);
  await expect(label(page, /^入力: 新Edge（合成431件・検証済み・2026-11-05）$/)).toBeVisible();
  for (const text of [
    /^公認掲載 431件$/,
    /^掲載内の現職 177件$/,
    /^掲載内の新人 243件$/,
    /^掲載内の元職 11件$/,
    /^掲載地域 1\/47都道府県$/,
    /^都道府県議 117件$/,
    /^市区町村議 314件$/,
    /推薦16件は公認の集計から除いています。/,
  ]) {
    await reveal(page, label(page, text));
  }
  await reveal(page, page.getByRole('button', {
    name: /都道府県別の公認掲載件数[\s\S]*\D1都道府県(?:\D|$)/,
  }));
  await captureCandidate(page, '2026/11/05', newerSourceUrl);
  await reveal(page, label(page, /^公認掲載 431件$/), -1);
  await page.screenshot({ path: info.outputPath('newer-complete-synthetic-edge.png') });

  await announcementCard(page);
  await clickButton(page, 'キャッシュを再読込', -1);
  await expect(label(page, /^キャッシュ読取: 2回（合成412件）$/)).toBeVisible();
  await baselineCard(page);
  await captureCandidate(page, '2026/11/04', sourceUrl);
  await announcementCard(page);
  await legacyStorage(page);
});
