import { expect, test, type Locator, type Page } from '@playwright/test';

const origin = 'http://127.0.0.1:7362';
const sourceUrl = 'https://new-kokumin.jp/member';
const cacheKey = 'election_intelligence_snapshot_v6_local';
type Diagnostics = { blocked: string[]; errors: string[]; sources: string[] };
const diagnostics = new WeakMap<Page, Diagnostics>();

test.beforeEach(async ({ context, page }) => {
  const observed: Diagnostics = { blocked: [], errors: [], sources: [] };
  diagnostics.set(page, observed);
  const watch = (target: Page) => {
    target.on('pageerror', error => observed.errors.push(error.message));
    target.on('console', message => {
      if (message.type() === 'error') observed.errors.push(message.text());
    });
  };
  watch(page);
  context.on('page', watch);
  await context.route('**/*', async route => {
    const url = new URL(route.request().url());
    if (url.href === sourceUrl && route.request().isNavigationRequest()) {
      observed.sources.push(url.href);
      // Verify the real link without contacting the official website.
      await route.fulfill({
        contentType: 'text/html',
        body: '<!doctype html><title>Intercepted official source</title><p>offline fixture</p>',
      });
    } else if (url.origin === origin && !url.pathname.includes('/synthetic-supabase')) {
      await route.continue();
    } else if (url.protocol === 'data:' || url.protocol === 'blob:') {
      await route.continue();
    } else {
      observed.blocked.push(url.href);
      await route.abort('blockedbyclient');
    }
  });
  await context.routeWebSocket('**/*', socket => {
    observed.blocked.push('websocket');
    socket.close();
  });
});

test.afterEach(async ({ page }, info) => {
  const observed = diagnostics.get(page)!;
  await info.attach('browser-diagnostics', {
    body: JSON.stringify(observed, null, 2),
    contentType: 'application/json',
  });
  expect(observed.blocked).toEqual([]);
  expect(observed.errors).toEqual([]);
  expect(new URL(page.url()).origin).toBe(origin);
});

function label(page: Page, name: RegExp): Locator {
  return page.getByLabel(name).or(page.getByText(name)).first();
}

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

async function stored(page: Page, suffix: string): Promise<string | null> {
  return page.evaluate(key => {
    const row = Object.entries(localStorage).find(([name]) => name.endsWith(key));
    return row ? row[1] : null;
  }, suffix);
}

async function openScenario(page: Page, cache: 'legacy' | 'empty'): Promise<void> {
  await page.goto('/?cache=' + cache);
  await expect.poll(async () =>
    Number(await stored(page, 'local_member_fixture_edge_failures'))).toBeGreaterThan(0);
  // This is the real page, not a separately reconstructed card.
  await expect(label(page, /^統一地方選700 公開ダッシュボード$/)).toBeVisible();
  await observation(page);
}

async function observation(page: Page, direction = 1): Promise<void> {
  await reveal(page, label(page, /^党公式名簿の掲載人数: 416人$/), direction);
  await reveal(page, label(page, /^確認日: 2026\/11\/14（原本の基準日は記載なし）$/));
  await reveal(page, label(page, /県別内訳・計画KPIは更新していません/));
  await expect(label(page, /党公式名簿の掲載人数: 394人/)).toHaveCount(0);
  await expect(label(page, /議員名簿の取得時点では 416人/)).toHaveCount(0);
}

async function oldSnapshot(page: Page): Promise<void> {
  await reveal(page, label(page, /議員名簿の取得時点では 394人。700人まで残り 306人/));
  await reveal(page, label(page, /名簿の取得日時 2026\/10\/11 00:00（現在の人数は未確認）/));
  await reveal(page, label(page, /^名簿取得値$/));
  const raw = await stored(page, cacheKey);
  expect(raw).toContain('394');
  expect(raw).toContain('2026-10-11');
  expect(raw).not.toContain('416');
}

test('legacy394 + HTTP503 keeps observed416 separate from old roster and KPI', async ({ page }, info) => {
  await openScenario(page, 'legacy');
  const oldCache = await stored(page, cacheKey);
  const oldPlan = await stored(page, 'local_election_plan_v1');
  await oldSnapshot(page);
  await observation(page, -1);
  await page.screenshot({ path: info.outputPath('observed416-with-legacy394.png') });
  expect(await stored(page, cacheKey)).toBe(oldCache);
  expect(await stored(page, 'local_election_plan_v1')).toBe(oldPlan);
  expect(diagnostics.get(page)!.sources).toEqual([]);
});

test('empty cache + HTTP503 retains dated observation and labels plan baseline', async ({ page }, info) => {
  await openScenario(page, 'empty');
  expect(await stored(page, cacheKey)).toBeNull();
  await reveal(page, label(page, /計画の起点 340人から 700人へ/));
  await reveal(page, label(page, /^計画の起点$/));
  await expect(label(page, /議員名簿の取得時点では 394人/)).toHaveCount(0);
  await observation(page, -1);
  await page.screenshot({ path: info.outputPath('observed416-with-empty-cache.png') });
  expect(await stored(page, cacheKey)).toBeNull();
  expect(diagnostics.get(page)!.sources).toEqual([]);
});

test('reload preserves synthetic cache and real source link opens intercepted popup', async ({ page }, info) => {
  await openScenario(page, 'legacy');
  const oldCache = await stored(page, cacheKey);
  await page.reload();
  await expect.poll(async () =>
    Number(await stored(page, 'local_member_fixture_edge_failures'))).toBeGreaterThan(0);
  await observation(page);
  await oldSnapshot(page);
  expect(await stored(page, cacheKey)).toBe(oldCache);
  const button = page.getByRole('button', { name: '党公式の地方議員名簿を開く', exact: true });
  await reveal(page, button, -1);
  const popupPromise = page.waitForEvent('popup');
  await button.click();
  const popup = await popupPromise;
  await popup.waitForLoadState('domcontentloaded');
  expect(popup.url()).toBe(sourceUrl);
  await expect(popup).toHaveTitle('Intercepted official source');
  expect(diagnostics.get(page)!.sources).toEqual([sourceUrl]);
  await popup.close();
  await observation(page, -1);
  await page.screenshot({ path: info.outputPath('reloaded-source-return.png') });
  expect(await stored(page, cacheKey)).toBe(oldCache);
});
