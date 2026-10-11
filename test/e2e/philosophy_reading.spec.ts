import { test, expect, type Page, type TestInfo } from '@playwright/test';

async function field(page: Page, name: RegExp, value: string) {
  const input = page.getByRole('textbox', { name });
  await expect(input).toHaveCount(1);
  await input.focus();
  // Flutter connects the browser input to its controller on the next frame.
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await input.fill(value);
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await expect(input).toHaveValue(value);
}
async function capture(page: Page, info: TestInfo, name: string) {
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).filter(a => a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
  });
  for (let i = 0; i < 3; i++) {
    await page.screenshot({ path: info.outputPath(`${name}-${i}.png`) });
    await page.waitForTimeout(200);
  }
}
async function openWork(page: Page, title: string) {
  await page.getByRole('tab', { name: '著作', exact: true }).click();
  await expect(page.getByRole('button', { name: '著者を追加', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: '著作を追加', exact: true })).toBeVisible();
  await field(page, /^著者・著作を検索/, title);
  await page.getByRole('button', { name: new RegExp(`^${title} `) }).click();
}

test.setTimeout(60000);

test.beforeEach(async ({ request }) => {
  const reset = await request.post('http://127.0.0.1:7359', { data: { action: 'fixture.reset' } });
  expect(reset.ok()).toBeTruthy();
});

test('record pages, understanding and impression persists across reload; reread keeps one completed work', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '国家');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^総ページ数/, '100');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: '記録を追加', exact: true }).click();
  await field(page, /^開始ページ/, '1'); await field(page, /^終了ページ/, '10');
  await field(page, /^感想/, '正義の意味を考えた');
  await page.getByRole('button', { name: /未評価/ }).click();
  await page.getByRole('menuitem', { name: '3 要点を理解した', exact: true }).click();
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 正義の意味を考えた/ }).last()).toBeVisible();
  await page.getByRole('button', { name: '読了にする', exact: true }).click();
  await expect(page.getByRole('group', { name: /状態: 読了\（読了は手動で設定\）/ }).last()).toBeVisible();
  await capture(page, info, 'saved-record');
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '国家');
  await expect(page.getByRole('group', { name: /感想: 正義の意味を考えた/ }).last()).toBeVisible();
  await page.getByRole('button', { name: '別の版・再読を始める', exact: true }).click();
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /第2回/ }).last()).toBeVisible();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('tab', { name: '進捗', exact: true }).click();
  await expect(page.getByRole('button', { name: '著作を追加', exact: true })).toHaveCount(0);
  await expect(page.getByRole('tabpanel')).toHaveCount(1);
  await expect(page.getByRole('tabpanel')).toMatchAriaSnapshot(`
- tabpanel:
  - group:
    - text: /.*収録済み著作全体.*読了 1 . 17 著作.*/
`);
  await capture(page, info, 'progress');
  expect(errors).toEqual([]);
});

test('invalid page range and failed save preserve input; retry, edit history and deletion work', async ({ page }, info) => {
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '省察');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^総ページ数/, '20');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.getByRole('button', { name: '記録を追加', exact: true }).click();
  await field(page, /^開始ページ/, '1'); await field(page, /^終了ページ/, '30');
  await field(page, /^感想/, '失敗して再試行');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('総ページ数を超えています', { exact: true })).toBeVisible();
  await field(page, /^終了ページ/, '10');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('保存できませんでした。入力を保持しています。再試行してください', { exact: true }).first()).toBeVisible();
  await field(page, /^感想/, '失敗して再試行');
  await capture(page, info, 'failure-kept-input');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 失敗して再試行/ }).last()).toBeVisible();
  await page.getByRole('button', { name: '記録を編集', exact: true }).click();
  await field(page, /^感想/, '読み直して理解した');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 読み直して理解した.*編集前の記録（1件）/ }).last()).toBeVisible();
  await capture(page, info, 'edit-history');
  await page.getByRole('button', { name: '記録を削除', exact: true }).click();
  await page.getByRole('button', { name: '削除', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 読み直して理解した/ }).last()).toHaveCount(0);
});

test('guest author-to-work navigation, compound filters, empty state and keyboard input', async ({ page }, info) => {
  await page.goto('/?guest=1');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await page.getByRole('button', { name: /^プラトン / }).click();
  await expect(page.getByRole('button', { name: /^国家 / })).toBeVisible();
  await page.getByRole('button', { name: /^国家 / }).click();
  await expect(page.getByRole('button', { name: '読書を始める', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('button', { name: '分類を解除', exact: true }).click();
  await page.getByRole('button', { name: /成立世紀/ }).click();
  await page.getByRole('menuitem', { name: '紀元前4世紀', exact: true }).click();
  await page.getByRole('button', { name: /国／地域/ }).click();
  await page.getByRole('menuitem', { name: '古代ギリシア', exact: true }).click();
  await page.getByRole('button', { name: /ジャンル/ }).click();
  await page.getByRole('menuitem', { name: '政治哲学', exact: true }).click();
  await expect(page.getByRole('button', { name: /^国家 / })).toBeVisible();
  await expect(page.getByRole('button', { name: /^論語 / })).toHaveCount(0);
  await field(page, /^著者・著作を検索/, '該当しない著作');
  await page.getByRole('textbox', { name: /^著者・著作を検索/ }).press('Tab');
  await expect(page.getByText('条件に一致する著作はありません', { exact: true })).toBeVisible();
  await capture(page, info, 'guest-empty');
});
