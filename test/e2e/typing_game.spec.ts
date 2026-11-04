import { expect, test, type Page } from '@playwright/test';


async function openGame(page: Page) {
  const started = Date.now();
  await page.goto('/');
  // Accessible roles can exist behind the startup shell. Wait for the real handoff.
  await expect(page.locator('#seo-shell')).toHaveCount(0, { timeout: 60_000 });
  test.info().annotations.push({ type: 'synthetic-game-ready-ms', description: String(Date.now() - started) });
}

test('romaji input, scoring, deadline and retry in a browser', async ({ page }, info) => {
  test.setTimeout(100_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await openGame(page);
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
  await expect(page.locator('flt-semantics').getByText('惜しい！次の文字を確認しよう', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('typing-active.png'), fullPage: true });
  await expect(page.getByRole('button', { name: /もう一度挑戦/ })).toBeVisible({ timeout: 65_000 });
  await expect(page.getByText('残り 0秒', { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('typing-result.png'), fullPage: true });
  await page.keyboard.press('Enter');
  await expect(input).toBeVisible();
  await expect(page.getByText('スコア 0', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});


test('ten-word practice finishes and missed words can be practised again', async ({ page }, info) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await openGame(page);
  const practice = page.getByRole('checkbox', { name: '10問じっくり練習', exact: true });
  await expect(practice).toBeVisible({ timeout: 60_000 });
  await practice.click();
  await expect(practice).toBeChecked();
  await page.getByRole('button', { name: /スタート/ }).click();
  const input = page.getByRole('textbox', { name: /^ローマ字入力/ });
  await input.scrollIntoViewIfNeeded();
  await input.focus();
  const guide = await page.getByText(/使えるつづり:/).textContent();
  const missed = guide!.match(/使えるつづり:\s*([a-z]+)/)![1];
  await input.pressSequentially('q');
  for (let word = 1; word <= 10; word++) {
    const text = await page.getByText(/使えるつづり:/).textContent();
    const spelling = text!.match(/使えるつづり:\s*([a-z]+)/)![1];
    await input.pressSequentially(spelling);
    await expect(page.getByText(`クリア ${word}問`, { exact: true })).toBeVisible();
  }
  await expect(page.getByText(/10問完走！/)).toBeVisible();
  await expect(page.getByRole('group', { name: /間違えたことばを振り返ろう/ })).toBeVisible();
  await page.screenshot({ path: info.outputPath('practice-review.png'), fullPage: true });
  await page.getByRole('button', { name: '苦手なことばを練習', exact: true }).click();
  await expect(page.getByText('苦手なことばを10問練習中', { exact: true })).toBeVisible();
  await expect(page.getByText(/使えるつづり:/)).toContainText(missed);
  await input.scrollIntoViewIfNeeded();
  await input.focus();
  await input.pressSequentially(missed);
  await expect(page.getByText('クリア 1問', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '練習を終える', exact: true }).click();
  await expect(page.getByRole('button', { name: /もう一度挑戦/ })).toBeVisible();
  expect(errors).toEqual([]);
});


test('English guidance supports practice and switching back keeps the result', async ({ page }, info) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await openGame(page);
  const language = page.getByRole('button', { name: 'English', exact: true });
  await expect(language).toBeVisible({ timeout: 60_000 });
  await language.click();
  await expect(page.getByRole('heading', { name: 'Kotoba Typing' })).toBeVisible();
  await page.getByRole('checkbox', { name: '10-word practice', exact: true }).click();
  await page.getByRole('button', { name: 'Start (Enter)', exact: true }).click();
  await expect(page.getByRole('button', { name: '日本語', exact: true })).toBeDisabled();
  const input = page.getByRole('textbox', { name: /^Romaji input/ });
  await input.scrollIntoViewIfNeeded();
  await input.focus();
  const guide = await page.getByText(/Accepted spellings:/).textContent();
  const spelling = guide!.match(/Accepted spellings:\s*([a-z]+)/)![1];
  await input.pressSequentially('q');
  await input.pressSequentially(spelling);
  await expect(page.getByText('Words 1', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'End practice', exact: true }).click();
  await expect(page.getByRole('group', { name: /Words to practise/ })).toBeVisible();
  await page.screenshot({ path: info.outputPath('english-practice-result.png'), fullPage: true });
  await page.getByRole('button', { name: '日本語', exact: true }).click();
  await expect(page.getByText('クリア 1問', { exact: true })).toBeVisible();
  await expect(page.getByRole('group', { name: /間違えたことばを振り返ろう/ })).toBeVisible();
  expect(errors).toEqual([]);
});


test('Enter starts ready for typing and browser IME commits score once', async ({ page }, info) => {
  test.setTimeout(90_000);
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await openGame(page);
  await expect(page.getByRole('button', { name: /スタート/ })).toBeVisible({ timeout: 60_000 });
  await page.keyboard.press('Enter');
  const guide = await page.getByText(/使えるつづり:/).textContent({ timeout: 7500 });
  const spelling = guide!.match(/使えるつづり:\s*([a-z]+)/)![1];
  // No explicit input click/focus: the first letter must work after Start.
  await page.keyboard.type(spelling[0]);
  await expect(page.getByText('スコア 10', { exact: true })).toBeVisible();
  const cdp = await page.context().newCDPSession(page);
  const suffix = spelling.slice(1);
  await cdp.send('Input.imeSetComposition', {
    text: suffix, selectionStart: suffix.length, selectionEnd: suffix.length,
  });
  await expect(page.locator('flt-semantics').getByText(/変換中です。英語キーボード/)).toBeVisible();
  await expect(page.getByText('スコア 10', { exact: true })).toBeVisible();
  await cdp.send('Input.insertText', { text: suffix });
  await expect(page.getByText('クリア 1問', { exact: true })).toBeVisible();
  await expect(page.getByText(`スコア ${spelling.length * 10 + 50}`, { exact: true })).toBeVisible();
  await cdp.send('Input.imeSetComposition', { text: 'q', selectionStart: 1, selectionEnd: 1 });
  await cdp.send('Input.imeSetComposition', { text: '', selectionStart: 0, selectionEnd: 0 });
  await expect(page.getByRole('textbox', { name: /^ローマ字入力/ })).toHaveValue('');
  await expect(page.getByText('正確さ 100.0%', { exact: true })).toBeVisible();
  await expect(page.locator('flt-semantics').getByText(/変換中です。英語キーボード/)).not.toBeVisible();
  await cdp.send('Input.imeSetComposition', { text: 'あ', selectionStart: 1, selectionEnd: 1 });
  await cdp.send('Input.insertText', { text: 'あ' });
  await expect(page.getByText('クリア 1問', { exact: true })).toBeVisible();
  await expect(page.getByText(`スコア ${spelling.length * 10 + 50}`, { exact: true })).toBeVisible();
  await page.screenshot({ path: info.outputPath('composed-input.png'), fullPage: true });
  await cdp.detach();
  expect(errors).toEqual([]);
});
