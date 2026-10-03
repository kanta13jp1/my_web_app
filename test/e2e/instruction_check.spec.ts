import {test, expect} from '@playwright/test';

test.beforeEach(async ({page}) => {
  await page.goto('/labs/instruction-check/index.html');
});

test('examples explain missing, present and tool-assisted responses', async ({page}, info) => {
  await expect(page.getByRole('heading', {level: 1})).toContainText('AIの返答に出てくる');
  await expect(page.getByText('Claude Codeの起動やファイルの読み取りは行いません。', {exact: false})).toBeVisible();
  await page.getByRole('button', {name: '例1：Cだけ返った', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('2個中1個');
  await expect(page.getByRole('status')).toContainText('MARK_A：未検出');
  await expect(page.getByRole('status')).toContainText('読んでいないとは断定できません');
  await page.getByRole('button', {name: '例2：両方返った', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('2個中2個');
  await expect(page.getByRole('status')).toContainText('指示をすべて守ったという意味ではありません');
  await page.getByRole('button', {name: '例3：途中でツールを使った', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('途中でファイルを開いて答えを見つけた可能性を除外できません');
  await page.screenshot({path: info.outputPath('explained-comparison.png'), fullPage: true});
});

test('exact comparison and edits invalidate old results', async ({page}) => {
  await page.getByRole('button', {name: '例1：Cだけ返った', exact: true}).click();
  await page.getByLabel('AIから返ってきた文章').fill('MARK_C_extra MARK_A');
  await expect(page.getByRole('status')).not.toContainText('MARK_C：検出');
  await page.getByRole('button', {name: '返答と目印を照合する', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('MARK_C：未検出');
  await expect(page.getByRole('status')).toContainText('MARK_A：検出');
  await page.getByLabel('AIから返ってきた文章').fill('MARK_C。');
  await page.getByRole('button', {name: '返答と目印を照合する', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('2個中0個');
});

test('invalid markers clear results and examples recover', async ({page}) => {
  await page.getByRole('button', {name: '例2：両方返った', exact: true}).click();
  for (const value of ['', 'MARK_C MARK_C']) {
    await page.getByLabel('ファイルに書いた目印（比べたいもの）').fill(value);
    await page.getByRole('button', {name: '返答と目印を照合する', exact: true}).click();
    await expect(page.getByRole('alert')).not.toBeEmpty();
    await expect(page.getByRole('status')).not.toContainText('：検出');
  }
  await page.getByRole('button', {name: '例1：Cだけ返った', exact: true}).click();
  await expect(page.getByRole('alert')).toBeHidden();
  await expect(page.getByRole('status')).toContainText('2個中1個');
});

test('unknown count is never presented as zero and invalid counts are rejected', async ({page}) => {
  await expect(page.getByLabel('実行ログで確認したツール使用回数')).toHaveValue('');
  await page.getByLabel('AIから返ってきた文章').fill('MARK_C MARK_A');
  await page.getByRole('button', {name: '返答と目印を照合する', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('2個中2個');
  await expect(page.getByRole('status')).toContainText('ツール使用回数：未確認');
  await expect(page.getByRole('status')).not.toContainText('ツール使用回数：0');
  for (const value of ['-1', '1.5']) {
    await page.getByLabel('実行ログで確認したツール使用回数').fill(value);
    await page.getByRole('button', {name: '返答と目印を照合する', exact: true}).click();
    await expect(page.getByRole('status')).not.toContainText('：検出');
    expect(await page.getByLabel('実行ログで確認したツール使用回数').evaluate((el: HTMLInputElement) => el.validity.valid)).toBe(false);
  }
  await page.getByRole('button', {name: '例1：Cだけ返った', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('ツール使用回数：0');
});

test('local processing and responsive layout', async ({page}) => {
  const requests: string[] = [];
  page.on('request', request => requests.push(request.url()));
  await page.getByRole('button', {name: '例1：Cだけ返った', exact: true}).click();
  await page.getByLabel('AIから返ってきた文章').fill('<script>window.untrusted=true</script> MARK_A');
  await page.getByRole('button', {name: '返答と目印を照合する', exact: true}).click();
  await expect(page.getByRole('status')).toContainText('MARK_A：検出');
  expect(await page.evaluate(() => (window as any).untrusted)).toBeUndefined();
  expect(requests).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('historical records expose all twelve conditions and real event excerpts', async ({page}, info) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.getByRole('button', {name: '実行記録12件を表示する'}).click();
  await expect(page.locator('#run-select option')).toHaveCount(12);
  for (const version of ['old', 'new']) for (const condition of ['N','C','A','B','I','E']) {
    await page.locator('#run-select').selectOption(`${version}-${condition}`);
    await expect(page.locator('#evidence-panel')).toBeVisible();
    await expect(page.locator('#run-summary')).toContainText(`条件 ${condition}`);
    await expect(page.locator('#run-tools')).toContainText('ツール使用イベント：0件');
    await expect(page.locator('#run-tools')).toContainText('全4イベント');
    await expect(page.locator('#run-source')).toHaveAttribute('href', new RegExp(`/results/${version}-${condition}\\.json$`));
  }
  await page.locator('#run-select').selectOption('new-A');
  await expect(page.locator('#run-answer')).toHaveText('NONE');
  await page.locator('#run-select').selectOption('new-E');
  await expect(page.locator('#run-answer')).toContainText('LOADMARK_A_79bd0e31');
  await page.locator('#run-log-details summary').click();
  await expect(page.locator('#run-events')).toContainText('元ログ 4行目');
  await expect(page.locator('#run-events')).toContainText('"subtype": "success"');
  await expect(page.locator('#run-events')).not.toContainText('session_id');
  await page.locator('#evidence').scrollIntoViewIfNeeded();
  await page.screenshot({path: info.outputPath('historical-logs.png'), fullPage: true});
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(errors).toEqual([]);
});
test('unavailable evidence clears previous records and can recover', async ({page}) => {
  await page.route('**/evidence.json', route => route.fulfill({status: 503, body: 'unavailable'}));
  await page.getByRole('button', {name: '実行記録12件を表示する'}).click();
  await expect(page.locator('#evidence-message')).toContainText('取得できませんでした');
  await expect(page.locator('#evidence-panel')).toBeHidden();
  await expect(page.locator('#run-select')).toBeDisabled();
  await page.unroute('**/evidence.json');
  await page.getByRole('button', {name: '実行記録12件を表示する'}).click();
  await expect(page.locator('#evidence-panel')).toBeVisible();
});
