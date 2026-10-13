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
  const savings = page.getByRole('textbox', { name: '現在の現金・預金（計画の起点）' });
  await expect(savings).toBeVisible();
  await enterAmount(page, '現在の現金・預金（計画の起点）', '400000');
  await enterAmount(page, '毎月の生活費（食費・交通・日用品等）', '50000');
  await page.getByRole('button', { name: '計画を保存・再計算' }).click();
  await expect(page.getByRole('heading', { name: '必要な積立：月 ¥70,834', exact: true })).toBeVisible();
  await page.getByRole('button', { name: '月ごとの目標と現計画の見込み' }).click();
  await expect(page.getByRole('heading', { name: '2027-10-13 自由資金目標 ¥1,000,000 / 現計画 ¥1,950,000', exact: true })).toBeVisible();
  await enterAmount(page, '今日の生活費合計（計画用メモ）', '1200');
  await page.getByRole('button', { name: '生活費メモを保存', exact: true }).click();
  const morning = page.getByRole('checkbox', { name: '朝：朝食・食器洗い・歯磨き、今日の予定を確認' });
  await morning.click();
  await expect(morning).toBeChecked();
  await page.screenshot({ path: test.info().outputPath('daily-design.png'), fullPage: true });
  await page.reload();
  await savings.click();
  await expect(savings).toHaveValue('400000');
  await expect(page.getByRole('heading', { name: '必要な積立：月 ¥70,834', exact: true })).toBeVisible();
  await expect(morning).toBeChecked();
  await page.getByRole('textbox', { name: '今日の生活費合計（計画用メモ）' }).click();
  await expect(page.getByRole('textbox', { name: '今日の生活費合計（計画用メモ）' })).toHaveValue('1200');
  expect(financialWrites).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test('unaffordable plan shows gap while retaining food and repayment', async ({ page }) => {
  await page.goto('/?income=250000');
  await enterAmount(page, '現在の現金・預金（計画の起点）', '0');
  await expect(page.getByRole('textbox', { name: '登録済みの手取り収入（収入増なし）' })).toHaveAttribute('readonly', /^(readonly)?$/);
  await enterAmount(page, '毎月の生活費（食費・交通・日用品等）', '60000');
  await page.getByRole('button', { name: '計画を保存・再計算' }).click();
  await expect(page.getByRole('heading', { name: '現計画では月 ¥115,000 不足', exact: true })).toBeVisible();
  await expect(page.getByText(/生活費の日割り目安/)).toHaveCount(0);
  await expect(page.getByRole('group', { name: /食事・通勤・医療と返済を守り/ })).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('deficit.png') });
});


test('account analysis proposes reviewable amounts and requires explicit save', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: '口座を分析してAI提案', exact: true }).click();
  await page.getByRole('textbox', { name: '現在の現金・預金（計画の起点）' }).click();
  await expect(page.getByRole('textbox', { name: '現在の現金・預金（計画の起点）' })).toHaveValue('400000');
  await page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' }).click();
  await expect(page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' })).toHaveValue('70000');
  await expect(page.getByText(/架空家計・模擬AI応答/)).toBeVisible();
  await expect(page.getByRole('heading', { name: /必要な積立/ })).toHaveCount(0);
  await page.getByRole('button', { name: '計画を保存・再計算' }).click();
  await expect(page.getByRole('heading', { name: '必要な積立：月 ¥73,334' })).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('ai-proposal.png'), fullPage: true });
});

test('unavailable AI is labelled as a provisional proposal, not an AI success', async ({ page }) => {
  await page.goto('/?ai=error');
  await page.getByRole('button', { name: '口座を分析してAI提案', exact: true }).click();
  await expect(page.getByText('AIを利用できず、仮置き案を表示', { exact: true })).toBeVisible();
  await page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' }).click();
  await expect(page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' })).toHaveValue('60000');
  await expect(page.getByText(/架空家計・模擬AI応答/)).toHaveCount(0);
});
