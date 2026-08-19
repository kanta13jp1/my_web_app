import { expect, Page, test } from '@playwright/test';

const treatmentPath = '/?lp_hypothesis=h03&lp_variant=treatment';
const controlPath = '/?lp_hypothesis=h03&lp_variant=control';

test.describe('LP first-user acquisition', () => {
  test.describe.configure({ timeout: 120_000 });

  test('H03 treatment puts a real no-signup trial in the first viewport', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    const trialInput = page.getByRole('textbox', { name: /登録なしで試す/ });
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

  test('H04 treatment reveals Google save and Magic Link fallback after value', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    await page
      .getByRole('button', { name: 'この例で即試す', exact: true })
      .click();

    await expect(
      page.getByRole('group', { name: /提案された1件/ }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', {
        name: 'Googleで無料登録して保存',
        exact: true,
      }),
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

  test('Google callback failure exposes safe retry and Magic Link recovery', async ({
    page,
  }, testInfo) => {
    const browserIssues: string[] = [];
    page.on('console', (message) => {
      if (message.type() === 'error') {
        browserIssues.push(`console: ${message.text()}`);
      }
    });
    page.on('pageerror', (error) => {
      browserIssues.push(`pageerror: ${error.message}`);
    });
    page.on('response', (response) => {
      if (response.status() >= 500) {
        browserIssues.push(
          `http ${response.status()}: ${response.url()}`,
        );
      }
    });

    await openLanding(
      page,
      '/?lp_hypothesis=h04&lp_variant=treatment&lp_qa=1'
        + '#error=server_error'
        + '&error_description=Unable+to+exchange+external+code+'
        + 'for+private%40example.com',
    );

    const notice = page.getByText(
      'Google登録を完了できませんでした',
      { exact: true },
    );
    const retry = page.getByRole('button', {
      name: 'Googleでもう一度',
      exact: true,
    });
    const magicLink = page.getByRole('button', {
      name: 'Magic Linkで続ける',
      exact: true,
    });

    await expect(notice).toBeVisible();
    await expect(retry).toBeVisible();
    await expect(magicLink).toBeVisible();
    await expect(page.getByText('private@example.com')).toHaveCount(0);
    expect(decodeURIComponent(page.url())).not.toContain(
      'private@example.com',
    );

    const viewport = page.viewportSize();
    const recoveryBox = await magicLink.boundingBox();
    expect(viewport).not.toBeNull();
    expect(recoveryBox).not.toBeNull();
    expect(recoveryBox!.y + recoveryBox!.height).toBeLessThanOrEqual(
      viewport!.height,
    );

    await testInfo.attach('oauth-callback-recovery', {
      // Flutter Web canvases can duplicate frames when Playwright temporarily
      // resizes the viewport for a full-page capture. Keep this visual proof
      // aligned with the viewport whose recovery controls were asserted above.
      body: await page.screenshot(),
      contentType: 'image/png',
    });
    await testInfo.attach('oauth-callback-browser-issues', {
      body: JSON.stringify(browserIssues, null, 2),
      contentType: 'application/json',
    });
    expect(browserIssues).toEqual([]);
  });

  test('H03 control keeps recoverable authentication before the lower trial', async ({
    page,
  }) => {
    await openLanding(page, controlPath);

    const googleAction = page.getByRole('button', {
      name: 'Googleで無料登録',
      exact: true,
    });
    const magicLinkAction = page.getByRole('button', {
      name: 'Magic Linkで今すぐ始める',
      exact: true,
    });
    const lowerTrial = page.getByRole('button', {
      name: '今やる1件を試す',
      exact: true,
    });

    await expect(googleAction).toBeVisible();
    await expect(magicLinkAction).toBeVisible();
    await expect(lowerTrial).toBeVisible();
    await expect(
      page.getByRole('textbox', { name: /登録なしで試す/ }),
    ).toHaveCount(0);

    const authBox = await googleAction.boundingBox();
    const trialBox = await lowerTrial.boundingBox();
    expect(authBox).not.toBeNull();
    expect(trialBox).not.toBeNull();
    expect(authBox!.y).toBeLessThan(trialBox!.y);

    await page
      .getByRole('textbox', { name: /メールアドレス/ })
      .first()
      .fill('sales @example.com');
    await magicLinkAction.click();
    await expect(
      page.getByText('メールアドレスの形式を確認してください。', {
        exact: false,
      }).first(),
    ).toBeVisible();
    await expect(googleAction).toBeVisible();
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

  await page.route('**/functions/v1/growth-hub', async (route) => {
    const body = JSON.parse(route.request().postData() ?? '{}') as {
      action?: string;
    };
    const responseBody = body.action === 'landing.trial'
      ? {
          success: true,
          action: '止まっている案件を1つ開き、確認先を1人決める',
          reason: '10分で連絡文の下書きまで進められるためです。',
        }
      : { success: true, skipped: true };
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(responseBody),
    });
  });

  const response = await page.goto(path, { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBeTruthy();
  await expect(page).toHaveTitle(
    '自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ',
    { timeout: 60_000 },
  );
  await expect(
    page.getByText('仕事・学習・お金の「次の1件」を、AIと一緒に絞る', {
      exact: true,
    }),
  ).toBeVisible({ timeout: 60_000 });
  await page.locator('#seo-shell').waitFor({
    state: 'detached',
    timeout: 10_000,
  });
}
