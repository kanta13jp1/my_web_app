import { expect, test, type Locator, type Page } from '@playwright/test';

const origin = 'http://127.0.0.1:7362';
type Diagnostics = {
  blocked: string[];
  consoleErrors: string[];
  pageErrors: string[];
  popups: number;
};
const diagnostics = new WeakMap<Page, Diagnostics>();

test.beforeEach(async ({ context, page }, info) => {
  const seen: Diagnostics = { blocked: [], consoleErrors: [], pageErrors: [], popups: 0 };
  diagnostics.set(page, seen);
  context.on('page', () => seen.popups++);
  page.on('pageerror', error => seen.pageErrors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') seen.consoleErrors.push(message.text());
  });
  await context.route('**/*', async route => {
    const url = new URL(route.request().url());
    if (url.origin === origin || url.protocol === 'data:' || url.protocol === 'blob:') {
      await route.continue();
    } else {
      seen.blocked.push(url.origin);
      await route.abort('blockedbyclient');
    }
  });
  await context.routeWebSocket('**/*', socket => {
    seen.blocked.push('websocket');
    socket.close();
  });
  await page.goto('/');
  const mobile = info.project.name === 'mobile-390';
  expect(await page.evaluate(() => window.innerWidth)).toBe(mobile ? 390 : 1440);
  await expect(label(page, mobile ? /^表示倍率 1\.6倍$/ : /^表示倍率 1\.0倍$/)).toBeVisible();
});

test.afterEach(async ({ page }, info) => {
  const seen = diagnostics.get(page);
  if (seen && (seen.blocked.length || seen.consoleErrors.length || seen.pageErrors.length || seen.popups)) {
    await info.attach('browser-diagnostics', {
      body: JSON.stringify(seen),
      contentType: 'application/json',
    });
  }
  expect(seen).toEqual({ blocked: [], consoleErrors: [], pageErrors: [], popups: 0 });
  expect(new URL(page.url()).origin).toBe(origin);
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

async function clickButton(page: Page, text: string, direction = 1): Promise<void> {
  const button = page.getByRole('button', { name: text, exact: true });
  await reveal(page, button, direction);
  await button.click();
}

async function top(page: Page): Promise<void> {
  await reveal(page, label(page, /^給与プレビューの合成画面試験$/), -1);
}

test('合成解析の表示と訂正、閉鎖・再表示で入力を破棄する', async ({ page }, info) => {
  const net = label(page, /手取り額（円）\s+解析値\s+37$/);
  const draft = label(page, /^訂正候補\s+41$/);
  await reveal(page, label(page, /^給与明細の解析プレビュー$/));
  await reveal(page, label(page, /今回の解析結果・訂正候補は未登録です。/));
  await reveal(page, label(page, /閉じると画面内の訂正候補は消え、保管済みのPDFは残ります。/));
  await reveal(page, label(page, /総支給額（円）\s+解析値\s+未読取・要確認$/));
  await reveal(page, net);
  await reveal(page, label(page, /課税対象額（円）\s+解析値\s+0$/));
  await reveal(page, label(page, /社会保険料合計（円）\s+解析値\s+未読取・要確認$/));
  await expect(label(page, /非表示の試験用(警告原文|抽出本文)/)).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('synthetic-values.png') });

  await clickButton(page, '訂正候補を入力');
  const field = page.getByRole('textbox', { name: /手取り額（円）の訂正候補/ });
  await top(page);
  await reveal(page, field);
  await field.click();
  await expect(field).toBeFocused();
  await field.fill('41');
  await expect(field).toHaveValue('41');
  await clickButton(page, '訂正候補を見直す');
  await reveal(page, net, -1);
  await reveal(page, draft);
  await page.screenshot({ path: info.outputPath('unsaved-draft.png') });

  await clickButton(page, '入力を破棄して閉じる');
  await top(page);
  await expect(label(page, /^画面内の入力を破棄しました$/)).toBeVisible();
  await clickButton(page, '正常な合成応答を表示');
  await reveal(page, net);
  await expect(draft).toHaveCount(0);
  await page.reload();
  await reveal(page, net);
  await expect(draft).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('reopened-synthetic.png') });
});

test('所有者・保管先が違う応答と旧形式をそれぞれ拒否する', async ({ page }, info) => {
  const rawValue = label(page, /手取り額（円）\s+解析値\s+37$/);
  for (const name of ['別の所有者の応答', '異なる保管先の応答', '旧形式の応答']) {
    await reveal(page, rawValue);
    await top(page);
    await clickButton(page, name);
    await expect(label(page, /^応答を拒否しました$/)).toBeVisible();
    await expect(label(page, /^給与明細の解析プレビュー$/)).toHaveCount(0);
    await expect(rawValue).toHaveCount(0);
    await expect(page.getByRole('button', { name: '訂正候補を入力', exact: true })).toHaveCount(0);
    if (name === '旧形式の応答') {
      await page.screenshot({ path: info.outputPath('legacy-rejected.png') });
    }
    await clickButton(page, '正常な合成応答を表示');
  }
});
