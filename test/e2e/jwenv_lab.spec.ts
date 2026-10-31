import { test, expect } from '@playwright/test';

const path = '/labs/jwenv/index.html';
test.beforeEach(async ({ page }) => {
  await page.goto(path);
  await page.locator('[data-lang="ja"]').click();
  await expect(page.locator('#input-check')).toContainText('入力形式OK');
});

test('model-free input check renders and remains usable in both languages', async ({ page }, info) => {
  await expect(page.locator('h1')).toHaveText('Jev WebGPU Demo');
  await expect(page.locator('#model-file')).toBeVisible();
  await expect(page.locator('#run')).toBeDisabled();
  await expect(page.locator('#input-check')).toContainText('4問');
  await page.locator('#tab-request').click();
  await expect(page.locator('#json-req')).toContainText('jev-latest');
  await page.locator('[data-lang="en"]').click();
  await expect(page.locator('#input-check')).toContainText('Input format OK');
  await page.locator('[data-lang="ja"]').click();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBeTruthy();
  await page.screenshot({path:info.outputPath('jwenv-valid.png'),fullPage:true});
});

test('ninth option is explained before model loading and eight options recover', async ({ page }, info) => {
  const requests: string[] = [];
  page.on('request', r => { if (r.postData()) requests.push(r.postData()!); });
  const choices = page.locator('.qcard').nth(1).locator('.q-crit');
  const options = Array.from({length:9},(_, i) => `option${i}`);
  await choices.fill(options.join('\n'));
  await expect(page.locator('#input-check')).toContainText('選択肢は最大8個');
  await expect(page.locator('#run')).toBeDisabled();
  await page.locator('#input-check').scrollIntoViewIfNeeded();
  await page.screenshot({path:info.outputPath('jwenv-nine-options.png'),fullPage:true});
  await choices.fill(options.slice(0,8).join('\n'));
  await expect(page.locator('#input-check')).toContainText('入力形式OK');
  await page.locator('#tab-request').click();
  await expect(page.locator('#json-req')).toContainText('option7');
  await expect(page.locator('#json-req')).not.toContainText('option8');
  await page.locator('#state').fill('jwenv-preflight-private-sentinel');
  expect(requests.some(body => body.includes('jwenv-preflight-private-sentinel'))).toBeFalsy();
  await page.screenshot({path:info.outputPath('jwenv-recovered.png'),fullPage:true});
});

test('duplicate question or option is not silently overwritten; empty question recovers', async ({ page }, info) => {
  const card = page.locator('.qcard').nth(1);
  await card.locator('.q-id').fill('is_angry');
  await expect(page.locator('#input-check')).toContainText('質問IDが重複');
  await card.locator('.q-id').fill('emotion');
  await card.locator('.q-crit').fill('food: 食費\nfood: 飲食\ntransport: 交通');
  await expect(page.locator('#input-check')).toContainText('選択肢名が重複');
  await page.locator('#tab-request').click();
  await expect(page.locator('#json-req')).toContainText('duplicate_option');
  await card.locator('.q-crit').fill('food: 食費\ntransport: 交通');
  await expect(page.locator('#input-check')).toContainText('入力形式OK');
  await page.locator('#add-question').click();
  await expect(page.locator('.qcard')).toHaveCount(5);
  await expect(page.locator('#input-check')).toContainText('判定したい内容');
  await page.locator('.qcard').last().locator('.q-del').click();
  await expect(page.locator('#input-check')).toContainText('入力形式OK');
  await page.screenshot({path:info.outputPath('jwenv-duplicate-recovered.png'),fullPage:true});
});
