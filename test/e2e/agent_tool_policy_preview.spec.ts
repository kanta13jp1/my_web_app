import { test, expect, type Page } from '@playwright/test';

async function open(page: Page) {
  await page.goto('/');
  await expect(page.getByRole('button', {name: '保存せずに確認', exact: true})).toBeVisible({timeout: 30000});
}
async function enter(page: Page, value: string) {
  const input = page.getByRole('textbox');
  await input.focus();
  await input.fill(value);
}

test('read result stays a simulation', async ({page}, info) => {
  await open(page);
  await page.getByRole('button', {name: '保存せずに確認', exact: true}).click();
  await expect(page.getByText('試し判定：要求を満たします', {exact: true})).toBeVisible();
  await expect(page.getByText('これは試し判定です。実行時には別途権限を確認します。', {exact: true})).toBeVisible();
  await page.screenshot({path: info.outputPath('read.png')});
});
test('unknown input can be corrected', async ({page}, info) => {
  await open(page);
  await enter(page, 'read, unknown');
  await page.getByRole('button', {name: '保存せずに確認', exact: true}).click();
  await expect(page.getByText('試し判定：操作を止めます', {exact: true})).toBeVisible();
  await enter(page, 'read');
  await expect(page.getByText('試し判定：操作を止めます', {exact: true})).toHaveCount(0);
  await page.getByRole('button', {name: '保存せずに確認', exact: true}).click();
  await expect(page.getByText('試し判定：要求を満たします', {exact: true})).toBeVisible();
  await page.screenshot({path: info.outputPath('corrected.png')});
});
test('transport failure never becomes permission and can recover', async ({page}, info) => {
  await open(page);
  await enter(page, 'offline');
  await page.getByRole('button', {name: '保存せずに確認', exact: true}).click();
  await expect(page.getByText(/確認できませんでした。/)).toBeVisible();
  await expect(page.getByText('試し判定：要求を満たします', {exact: true})).toHaveCount(0);
  await page.getByRole('button', {name: '保存せずに確認', exact: true}).click();
  await expect(page.getByText('試し判定：要求を満たします', {exact: true})).toBeVisible();
  await page.screenshot({path: info.outputPath('recovered.png')});
});
