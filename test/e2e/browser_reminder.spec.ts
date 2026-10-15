import { expect, test } from '@playwright/test';

// The legacy headless shell reports Notification.permission='denied' even
// when the Permissions API is granted. Use Chromium's real browser channel.
test.use({ channel: 'chromium' });

test('desktop reminder is opt-in, testable and stoppable', async ({ page, context }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Desktop notification feature');
  const settings = page.getByLabel('Dialog', { exact: true });
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await context.grantPermissions(['notifications'], {
    origin: new URL(process.env.E2E_BASE_URL ?? 'http://127.0.0.1:7361').origin,
  });
  await page.goto('/');
  await testInfo.attach('browser-permission', {
    body: JSON.stringify(await page.evaluate(async () => ({
      permission: Notification.permission,
      origin: location.origin,
      secure: isSecureContext,
      query: (await navigator.permissions.query({ name: 'notifications' })).state,
    }))), contentType: 'application/json',
  });
  expect(await page.evaluate(() => Notification.permission)).toBe('granted');
  await page.getByRole('button', { name: /^「手は机へ」デスクトップ通知/ }).click();
  await expect(settings.getByText('ブラウザの通知：許可済み', { exact: true })).toBeVisible();
  await expect(settings.getByText('停止中', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'テスト通知', exact: true }).click();
  await expect(settings.getByText('テスト通知を要求しました。表示されない場合はWindowsとブラウザの通知設定を確認してください。', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '開始', exact: true }).click();
  await expect(settings.getByText('実行中・約5分おき', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '停止', exact: true }).click();
  await expect(settings.getByText('停止中', { exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('desktop-reminder.png'), fullPage: true });
  await page.reload();
  await page.getByRole('button', { name: /^「手は机へ」デスクトップ通知/ }).click();
  await expect(settings.getByText('停止中', { exact: true })).toBeVisible();
  expect(errors).toEqual([]);
});

test('permission request happens only on the explicit click', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Desktop notification feature');
  const settings = page.getByLabel('Dialog', { exact: true });
  await page.addInitScript(() => {
    (window as any).__permissionClicks = [];
    Object.defineProperty(Notification, 'permission', { configurable: true, get: () => 'default' });
    Notification.requestPermission = () => {
      (window as any).__permissionClicks.push(navigator.userActivation.isActive);
      return Promise.resolve('denied');
    };
  });
  await page.goto('/');
  await page.getByRole('button', { name: /^「手は机へ」デスクトップ通知/ }).click();
  expect(await page.evaluate(() => (window as any).__permissionClicks)).toHaveLength(0);
  await page.getByRole('button', { name: '開始', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__permissionClicks)).toEqual([true]);
  await expect(settings.getByText('通知がブロックされています。ブラウザのサイト設定で変更できます。', { exact: true })).toBeVisible();
  await expect(settings.getByText('停止中', { exact: true })).toBeVisible();
});
