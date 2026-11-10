import { expect, test, type Locator, type Page, type TestInfo } from '@playwright/test';

const origin = 'http://127.0.0.1:7362';
type Diagnostics = {
  blocked: string[];
  consoleErrors: string[];
  pageErrors: string[];
  popups: number;
};
const diagnostics = new WeakMap<Page, Diagnostics>();

test.beforeEach(async ({ context, page }) => {
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

async function openPanel(page: Page, info: TestInfo, dark: boolean) {
  const mobile = info.project.name === 'mobile-390';
  await page.goto(dark ? '/?appearance=dark-dense' : '/');
  expect(await page.evaluate(() => window.innerWidth)).toBe(mobile ? 390 : 1440);
  await expect(label(page, mobile ? /^表示倍率 1\.6倍$/ : /^表示倍率 1\.0倍$/)).toBeVisible();
  const panel = page.locator('[flt-semantics-identifier="asset-panel-bounds"]');
  const header = panel.getByRole('button', { name: /KGI: 進み具合/ });
  await expect(header).toBeInViewport({ ratio: 0.99 });
  const bounds = await panel.boundingBox();
  if (!bounds || bounds.width < 180 || bounds.height < 35) throw Error('Missing panel bounds');
  expect(bounds.x).toBeGreaterThanOrEqual(0);
  expect(bounds.x + bounds.width).toBeLessThanOrEqual(page.viewportSize()!.width + 0.5);
  return { panel, header, metric: label(page, /KPI: 完了数/), mobile };
}

type Bounds = { x: number; y: number; width: number; height: number };
type Frame = { image: string; before: Bounds; after: Bounds };

async function capture(panel: Locator, info: TestInfo, name: string): Promise<Frame> {
  const before = await panel.boundingBox();
  const png = await panel.screenshot({ scale: 'css' });
  const after = await panel.boundingBox();
  if (!before || !after) throw Error('Panel disappeared while capturing ' + name);
  await info.attach(name, { body: png, contentType: 'image/png' });
  return { image: png.toString('base64'), before, after };
}

// Read the composited screenshot, including CanvasKit pixels and the clipped edges.
async function paint(page: Page, baseline: Frame, current: Frame, dark: boolean) {
  const bounds = [baseline.before, baseline.after, current.before, current.after];
  for (const key of ['x', 'y', 'width', 'height'] as const) {
    const values = bounds.map(box => box[key]);
    expect(Math.max(...values) - Math.min(...values), 'capture bounds: ' + key)
      .toBeLessThanOrEqual(0.5);
  }
  return page.evaluate(async input => {
    async function rgba(image: string) {
      const bitmap = new Image();
      bitmap.src = 'data:image/png;base64,' + image;
      await bitmap.decode();
      const surface = document.createElement('canvas');
      surface.width = bitmap.naturalWidth;
      surface.height = bitmap.naturalHeight;
      const ctx = surface.getContext('2d')!;
      ctx.drawImage(bitmap, 0, 0);
      return ctx.getImageData(0, 0, surface.width, surface.height);
    }
    const a = await rgba(input.baseline);
    const b = await rgba(input.current);
    if (a.width !== b.width || a.height !== b.height) throw Error('Panel moved during input');
    const text = input.dark ? [255, 255, 255] : [15, 23, 42];
    const accent = [15, 118, 110];
    let titlePixels = 0, accentPixels = 0, changed = 0, cornerChanges = 0;
    const radius = input.dark ? 10 : 12;
    for (let y = 0; y < Math.min(90, a.height); y++) {
      for (let x = 0; x < a.width; x++) {
        const i = (y * a.width + x) * 4;
        const near = (color: number[]) => color.every((v, c) => Math.abs(a.data[i + c] - v) <= 8);
        if (x >= 40 && x < a.width - 40 && near(text)) titlePixels++;
        if (near(accent)) accentPixels++;
        const diff = Math.max(...[0, 1, 2].map(c => Math.abs(a.data[i + c] - b.data[i + c])));
        if (diff >= 6) {
          if (x >= 4 && x < a.width - 4 && y >= 3) changed++;
          // Exclude the antialiased border, sample both top corners well outside the radius.
          const dx = radius - Math.min(x + 0.5, a.width - x - 0.5);
          const dy = radius - y - 0.5;
          if (dx > 0 && dy > 0 && Math.hypot(dx, dy) > radius + 1.5) cornerChanges++;
        }
      }
    }
    return { titlePixels, accentPixels, changed, cornerChanges };
  }, { baseline: baseline.image, current: current.image, dark });
}

test('light expanded panel paints its text and responds to keyboard focus', async ({ page }, info) => {
  const { panel, metric, header } = await openPanel(page, info, false);
  await expect(metric).toBeInViewport();
  const before = await capture(panel, info, 'light-expanded');
  await page.keyboard.press('Tab');
  // Allow Flutter's focus-layer animation to settle before comparing the composited frame.
  await page.waitForTimeout(350);
  const focused = await capture(panel, info, 'light-focused');
  const pixels = await paint(page, before, focused, false);
  expect(pixels.titlePixels).toBeGreaterThan(15);
  expect(pixels.accentPixels).toBeGreaterThan(10);
  expect(pixels.changed).toBeGreaterThan(25);
  expect(pixels.cornerChanges).toBe(0);
  await page.keyboard.press('Enter');
  await expect(metric).toHaveCount(0);
  await expect(header).toBeInViewport();
  await page.keyboard.press('Enter');
  await expect(metric).toBeInViewport();
});

test('dark dense panel paints held ink and expands on release', async ({ page }, info) => {
  const { panel, header, metric, mobile } = await openPanel(page, info, true);
  await expect(metric).toHaveCount(0);
  const box = await header.boundingBox();
  if (!box) throw Error('Missing hit target');
  const x = box.x + 8, y = box.y + 8;
  if (!mobile) {
    await page.mouse.move(x, y);
    // Capture the settled hover state so hover alone cannot satisfy the ink check.
    await page.waitForTimeout(350);
  }
  const before = await capture(panel, info, 'dark-dense-rest');
  const touch = mobile ? await page.context().newCDPSession(page) : null;
  let held: Frame;
  if (touch) {
    await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
  } else {
    await page.mouse.down();
  }
  try {
    await page.waitForTimeout(180);
    held = await capture(panel, info, 'dark-dense-held');
  } finally {
    if (touch) {
      try {
        await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } finally {
        await touch.detach();
      }
    } else {
      await page.mouse.up();
    }
  }
  const pixels = await paint(page, before, held, true);
  expect(pixels.titlePixels).toBeGreaterThan(15);
  expect(pixels.accentPixels).toBeGreaterThan(10);
  expect(pixels.changed).toBeGreaterThan(25);
  expect(pixels.cornerChanges).toBe(0);
  await expect(metric).toBeInViewport();
  await capture(panel, info, 'dark-dense-expanded');
  if (mobile) await header.tap(); else await header.click();
  await expect(metric).toHaveCount(0);
});
