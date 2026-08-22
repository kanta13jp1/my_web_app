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

  test('custom input hides the unrelated fixed sample without hiding the trial action', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    const trialInput = page.getByRole('textbox', { name: /登録なしで試す/ });
    const sampleAction = page.getByRole('button', {
      name: 'この入力例でAIに提案させる',
      exact: true,
    });
    const trialAction = page.getByRole('button', {
      name: '今やる1件を試す',
      exact: true,
    });

    await expect(sampleAction).toBeVisible();
    const inputBoxBeforeTyping = await trialInput.boundingBox();
    const trialActionBox = await trialAction.boundingBox();
    const prompt =
      'サブスクで無駄な支払いが多い。サブスクを棚卸ししたい。';
    expect(trialActionBox).not.toBeNull();
    await page.mouse.click(
      trialActionBox!.x + trialActionBox!.width / 2,
      trialActionBox!.y - 20,
    );
    await expect(trialInput).toBeFocused();
    for (const character of prompt) {
      await page.keyboard.insertText(character);
      await expect(trialInput).toBeFocused();
    }

    await expect(trialInput).toHaveValue(prompt);
    const inputBoxAfterTyping = await trialInput.boundingBox();
    expect(inputBoxBeforeTyping).not.toBeNull();
    expect(inputBoxAfterTyping).not.toBeNull();
    expect(inputBoxAfterTyping!.y).toBeCloseTo(
      inputBoxBeforeTyping!.y,
      1,
    );

    await expect(sampleAction).toBeVisible();
    await page.keyboard.press('Tab');
    await expect(sampleAction).toHaveCount(0);
    await expect(trialAction).toBeVisible();
  });

  test('trial action reveals the generated result without jumping to the save form', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    const trialInput = page.getByRole('textbox', { name: /登録なしで試す/ });
    const trialAction = page.getByRole('button', {
      name: '今やる1件を試す',
      exact: true,
    });
    const trialActionBox = await trialAction.boundingBox();
    expect(trialActionBox).not.toBeNull();
    await page.mouse.click(
      trialActionBox!.x + trialActionBox!.width / 2,
      trialActionBox!.y - 20,
    );
    await page.keyboard.insertText('今日の最優先タスクを1件に絞りたい');
    await trialAction.click();
    await completeGuidedTrial(page);

    const trialResultCard = page.getByRole('group', {
      name: /登録なしで試す:.*AIからの提案.*10分で連絡文の下書きまで進められるためです。/,
    });
    await expect(trialResultCard).toBeVisible();
    await expect(trialAction).toBeVisible();
    const triggerBoxAfterResult = await trialAction.boundingBox();
    const viewport = page.viewportSize();
    expect(triggerBoxAfterResult).not.toBeNull();
    expect(viewport).not.toBeNull();
    expect(triggerBoxAfterResult!.y).toBeGreaterThanOrEqual(0);
    expect(triggerBoxAfterResult!.y + triggerBoxAfterResult!.height).toBeLessThan(
      viewport!.height * 0.7,
    );
    await expect(
      page.getByRole('textbox', { name: 'メールアドレス', exact: true }),
    ).toHaveCount(0);
  });

  test('H04 treatment reveals Google save and Magic Link fallback after value', async ({
    page,
  }) => {
    await openLanding(page, treatmentPath);

    await page
      .getByRole('button', {
        name: 'この入力例でAIに提案させる',
        exact: true,
      })
      .click();

    const trialResultCard = page.getByRole('group', {
      name: /登録なしで試す:.*AIからの提案.*10分で連絡文の下書きまで進められるためです。/,
    });
    await expect(trialResultCard).toBeVisible();
    await expect(
      page.getByRole('button', {
        name: 'Googleで無料登録して引き継ぐ',
        exact: true,
      }),
    ).toBeVisible();
    await expect(
      page.getByRole('textbox', { name: 'メールアドレス', exact: true }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', {
        name: '無料登録して提案を引き継ぐ',
        exact: true,
      }),
    ).toBeVisible();
    await expect(trialResultCard).toHaveAccessibleName(
      /パスワード・カード入力はありません。/,
    );
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

async function completeGuidedTrial(page: Page) {
  for (let step = 0; step < 5; step += 1) {
    await expect(
      page.getByRole('group', {
        name: new RegExp(`登録なしで試す:.*質問 ${step + 1} / 5`),
      }),
    ).toBeVisible();
    const quickAnswer = page.getByRole('button', { name: /迷ったら/ });
    await expect(quickAnswer).toBeVisible();
    await quickAnswer.click();
    const next = page.getByRole('button', {
      name: step === 4 ? '送る内容を確認' : '次の質問へ',
      exact: true,
    });
    await expect(next).toBeEnabled();
    await next.click();
  }
  await expect(
    page.getByRole('group', {
      name: /登録なしで試す:.*AIに送る内容を確認/,
    }),
  ).toBeVisible();
  const submit = page.getByRole('button', {
    name: 'この内容でAIに提案してもらう',
    exact: true,
  });
  await expect(submit).toBeVisible();
  await submit.click();
}

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
