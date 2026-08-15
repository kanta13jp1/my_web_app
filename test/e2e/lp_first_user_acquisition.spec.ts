import { expect, Page, test } from '@playwright/test';

const treatmentPath = '/?lp_hypothesis=h03&lp_variant=treatment';
const controlPath = '/?lp_hypothesis=h03&lp_variant=control';

test.describe('LP first-user acquisition', () => {
  test.describe.configure({ timeout: 120_000 });

  test('H03 treatment puts a real no-signup trial in the first viewport', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    const trialInput = page.getByRole('textbox', { name: /30秒で試す/ });
    const trialAction = page.getByRole('button', {
      name: '今やる1件を試す',
      exact: true,
    });

    await expect(trialInput).toBeVisible();
    await expect(trialAction).toBeVisible();

    const inputBox = await trialInput.boundingBox();
    const actionBox = await trialAction.boundingBox();
    const viewport = page.viewportSize();
    expect(inputBox).not.toBeNull();
    expect(actionBox).not.toBeNull();
    expect(viewport).not.toBeNull();
    const unobscuredViewportBottom =
      viewport!.width < 720 ? viewport!.height - 68 : viewport!.height;
    expect(inputBox!.y + inputBox!.height).toBeLessThanOrEqual(
      unobscuredViewportBottom,
    );
    expect(actionBox!.y + actionBox!.height).toBeLessThanOrEqual(
      unobscuredViewportBottom,
    );
    expect(inputBox!.y).toBeLessThan(actionBox!.y);
  });

  test('H04 treatment reveals one-field Magic Link capture after value', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    await page
      .getByRole('button', { name: '今やる1件を試す', exact: true })
      .click();

    await expect(
      page.getByRole('group', { name: /提案された1件/ }),
    ).toBeVisible();
    await expect(
      page.getByRole('textbox', { name: 'メールアドレス', exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', {
        name: '無料で保存して始める',
        exact: true,
      }),
    ).toBeVisible();
    await expect(
      page.getByRole('group', {
        name: /パスワード・カード入力は不要です。/,
      }),
    ).toBeVisible();
  });

  test('H03 control keeps authentication before the lower trial', async ({
    page,
  }) => {
    await openLanding(page, controlPath);

    const authAction = page.getByRole('button', {
      name: 'Magic Linkで今すぐ始める',
      exact: true,
    });
    const lowerTrial = page.getByRole('button', {
      name: '今やる1件を試す',
      exact: true,
    });

    await expect(authAction).toBeVisible();
    await expect(lowerTrial).toBeVisible();
    await expect(
      page.getByRole('textbox', { name: /30秒で試す/ }),
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
  await expect(page).toHaveTitle(
    '自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ',
    { timeout: 60_000 },
  );
  await expect(
    page.getByText('仕事・学習・お金の「次の1件」を、AIが1分で決める', {
      exact: true,
    }),
  ).toBeVisible({ timeout: 60_000 });
}
