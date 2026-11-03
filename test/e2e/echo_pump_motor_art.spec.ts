import { test, expect } from '@playwright/test';

for (const missing of [false, true]) {
  test(`MCP pump states and escape ${missing ? 'with missing images' : 'with rendered images'}`, async ({ page }, info) => {
    test.setTimeout(90000);
    const states = new Set<string>();
    const errors: string[] = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.route('**/assets/echo_pump/pump_*.png', async route => {
      const state = route.request().url().match(/pump_(fault|idle|live)\.png/)?.[1];
      if (state) states.add(state);
      if (missing) await route.abort(); else await route.continue();
    });
    await page.goto('/');
    const button = (name: string) => page.getByRole(/^[ABC] /.test(name) ? 'checkbox' : 'button', {name, exact: true});
    await expect(button('ゲーム開始')).toBeVisible({timeout: 30000});
    await button('ゲーム開始').click();
    await button('スキップして開始').click();
    for (const label of [
      'B 整備', 'A 搬入', '中央廊下へ', '工具庫へ', 'ヒューズを回収',
      '中央廊下へ', 'ポンプ室へ', 'ヒューズで修理', '中央廊下へ', '管理室へ',
      'B 整備', 'C 排水', '1ターン待つ', '1ターン待つ', '中央廊下へ',
      'ポンプ室へ', '隔壁を閉じる', '排水ポンプを起動', '中央廊下へ', '管理室へ', '出口へ',
    ]) {
      await button(label).click();
      if (['ヒューズで修理', '排水ポンプを起動'].includes(label)) {
        const view = page.viewportSize()!;
        await page.mouse.move(view.width/2, view.height/2);
        await page.mouse.wheel(0, 30000);
        await page.waitForTimeout(1400);
        await page.screenshot({path: info.outputPath(`pump-${label}-${missing ? 'fallback' : 'rendered'}.png`)});
      }
    }
    await expect(button('リトライ')).toBeVisible();
    expect([...states].sort()).toEqual(['fault','idle','live']);
    expect(errors).toEqual([]);
    await button('リトライ').click();
    await expect(button('B 整備')).toBeVisible();
  });
}
