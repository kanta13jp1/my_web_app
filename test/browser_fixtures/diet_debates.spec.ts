import { expect, test, type Locator, type Page } from '@playwright/test';

const origin = 'http://127.0.0.1:7360';

declare global {
  interface Window {
    fixtureOpenedSources: string[];
  }
}

type BrowserDiagnostics = {
  blockedRequests: string[];
  pageErrors: string[];
  consoleErrors: string[];
};

const diagnostics = new WeakMap<Page, BrowserDiagnostics>();

test.beforeEach(async ({ context, page }, info) => {
  const observed: BrowserDiagnostics = { blockedRequests: [], pageErrors: [], consoleErrors: [] };
  diagnostics.set(page, observed);
  page.on('pageerror', error => observed.pageErrors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') observed.consoleErrors.push(message.text());
  });
  await context.route('**/*', async route => {
    const url = new URL(route.request().url());
    if (url.origin === origin || url.protocol === 'data:') {
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
  // The browser never navigates to the official source. Check the intended URL.
  await context.addInitScript(() => {
    window.fixtureOpenedSources = [];
    window.open = (url?: string | URL) => {
      window.fixtureOpenedSources.push(String(url));
      return window;
    };
    const click = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () {
      if (this.href && this.origin !== location.origin) {
        window.fixtureOpenedSources.push(this.href);
        return;
      }
      click.call(this);
    };
    document.addEventListener('click', event => {
      const link = event.composedPath().find(item => item instanceof HTMLAnchorElement);
      if (link instanceof HTMLAnchorElement && link.origin !== location.origin) {
        event.preventDefault();
        window.fixtureOpenedSources.push(link.href);
      }
    }, true);
  });
  await page.goto('/');
  expect(await page.evaluate(() => window.innerWidth))
    .toBe(info.project.name === 'mobile-390' ? 390 : 1440);
  await expect(label(page, /国会の質疑を読む/)).toBeInViewport();
});

test.afterEach(async ({ page }, info) => {
  const observed = diagnostics.get(page);
  if (observed && Object.values(observed).some(entries => entries.length > 0)) {
    await info.attach('browser-diagnostics', {
      body: JSON.stringify(observed, null, 2),
      contentType: 'application/json',
    });
  }
  expect(observed).toEqual({ blockedRequests: [], pageErrors: [], consoleErrors: [] });
});

function label(page: Page, name: RegExp): Locator {
  return page.getByLabel(name).or(page.getByText(name)).first();
}

type Exposure = {
  rect: { x: number; y: number; width: number; height: number };
  intersection: { x: number; y: number; width: number; height: number };
  ratio: number;
};

async function exposure(item: Locator): Promise<Exposure> {
  return item.evaluate(element => new Promise<Exposure>(resolve => {
    const observer = new IntersectionObserver(([entry]) => {
      observer.disconnect();
      const box = (rect: DOMRectReadOnly) => ({
        x: rect.x, y: rect.y, width: rect.width, height: rect.height,
      });
      resolve({
        rect: box(entry.boundingClientRect),
        intersection: box(entry.intersectionRect),
        ratio: entry.intersectionRatio,
      });
    });
    observer.observe(element);
  }));
}

// Flutter semantics can have a window-space box while clipped by its ListView.
// Scroll the real canvas until the target's center is inside its actual visible area.
async function reveal(page: Page, item: Locator, direction = 1): Promise<void> {
  const viewport = page.viewportSize()!;
  // Tolerate only subpixel rounding of the observed intersection edges.
  const intersectionRoundingTolerance = 0.001;
  let lastExposure: Exposure | null = null;
  await page.mouse.move(viewport.width / 2, viewport.height * 0.7);
  for (let i = 0; i < 65; i++) {
    lastExposure = await item.count() ? await exposure(item) : null;
    if (lastExposure) {
      const { rect, intersection, ratio } = lastExposure;
      const centerY = rect.y + rect.height / 2;
      const horizontal = rect.width > 0 && rect.x >= 0 &&
        rect.x + rect.width <= viewport.width &&
        intersection.x <= rect.x + intersectionRoundingTolerance &&
        intersection.x + intersection.width + intersectionRoundingTolerance >= rect.x + rect.width;
      if (rect.height > 0 && horizontal && ratio > 0 &&
          centerY > intersection.y &&
          centerY < intersection.y + intersection.height) {
        await expect(item).toBeInViewport();
        return;
      }
    }
    const scrollDirection = lastExposure
      ? (lastExposure.rect.y + lastExposure.rect.height / 2 < viewport.height / 2 ? -1 : 1)
      : direction;
    await page.mouse.wheel(0, scrollDirection * Math.min(300, viewport.height / 3));
    await page.evaluate(() => new Promise<void>(resolve =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  }
  throw new Error('Could not reveal ' + item.toString() +
    '; last exposure=' + JSON.stringify({ viewport, lastExposure }));
}

async function checkSource(page: Page, name: string, url: string): Promise<void> {
  const button = page.getByRole('button', { name, exact: true });
  await reveal(page, button);
  await button.click();
  await expect.poll(() => page.evaluate(() => window.fixtureOpenedSources.at(-1))).toBe(url);
  expect(new URL(page.url()).origin).toBe(origin);
}

test('法案の読み方を切り替え、一次資料のリンク先を確認する', async ({ page }, info) => {
  await label(page, /要約・法案メモ/).click();
  const memo = label(page, /法案メモ　飲食料品の消費税と働く人への支援金/);
  await memo.click();
  const plain = label(page, /地方分と合わせて1％/);
  await reveal(page, plain);
  await page.screenshot({ path: info.outputPath('bill-plain.png') });

  const legal = label(page, /^法律用語版$/);
  await reveal(page, legal, -1);
  await legal.click();
  await reveal(page, label(page, /国税の消費税率を0.78％/));
  await page.screenshot({ path: info.outputPath('bill-legal.png') });
  await checkSource(page, '税率についての大臣説明（10月9日）',
    'https://www.fsa.go.jp/common/conference/minister/2026b/20261009-1.html');
  await checkSource(page, '衆議院・提出時の法案本文',
    'https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/honbun/houan/g22209001.htm');
  await checkSource(page, '衆議院・この法案の審議経過',
    'https://www.shugiin.go.jp/internet/itdb_gian.nsf/html/gian/keika/1DE342E.htm');
  await checkSource(page, '衆議院審議中継・田中議員の発言開始位置',
    'https://www.shugiintv.go.jp/jp/index.php?ex=VL&deli_id=56466&time=22942.4');
  const toggle = label(page, /^やわらか版$/);
  await reveal(page, toggle, -1);
  await toggle.click();
  await reveal(page, plain);
});

test('文字拡大、既読切替、検索した次・前の結果を操作する', async ({ page }, info) => {
  const ready = label(page, /既読はログイン利用者別、文字サイズは端末共通/);
  const keyword = page.getByRole('textbox', { name: /テーマ・キーワード/ });
  // The body above this field wraps at the selected font size on both viewports.
  const keywordTop = () => keyword.evaluate(element => element.getBoundingClientRect().top);
  const readKeys = () => page.evaluate(() => Object.keys(localStorage)
    .filter(key => key.includes('diet_debates.v1.read.browser-fixture-owner.speech:')));
  await expect(ready).toBeVisible();
  await expect(keyword).toBeInViewport();
  const standardTop = await keywordTop();
  expect(await readKeys()).toEqual([]);
  await label(page, /本文の文字サイズ/).click();
  await label(page, /^特大$/).click();
  await expect.poll(() => page.evaluate(() =>
    Object.entries(localStorage).some(([key, val]) =>
      key.endsWith('diet_debates.font_size') && Number(JSON.parse(val)) === 24))).toBe(true);
  await expect(ready).toBeVisible();
  await expect.poll(keywordTop).toBeGreaterThan(standardTop + 2);
  const largeTop = await keywordTop();

  async function searchChildcare(): Promise<void> {
    await label(page, /^子育て$/).click();
    const search = page.getByRole('button', { name: '会議録を検索', exact: true }).last();
    await reveal(page, search);
    await search.click();
  }
  await searchChildcare();

  async function atPageStart(start: number): Promise<void> {
    // No reverse scroll or scrollIntoView: the new results must already be visible.
    await expect(label(page, /「子育て」の会議録API検索結果　20件/)).toBeInViewport();
    await expect(label(page, new RegExp('API取得開始位置　' + start + '件目／')))
      .toBeInViewport();
  }
  await atPageStart(1);
  await page.screenshot({ path: info.outputPath('search-large.png') });

  const unread = page.getByRole('button', { name: '発言を既読にする', exact: true }).first();
  await reveal(page, unread);
  await unread.click();
  const read = page.getByRole('button', { name: '発言は既読・未読に戻す', exact: true }).first();
  await expect(read).toBeInViewport();
  await expect.poll(readKeys).toHaveLength(1);
  const marked = await readKeys();
  await page.screenshot({ path: info.outputPath('read-mark.png') });

  await page.reload();
  await expect(ready).toBeVisible();
  await expect(keyword).toBeInViewport();
  await expect.poll(async () => Math.abs(await keywordTop() - largeTop)).toBeLessThanOrEqual(1);
  expect(await readKeys()).toEqual(marked);
  await searchChildcare();
  await atPageStart(1);
  await reveal(page, read);
  await read.click();
  await expect.poll(readKeys).toEqual([]);

  const next = page.getByRole('button', { name: '次の10件', exact: true });
  await reveal(page, next);
  await next.click();
  await atPageStart(11);
  await page.screenshot({ path: info.outputPath('second-page.png') });
  const previous = page.getByRole('button', { name: '前の10件', exact: true });
  await reveal(page, previous);
  await previous.click();
  await atPageStart(1);
  await page.screenshot({ path: info.outputPath('first-page-restored.png') });
});
