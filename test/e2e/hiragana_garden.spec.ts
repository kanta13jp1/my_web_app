import { test, expect } from '@playwright/test';

const route = '/labs/hiragana-garden/index.html';
test('follow all five guides, reset and draw freely without sending strokes', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('requestfailed', r => errors.push(r.url()));
  page.on('response', r => { if (r.status() >= 500) errors.push(String(r.status())); });
  await page.goto(route);
  await expect(page.getByLabel('もじを えらぶ')).toBeEnabled();
  const requests: string[] = [];
  page.on('request', r => requests.push(`${r.method()} ${r.url()}`));
  await page.screenshot({ path: info.outputPath('01-ready.png'), fullPage: true });
  for (const letter of ['く', 'し', 'つ', 'へ', 'の']) {
    await page.getByLabel('もじを えらぶ').selectOption(letter);
    await page.locator('#board').scrollIntoViewIfNeeded();
    const positions = await page.locator('#track').evaluate((node: SVGPathElement) => {
      const length = node.getTotalLength();
      return Array.from({ length: Math.ceil(length / 3) + 1 }, (_, i) => {
        const p = node.getPointAtLength(Math.min(i * 3, length));
        const transformed = new DOMPoint(p.x, p.y).matrixTransform(node.getScreenCTM()!);
        return { x: transformed.x, y: transformed.y };
      });
    });
    await page.mouse.move(positions[0].x, positions[0].y);
    await page.mouse.down();
    for (const [index, p] of positions.entries()) {
      await page.mouse.move(p.x, p.y);
      if (index === Math.floor(positions.length / 2)) {
        await page.mouse.up();
        await expect(page.getByRole('status')).not.toContainText('さいごまで');
        await page.mouse.down();
      }
    }
    await page.mouse.up();
    await expect(page.getByRole('status')).toContainText('さいごまで線をたどれたね');
  }
  await page.screenshot({ path: info.outputPath('02-complete.png'), fullPage: true });
  await page.getByRole('button', { name: 'もういちど', exact: true }).click();
  await expect(page.getByRole('status')).toHaveText('1の丸から、はじめよう。');
  await page.getByLabel('れんしゅうの しかた').selectOption('free');
  await page.locator('#board').scrollIntoViewIfNeeded();
  const box = (await page.locator('#board').boundingBox())!;
  await page.mouse.move(box.x + box.width * .3, box.y + box.height * .4);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width * .6, box.y + box.height * .6, { steps: 10 });
  await page.mouse.up();
  await expect(page.locator('#ink path')).toHaveCount(1);
  await page.screenshot({ path: info.outputPath('03-free.png'), fullPage: true });
  await page.getByRole('button', { name: 'もういちど', exact: true }).click();
  await expect(page.locator('#ink path')).toHaveCount(0);
  expect(requests).toEqual([]);
  expect(errors).toEqual([]);
});

test('wrong start does not complete; reset and keyboard guide recover at narrow width', async ({ page }, info) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto(route);
  await page.locator('#board').scrollIntoViewIfNeeded();
  const box = (await page.locator('#board').boundingBox())!;
  await page.mouse.click(box.x + box.width * .675, box.y + box.height * .8125);
  await expect(page.getByRole('status')).toContainText('ゆっくり続けよう');
  await page.getByRole('button', { name: 'もういちど', exact: true }).click();
  await page.addStyleTag({ content: 'html { font-size: 200%; }' });
  const guide = page.getByRole('button', { name: 'おてほんの順番を見る' });
  await guide.focus();
  await guide.press('Enter');
  await expect(guide).toHaveAttribute('aria-pressed', 'true');
  await expect(page.getByRole('status')).toContainText('これはお手本の表示です');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  for (const control of [guide, page.getByLabel('もじを えらぶ'), page.getByLabel('れんしゅうの しかた')]) {
    expect((await control.boundingBox())!.height).toBeGreaterThanOrEqual(44);
  }
  await page.screenshot({ path: info.outputPath('04-keyboard-large-text.png'), fullPage: true });
});

test('missing JavaScript leaves an honest static fallback', async ({ browser }, info) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto(new URL(route, info.project.use.baseURL as string).href);
  await expect(page.getByText('操作にはJavaScriptが必要です。', { exact: false })).toBeVisible();
  await expect(page.getByLabel('もじを えらぶ')).toBeDisabled();
  await expect(page.getByRole('img', { name: 'く の練習用紙' })).toBeVisible();
  await page.screenshot({ path: info.outputPath('05-no-javascript.png'), fullPage: true });
  await context.close();
});
