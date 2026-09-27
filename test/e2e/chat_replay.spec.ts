import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  test.setTimeout(90_000);
  await page.goto('http://127.0.0.1:7359/');
  await expect(page.getByRole('button', { name: /^発表用サンプル 最終更新/ })).toBeVisible({ timeout: 60_000 });
});

test('saved history presents, rewinds and exits without requests', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('requestfailed', r => errors.push(r.url()));
  page.on('response', r => { if (r.status() >= 500) errors.push(r.url()); });
  await page.getByRole('button', { name: /^発表用サンプル 最終更新/ }).click();
  await page.getByRole('button', { name: '読み込み済みの会話を発表', exact: true }).click();
  await expect(page.getByText('準備ができました', { exact: true })).toBeVisible();
  await expect(page.getByText('会話を一件ずつ紹介したいです。', { exact: true })).not.toBeVisible();
  const calls: string[] = [];
  page.on('request', r => calls.push(`${r.method()} ${r.url()}`));
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).filter(a =>
      a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
  });
  await page.getByRole('button', { name: '次へ', exact: true }).click();
  await expect(page.getByText('会話を一件ずつ紹介したいです。', { exact: true })).toBeVisible();
  for (let i = 0; i < 3; i++) {
    await page.screenshot({ path: info.outputPath(`replay-${i}.png`) });
    await page.waitForTimeout(250);
  }
  await page.keyboard.press('ArrowRight');
  await expect(page.getByText('保存済み回答です。読み出し回数: 1', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: '次へ', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: '前へ', exact: true }).click();
  await page.getByRole('button', { name: '最初に戻す', exact: true }).click();
  await expect(page.getByText('準備ができました', { exact: true })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.getByRole('button', { name: '読み込み済みの会話を発表', exact: true })).toBeVisible();
  expect(calls).toEqual([]);
  expect(errors).toEqual([]);
});

test('empty history disables presentation; another history recovers', async ({ page }) => {
  await page.getByRole('button', { name: /^空の会話 最終更新/ }).click();
  await expect(page.getByRole('button', { name: '読み込み済みの会話を発表', exact: true })).toBeDisabled();
  const back = page.getByRole('button', { name: '履歴一覧へ戻る', exact: true });
  if (await back.isVisible()) await back.click();
  await page.getByRole('button', { name: /^発表用サンプル 最終更新/ }).click();
  await expect(page.getByRole('button', { name: '読み込み済みの会話を発表', exact: true })).toBeEnabled();
});

test('failed read cannot present; reselecting recovers', async ({ page }) => {
  await page.goto('http://127.0.0.1:7359/?fail=true');
  await page.getByRole('button', { name: /^発表用サンプル 最終更新/ }).click();
  await expect(page.getByRole('button', { name: '読み込み済みの会話を発表', exact: true })).toBeDisabled();
  const back = page.getByRole('button', { name: '履歴一覧へ戻る', exact: true });
  if (await back.isVisible()) await back.click();
  await page.getByRole('button', { name: /^発表用サンプル 最終更新/ }).first().click();
  await page.getByRole('button', { name: '読み込み済みの会話を発表', exact: true }).click();
  await expect(page.getByText('準備ができました', { exact: true })).toBeVisible();
});
