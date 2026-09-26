import { test, expect } from '@playwright/test';

for (const platform of ['android', 'ios']) {
  test(`${platform}: draft dismissal, failed save and recovery`, async ({ page }, info) => {
    test.setTimeout(90_000);
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('requestfailed', r => errors.push(r.url()));
    page.on('response', r => { if (r.status() >= 500) errors.push(`${r.status()} ${r.url()}`); });
    await page.goto(`http://127.0.0.1:7358/?platform=${platform}`);
    const open = page.getByRole('button', { name: 'Inboxへメモを開く', exact: true });
    await expect(open).toBeVisible({ timeout: 60_000 });
    await open.click();
    const input = page.getByRole('textbox', { name: /メモ/ });
    const save = page.getByRole('button', { name: 'Inboxに保存', exact: true });
    await expect(save).toBeDisabled();
    await input.fill('確認用メモ');
    await page.keyboard.press('Escape');
    await expect(page.getByText('入力したメモを破棄しますか？', { exact: true })).toBeVisible();
    await page.getByRole('button', { name: '入力を続ける', exact: true }).click();
    await expect(input).toHaveValue('確認用メモ');
    await page.getByRole('button', { name: 'キャンセル', exact: true }).click();
    await page.getByRole('button', { name: '破棄する', exact: true }).click();
    await expect(open).toBeVisible();
    await expect(page.getByText('保存呼出: 0', { exact: true })).toBeVisible();
    await open.click();
    await input.fill('失敗');
    await save.click();
    await expect(page.getByRole('button', { name: '保存中…', exact: true })).toBeDisabled();
    await page.keyboard.press('Escape');
    await expect(input).toHaveValue('失敗');
    await expect(page.getByText('保存できませんでした。通信状態を確認して、もう一度お試しください。', { exact: true })).toBeVisible();
    await expect(input).toHaveValue('失敗');
    await input.fill('再試行したメモ');
    // Flutter canvas animations are not DOM animations. Confirm semantic state,
    // then collect three low-FPS frames after bounded DOM animation settling.
    await page.evaluate(async () => {
      await Promise.all(document.getAnimations({ subtree: true }).filter(a =>
        a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
    });
    for (let i = 0; i < 3; i++) {
      await page.screenshot({ path: info.outputPath(`inbox-${i}.png`) });
      await page.waitForTimeout(250);
    }
    await save.focus();
    await page.keyboard.press('Enter');
    await expect(page.getByText('保存済み: 再試行したメモ', { exact: true })).toBeVisible();
    await expect(page.getByText('保存呼出: 2', { exact: true })).toBeVisible();
    expect(errors).toEqual([]);
  });
}
