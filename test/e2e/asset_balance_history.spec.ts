import { test, expect, type Page, type TestInfo } from '@playwright/test';

test.use({ timezoneId: 'Asia/Tokyo' });
const browserIssues = new WeakMap<Page, string[]>();

test.beforeEach(async ({ page }, info) => {
  const issues: string[] = [];
  browserIssues.set(page, issues);
  page.on('pageerror', error => issues.push(`page: ${error.message}`));
  page.on('console', message => {
    if (message.type() === 'error') issues.push(`console: ${message.text()}`);
  });
  page.on('requestfailed', request => issues.push(`request: ${request.url()}`));
  page.on('response', response => {
    if (response.status() >= 500) issues.push(`HTTP ${response.status()}: ${response.url()}`);
  });
});

test.afterEach(async ({ page }, info) => {
  await info.attach('browser-issues', {
    body: JSON.stringify(browserIssues.get(page) ?? []),
    contentType: 'application/json',
  });
});

async function capture(page: Page, info: TestInfo, name: string) {
  await page.waitForFunction(() => document.body.getAnimations({ subtree: true }).every(animation => animation.playState !== 'running'));
  await page.screenshot({ path: info.outputPath(`${name}.png`) });
  for (let frame = 0; frame < 3; frame++) {
    await page.screenshot({ path: info.outputPath(`${name}-frame-${frame}.png`) });
    await page.waitForTimeout(250);
  }
}

test('shows minute timestamps and distinct same-day history without writes', async ({ page }, info) => {
  const financialWrites: string[] = [];
  page.on('request', request => {
    if (/\/rest\/v1\/(cfo_assets|wealth_struggles)/.test(request.url()) &&
        !['GET', 'HEAD', 'OPTIONS'].includes(request.method())) {
      financialWrites.push(request.method());
    }
  });
  await page.goto('/');
  await expect(page.getByRole('button', { name: '残高履歴', exact: true })).toBeVisible({ timeout: 30000 });
  await expect(page.getByText('残高日時 2026-10-11 17:44 JST', { exact: true })).toBeVisible();
  await capture(page, info, 'balance-timestamp');
  await page.getByRole('button', { name: '残高履歴', exact: true }).focus();
  await page.keyboard.press('Enter');
  await expect(page.getByText('サンプル銀行の残高履歴', { exact: true })).toBeVisible();
  for (const timestamp of ['2026-10-11 17:44 JST', '2026-10-11 02:18 JST', '2026-10-09 17:39 JST']) {
    await expect(page.getByRole('group', { name: new RegExp(timestamp) })).toBeVisible();
  }
  await expect(page.getByRole('group', { name: /JST.*¥12,000/ })).toHaveCount(2);
  await expect(page.getByRole('group', { name: /2026-10-09 17:39 JST.*¥-5,000/ })).toBeVisible();
  await capture(page, info, 'balance-history');
  await page.getByRole('button', { name: '閉じる', exact: true }).click();
  await expect(page.getByText('サンプル銀行の残高履歴', { exact: true })).toHaveCount(0);
  expect(financialWrites).toEqual([]);
});

test('failed history load can retry without changing the latest timestamp', async ({ page }, info) => {
  await page.goto('/?history=error');
  await page.getByRole('button', { name: '残高履歴', exact: true }).click();
  await expect(page.getByText('履歴を読み込めませんでした。', { exact: true })).toBeVisible();
  await capture(page, info, 'history-error');
  await page.getByRole('button', { name: '再試行', exact: true }).click();
  await expect(page.getByRole('group', { name: /2026-10-11 02:18 JST.*¥12,000/ })).toBeVisible();
  await capture(page, info, 'history-recovered');
});

test('empty history explains that no records exist', async ({ page }, info) => {
  await page.goto('/?history=empty');
  await page.getByRole('button', { name: '残高履歴', exact: true }).click();
  await expect(page.getByText('残高履歴はありません。', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'さらに読み込む', exact: true })).toHaveCount(0);
  await capture(page, info, 'history-empty');
});
