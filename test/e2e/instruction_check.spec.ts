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
  await expect(page.getByRole('alert')).toBeEmpty();
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
