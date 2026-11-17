import { test, expect, Page } from '@playwright/test';
import { readFile } from 'node:fs/promises';

async function save(page: Page, button: string, filename: string) {
  const pending = page.waitForEvent('download');
  await page.getByRole('button', { name: button, exact: true }).click();
  const download = await pending;
  expect(download.suggestedFilename()).toBe(filename);
  const path = await download.path();
  expect(path).not.toBeNull();
  const text = await readFile(path!, 'utf8');
  const value = JSON.parse(text);
  expect(text).toBe(JSON.stringify(value, null, 2));
  return { value, path: path! };
}

test('Sound Bloom downloads the edited composition and reopens it', async ({ page }, info) => {
  await page.goto('/labs/sound-bloom/index.html');
  await page.getByRole('button', { name: '02 木漏れ日', exact: true }).click();
  const tempo = page.locator('#tempo');
  await tempo.focus(); await tempo.press('Home'); await tempo.press('ArrowRight');
  const saved = await save(page, '構成を保存', 'sound-bloom.json');
  expect(saved.value.tempo).toBe(61);
  await page.getByRole('button', { name: '種をすべて消す', exact: true }).click();
  await page.getByLabel('構成を開く').setInputFiles(saved.path);
  await expect(page.locator('#status')).toHaveText('保存した構成を復元しました。');
  expect((await save(page, '構成を保存', 'sound-bloom.json')).value).toEqual(saved.value);
  await page.screenshot({ path: info.outputPath('sound-bloom-save.png'), fullPage: true });
});

test('invalid composition leaves state intact and a subsequent valid file recovers', async ({ page }) => {
  await page.goto('/labs/sound-bloom/index.html');
  const saved = await save(page, '構成を保存', 'sound-bloom.json');
  await page.getByLabel('構成を開く').setInputFiles({ name: 'invalid.json', mimeType: 'application/json', buffer: Buffer.from('{broken') });
  await expect(page.locator('#status')).toContainText('構成ファイルを読み込めません');
  expect((await save(page, '構成を保存', 'sound-bloom.json')).value).toEqual(saved.value);
  await page.getByLabel('構成を開く').setInputFiles(saved.path);
  await expect(page.locator('#status')).toHaveText('保存した構成を復元しました。');
});

test('Jev Mario exports repeated empty measurements without a model connection', async ({ page }, info) => {
  await page.goto('/labs/jev-mario/index.html');
  const first = await save(page, '結果JSONを保存', 'jev-mario-measurement.json');
  expect(first.value.samples).toEqual([]);
  expect(first.value.counts).toEqual({ attempts: 0, failures: 0, cancelled: 0, applied: 0, stale: 0 });
  expect((await save(page, '結果JSONを保存', 'jev-mario-measurement.json')).value).toEqual(first.value);
  await page.screenshot({ path: info.outputPath('jev-mario-export.png'), fullPage: true });
});
