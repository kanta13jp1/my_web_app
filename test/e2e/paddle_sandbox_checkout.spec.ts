import {
  expect,
  Frame,
  Locator,
  Page,
  test,
  TestInfo,
} from '@playwright/test';

type PaddleEvent = {
  receivedAt?: string;
  name?: string;
  checkoutId?: string | null;
  transactionId?: string | null;
  message?: string | null;
};

type Scenario = 'success' | 'failure' | 'cancel';

const realSandboxEnabled = process.env.PADDLE_SANDBOX_E2E === 'true';
const testEmail = 'paddle-sandbox-e2e@example.com';

test.describe('real Paddle sandbox checkout', () => {
  test.describe.configure({ mode: 'serial', timeout: 180_000 });
  test.skip(
    !realSandboxEnabled,
    'Set PADDLE_SANDBOX_E2E=true only in the guarded manual cloud workflow.',
  );

  test('cancel emits checkout.closed and Flutter shows cancellation', async ({
    page,
    browser,
  }, testInfo) => {
    await openFlutterCheckout(page);
    await closeCheckout(page);
    await expectFlutterText(page, 'Sandbox checkout を中断しました。');

    const events = await collectEvidence(page, testInfo, 'cancel', {
      browserVersion: browser.version(),
    });
    expect(eventNames(events)).toContain('checkout.closed');
    expect(eventNames(events)).not.toContain('checkout.completed');
  });

  test('declined card emits failure and Flutter renders error state', async ({
    page,
    browser,
  }, testInfo) => {
    await openFlutterCheckout(page);
    await completeCardForm(page, '4000000000000002');
    await expect(
      page.getByRole('button', { name: 'もう一度試す' }),
    ).toBeVisible({ timeout: 60_000 });

    const events = await collectEvidence(page, testInfo, 'failure', {
      browserVersion: browser.version(),
    });
    expect(eventNames(events)).toEqual(
      expect.arrayContaining([
        expect.stringMatching(
          /^checkout\.(payment\.(failed|error)|error)$/,
        ),
      ]),
    );
    await closeCheckoutIfPresent(page);
    await expect(
      page.getByRole('button', { name: 'もう一度試す' }),
      'checkout.closed must not replace the failed terminal state',
    ).toBeVisible({ timeout: 30_000 });
  });

  test('valid test card completes and Flutter renders success state', async ({
    page,
    browser,
  }, testInfo) => {
    await openFlutterCheckout(page);
    await completeCardForm(page, '4242424242424242');
    await expect(
      page.getByRole('button', { name: 'ホームへ戻る' }),
    ).toBeVisible({ timeout: 90_000 });

    const events = await collectEvidence(page, testInfo, 'success', {
      browserVersion: browser.version(),
    });
    expect(eventNames(events)).toContain('checkout.completed');
    expect(
      events.some((event) => Boolean(event.transactionId)),
      'checkout.completed evidence should include a transaction ID',
    ).toBe(true);
    await closeCheckoutIfPresent(page);
    await expect(
      page.getByRole('button', { name: 'ホームへ戻る' }),
      'checkout.closed must not replace the completed terminal state',
    ).toBeVisible({ timeout: 30_000 });
  });
});

async function openFlutterCheckout(page: Page) {
  // The evidence server falls back to index.html for Flutter path routes.
  const response = await page.goto('/subscription-billing', {
    waitUntil: 'domcontentloaded',
  });
  expect(response?.ok()).toBe(true);

  await page.waitForFunction(
    () =>
      Boolean(
        document.querySelector('flutter-view') ||
          document.querySelector('flt-glass-pane'),
      ),
    undefined,
    { timeout: 60_000 },
  );
  await enableFlutterAccessibility(page);

  const checkoutButton = page.getByRole('button', {
    name: /Paddle sandbox を開く|もう一度試す/,
  });
  await expect(checkoutButton).toBeVisible({
    timeout: 30_000,
  });
  await checkoutButton.scrollIntoViewIfNeeded();
  await checkoutButton.click();
  await expect(page.locator('iframe[name="paddle_frame"]')).toBeVisible({
    timeout: 30_000,
  });
}

async function enableFlutterAccessibility(page: Page) {
  const placeholder = page.locator('flt-semantics-placeholder').first();
  await placeholder.waitFor({ state: 'attached', timeout: 5_000 }).catch(
    () => undefined,
  );
  if ((await placeholder.count()) > 0) {
    // Flutter's semantics placeholder can be intentionally zero-sized and
    // outside the rendered viewport. Dispatch the element's click handler
    // directly so headless cloud runners can enable accessibility without a
    // coordinate-based Playwright click.
    await placeholder.evaluate((element) =>
      (element as HTMLElement).click(),
    );
  }
}

