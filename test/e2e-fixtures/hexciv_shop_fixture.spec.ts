import { expect, Page, Route, test, TestInfo } from '@playwright/test';

// Runs the real main.dart route. Only HTTP responses/session data are fixtures.
// Never run this against production or use real accounts, tokens, or payments.
const appOrigin = 'http://127.0.0.1:7357';
const apiOrigin = 'http://127.0.0.1:54321';
if (process.env.E2E_BASE_URL !== appOrigin) {
  throw new Error('HexCiv fixture requires E2E_BASE_URL=' + appOrigin);
}
const productId = 'hexciv-win64';
const title = 'HexCiv (Windows版)';
const buyLabel = '¥500 で購入';
const query = '?utm_source=fixture&utm_campaign=hexciv_browser';
const product = {
  id: productId,
  name_ja: title,
  summary_ja: '文明の発展を楽しむWindows用4Xゲーム。',
  description_ja: 'ブラウザ検証用の商品情報です。実際の販売・購入ではありません。',
  price_jpy: 500,
  version: 'fixture',
  file_size_bytes: 37539020,
  sha256: '0'.repeat(64),
  stripe_price_id: 'price_browser_fixture_not_real',
  product_type: 'game',
  format_label: 'ZIP / Windows',
  requirements_ja: 'Windows 10 / 11 (64-bit)',
  license_summary_ja: 'テスト用。配布・決済は行いません。',
  preview_image_url: null,
  download_file_name: 'HexCiv-fixture.zip',
};

type Payload = Record<string, unknown>;
type LiveAnnouncement = { message: string; assertiveness: string };
type FixtureWindow = Window & { __hexcivLiveAnnouncements?: LiveAnnouncement[] };
type Options = {
  signedIn?: boolean;
  purchased?: boolean;
  empty?: boolean;
  purchasable?: boolean;
  failProductOnce?: boolean;
  productErrorStatus?: number;
  holdProduct?: boolean;
  holdCheckout?: boolean;
  telemetryFails?: boolean;
};

function barrier() {
  let release!: () => void;
  const promise = new Promise<void>((resolve) => { release = resolve; });
  return { promise, release };
}

