import { test, expect, type Page } from '@playwright/test';

const card = (page: Page, platform: string) =>
  page.getByRole('group', { name: new RegExp(`^${platform} `) });
const status = (page: Page, platform: string, label: string) =>
  card(page, platform).getByRole('button', { name: `確認状態 ${label}`, exact: true });

async function openChecklist(page: Page) {
  await page.goto('/platform-release-checklist');
  await expect(page.getByRole('heading', { name: 'プラットフォーム別リリース確認', exact: true }))
    .toBeVisible({ timeout: 30_000 });
}

async function markWeb(page: Page) {
  await status(page, 'Web', '未確認').click();
  // Select the visible option, without assuming desktop keyboard focus on touch viewports.
  await page.getByRole('menuitem', { name: '確認済み', exact: true }).click();
  await expect(status(page, 'Web', '確認済み')).toBeVisible();
  const note = page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ });
  await note.click();
  await note.fill('Chrome で確認');
}

test('platform release checklist starts each platform as untested', async ({ page }, info) => {
  await openChecklist(page);
  for (const platform of ['Web', 'iOS', 'Android']) {
    await expect(status(page, platform, '未確認')).toHaveCount(1);
    await expect(page.getByRole('textbox', { name: `${platform} の確認メモ`, exact: true })).toHaveValue('');
  }
  await page.screenshot({ path: info.outputPath('checklist-initial.png') });
});

test('platform release checklist reloads a platform result and note', async ({ page }, info) => {
  await openChecklist(page);
  await markWeb(page);
  await page.waitForTimeout(300);
  await page.reload();
  await expect(status(page, 'Web', '確認済み')).toBeVisible({ timeout: 30_000 });
  await page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ }).click();
  await expect(page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ })).toHaveValue('Chrome で確認');
  await expect(status(page, 'iOS', '未確認')).toHaveCount(1);
  await expect(status(page, 'Android', '未確認')).toHaveCount(1);
  await page.screenshot({ path: info.outputPath('checklist-reloaded.png') });
});

test('platform release checklist restores a cleared result and note', async ({ page }, info) => {
  await openChecklist(page);
  await markWeb(page);
  await page.getByRole('button', { name: '確認内容を空にする', exact: true }).click();
  await expect(status(page, 'Web', '未確認')).toBeVisible();
  await page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ }).click();
  await expect(page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ })).toHaveValue('');
  await page.screenshot({ path: info.outputPath('checklist-cleared.png') });
  await page.getByRole('button', { name: '元に戻す', exact: true }).click();
  await expect(status(page, 'Web', '確認済み')).toBeVisible();
  await page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ }).click();
  await expect(page.getByRole('textbox', { name: /^Web の確認メモ(?: |$)/ })).toHaveValue('Chrome で確認');
  await page.screenshot({ path: info.outputPath('checklist-restored.png') });
});
