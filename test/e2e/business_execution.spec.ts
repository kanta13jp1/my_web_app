import { test, expect, type Locator, type Page } from '@playwright/test';

// Build test/fixtures/business_execution_app.dart and serve it on loopback.
// Do not point these mutation scenarios at a deployment or a real user account.
test.setTimeout(90_000);

const title = '相談申込数';
const reflectionLabel = '月次の振り返り（続けること・変えること・次月の行動）';
const button = (page: Page, name: string) =>
  page.getByRole('button', { name, exact: true });
// These fixed Japanese field labels contain no regular-expression operators.
const field = (page: Page, label: string) =>
  page.getByRole('textbox', { name: new RegExp('^' + label + '(?: |$)') });

function fixtureOrigin(): string {
  const raw = process.env.E2E_BASE_URL;
  if (!raw) throw new Error('Set E2E_BASE_URL to the locally served browser fixture.');
  const url = new URL(raw);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname)) {
    throw new Error('Business execution E2E only permits a loopback fixture.');
  }
  return url.origin;
}

// Scroll the Flutter view itself. Scrolling only a semantics DOM element does
// not necessarily move the canvas hit target. Never use force-click or raw x/y
// input to bypass a missing user-visible control.
async function reveal(page: Page, target: Locator) {
  const viewport = page.viewportSize();
  if (!viewport) throw new Error('A fixed desktop/mobile viewport is required.');
  await page.mouse.move(viewport.width / 2, viewport.height / 2);
  await page.mouse.wheel(0, -10000);
  await page.waitForTimeout(80);
  for (let step = 0; step < 32; step++) {
    if (await target.count() === 1) {
      const box = await target.boundingBox();
      if (box && box.y >= 60 && box.y + box.height <= viewport.height - 8) return;
    }
    await page.mouse.wheel(0, 250);
    // Wait only for each real scroll frame; assertions still have bounded waits.
    await page.waitForTimeout(80);
  }
  throw new Error('Could not reveal the requested control by scrolling.');
}

async function click(page: Page, label: string) {
  const target = button(page, label);
  await reveal(page, target);
  await target.click();
}

async function enter(page: Page, label: string, value: string) {
  const input = field(page, label);
  await reveal(page, input);
  await input.focus();
  await expect(input).toBeFocused();
  await input.press('ControlOrMeta+A');
  await input.press('Backspace');
  await input.pressSequentially(value);
  await expect(input).toHaveValue(value);
}

async function inputValue(page: Page, label: string, value: string) {
  const input = field(page, label);
  await reveal(page, input);
  await input.focus();
  await expect(input).toHaveValue(value);
}

async function open(page: Page, monthEnd = false) {
  await page.goto(fixtureOrigin() + (monthEnd ? '/?monthEnd=1' : '/'));
  await expect(
    page.getByText('架空データ検証：経営の実行記録', { exact: true }),
  ).toBeVisible({ timeout: 30_000 });
  await expect(button(page, '月の実行計画を作る')).toBeEnabled();
}

async function openPlan(page: Page) {
  const plan = page.getByRole('button', { name: new RegExp('^' + title) });
  await reveal(page, plan);
  await plan.click();
  await expect(button(page, '計画一覧へ（未保存入力は破棄）')).toBeVisible();
}

async function createPlan(page: Page) {
  await click(page, '月の実行計画を作る');
  await enter(page, '解決したい課題', '架空の提案が相談につながらない');
  await enter(page, '成果指標（KPI）例：月内の相談申込数', title);
  await enter(page, '成果の単位 例：件', '件');
  await enter(page, '期間終了時の成果目標', '3');
  await enter(page, '行動指標（KDI）例：顧客へのヒアリング', 'ヒアリング');
  await enter(page, '行動の単位 例：回', '回');
  await enter(page, '1日あたりの行動目標', '2');
  await enter(page, '開始日 YYYY-MM-DD', '2026-10-29');
  await click(page, '計画を端末に保存');
  await expect(
    page.getByText('未入力: 2日（今日を含む対象日のみ）', { exact: true }),
  ).toBeVisible();
}

async function saveDay(page: Page, amount: string, note: string, update = false) {
  await enter(page, 'この日の行動実績（回）', amount);
  await enter(page, '日次の振り返り・次の一手', note);
  await click(page, update ? 'この日の記録を更新' : 'この日の記録を保存');
  await expect(
    page.getByText('日次実績を保存して読み戻しました。', { exact: true }),
  ).toBeVisible();
}

test.beforeEach(async ({ page }) => {
  await open(page);
});

