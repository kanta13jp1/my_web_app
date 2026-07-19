import { expect, Page, test } from '@playwright/test';

const treatmentPath = '/?lp_hypothesis=h03&lp_variant=treatment';
const controlPath = '/?lp_hypothesis=h03&lp_variant=control';

test.describe('LP first-user acquisition', () => {
  test.describe.configure({ timeout: 60_000 });

  test('H03 treatment puts a real no-signup trial in the first viewport', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    const trialHeading = page.getByText('30秒で試す: いま詰まっていることは？', {
      exact: true,
    });
    const trialInput = page.getByLabel(
      '例: 今日いちばん詰まっていることを簡単に書く',
      { exact: true },
    );

    await expect(trialHeading).toBeVisible();
    await expect(trialInput).toBeVisible();

    const headingBox = await trialHeading.boundingBox();
    const viewport = page.viewportSize();
    expect(headingBox).not.toBeNull();
    expect(viewport).not.toBeNull();
    expect(headingBox!.y + headingBox!.height).toBeLessThanOrEqual(
      viewport!.height,
    );
  });

  test('H04 treatment reveals one-field Magic Link capture after value', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    await page.getByText('今やる1件を試す', { exact: true }).click();

    await expect(page.getByText('提案された1件', { exact: true })).toBeVisible();
    await expect(page.getByPlaceholder('you@example.com')).toBeVisible();
    await expect(
      page.getByText('無料で保存して始める', { exact: true }),
    ).toBeVisible();
    await expect(
      page.getByText('パスワード・カード入力は不要です。', { exact: true }),
    ).toBeVisible();
  });

  test('H03 control keeps authentication before the lower trial', async ({
    page,
  }) => {
    await openLanding(page, controlPath);

    const authAction = page.getByText('Magic Linkで今すぐ始める', {
      exact: true,
    });
    const lowerTrial = page.getByText('今やる1件を試す', { exact: true });

    await expect(authAction).toBeVisible();
    await expect(lowerTrial).toBeVisible();
    await expect(
      page.getByText('30秒で試す: いま詰まっていることは？', {
        exact: true,
      }),
    ).toHaveCount(0);

    const authBox = await authAction.boundingBox();
    const trialBox = await lowerTrial.boundingBox();
    expect(authBox).not.toBeNull();
    expect(trialBox).not.toBeNull();
    expect(authBox!.y).toBeLessThan(trialBox!.y);
  });
});

async function openLanding(page: Page, path: string) {
  await page.route('**/rest/v1/app_analytics*', async (route) => {
    const isRead = route.request().method() === 'GET';
    await route.fulfill({
      status: isRead ? 200 : 204,
      contentType: 'application/json',
      headers: isRead ? { 'content-range': '0-0/0' } : undefined,
      body: isRead ? '[]' : '',
    });
  });

  const response = await page.goto(path, { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBeTruthy();
  await expect(
    page.getByText('仕事・学習・お金の「次の1件」を、AIが1分で決める', {
      exact: true,
    }),
  ).toBeVisible({ timeout: 30_000 });
}
