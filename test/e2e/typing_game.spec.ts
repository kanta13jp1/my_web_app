import { expect, test } from '@playwright/test';

test('romaji input, scoring, deadline and retry in a browser', async ({ page }, info) => {
  test.setTimeout(100_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/');
  await expect(page.getByRole('button', { name: /スタート/ })).toBeVisible({ timeout: 60_000 });
  await page.getByRole('button', { name: /スタート/ }).click();
  const input = page.getByRole('textbox', { name: /^ローマ字入力/ });
  await input.scrollIntoViewIfNeeded();
  await input.focus();
  // Flutter Card merges its child text into one semantics node.
  const guide = await page.getByText(/使えるつづり:/).textContent({ timeout: 7500 });
  const spelling = guide!.match(/使えるつづり:\s*([a-z]+)/)![1];
  await input.pressSequentially(spelling);
  await expect(page.getByText('クリア 1問', { exact: true })).toBeVisible();
  await expect(page.getByText(`スコア ${spelling.length * 10 + 50}`, { exact: true })).toBeVisible();
  await input.pressSequentially('q');
  await expect(page.getByText('惜しい！次の文字を確認しよう', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('typing-active.png'), fullPage: true });
  await expect(page.getByRole('button', { name: /もう一度挑戦/ })).toBeVisible({ timeout: 65_000 });
  await expect(page.getByText('残り 0秒', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('typing-result.png'), fullPage: true });
  await page.keyboard.press('Enter');
  await expect(input).toBeVisible();
  await expect(page.getByText('スコア 0', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});
