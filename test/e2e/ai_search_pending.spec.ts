import { test, expect, type Page } from '@playwright/test';

const input = (page: Page) => page.getByRole('textbox', { name: /^ノートの検索語/ });
async function search(page: Page, query: string) {
  await input(page).focus();
  await expect(input(page)).toBeFocused();
  await input(page).fill(query);
  await input(page).press('Enter');
}
async function open(page: Page) {
  await page.goto('/');
  await expect(page.getByText('ノート検索', { exact: true })).toBeVisible({ timeout: 60000 });
}

test.beforeEach(async ({ page }) => {
  await open(page);
});

test('latest query wins while prior results remain readable', async ({ page }, info) => {
  await search(page, '最初');
  await expect(page.getByRole('group').filter({ hasText: /^最初 のノート / })).toBeVisible();
  await search(page, '遅い検索');
  await expect(page.getByText('前の結果:「最初」（1件）', { exact: false })).toBeVisible();
  await expect(page.getByRole('group').filter({ hasText: /^最初 のノート / })).toBeVisible();
  await page.screenshot({ path: info.outputPath('previous-results-pending.png') });
  await search(page, '最新');
  await expect(page.getByRole('group').filter({ hasText: /^最新 のノート / })).toBeVisible();
  await page.waitForTimeout(2000);
  await expect(page.getByRole('group').filter({ hasText: /^最新 のノート / })).toBeVisible();
  await expect(page.getByRole('group').filter({ hasText: /^遅い検索 のノート / })).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('latest-result.png') });
});

test('failed search retains prior result and retry recovers', async ({ page }, info) => {
  await search(page, '最初');
  await expect(page.getByRole('group').filter({ hasText: /^最初 のノート / })).toBeVisible();
  await search(page, '失敗から再試行');
  await expect(page.getByText('「失敗から再試行」の検索: 検索できませんでした。通信状態を確認して再試行してください。', { exact: true })).toBeVisible();
  await expect(page.getByRole('group').filter({ hasText: /^最初 のノート / })).toBeVisible();
  await page.screenshot({ path: info.outputPath('failure-preserved.png') });
  await page.getByRole('button', { name: '再試行', exact: true }).click();
  await expect(page.getByRole('group').filter({ hasText: /^失敗から再試行 のノート / })).toBeVisible();
  await page.screenshot({ path: info.outputPath('retry-recovered.png') });
});

test('cleared query stays empty after a late response and can search again', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await search(page, '遅い検索');
  await page.getByRole('button', { name: '検索をクリア', exact: true }).click();
  await page.waitForTimeout(2000);
  await input(page).focus();
  await expect(input(page)).toHaveValue('');
  await expect(page.getByRole('group').filter({ hasText: /^遅い検索 のノート / })).toHaveCount(0);
  await expect(page.getByText('検索語を入力して検索してください', { exact: true })).toBeVisible();
  await search(page, '該当なし');
  await expect(page.getByText('「該当なし」に該当するノートはありません', { exact: true })).toBeVisible();
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).filter(a =>
      a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
  });
  for (let i = 0; i < 3; i++) {
    await page.screenshot({ path: info.outputPath(`empty-${i}.png`) });
    await page.waitForTimeout(250);
  }
  expect(errors).toEqual([]);
});
