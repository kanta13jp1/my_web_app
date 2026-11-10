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
  try {
    await expect(header).toBeInViewport({ ratio: 0.99 });
  } catch (original) {
    try {
      if (info.project.name !== 'desktop' && info.project.name !== 'mobile-390') throw Error('Unknown project');
      const name = /KGI: 進み具合/;
      const panels = await panel.count();
      const boundCount = (count: number) => count <= 99 ? count : 'overflow';
      const counts = await Promise.all([
        page.getByRole('button', { name }).count(),
        panel.getByRole('button', { name }).count(),
        panel.getByRole('button', { name, includeHidden: true }).count(),
        panel.getByRole('button').count(),
        panel.getByRole('progressbar').count(),
        panel.getByText(name).count(),
        panel.getByLabel(name).count(),
        page.getByText(name).count(),
        page.getByLabel(name).count(),
      ]);
      // Inspect only single, fixed fixture scope and serialize a bounded enum/boolean projection.
      // Playwright's locator earlier already pierces open shadow roots.
      const states = panels === 1
        ? await panel.evaluate((root) => {
            const known = new Set(['button', 'group', 'progressbar', 'generic', 'none', 'presentation']);
            const roleOf = (el: Element) => {
              const role = el.getAttribute('role');
              return role === null ? 'absent' : known.has(role) ? role : 'other';
            };
            const matches = (value: string | null) => (value ?? '').includes('KGI: 進み具合');
            const all = Array.from(root.querySelectorAll('flt-semantics,button,[role]'));
            const small = [root, ...all.slice(0, 24)];
            return {
              more: all.length > 24,
              nodes: small.map(el => {
                const box = el.getBoundingClientRect();
                return {
                  parent: small.indexOf(el.parentElement as Element),
                  role: roleOf(el),
                  nativeButton: el.tagName === 'BUTTON',
                  labelHasKgi: matches(el.getAttribute('aria-label')),
                  textHasKgi: matches(el.textContent),
                  focusable: (el as HTMLElement).tabIndex >= 0,
                  nonemptyBox: box.width > 0 && box.height > 0,
                };
              }),
            };
          }, undefined, { timeout: 2000 })
        : null;
      console.log('ASSET_PANEL_SEMANTICS_V1 ' + JSON.stringify({
        project: info.project.name === 'desktop' ? 'desktop' : 'mobile-390',
        mode: dark ? 'dark-dense' : 'light',
        panels: boundCount(panels),
        // Order: global named button, scoped named button, scoped named incl. hidden,
        // scoped any button, scoped progressbar, scoped title text/label, global title text/label.
        counts: counts.map(boundCount),
        states,
      }));
    } catch {
      console.log('ASSET_PANEL_SEMANTICS_V1 unavailable');
    }
    // Salvage only the existing initial capture, after a failed acceptance assertion.
    // The original error still propagates; attachment presence never marks this case passed.
    try {
      const url = new URL(page.url());
      const viewport = page.viewportSize();
      const project = info.project.name;
      const knownCase = info.title === (dark
        ? 'dark dense panel paints held ink and expands on release'
        : 'light expanded panel paints its text and responds to keyboard focus');
      const visible = (b: Bounds | null): b is Bounds => Boolean(b && viewport
        && b.width >= 180 && b.height >= 35 && b.height <= 1800
        && b.x >= 0 && b.y >= 0 && b.x + b.width <= viewport.width && b.y + b.height <= viewport.height);
      if (knownCase && (project === 'desktop' || project === 'mobile-390') && url.origin === origin
          && url.pathname === '/' && url.search === (dark ? '?appearance=dark-dense' : '')
          && await panel.count() === 1 && await panel.isVisible()) {
        const before = await panel.boundingBox({ timeout: 2000 });
        if (visible(before)) {
          const png = await panel.screenshot({ scale: 'css', timeout: 2500 });
          const after = await panel.boundingBox({ timeout: 2000 });
          if (visible(after) && png.byteLength <= 4 * 1024 * 1024 && await panel.count() === 1
              && (['x', 'y', 'width', 'height'] as const).every(k => Math.abs(before[k] - after[k]) <= 0.5)) {
            await info.attach(dark ? 'dark-dense-rest' : 'light-expanded', { body: png, contentType: 'image/png' });
          }
        }
      }
    } catch {
      console.log('ASSET_PANEL_DIAGNOSTIC_CROP unavailable');
    }
    throw original;
  }
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
