import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  const issues: string[] = [];
  page.on('console', message => {
    if (message.type() === 'error') issues.push(`console: ${message.text()}`);
  });
  page.on('requestfailed', request => issues.push(`request: ${request.url()}`));
  page.on('response', response => {
    if (response.status() >= 500) issues.push(`http: ${response.status()} ${response.url()}`);
  });
  page.on('pageerror', error => issues.push(`page: ${error.message}`));
  (page as any).__echoIssues = issues;
});

test.afterEach(async ({ page }, info) => {
  const issues: string[] = (page as any).__echoIssues;
  await info.attach('browser-issues', {
    body: JSON.stringify(issues), contentType: 'application/json',
  });
  expect(issues).toEqual([]);
});

test('power, escape and retry work in the browser', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'ゲーム開始', exact: true })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('#seo-shell')).toBeHidden();
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  await page.getByRole('button', { name: 'スキップして開始', exact: true }).click();
  const button = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', { name, exact: true });
  await expect(button('A 搬入')).toBeVisible({ timeout: 30000 });
  await page.waitForLoadState('networkidle');
  await expect(page.getByText('管理室', { exact: true }).first()).toBeVisible();
  const exploration = page.getByRole('group').filter({
    has: page.getByRole('button', { name: '保守メモを調べる', exact: true }),
  });
  await expect(exploration.getByText('安全な管理室 / 室内の確認はターンを消費しません。', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('start.png'), fullPage: true });
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).map(animation =>
      animation.finished.catch(() => undefined)));
  });
  // Flutter paints on canvas: capture settled frames as the motion fallback.
  for (let frame = 0; frame < 3; frame++) {
    await page.waitForTimeout(300);
    await page.screenshot({ path: info.outputPath(`frame-${frame}.png`) });
  }
  const click = async (name: string) => {
    await button(name).click();
  };
  for (const label of [
    'B 整備', 'A 搬入', '中央廊下へ', '工具庫へ', 'ヒューズを回収',
    '中央廊下へ', 'ポンプ室へ', 'ヒューズで修理', '中央廊下へ', '管理室へ',
    'B 整備', 'C 排水', '1ターン待つ', '1ターン待つ', '中央廊下へ',
    'ポンプ室へ', '隔壁を閉じる', '排水ポンプを起動', '中央廊下へ', '管理室へ', '出口へ',
  ]) {
    await click(label);
    if (['ヒューズで修理', '隔壁を閉じる', '排水ポンプを起動'].includes(label)) {
      const state = label === 'ヒューズで修理' ? /設備断面：ヒューズ装着済み、隔壁開放、水位高/
        : label === '隔壁を閉じる' ? /設備断面：ヒューズ装着済み、隔壁閉鎖、水位高/
        : /設備断面：ヒューズ装着済み、隔壁閉鎖、水位低下・排水完了/;
      await expect(page.getByRole('img', { name: state })).toBeAttached();
      // Scroll the Flutter canvas itself so the equipment is painted on screen.
      const view = page.viewportSize()!;
      await page.mouse.move(view.width / 2, view.height / 2);
      await page.mouse.wheel(0, 30000);
      await page.waitForTimeout(150);
      await page.screenshot({ path: info.outputPath(`machinery-${label}-transition.png`) });
      await page.waitForTimeout(1200);
      await page.screenshot({ path: info.outputPath(`machinery-${label}.png`) });
    }
    if (label === '隔壁を閉じる') {
      await page.mouse.move(100, 200);
      await page.mouse.wheel(0, -30000);
      await page.waitForTimeout(650);
      await page.screenshot({ path: info.outputPath('character-sealed.png') });
      // Flutter's semantic nodes do not scroll the painted canvas themselves.
      const viewport = page.viewportSize()!;
      await page.mouse.move(viewport.width / 2, viewport.height / 2);
      await page.mouse.wheel(0, 600);
      await page.waitForTimeout(300);
      await page.screenshot({ path: info.outputPath('sealed-map.png'), fullPage: true });
      await page.mouse.wheel(0, -600);
      await page.waitForTimeout(300);
    }
  }
  await expect(button('リトライ')).toBeVisible();
  await page.mouse.move(100, 200);
  await page.mouse.wheel(0, -30000);
  await page.waitForTimeout(650);
  await page.screenshot({ path: info.outputPath('character-escaped.png') });
  await page.screenshot({ path: info.outputPath('escaped.png'), fullPage: true });
  await click('リトライ');
  await expect(button('B 整備')).toBeVisible();
  await page.reload();
  await expect(button('ゲーム開始')).toBeVisible();
  await expect(button('A 搬入')).toHaveCount(0);
  expect(errors).toEqual([]);
});