test('monthly review restores a user-created plan and daily results after navigation',
  async ({ page }, info) => {
    await createPlan(page);
    await enter(page, 'この日時点の成果実績（任意・件）', '1');
    await saveDay(page, '2', '質問の順番を改善した');
    await enter(page, reflectionLabel, '次月は紹介経路を試す');
    await click(page, '月次の振り返りを保存');
    await expect(
      page.getByText('月次の振り返りを保存して読み戻しました。', { exact: true }),
    ).toBeVisible();

    // Full page navigation destroys the Dart runtime and restores real storage.
    await open(page, true);
    await openPlan(page);
    await expect(
      page.getByText('期間終了・月次の振り返り', { exact: true }),
    ).toBeVisible();
    await expect(page.getByText('2026-10-30: 2 回', { exact: true })).toBeVisible();
    await expect(page.getByText('成果実績（2026-10-30時点）: 1 件 / 目標 3 件',
      { exact: true })).toBeVisible();
    await expect(page.getByText('未入力: 2日（今日を含む対象日のみ）',
      { exact: true })).toBeVisible();
    await inputValue(page, reflectionLabel, '次月は紹介経路を試す');
    await page.screenshot({ path: info.outputPath('monthly-restored.png') });
  });

test('blank actual is rejected while zero is saved and missing days remain visible',
  async ({ page }, info) => {
    await createPlan(page);
    await click(page, 'この日の記録を保存');
    await expect(
      page.getByText('実績は0〜10億で入力してください。', { exact: true }),
    ).toBeVisible();
    await page.reload();
    await expect(button(page, '月の実行計画を作る')).toBeEnabled();
    await openPlan(page);
    await expect(page.getByText('未入力: 2日（今日を含む対象日のみ）',
      { exact: true })).toBeVisible();
    await inputValue(page, 'この日の行動実績（回）', '');

    await saveDay(page, '0', '今日は実行しなかった');
    await page.reload();
    await expect(button(page, '月の実行計画を作る')).toBeEnabled();
    await openPlan(page);
    await expect(page.getByText('未入力: 1日（今日を含む対象日のみ）',
      { exact: true })).toBeVisible();
    await expect(page.getByText('成果実績（KPI）は未入力です。',
      { exact: true })).toBeVisible();
    await inputValue(page, 'この日の行動実績（回）', '0');
    await inputValue(page, 'この日時点の成果実績（任意・件）', '');
    await page.screenshot({ path: info.outputPath('zero-is-not-missing.png') });
  });

test('two real tabs retain a stale draft and require confirmation before replacing saved work',
  async ({ page, context }, info) => {
    await createPlan(page);
    const second = await context.newPage();
    try {
      await open(second);
      await openPlan(second);
      await enter(second, 'この日の行動実績（回）', '2');
      await enter(second, '日次の振り返り・次の一手', 'タブBの日次下書き');
      await enter(second, reflectionLabel, 'タブBの月次下書き');

      await saveDay(page, '1', 'タブAが先に保存した日次');
      await enter(page, reflectionLabel, 'タブAが先に保存した月次');
      await click(page, '月次の振り返りを保存');
      await expect(page.getByText('月次の振り返りを保存して読み戻しました。',
        { exact: true })).toBeVisible();

      // Both pages use real LocalBusinessExecutionStore and origin-wide locks.
      // No localStorage edits, injected records or mock transport are used.
      await click(second, 'この日の記録を保存');
      await expect(button(second, '保存結果を再読み込み')).toBeEnabled();
      await click(second, '保存結果を再読み込み');
      await expect(button(second, 'この日の記録を更新')).toBeDisabled();
      await expect(button(second, '月次の振り返りを保存')).toBeDisabled();
      await inputValue(second, '日次の振り返り・次の一手', 'タブBの日次下書き');
      await inputValue(second, reflectionLabel, 'タブBの月次下書き');
      await expect(second.getByText(/最新の日次振り返り: タブAが先に保存した日次/))
        .toBeVisible();
      await expect(second.getByText('最新の月次振り返り: タブAが先に保存した月次',
        { exact: true })).toBeVisible();
      await second.screenshot({ path: info.outputPath('two-tab-conflict.png') });

      await click(second, '最新記録を確認し、この日次入力で上書きする');
      await click(second, 'この日の記録を更新');
      await expect(second.getByText('日次実績を保存して読み戻しました。',
        { exact: true })).toBeVisible();
      await click(second, '最新記録を確認し、この月次入力で上書きする');
      await click(second, '月次の振り返りを保存');
      await expect(second.getByText('月次の振り返りを保存して読み戻しました。',
        { exact: true })).toBeVisible();

      await page.reload();
      await expect(button(page, '月の実行計画を作る')).toBeEnabled();
      await openPlan(page);
      await inputValue(page, 'この日の行動実績（回）', '2');
      await inputValue(page, '日次の振り返り・次の一手', 'タブBの日次下書き');
      await inputValue(page, reflectionLabel, 'タブBの月次下書き');
      await page.screenshot({ path: info.outputPath('two-tab-recovered.png') });
    } finally {
      await second.close();
    }
  });