async function completeCardForm(page: Page, cardNumber: string) {
  const email = await findVisibleInFrames(
    page,
    (frame) =>
      frame
        .getByLabel(/email/i)
        .or(frame.getByPlaceholder(/email/i))
        .or(frame.locator('input[type="email"]')),
    30_000,
  );
  await email.fill(testEmail);

  await chooseCountryIfRequired(page);
  await fillIfVisible(page, /zip|postal/i, '10001');
  await clickVisibleInFrames(page, /continue|next|次へ/i, 30_000);

  const card = await findVisibleInFrames(
    page,
    (frame) =>
      frame
        .getByLabel(/card number/i)
        .or(frame.getByPlaceholder(/card number/i))
        .or(frame.locator('input[autocomplete="cc-number"]')),
    30_000,
  );
  await card.fill(cardNumber);

  await fillRequiredField(
    page,
    /expiration|expiry|mm\s*\/\s*yy/i,
    '12/30',
    'input[autocomplete="cc-exp"]',
  );
  await fillRequiredField(
    page,
    /security code|cvc|cvv/i,
    '100',
    'input[autocomplete="cc-csc"]',
  );
  await fillIfVisible(page, /name on card|card\s*holder/i, 'Paddle Sandbox Test');
  await fillIfVisible(page, /zip|postal/i, '10001');

  await clickVisibleInFrames(
    page,
    /^(?:pay\s+[$€£¥]\s*\d[\d.,]*|pay now|subscribe now|complete purchase|purchase|buy now|start subscription)(?:\s.*)?$/i,
    30_000,
  );
}

async function chooseCountryIfRequired(page: Page) {
  const select = await maybeFindVisibleInFrames(page, (frame) =>
    frame.locator(
      'select[autocomplete="country"], select[name*="country" i]',
    ),
  );
  if (select) {
    await select.selectOption('US').catch(async () => {
      await select.selectOption({ label: 'United States' });
    });
    return;
  }

  const country = await maybeFindVisibleInFrames(page, (frame) =>
    frame
      .getByLabel(/country/i)
      .or(frame.getByRole('combobox', { name: /country/i })),
  );
  if (!country) return;

  await country.click();
  const option = await findVisibleInFrames(
    page,
    (frame) => frame.getByRole('option', { name: /United States/i }),
    10_000,
  );
  await option.click();
}

async function fillRequiredField(
  page: Page,
  label: RegExp,
  value: string,
  fallbackSelector: string,
) {
  const field = await findVisibleInFrames(
    page,
    (frame) =>
      frame
        .getByLabel(label)
        .or(frame.getByPlaceholder(label))
        .or(frame.locator(fallbackSelector)),
    30_000,
  );
  await field.fill(value);
}

async function fillIfVisible(page: Page, label: RegExp, value: string) {
  const field = await maybeFindVisibleInFrames(page, (frame) =>
    frame
      .getByLabel(label)
      .or(frame.getByPlaceholder(label)),
  );
  if (field) await field.fill(value);
}

async function closeCheckout(page: Page) {
  const close = await findVisibleInFrames(
    page,
    (frame) =>
      frame
        .getByRole('button', { name: /close|閉じる/i })
        .or(frame.getByLabel(/close|閉じる/i))
        .or(frame.locator('img[alt="Close"]')),
    20_000,
  );
  await close.click();
}

async function closeCheckoutIfPresent(page: Page) {
  const frame = page.locator('iframe[name="paddle_frame"]');
  if (!(await frame.isVisible().catch(() => false))) return;
  await closeCheckout(page);
  await expect(frame).toBeHidden({ timeout: 30_000 });
}

async function expectFlutterText(
  page: Page,
  text: string,
  timeout = 30_000,
) {
  await expect(page.getByText(text, { exact: false })).toBeVisible({ timeout });
}

async function clickVisibleInFrames(
  page: Page,
  name: RegExp,
  timeout: number,
) {
  const button = await findVisibleInFrames(
    page,
    (frame) => frame.getByRole('button', { name }),
    timeout,
  );
  await expect(button).toBeEnabled();
  await button.click();
}

async function findVisibleInFrames(
  page: Page,
  factory: (frame: Frame) => Locator,
  timeout: number,
) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const match = await maybeFindVisibleInFrames(page, factory);
    if (match) return match;
    await page.waitForTimeout(250);
  }
  throw new Error(`No matching visible Paddle control appeared in ${timeout}ms`);
}

async function maybeFindVisibleInFrames(
  page: Page,
  factory: (frame: Frame) => Locator,
) {
  for (const frame of page.frames().reverse()) {
    const candidates = factory(frame);
    const count = await candidates.count().catch(() => 0);
    for (let index = 0; index < count; index += 1) {
      const candidate = candidates.nth(index);
      if (await candidate.isVisible().catch(() => false)) return candidate;
    }
  }
  return null;
}

async function collectEvidence(
  page: Page,
  testInfo: TestInfo,
  scenario: Scenario,
  metadata: { browserVersion: string },
) {
  const events = await page.evaluate<PaddleEvent[]>(() => {
    const readLog = (
      window as Window & {
        getPaddleSandboxEventLog?: () => PaddleEvent[];
      }
    ).getPaddleSandboxEventLog;
    return typeof readLog === 'function' ? readLog() : [];
  });
  const evidence = {
    scenario,
    result: testInfo.status,
    recordedAtJst: formatJst(new Date()),
    browser: `Chromium ${metadata.browserVersion}`,
    githubSha: process.env.GITHUB_SHA ?? null,
    events,
  };

  await testInfo.attach(`${scenario}-events.json`, {
    body: Buffer.from(`${JSON.stringify(evidence, null, 2)}\n`),
    contentType: 'application/json',
  });
  await testInfo.attach(`${scenario}-flutter-result.png`, {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });
  return events;
}

function eventNames(events: PaddleEvent[]) {
  return events.map((event) => event.name ?? '');
}

function formatJst(date: Date) {
  return `${new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'Asia/Tokyo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(date)} JST`;
}