test('contact failure can recover with retry', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('button', { name: 'ゲーム開始', exact: true })).toBeVisible({ timeout: 30000 });
  await expect(page.locator('#seo-shell')).toBeHidden();
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  await page.getByRole('button', { name: 'スキップして開始', exact: true }).click();
  const button = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', { name, exact: true });
  await expect(button('中央廊下へ')).toBeVisible({ timeout: 30000 });
  await expect(button('出口へ')).toBeDisabled();
  for (let contact = 0; contact < 3; contact++) {
    await button('中央廊下へ').click();
    await button('ポンプ室へ').click();
  }
  await expect(button('リトライ')).toBeVisible();
  await expect(button('1ターン待つ')).toBeDisabled();
  await button('リトライ').click();
  await expect(button('中央廊下へ')).toBeEnabled();
});


test('opening artwork and keyboard start', async ({ page }, info) => {
  await page.goto('/');
  const start = page.getByRole('button', { name: 'ゲーム開始', exact: true });
  await expect(start).toBeVisible({ timeout: 30000 });
  await expect(page.locator('#seo-shell')).toBeHidden();
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).map(animation =>
      animation.finished.catch(() => undefined)));
  });
  for (let frame = 0; frame < 3; frame++) {
    await page.waitForTimeout(300);
    await page.screenshot({ path: info.outputPath(`opening-${frame}.png`), fullPage: true });
  }
  await start.focus();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('button', { name: 'スキップして開始', exact: true })).toBeVisible();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('checkbox', { name: 'A 搬入', exact: true })).toBeVisible();
  await expect(start).toHaveCount(0);
});


test('intro can pause, resume and finish automatically', async ({ page }, info) => {
  test.setTimeout(60000);
  await page.goto('/');
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  await page.getByRole('button', { name: '一時停止', exact: true }).click();
  await page.waitForTimeout(500);
  await page.screenshot({ path: info.outputPath('intro-paused.png') });
  await expect(page.getByRole('checkbox', { name: 'A 搬入', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: '再開', exact: true }).click();
  await page.waitForTimeout(1500);
  await page.screenshot({ path: info.outputPath('intro-first.png') });
  await page.waitForTimeout(6000);
  await page.screenshot({ path: info.outputPath('intro-second.png') });
  await page.waitForTimeout(6000);
  await page.screenshot({ path: info.outputPath('intro-third.png') });
  await expect(page.getByRole('checkbox', { name: 'A 搬入', exact: true })).toBeVisible({ timeout: 15000 });
  await expect(page.getByRole('button', { name: 'スキップして開始', exact: true })).toHaveCount(0);
});


test('character art, locations and threat update with play', async ({ page }, info) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'ゲーム開始', exact: true }).click();
  await page.getByRole('button', { name: 'スキップして開始', exact: true }).click();
  const cast = (label: string) => page.getByText(label, { exact: true }).or(page.getByLabel(label, { exact: true })).first();
  await expect(cast('管理室の探索ビュー')).toBeVisible();
  for (const name of ['character_technician.png', 'character_stalker.png']) {
    const response = await page.request.get(`/assets/assets/echo_pump/${name}`);
    expect(response.ok()).toBeTruthy();
    expect(response.headers()['content-type']).toContain('image/png');
    expect((await response.body()).length).toBeGreaterThan(100000);
  }
  await page.screenshot({ path: info.outputPath('character-start.png') });
  await page.getByRole('checkbox', { name: 'B 整備', exact: true }).click();
  await page.getByRole('checkbox', { name: 'A 搬入', exact: true }).click();
  await page.getByRole('button', { name: '中央廊下へ', exact: true }).click();
  await page.mouse.move(100, 200);
  await page.mouse.wheel(0, -20000);
  await expect(cast('あなた / 保守員：中央廊下、探索中')).toBeVisible();
  await expect(cast('敵 / 音を追う影：搬入区画、接近注意')).toBeVisible();
  await page.waitForTimeout(650);
  await page.screenshot({ path: info.outputPath('character-nearby.png') });
});
