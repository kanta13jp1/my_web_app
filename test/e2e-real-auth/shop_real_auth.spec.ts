import { expect, Locator, Page, test, TestInfo } from '@playwright/test';
import { readFileSync, mkdirSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';

const app = 'http://127.0.0.1:7357';
const api = 'http://127.0.0.1:54321';
const project = `hexciv-auth-${process.env.GITHUB_RUN_ID}-${process.env.GITHUB_RUN_ATTEMPT}`;
const work = resolve(process.env.RUNNER_TEMP ?? '', project);
if (process.env.GITHUB_ACTIONS !== 'true' || process.env.RUNNER_ENVIRONMENT !== 'github-hosted' ||
    !/^hexciv-auth-[1-9][0-9]*-[1-9][0-9]*$/.test(project) ||
    dirname(work) !== resolve(process.env.RUNNER_TEMP ?? '') || process.env.E2E_BASE_URL !== app) {
  throw new Error('Refusing non-isolated browser credentials');
}
const state = JSON.parse(readFileSync(join(work, 'state.json'), 'utf8'));
if (state.url !== api || state.project !== project) throw new Error('Unexpected Auth origin');
// Never inject a fabricated session, intercept an Auth/REST response, or use the
// service-role key in a browser. Only the real password login form signs in.
const users: Record<string, { email: string; password: string }> = state.users;
const product = '/shop/product?product_id=hexciv-win64&utm_source=isolated&utm_campaign=real-auth-test&utm_content=browser';
const observations = new Map<Page, Awaited<ReturnType<typeof isolation>>>();

async function isolation(page: Page) {
  const calls: { path: string; method: string; status: number }[] = [];
  const blocked = new Set<string>();
  const pageErrors: string[] = [];
  page.on('pageerror', () => pageErrors.push('Unhandled browser exception (body intentionally omitted)'));
  page.on('response', r => {
    const u = new URL(r.url());
    if (u.origin === api && (u.pathname.startsWith('/auth/v1/') ||
        u.pathname.includes('shop_product') || u.pathname.includes('shop_purchases'))) {
      calls.push({ path: u.pathname, method: r.request().method(), status: r.status() });
    }
  });
  await page.context().route('**/*', route => {
    const r = route.request();
    const u = new URL(r.url());
    if (u.origin === api || (u.origin === app && r.method() === 'GET')) return route.continue();
    // Renderer/font downloads only, never external auth, analytics, or checkout.
    if (r.method() === 'GET' && ['www.gstatic.com', 'fonts.gstatic.com'].includes(u.hostname)) return route.continue();
    blocked.add(`${r.method()} ${u.origin}${u.pathname}`);
    return route.abort('blockedbyclient');
  });
  const observed = { calls, blocked, pageErrors, phase: 'boot' };
  observations.set(page, observed);
  return observed;
}

async function boot(page: Page, path: string) {
  const response = await page.goto(path, { waitUntil: 'domcontentloaded' });
  expect(response?.ok()).toBe(true);
  await page.locator('flutter-view, flt-glass-pane').first().waitFor({ timeout: 60_000 });
  await page.locator('#seo-shell').waitFor({ state: 'detached' });
}

async function click(page: Page, target: Locator) {
  await target.scrollIntoViewIfNeeded();
  await expect(target).toBeEnabled();
  await target.click(); // No force/JS click: use real pointer input.
}

async function footer(page: Page) {
  const reload = page.getByRole('button', { name: '更新情報と口コミを再読み込み', exact: true });
  await reload.scrollIntoViewIfNeeded();
  const v = page.viewportSize()!;
  await page.mouse.move(v.width / 2, v.height / 2);
  await page.mouse.wheel(0, 20_000);
  await expect(reload).toBeInViewport();
  await expect(reload).toBeEnabled();
}

async function login(page: Page, name: string) {
  await expect(page).toHaveURL(/\/login\?shop_product=hexciv-win64/);
  const toggle = page.getByRole('button', { name: 'パスワードを使う', exact: true });
  // Form layout is allowed to show the password field without a toggle.
  await expect(page.getByRole('textbox', { name: 'メールアドレス', exact: true })).toBeVisible();
  if (await toggle.count()) await click(page, toggle);
  // Password inputs have no implicit textbox role. Match their actual label,
  // as recommended by Playwright, without changing the production widget.
  // Omit credential values and Playwright fill call logs even on failure.
  let field = 'email';
  try {
    observations.get(page)!.phase = 'email-input';
    await page.getByLabel('メールアドレス', { exact: true }).fill(users[name].email, { timeout: 20_000 });
    field = 'password';
    observations.get(page)!.phase = 'password-input';
    await page.getByLabel('パスワード', { exact: true }).fill(users[name].password, { timeout: 20_000 });
  } catch {
    throw new Error(`Could not fill isolated ${field} input; credentials omitted`);
  }
  observations.get(page)!.phase = 'real-auth-submit';
  const authResponse = page.waitForResponse(r => new URL(r.url()).origin === api &&
    new URL(r.url()).pathname === '/auth/v1/token' && r.request().method() === 'POST');
  await click(page, page.getByRole('button', { name: 'メールでログイン', exact: true }));
  expect((await authResponse).status()).toBe(200);
  await expect(page).toHaveURL(/\/shop\/product\?/);
  const location = new URL(page.url());
  expect(location.searchParams.get('product_id')).toBe('hexciv-win64');
  expect(location.searchParams.get('utm_source')).toBe('isolated');
  expect(location.searchParams.get('utm_campaign')).toBe('real-auth-test');
  expect(location.searchParams.get('utm_content')).toBe('browser');
  observations.get(page)!.phase = 'product-after-login';
}

async function capture(page: Page, info: TestInfo, name: string) {
  // Explicit product-only captures. No login page, password, trace or video.
  expect(new URL(page.url()).pathname).toBe('/shop/product');
  await page.evaluate(() => new Promise<void>(r => requestAnimationFrame(() => requestAnimationFrame(() => r()))));
  mkdirSync('shop-real-auth-evidence', { recursive: true });
  await page.screenshot({ path: `shop-real-auth-evidence/${info.project.name}-${name}.png`, animations: 'disabled' });
}

async function summary(page: Page, info: TestInfo, observed: Awaited<ReturnType<typeof isolation>>) {
  expect([...observed.blocked], 'No attempted hosted API or external checkout').toEqual([]);
  expect(observed.pageErrors).toEqual([]);
}

test.afterEach(async ({ page }, info) => {
  const observed = observations.get(page);
  if (!observed) return;
  // Always retain value-free diagnostics, including on failure. Do not capture
  // credentials, full DOM, login screenshots, input values, traces or headers.
  const inputs = page.isClosed() ? [] : await page.locator('input,textarea').evaluateAll(nodes => nodes.map(n => ({
    tag: n.tagName, type: n.getAttribute('type'), role: n.getAttribute('role'),
    disabled: (n as HTMLInputElement).disabled,
  }))).catch(() => []);
  await info.attach('sanitized-api-observations', {
    contentType: 'application/json',
    body: JSON.stringify({ scope: 'Disposable actual Auth/REST; synthetic purchases; not production or payment proof',
      route: page.url(), phase: observed.phase, inputs, calls: observed.calls,
      blocked: [...observed.blocked], pageErrors: observed.pageErrors }),
  });
  observations.delete(page);
});

test('real purchaser login returns to product with attribution; review create/edit/delete persists', async ({ page }, info) => {
  const observed = await isolation(page);
  await boot(page, product);
  await expect(page.getByText('配布版 vauth-test-v1', { exact: true })).toBeVisible();
  await footer(page);
  await expect(page.getByText('口コミ・評価の登録には、ログインと商品の購入が必要です。', { exact: true })).toBeVisible();
  await click(page, page.getByRole('button', { name: 'ログインして購入', exact: true }));
  await login(page, 'a');
  await footer(page);
  await click(page, page.getByRole('button', { name: '口コミ・評価を書く', exact: true }));
  await click(page, page.getByRole('button', { name: '星5を選択', exact: true }));
  await page.getByRole('textbox', { name: '口コミ（任意）', exact: true }).fill('実認証による検証用の口コミ');
  await click(page, page.getByRole('button', { name: '公開して保存', exact: true }));
  await expect(page.getByText('あなたの評価：★ 5 / 5', { exact: true })).toBeVisible();
  await footer(page);
  await capture(page, info, 'review-created');
  await page.reload({ waitUntil: 'domcontentloaded' });
  await footer(page);
  await expect(page.getByText('あなたの評価：★ 5 / 5', { exact: true })).toBeVisible();
  await click(page, page.getByRole('button', { name: '自分の口コミを編集', exact: true }));
  await click(page, page.getByRole('button', { name: '星4を選択', exact: true }));
  await page.getByRole('textbox', { name: '口コミ（任意）', exact: true }).fill('編集が保存された検証用の口コミ');
  await click(page, page.getByRole('button', { name: '公開して保存', exact: true }));
  await expect(page.getByText('あなたの評価：★ 4 / 5', { exact: true })).toBeVisible();
  await footer(page);
  await capture(page, info, 'review-edited');
  await click(page, page.getByRole('button', { name: '自分の口コミを削除', exact: true }));
  await click(page, page.getByRole('button', { name: '削除する', exact: true }));
  await expect(page.getByText('評価はまだありません（0件）', { exact: true })).toBeVisible();
  await footer(page);
  await capture(page, info, 'review-deleted');
  expect(observed.calls.filter(c => c.path.endsWith('/save_shop_product_review') && c.status >= 200 && c.status < 300)).toHaveLength(2);
  await click(page, page.getByRole('button', { name: '口コミ・評価を書く', exact: true }));
  await page.getByRole('textbox', { name: '口コミ（任意）', exact: true }).fill('ログアウトで中断する未送信の下書き');
  // The isolated Dart entrypoint calls the real Supabase client's signOut.
  // No auth event/session/HTTP response is fabricated by this bridge.
  await page.evaluate(async () => {
    const bridge = (window as Window & { hexcivIsolatedSignOut: () => Promise<void> }).hexcivIsolatedSignOut;
    if (typeof bridge !== 'function') throw new Error('Missing isolated sign-out bridge');
    await bridge();
  });
  await expect(page.getByText('ログイン状態が変わりました', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: '公開して保存', exact: true })).toHaveCount(0);
  await click(page, page.getByRole('button', { name: '閉じる', exact: true }));
  await footer(page);
  await expect(page.getByText('口コミ・評価の登録には、ログインと商品の購入が必要です。', { exact: true })).toBeVisible();
  await expect(page.getByText('評価はまだありません（0件）', { exact: true })).toBeVisible();
  expect(observed.calls.some(c => c.path === '/auth/v1/logout' && c.status === 204)).toBe(true);
  expect(observed.calls.filter(c => c.path.endsWith('/save_shop_product_review'))).toHaveLength(2);
  await summary(page, info, observed);
});

test('real nonbuyer session can read updates but cannot open review editor', async ({ page }, info) => {
  const observed = await isolation(page);
  await boot(page, '/login?shop_product=hexciv-win64&utm_source=isolated&utm_campaign=real-auth-test&utm_content=browser');
  await login(page, 'b');
  await footer(page);
  await expect(page.getByText('購入が確認できたアカウントから口コミ・評価を登録できます。', { exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: '口コミ・評価を書く', exact: true })).toHaveCount(0);
  await expect(page.getByText('現在の配布版：vauth-test-v1', { exact: true })).toBeVisible();
  await capture(page, info, 'nonbuyer-read-only');
  expect(observed.calls.some(c => c.path.endsWith('/get_my_shop_product_review') && c.status === 200)).toBe(true);
  expect(observed.calls.some(c => c.path.endsWith('/save_shop_product_review'))).toBe(false);
  await summary(page, info, observed);
});
