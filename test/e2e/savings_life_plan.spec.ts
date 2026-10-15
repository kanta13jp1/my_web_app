import { test, expect, type Page, type Locator } from '@playwright/test';


// Scroll the actual Flutter viewport before clicking. DOM auto-scroll can move
// the semantics proxy without moving the painted canvas on mobile.
async function clickVisible(page: Page, target: Locator) {
  await expect(target).toBeVisible();
  const viewport = page.viewportSize()!;
  let box = (await target.boundingBox())!;
  if (box.y < 80 || box.y + box.height > viewport.height - 80) {
    await page.mouse.move(viewport.width / 2, viewport.height / 2);
    await page.mouse.wheel(0, box.y - viewport.height / 2);
    await expect(target).toBeInViewport();
    await page.evaluate(() => new Promise<void>(resolve =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
    box = (await target.boundingBox())!;
  }
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
}

async function enterAmount(page: Page, name: string, value: string) {
  const input = page.getByRole('textbox', { name });
  await clickVisible(page, input);
  await expect(input).toBeFocused();
  await input.press('End');
  await input.press('ControlOrMeta+A');
  await input.pressSequentially(value, { delay: 80 });
  await expect(input).toHaveValue(value);
  await input.press('Tab');
}



async function configureGoal(page: Page) {
  await expect(page.getByRole('group', { name: /目標は未設定です。目的・金額・期限を入力してください。/ })).toBeVisible();
  await enterAmount(page, '目標額', '1000000');
  await clickVisible(page, page.getByRole('button', { name: '目標期限を設定', exact: true }));
  await clickVisible(page, page.getByRole('button', { name: 'OK', exact: true }));
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
  await configureGoal(page);
  const savings = page.getByRole('textbox', { name: '現在の現金・預金（計画の起点）' });
  await expect(savings).toBeVisible();
  await enterAmount(page, '現在の現金・預金（計画の起点）', '400000');
  await enterAmount(page, '毎月の生活費（食費・交通・日用品等）', '50000');
  await clickVisible(page, page.getByRole('button', { name: '計画を保存・再計算' }));
  await expect(page.getByRole('heading', { name: '必要な積立：月 ¥70,834', exact: true })).toBeVisible();
  await clickVisible(page, page.getByRole('button', { name: '月ごとの目標と現計画の見込み' }));
  await expect(page.getByRole('heading', { name: '2027-10-13 自由資金目標 ¥1,000,000 / 現計画 ¥1,950,000', exact: true })).toBeVisible();
  await enterAmount(page, '今日の生活費合計（計画用メモ）', '1200');
  await clickVisible(page, page.getByRole('button', { name: '生活費メモを保存', exact: true }));
  const morning = page.getByRole('checkbox', { name: '朝：朝食・食器洗い・歯磨き、今日の予定を確認' });
  await clickVisible(page, morning);
  await expect(morning).toBeChecked();
  await page.screenshot({ path: test.info().outputPath('daily-design.png'), fullPage: true });
  await page.reload();
  await clickVisible(page, savings);
  await expect(savings).toHaveValue('400000');
  await expect(page.getByRole('heading', { name: '必要な積立：月 ¥70,834', exact: true })).toBeVisible();
  await expect(morning).toBeChecked();
  await expect(page.getByRole('group', { name: /今日の計画メモ ¥1,200 \/ 残り ¥412/ })).toBeVisible();
  expect(financialWrites).toEqual([]);
  expect(pageErrors).toEqual([]);
});

test('unaffordable plan shows gap while retaining food and repayment', async ({ page }) => {
  await page.goto('/?income=250000');
  await configureGoal(page);
  await enterAmount(page, '現在の現金・預金（計画の起点）', '0');
  await expect(page.getByRole('textbox', { name: '登録済みの手取り収入（収入増なし）' })).toHaveAttribute('readonly', /^(readonly)?$/);
  await enterAmount(page, '毎月の生活費（食費・交通・日用品等）', '60000');
  await clickVisible(page, page.getByRole('button', { name: '計画を保存・再計算' }));
  await expect(page.getByRole('heading', { name: '現計画では月 ¥115,000 不足', exact: true })).toBeVisible();
  await expect(page.getByText(/生活費の日割り目安/)).toHaveCount(0);
  await expect(page.getByRole('group', { name: /食事・通勤・医療と返済を守り/ })).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('deficit.png') });
});


test('account analysis proposes reviewable amounts and requires explicit save', async ({ page }) => {
  await page.goto('/');
  await configureGoal(page);
  await clickVisible(page, page.getByRole('button', { name: '口座を分析してAI提案', exact: true }));
  await clickVisible(page, page.getByRole('textbox', { name: '現在の現金・預金（計画の起点）' }));
  await expect(page.getByRole('textbox', { name: '現在の現金・預金（計画の起点）' })).toHaveValue('400000');
  await clickVisible(page, page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' }));
  await expect(page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' })).toHaveValue('70000');
  await expect(page.getByText(/架空家計・模擬AI応答/)).toBeVisible();
  await expect(page.getByRole('heading', { name: /必要な積立/ })).toHaveCount(0);
  await clickVisible(page, page.getByRole('button', { name: '計画を保存・再計算' }));
  await expect(page.getByRole('heading', { name: '必要な積立：月 ¥73,334' })).toBeVisible();
  await page.screenshot({ path: test.info().outputPath('ai-proposal.png'), fullPage: true });
});

test('unavailable AI is labelled as a provisional proposal, not an AI success', async ({ page }) => {
  await page.goto('/?ai=error');
  await clickVisible(page, page.getByRole('button', { name: '口座を分析してAI提案', exact: true }));
  await expect(page.getByText('AIを利用できず、仮置き案を表示', { exact: true })).toBeVisible();
  await clickVisible(page, page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' }));
  await expect(page.getByRole('textbox', { name: '毎月の生活費（食費・交通・日用品等）' })).toHaveValue('60000');
  await expect(page.getByText(/架空家計・模擬AI応答/)).toHaveCount(0);
});
