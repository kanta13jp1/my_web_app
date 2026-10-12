import { test, expect, type Page } from '@playwright/test';

async function enterAmount(page: Page, name: string, value: string) {
  const input = page.getByRole('textbox', { name });
  await input.click();
  await input.press('ControlOrMeta+A');
  await input.pressSequentially(value, { delay: 20 });
  await expect(input).toHaveValue(value);
  await input.press('Tab');
}


test('savings goal, daily design, and reload preserve planning values without financial writes', async ({ page }) => {
  const financialWrites: string[] = [];
  const pageErrors: string[] = [];
  page.on('request', request => {
    if (/supabase|\/rest\/v1\//.test(request.url()) && !['GET', 'HEAD', 'OPTIONS'].includes(request.method())) {
      financialWrites.push(`${request.method()} ${request.url()}`);
    }
  });
  page.on('pageerror', error => pageErrors.push(error.message));
  await page.goto('/');
  const savings = page.getByRole('textbox', { name: '目標用の現在貯蓄残高' });
  await expect(savings).toBeVisible();
  await enterAmount(page, '目標用の現在貯蓄残高', '400000');
  await enterAmount(page, '毎月の生活費（食費・交通・日用品等）', '50000');
  await page.getByRole('button', { name: '計画を保存・再計算' }).click();
  await expect(page.getByText('必要な積立：月 ¥50,000', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '月ごとの目標と現計画の見込み' }).click();
  await expect(page.getByText('2027-10-13', { exact: true })).toBeVisible();
  await expect(page.getByText('目標 ¥1,000,000 / 現計画 ¥2,200,000', { exact: true })).toBeVisible();
  await enterAmount(page, '今日の生活費合計（計画用メモ）', '1200');
  await page.getByRole('button', { name: '生活費メモを保存', exact: true }).click();
  const morning = page.getByRole('checkbox', { name: '朝：朝食・食器洗い・歯磨き、今日の予定を確認' });
  await morning.check();
  await expect(morning).toBeChecked();
  await page.screenshot({ path: test.info().outputPath('daily-design.png'), fullPage: true });
  await page.reload();
  await expect(savings).toHaveValue('400000');
  await expect(page.getByText('必要な積立：月 ¥50,000', { exact: true })).toBeVisible();
  await expect(morning).toBeChecked();
  await expect(page.getByRole('textbox', { name: '今日の生活費合計（計画用メモ）' })).toHaveValue('1200');
  expect(financialWrites).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test('unaffordable plan shows gap while retaining food and repayment', async ({ page }) => {
  await page.goto('/');
  await enterAmount(page, '目標用の現在貯蓄残高', '0');
  await enterAmount(page, '今後の毎月の手取り収入（計画値）', '250000');
  await enterAmount(page, '毎月の生活費（食費・交通・日用品等）', '60000');
  await page.getByRole('button', { name: '計画を保存・再計算' }).click();
  await expect(page.getByText('現計画では月 ¥93,334 不足', { exact: true })).toBeVisible();
  await expect(page.getByText(/生活費の日割り目安/)).toHaveCount(0);
  await expect(page.getByText(/食事や通勤費を削って合わせず/)).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('deficit.png') });
});