async function installFixture(page: Page, options: Options = {}) {
  const events: Payload[] = [];
  const checkouts: Payload[] = [];
  const blocked: string[] = [];
  const pageErrors: string[] = [];
  const assetResponses = new Set<string>();
  const productRequests: { kind: string; query: string }[] = [];
  const productBarrier = barrier();
  const checkoutBarrier = barrier();
  let productCalls = 0;
  let checkoutFails = false;
  let purchased = options.purchased ?? false;
  // Flutter 3.38 LiveRegion announces via a separate flt-announcement-* node,
  // removed after 300ms. Observe before boot, including open shadow DOM roots,
  // so assertions verify actual polite announcements rather than DOM timing.
  await page.addInitScript(() => {
    const announcements: LiveAnnouncement[] = [];
    (window as FixtureWindow).__hexcivLiveAnnouncements = announcements;
    const observed = new WeakSet<Node>();
    const scan = (root: Document | ShadowRoot) => {
      if (!observed.has(root)) {
        observed.add(root);
        observer.observe(root, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ['aria-live'] });
      }
      for (const node of root.querySelectorAll('[aria-live]')) {
        const message = node.textContent?.trim() ?? '';
        const assertiveness = node.getAttribute('aria-live') ?? '';
        if (message === '商品情報を読み込み中' &&
            !announcements.some((item) => item.message === message && item.assertiveness === assertiveness)) {
          announcements.push({ message, assertiveness });
        }
      }
      for (const node of root.querySelectorAll('*')) {
        if (node.shadowRoot) scan(node.shadowRoot);
      }
    };
    const observer = new MutationObserver(() => scan(document));
    scan(document);
  });
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('response', (response) => {
    if (response.ok() && /hexciv_turn(30|80|150)\.png/.test(response.url())) {
      assetResponses.add(new URL(response.url()).pathname);
    }
  });

  // Supabase Flutter 2.17.2 uses the unprefixed web storage key directly.
  // This is deliberately a fake, unsigned token, usable only by intercepted HTTP.
  const user = {
    id: '11111111-1111-4111-8111-111111111111',
    aud: 'authenticated', role: 'authenticated',
    email: 'browser-fixture@example.invalid',
    created_at: '2026-01-01T00:00:00Z',
    app_metadata: { provider: 'email', providers: ['email'] }, user_metadata: {},
  };
  const encode = (value: unknown) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({ sub: user.id, exp: 2208988800 })}.fixture`;
  const session = {
    access_token: token, refresh_token: 'fixture-not-a-real-refresh-token',
    token_type: 'bearer', expires_in: 3600, expires_at: 2208988800, user,
  };
  await page.addInitScript(({ session, signedIn }) => {
    window.localStorage.clear();
    window.sessionStorage.clear();
    if (signedIn) {
      window.localStorage.setItem('sb-127-auth-token', JSON.stringify(session));
    }
  }, { session, signedIn: options.signedIn ?? false });

  const reply = (route: Route, json: unknown, status = 200) => route.fulfill({
    status, contentType: 'application/json', body: JSON.stringify(json),
    headers: {
      'access-control-allow-origin': appOrigin,
      'access-control-allow-headers': '*',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
    },
  });
  await page.context().route('**/*', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin === apiOrigin) {
      if (request.method() === 'OPTIONS') return reply(route, {});
      if (url.pathname === '/rest/v1/shop_products') {
        // Navigator's deep-link route stack can load /shop's catalog as well
        // as /shop/hexciv. Only the id-filtered detail request owns these gates.
        const isDetail = url.searchParams.get('id') === `eq.${productId}`;
        productRequests.push({ kind: isDetail ? 'detail' : 'catalog', query: url.search });
        if (!isDetail) return reply(route, options.empty ? [] : [product]);
        productCalls++;
        if (options.holdProduct) await productBarrier.promise;
        if (options.failProductOnce && productCalls === 1) {
          return reply(route, { message: 'fixture_product_unavailable', code: 'FIXTURE' }, options.productErrorStatus ?? 400);
        }
        // maybeSingle() in PostgREST requests an array, then checks its size.
        return reply(route, options.empty ? [] : [{ ...product,
          stripe_price_id: options.purchasable === false ? null : product.stripe_price_id,
        }]);
      }
      if (url.pathname === '/rest/v1/shop_purchases') {
        return reply(route, purchased ? [{ id: 'fixture-purchase' }] : []);
      }
      if (url.pathname === '/functions/v1/shop-funnel') {
        events.push(request.postDataJSON());
        return reply(route, { ok: !options.telemetryFails }, options.telemetryFails ? 503 : 200);
      }
      if (url.pathname === '/functions/v1/shop-checkout') {
        checkouts.push(request.postDataJSON());
        if (options.holdCheckout) await checkoutBarrier.promise;
        return checkoutFails
          ? reply(route, { error: 'fixture_checkout_unavailable' }, 503)
          : reply(route, { checkout_url: `${appOrigin}/fixture-checkout` });
      }
      if (url.pathname === '/auth/v1/user') return reply(route, user);
      if (url.pathname === '/auth/v1/token') return reply(route, session);
      // Unrelated startup observers cannot write to a real backend.
      if (url.pathname.startsWith('/rest/v1/')) return reply(route, []);
      if (url.pathname.startsWith('/functions/v1/')) return reply(route, {});
      return reply(route, { error: 'Unexpected fixture API path' }, 404);
    }
    if (url.origin === appOrigin && request.method() === 'GET') {
      if (url.pathname === '/fixture-checkout') {
        return route.fulfill({ contentType: 'text/html; charset=utf-8',
          body: '<!doctype html><meta charset="utf-8"><h1>Mock checkout destination — no payment</h1>' });
      }
      return route.continue();
    }
    // The engine may fetch its public renderer/font files. No remote POSTs,
    // account APIs, Stripe endpoints, analytics or customer traffic are allowed.
    if (request.method() === 'GET' &&
        ['www.gstatic.com', 'fonts.gstatic.com'].includes(url.hostname)) {
      return route.continue();
    }
    blocked.push(`${request.method()} ${url.origin}${url.pathname}`);
    return route.abort('blockedbyclient');
  });
  return {
    events, checkouts, blocked, pageErrors, assetResponses, productRequests,
    releaseProduct: productBarrier.release,
    releaseCheckout: checkoutBarrier.release,
    failCheckout: (value: boolean) => { checkoutFails = value; },
    setPurchased: (value: boolean) => { purchased = value; },
    productCalls: () => productCalls,
  };
}

async function openShop(page: Page, suffix = query) {
  const response = await page.goto('/shop/hexciv' + suffix, { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBe(true);
  await page.locator('flutter-view, flt-glass-pane').first().waitFor({ timeout: 60_000 });
  await page.locator('#seo-shell').waitFor({ state: 'detached' });
}

async function capture(page: Page, info: TestInfo, name: string, stable = true) {
  // Flutter's semantic DOM may update before its canvas paint/scroll. Retain a
  // capture only after three consecutive rendered frames agree (no masks).
  let previous: Buffer | undefined;
  let stableFrames = 0;
  if (!stable) {
    // The live Flutter loading spinner intentionally never becomes static.
    await page.evaluate(() => new Promise<void>(resolve =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
    await info.attach(name, { body: await page.screenshot(), contentType: 'image/png' });
    return;
  }
  await expect.poll(async () => {
    await page.evaluate(() => new Promise<void>(resolve =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
    const current = await page.screenshot({ animations: 'disabled' });
    stableFrames = previous?.equals(current) ? stableFrames + 1 : 0;
    previous = current;
    return stableFrames;
  }, { timeout: 10_000, intervals: [100, 150, 250] }).toBeGreaterThanOrEqual(2);
  await info.attach(name, { body: previous!,
    contentType: 'image/png' });
}

async function evidence(page: Page, info: TestInfo, state: Awaited<ReturnType<typeof installFixture>>) {
  await info.attach('fixture-evidence', {
    contentType: 'application/json',
    body: JSON.stringify({
      scope: 'Real Flutter page; mocked HTTP and auth. NOT production P1 or Stripe/webhook validation.',
      route: page.url(), project: info.project.name,
      events: state.events, checkouts: state.checkouts,
      blocked: state.blocked, pageErrors: state.pageErrors,
      productRequests: state.productRequests,
      liveAnnouncements: await page.evaluate(() => (window as FixtureWindow).__hexcivLiveAnnouncements ?? []),
      screenshotAssetResponses: [...state.assetResponses],
    }, null, 2),
  });
  expect(state.pageErrors).toEqual([]);
  expect(state.blocked, 'Unexpected external traffic was blocked').toEqual([]);
  expect(state.events.every((event) => event.stage !== 'purchase_complete')).toBe(true);
}

test.use({ serviceWorkers: 'block' });
test.setTimeout(90_000);

test('loading, guest CTA and three real-game screenshots', async ({ page }, info) => {
  const fixture = await installFixture(page, { holdProduct: true });
  await openShop(page);
  try {
    // The visible semantics label and the engine announcement are distinct.
    const loading = page.getByRole('group').filter({ hasText: '商品情報を読み込み中' });
    await expect(loading).toBeVisible();
    await expect(loading).toHaveText('商品情報を読み込み中');
    await expect.poll(() => page.evaluate(() => (window as FixtureWindow).__hexcivLiveAnnouncements ?? []))
      .toContainEqual({ message: '商品情報を読み込み中', assertiveness: 'polite' });
    await capture(page, info, 'loading', false);
  } finally { fixture.releaseProduct(); }
  await expect(page.getByText(title, { exact: true })).toBeVisible();
  await expect(page.getByRole('img', { name: 'ターン30のゲーム画面', exact: true })).toBeVisible();
  await capture(page, info, 'guest-product');
  for (const turn of [30, 80, 150]) {
    const thumbnail = page.getByRole('button', { name: new RegExp(`ターン${turn}のスクリーンショットを表示`) });
    await thumbnail.scrollIntoViewIfNeeded();
    await thumbnail.click();
    const caption = page.getByText(new RegExp(turn === 30 ? '^序盤。' : turn === 80 ? '^中盤。' : '^終盤。'));
    await expect(caption).toBeVisible();
    await expect(page.getByRole('img', { name: `ターン${turn}のゲーム画面`, exact: true })).toBeVisible();
    await capture(page, info, `gallery-turn${turn}`);
  }
  expect(fixture.assetResponses.size).toBe(3);
  const login = page.getByRole('button', { name: 'ログインして購入', exact: true });
  await login.scrollIntoViewIfNeeded();
  await expect(login).toBeEnabled();
  await capture(page, info, 'guest-login-required');
  await expect.poll(() => fixture.events.filter((event) => event.stage === 'product_view').length).toBe(1);
  expect(fixture.checkouts).toEqual([]);
  await evidence(page, info, fixture);
});

test('product request error can recover with retry', async ({ page }, info) => {
  const fixture = await installFixture(page, { failProductOnce: true });
  await openShop(page);
  await expect(page.getByText('商品情報を読み込めませんでした', { exact: true })).toBeVisible();
  await expect(page.getByText(/通信状況を確認して「再試行」/)).toBeVisible();
  await expect(page.getByText(/PostgrestException|fixture_product_unavailable/)).toHaveCount(0);
  await capture(page, info, 'product-request-error');
  await page.getByRole('button', { name: '再試行', exact: true }).click();
  await expect(page.getByText(title, { exact: true })).toBeVisible();
  expect(fixture.productCalls()).toBe(2);
  await capture(page, info, 'product-recovered');
  await evidence(page, info, fixture);
});

test('transient product failure recovers through client automatic retry', async ({ page }, info) => {
  const fixture = await installFixture(page, { failProductOnce: true, productErrorStatus: 503 });
  await openShop(page);
  await expect(page.getByText(title, { exact: true })).toBeVisible({ timeout: 30_000 });
  expect(fixture.productCalls()).toBe(2);
  await expect(page.getByText('商品情報を読み込めませんでした', { exact: true })).toHaveCount(0);
  await capture(page, info, 'transient-request-recovered');
  await evidence(page, info, fixture);
});

test('unpublished product does not offer purchase', async ({ page }, info) => {
  const fixture = await installFixture(page, { empty: true });
  await openShop(page);
  await expect(page.getByText('準備中です', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: buyLabel, exact: true })).toHaveCount(0);
  await capture(page, info, 'unpublished');
  await evidence(page, info, fixture);
});

test('missing price does not offer checkout', async ({ page }, info) => {
  const fixture = await installFixture(page, { signedIn: true, purchasable: false });
  await openShop(page);
  const notice = page.getByText('販売準備中です', { exact: true });
  await notice.scrollIntoViewIfNeeded();
  await expect(notice).toBeVisible();
  await expect(page.getByRole('button', { name: buyLabel, exact: true })).toHaveCount(0);
  await capture(page, info, 'price-unavailable');
  await evidence(page, info, fixture);
});

test('checkout working, failure, retry and same-visitor redirect', async ({ page }, info) => {
  const fixture = await installFixture(page, { signedIn: true, holdCheckout: true });
  fixture.failCheckout(true);
  await openShop(page);
  const buy = page.getByRole('button', { name: buyLabel, exact: true });
  await buy.scrollIntoViewIfNeeded();
  await expect(buy).toBeEnabled();
  await buy.focus();
  await expect(buy).toBeFocused();
  await capture(page, info, 'purchase-keyboard-focus');
  await page.keyboard.press('Enter');
  try {
    await expect(page.getByRole('button', { name: '手続き中…', exact: true })).toBeDisabled();
    await capture(page, info, 'checkout-working-disabled');
  } finally { fixture.releaseCheckout(); }
  // Flutter merges title/body and also creates a temporary announcement copy.
  // Scope visual assertions to the page group, not the offscreen announcer.
  const failure = page.getByRole('group').getByText(/^購入手続きを開始できませんでした/);
  await expect(failure).toBeVisible();
  await expect(failure).toContainText('先に「購入済み」で購入状況を確認');
  await expect(page.getByText(/FunctionException|fixture_checkout_unavailable/)).toHaveCount(0);
  await capture(page, info, 'checkout-error');
  expect(fixture.events.filter((event) => event.stage === 'checkout_redirect')).toHaveLength(0);
  fixture.failCheckout(false);
  await buy.click();
  await expect(page).toHaveURL(`${appOrigin}/fixture-checkout`);
  await expect(page.getByRole('heading', { name: 'Mock checkout destination — no payment' })).toBeVisible();
  await expect.poll(() => fixture.events.filter((event) => event.stage === 'checkout_redirect').length).toBe(1);
  expect(fixture.checkouts).toHaveLength(2);
  expect(fixture.events.filter((event) => event.stage === 'purchase_click')).toHaveLength(2);
  expect(new Set([...fixture.events, ...fixture.checkouts].map((item) => item.visitor_id)).size).toBe(1);
  expect(fixture.events[0].visitor_id).toMatch(/^[0-9a-f-]{36}$/);
  for (const item of [...fixture.events, ...fixture.checkouts]) {
    expect(item.product_id).toBe(productId);
    expect(item.source).toBe('fixture');
  }
  expect(fixture.events.every((event) => event.campaign === 'hexciv_browser')).toBe(true);
  await evidence(page, info, fixture);
});

test('telemetry outage does not prevent mock checkout', async ({ page }, info) => {
  const fixture = await installFixture(page, { signedIn: true, telemetryFails: true });
  await openShop(page);
  const buy = page.getByRole('button', { name: buyLabel, exact: true });
  await buy.scrollIntoViewIfNeeded();
  await buy.click();
  await expect(page).toHaveURL(`${appOrigin}/fixture-checkout`);
  expect(fixture.checkouts).toHaveLength(1);
  await evidence(page, info, fixture);
});

test('success return waits for entitlement without offering duplicate purchase', async ({ page }, info) => {
  const fixture = await installFixture(page, { signedIn: true });
  await openShop(page, query + '&purchase=success');
  const pending = page.getByText('決済を確認しています', { exact: true });
  await pending.scrollIntoViewIfNeeded();
  await expect(pending).toBeVisible();
  await expect(page.getByText(/お支払いは完了しています/)).toHaveCount(0);
  await expect(page.getByRole('button', { name: buyLabel, exact: true })).toHaveCount(0);
  await capture(page, info, 'entitlement-pending');
  fixture.setPurchased(true);
  await page.getByRole('button', { name: '再読み込み', exact: true }).click();
  const download = page.getByRole('button', { name: 'ダウンロード', exact: true });
  await expect(download).toBeEnabled();
  await expect(page.getByRole('img', { name: 'ターン30のゲーム画面', exact: true })).toBeVisible();
  await download.focus();
  await expect(download).toBeFocused();
  await download.scrollIntoViewIfNeeded();
  await expect(download).toBeInViewport();
  // In the desktop CanvasKit capture, focusing/scrolling the semantic node can
  // leave the painted page at the top after reload (run34667960081). Send real
  // wheel input over the page, then retain the settled, unmasked pixels below.
  // The mobile focus capture already shows the control; do not overscroll it.
  const viewport = page.viewportSize();
  if (viewport && viewport.width >= 800) {
    await page.mouse.move(viewport.width / 2, viewport.height / 2);
    await page.mouse.wheel(0, viewport.height * 0.75);
  }
  await expect(download).toBeInViewport();
  await expect(page.getByRole('button', { name: buyLabel, exact: true })).toHaveCount(0);
  await capture(page, info, 'entitlement-confirmed');
  expect(fixture.checkouts).toEqual([]);
  await evidence(page, info, fixture);
});

test('canceled return explains that purchase did not complete', async ({ page }, info) => {
  const fixture = await installFixture(page, { signedIn: true });
  await openShop(page, query + '&purchase=canceled');
  await expect(page.getByText('購入は完了していません', { exact: true })).toBeVisible();
  await capture(page, info, 'checkout-canceled');
  const buy = page.getByRole('button', { name: buyLabel, exact: true });
  await buy.scrollIntoViewIfNeeded();
  await expect(buy).toBeEnabled();
  expect(fixture.checkouts).toEqual([]);
  await evidence(page, info, fixture);
});
