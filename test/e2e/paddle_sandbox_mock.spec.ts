import { expect, test } from '@playwright/test';

type PaddleEvent = {
  name: string;
  data?: Record<string, unknown>;
  error?: { detail?: string; message?: string };
};

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    const state: {
      environment?: string;
      eventCallback?: (event: PaddleEvent) => void;
      initializeOptions?: Record<string, unknown>;
      checkoutOptions?: Record<string, unknown>;
    } = {};

    (window as any).__paddleSandboxMock = state;
    (window as any).Paddle = {
      Environment: {
        set(environment: string) {
          state.environment = environment;
        },
      },
      Initialize(options: Record<string, unknown>) {
        state.initializeOptions = options;
        state.eventCallback = options.eventCallback as (
          event: PaddleEvent,
        ) => void;
      },
      Checkout: {
        open(options: Record<string, unknown>) {
          state.checkoutOptions = options;
          queueMicrotask(() =>
            state.eventCallback?.({ name: 'checkout.loaded' }),
          );
        },
      },
    };
  });
});

test('sandbox checkout maps open, failed, cancelled, and completed events', async ({
  page,
}) => {
  await page.goto('/paddle-sandbox');

  await expect(page.getByText('Paddle Sandbox 検証')).toBeVisible({
    timeout: 60_000,
  });
  await expect(page.getByText('検証専用・実課金なし')).toBeVisible();

  await page.getByRole('button', { name: 'Sandbox checkout を開く' }).click();
  await expect(page.getByText('Sandbox checkout を開きました')).toBeVisible();

  const initializedSafely = await page.evaluate(() => {
    const state = (window as any).__paddleSandboxMock;
    const settings = state.checkoutOptions?.settings;
    const items = state.checkoutOptions?.items;
    return {
      environment: state.environment,
      token: state.initializeOptions?.token,
      showAddTaxId: settings?.showAddTaxId,
      successUrl: settings?.successUrl,
      priceId: items?.[0]?.priceId,
    };
  });

  expect(initializedSafely.environment).toBe('sandbox');
  expect(initializedSafely.token).toMatch(/^test_/);
  expect(initializedSafely.showAddTaxId).toBe(true);
  expect(initializedSafely.successUrl).toContain('/paddle-sandbox?paddle=completed');
  expect(initializedSafely.priceId).toMatch(/^pri_/);

  await page.evaluate(() => {
    (window as any).__paddleSandboxMock.eventCallback({
      name: 'checkout.payment.failed',
      error: { detail: 'Sandbox card was declined' },
    });
  });
  await expect(page.getByText('Sandbox 決済が拒否されました')).toBeVisible();
  await expect(page.getByText('Sandbox card was declined')).toBeVisible();

  await page.evaluate(() => {
    (window as any).__paddleSandboxMock.eventCallback({ name: 'checkout.closed' });
  });
  await expect(page.getByText('チェックアウトを閉じました')).toBeVisible();

  await page.evaluate(() => {
    (window as any).__paddleSandboxMock.eventCallback({
      name: 'checkout.completed',
      data: { transaction_id: 'txn_sandbox_mock_2845' },
    });
  });
  await expect(page.getByText('Sandbox決済が完了しました')).toBeVisible();
  await expect(page.getByText('txn_sandbox_mock_2845')).toBeVisible();

  await page.evaluate(() => {
    (window as any).__paddleSandboxMock.eventCallback({ name: 'checkout.closed' });
  });
  await expect(page.getByText('Sandbox決済が完了しました')).toBeVisible();
});
