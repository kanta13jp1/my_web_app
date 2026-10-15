import { expect, test } from '@playwright/test';

test('desktop reminder is opt-in, testable and stoppable', async ({ page, context }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Desktop notification feature');
  await context.grantPermissions(['notifications']);
  await page.addInitScript(() => {
    const NativeNotification = window.Notification;
    (window as any).__reminderCalls = [];
    // Observe the real adapter boundary without relying on an OS toast in headless CI.
    (window as any).Notification = class extends NativeNotification {
      constructor(title: string, options?: NotificationOptions) {
        (window as any).__reminderCalls.push({ title, body: options?.body });
        super(title, options);
      }
    };
  });
  await page.goto('/');
  await page.getByText('「手は机へ」デスクトップ通知', { exact: true }).click();
  await expect(page.getByText('停止中', { exact: true })).toBeVisible();
  expect(await page.evaluate(() => (window as any).__reminderCalls)).toHaveLength(0);
  await page.getByRole('button', { name: 'テスト通知', exact: true }).click();
  await expect.poll(async () => page.evaluate(() => (window as any).__reminderCalls.length)).toBe(1);
  expect(await page.evaluate(() => (window as any).__reminderCalls[0].title)).toBe('手は机へ');
  await page.getByRole('button', { name: '開始', exact: true }).click();
  await expect(page.getByText('実行中・約5分おき', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '停止', exact: true }).click();
  await expect(page.getByText('停止中', { exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('desktop-reminder.png'), fullPage: true });
  await page.reload();
  await page.getByText('「手は机へ」デスクトップ通知', { exact: true }).click();
  await expect(page.getByText('停止中', { exact: true })).toBeVisible();
});

test('permission request happens only on the explicit click', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Desktop notification feature');
  await page.addInitScript(() => {
    (window as any).__permissionClicks = [];
    Object.defineProperty(Notification, 'permission', { configurable: true, get: () => 'default' });
    Notification.requestPermission = () => {
      (window as any).__permissionClicks.push(navigator.userActivation.isActive);
      return Promise.resolve('denied');
    };
  });
  await page.goto('/');
  await page.getByText('「手は机へ」デスクトップ通知', { exact: true }).click();
  expect(await page.evaluate(() => (window as any).__permissionClicks)).toHaveLength(0);
  await page.getByRole('button', { name: '開始', exact: true }).click();
  await expect.poll(() => page.evaluate(() => (window as any).__permissionClicks)).toEqual([true]);
  await expect(page.getByText('通知がブロックされています。ブラウザのサイト設定で変更できます。', { exact: true })).toBeVisible();
  await expect(page.getByText('停止中', { exact: true })).toBeVisible();
});
