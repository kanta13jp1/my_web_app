import { test, expect, type Page } from '@playwright/test';

const input = (page: Page) => page.getByRole('textbox', { name: /^ノートの検索語/ });
async function search(page: Page, query: string) {
  await input(page).focus();
  await expect(input(page)).toBeFocused();
  await input(page).fill(query);
  await expect(input(page)).toHaveValue(query);
  await input(page).press('Enter');
}
async function open(page: Page) {
  await page.goto('/');
  await expect(page.getByText('ノート検索', { exact: true })).toBeVisible({ timeout: 60000 });
}

test.afterEach(async ({ page }, info) => {
  if (info.status !== info.expectedStatus) {
    await info.attach('visible-dom', { body: await page.content(), contentType: 'text/html' });
  }
});

test.beforeEach(async ({ page }) => {
  await open(page);
});

test('latest query wins while prior results remain readable', async ({ page }, info) => {
  await search(page, '最初');
  await expect(page.getByRole('button').filter({ hasText: '最初 のノート' })).toBeVisible();
  await search(page, '遅い検索');
  await expect(page.getByText('前の結果:「最初」（1件）', { exact: false })).toBeVisible();
  await expect(page.getByRole('button').filter({ hasText: '最初 のノート' })).toBeVisible();
  await page.screenshot({ path: info.outputPath('previous-results-pending.png') });
  await search(page, '最新');
  await expect(page.getByRole('button').filter({ hasText: '最新 のノート' })).toBeVisible();
  await page.waitForTimeout(2000);
  await expect(page.getByRole('button').filter({ hasText: '最新 のノート' })).toBeVisible();
  await expect(page.getByRole('button').filter({ hasText: '遅い検索 のノート' })).toHaveCount(0);
  await page.screenshot({ path: info.outputPath('latest-result.png') });
});

test('failed search retains prior result and retry recovers', async ({ page }, info) => {
  await search(page, '最初');
  await expect(page.getByRole('button').filter({ hasText: '最初 のノート' })).toBeVisible();
  await search(page, '失敗から再試行');
  await expect(page.locator('flt-semantics').getByText('「失敗から再試行」の検索: 検索できませんでした。通信状態を確認して再試行してください。', { exact: true })).toBeVisible();
  await expect(page.getByRole('button').filter({ hasText: '最初 のノート' })).toBeVisible();
  await page.screenshot({ path: info.outputPath('failure-preserved.png') });
  await page.getByRole('button', { name: '再試行', exact: true }).click();
  await expect(page.getByRole('button').filter({ hasText: '失敗から再試行 のノート' })).toBeVisible();
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
  await expect(page.getByRole('button').filter({ hasText: '遅い検索 のノート' })).toHaveCount(0);
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


test('a result opens its note and back preserves the search', async ({ page }, info) => {
  await search(page, '最初');
  await page.getByRole('button').filter({ hasText: '最初 のノート' }).click();
  await expect(page.getByText('保存ノートを開いた画面', { exact: true })).toBeVisible();
  await expect(page.getByText('保存された本文: fixture-最初', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('opened-note.png') });
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await expect(page.getByText('「最初」の結果（1件）', { exact: true })).toBeVisible();
  await expect(input(page)).toHaveValue('最初');
});

test('a guest can search a sample and open it without logging in', async ({ page }, info) => {
  await page.goto('/?guest=1');
  await expect(page.getByRole('button', { name: 'ログインして検索', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: '検索', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'ログインして検索', exact: true }).click();
  await expect(page.getByText('ログイン入口', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('button', { name: 'サンプルで試す', exact: true }).click();
  await search(page, '買い物');
  await expect(page.getByRole('button').filter({ hasText: '週末の買い物' })).toBeVisible();
  await page.screenshot({ path: info.outputPath('guest-sample-search.png') });
  await page.getByRole('button').filter({ hasText: '週末の買い物' }).click();
  await expect(page.getByText('架空のノート・閲覧専用', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('guest-sample-open.png') });
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await expect(page.getByText('「買い物」の結果（1件）', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '自分のノートに戻る', exact: true }).click();
  await expect(page.getByRole('button', { name: 'ログインして検索', exact: true })).toBeVisible();
});
