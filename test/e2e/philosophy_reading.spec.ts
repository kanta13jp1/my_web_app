import { test, expect, type Page, type TestInfo } from '@playwright/test';

async function field(page: Page, name: RegExp, value: string) {
  const input = page.getByRole('textbox', { name });
  await expect(input).toHaveCount(1);
  await input.focus();
  // Flutter connects the browser input to its controller on the next frame.
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await input.fill(value);
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await expect(input).toHaveValue(value);
}
async function restoredField(page: Page, name: RegExp, value: string) {
  const input = page.getByRole('textbox', { name });
  await input.focus();
  // Flutter populates the native accessibility input when it receives focus.
  await page.evaluate(() => new Promise<void>(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve()))));
  await expect(input).toHaveValue(value);
}
async function choose(page: Page, name: RegExp, option: string) {
  await page.getByRole('button', { name }).click();
  const item = page.getByRole('menuitem', { name: option, exact: true });
  const menu = page.getByRole('menu', { name: 'Popup menu', exact: true });
  // Wait for the animated menu to expose its items before deciding to scroll.
  await expect(page.getByRole('menuitem').first()).toBeVisible();
  await menu.hover();
  // Flutter virtualizes offscreen items; mobile exercises native touch drags.
  const touch = test.info().project.use.isMobile
    ? await page.context().newCDPSession(page) : undefined;
  try {
    for (let attempt = 0; attempt < 16 && await item.count() === 0; attempt++) {
      if (touch) {
        const bounds = await menu.boundingBox();
        expect(bounds).not.toBeNull();
        const viewport = page.viewportSize()!;
        const x = bounds!.x + bounds!.width / 2;
        const top = Math.max(0, bounds!.y) + 40;
        const bottom = Math.min(viewport.height, bounds!.y + bounds!.height) - 40;
        await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: bottom }] });
        for (let step = 1; step <= 10; step++) {
          await touch.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: bottom - Math.min(300, bottom - top) * step / 10 }] });
          await page.waitForTimeout(30);
        }
        await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } else {
        await page.mouse.wheel(0, 240);
      }
      await page.waitForTimeout(300);
    }
    await expect(item).toHaveCount(1);
    await item.click();
  } finally {
    await touch?.detach();
  }
}
async function capture(page: Page, info: TestInfo, name: string) {
  await page.evaluate(async () => {
    await Promise.all(document.getAnimations({ subtree: true }).filter(a => a.effect?.getTiming().iterations !== Infinity).map(a => a.finished.catch(() => {})));
  });
  for (let i = 0; i < 3; i++) {
    await page.screenshot({ path: info.outputPath(`${name}-${i}.png`) });
    await page.waitForTimeout(200);
  }
}
async function openWork(page: Page, title: string) {
  await page.getByRole('tab', { name: '著作', exact: true }).click();
  await expect(page.getByRole('button', { name: '著者を追加', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: '著作を追加', exact: true })).toBeVisible();
  await field(page, /^著者・著作を検索/, title);
  await page.getByRole('button', { name: new RegExp(`^${title} `) }).click();
}

test.setTimeout(60000);

test.beforeEach(async ({ request }) => {
  const reset = await request.post('http://127.0.0.1:7359', { data: { action: 'fixture.reset' } });
  expect(reset.ok()).toBeTruthy();
});

test('record pages, understanding and impression persists across reload; reread keeps one completed work', async ({ page }, info) => {
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '国家');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^総ページ数/, '100');
  await field(page, /^出版社/, '読書テスト出版社');
  await field(page, /^訳者/, 'テスト訳者');
  await field(page, /^編集者・編者/, 'テスト編集者');
  await field(page, /^書籍・購入URL/, 'https://example.com/book');
  await field(page, /^版情報の出典URL/, 'https://example.com/source');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: '記録を追加', exact: true }).click();
  await field(page, /^開始ページ/, '1'); await field(page, /^終了ページ/, '10');
  await field(page, /^感想/, '正義の意味を考えた');
  await page.getByRole('button', { name: /未評価/ }).click();
  await page.getByRole('menuitem', { name: '3 要点を理解した', exact: true }).click();
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 正義の意味を考えた/ }).last()).toBeVisible();
  await page.getByRole('button', { name: '読了にする', exact: true }).click();
  await expect(page.getByRole('group', { name: /状態: 読了\（読了は手動で設定\）/ }).last()).toBeVisible();
  await capture(page, info, 'saved-record');
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '国家');
  await expect(page.getByRole('group', { name: /感想: 正義の意味を考えた/ }).last()).toBeVisible();
  await expect(page.getByRole('group', { name: /編集者・編者: テスト編集者/ }).last()).toBeVisible();
  await page.getByRole('button', { name: '版を編集', exact: true }).click();
  await restoredField(page, /^出版社/, '読書テスト出版社');
  await restoredField(page, /^訳者/, 'テスト訳者');
  await restoredField(page, /^編集者・編者/, 'テスト編集者');
  await restoredField(page, /^書籍・購入URL/, 'https://example.com/book');
  await restoredField(page, /^版情報の出典URL/, 'https://example.com/source');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.getByRole('button', { name: '別の版・再読を始める', exact: true }).click();
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  const viewport = page.viewportSize()!;
  await page.mouse.move(viewport.width / 2, viewport.height * .75);
  for (let attempt = 0; attempt < 8 && await page.getByRole('group', { name: /第2回/ }).count() === 0; attempt++) {
    await page.mouse.wheel(0, 360);
    await page.waitForTimeout(250);
  }
  await expect(page.getByRole('group', { name: /第2回/ }).last()).toBeVisible();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('tab', { name: '進捗', exact: true }).click();
  await expect(page.getByRole('button', { name: '著作を追加', exact: true })).toHaveCount(0);
  await expect(page.getByRole('tabpanel')).toHaveCount(1);
  await expect(page.getByRole('tabpanel')).toMatchAriaSnapshot(`
- tabpanel:
  - group:
    - text: /.*収録済み著作全体.*読了 1 . 80 著作.*/
`);
  await capture(page, info, 'progress');
  expect(errors).toEqual([]);
});

test('catalog edition prefills publisher, translator and editor; ISBN link and URL validation work', async ({ page, context }, info) => {
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '正法眼蔵随聞記');
  await page.getByRole('button', { name: /版・入手先/ }).click();
  await expect(page.getByRole('button', { name: 'この版の書誌出典を開く', exact: true })).toBeVisible();
  await context.route('https://www.amazon.co.jp/**', route => route.fulfill({ contentType: 'text/html', body: '<title>Book search fixture</title>' }));
  const popupPromise = page.waitForEvent('popup');
  await page.getByRole('button', { name: 'Amazonで書籍を検索（ISBN）', exact: true }).click();
  const popup = await popupPromise;
  await popup.waitForLoadState('domcontentloaded');
  expect(new URL(popup.url()).searchParams.get('k')).toBe('9784480080226');
  await popup.close();
  await page.getByRole('button', { name: 'この版で読書を始める', exact: true }).click();
  await restoredField(page, /^出版社/, '筑摩書房');
  await restoredField(page, /^訳者/, '水野弥穂子');
  await restoredField(page, /^編集者・編者/, '懐奘（記録・編纂）');
  await field(page, /^書籍・購入URL/, 'javascript:alert(1)');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('URLは有効なHTTPSアドレスを入力してください', { exact: true })).toBeVisible();
  await field(page, /^書籍・購入URL/, 'https://www.chikumashobo.co.jp/product/9784480080226/');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: /版・入手先/ }).click();
  await capture(page, info, 'catalog-edition-record');
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '正法眼蔵随聞記');
  await expect(page.getByRole('group', { name: /編集者・編者: 懐奘/ }).last()).toBeVisible();
  await expect(page.getByRole('button', { name: '登録した書籍・購入先を開く', exact: true })).toBeVisible();
});


test('choose two Japanese translations, preserve their ISBN/source fields after reload and edit independently', async ({ page, context }, info) => {
  test.setTimeout(120000);
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '論語');
  const books = [
    { label: '論語・岩波文庫（改訂新版）', publisher: '岩波書店', translator: '金谷治（訳注）', isbn: '9784003320211', volume: '岩波文庫・改訂新版', source: 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002845211', purchase: 'https://www.kinokuniya.co.jp/f/dsg-01-9784003320211' },
    { label: '論語・光文社古典新訳文庫（鶴ヶ谷真一訳）', publisher: '光文社', translator: '鶴ヶ谷真一（訳・注）', isbn: '9784334107741', volume: '光文社古典新訳文庫', source: 'https://www.kotensinyaku.jp/books/book420/', purchase: 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334107741' },
  ];
  await context.route('https://www.amazon.co.jp/**', route => route.fulfill({ contentType: 'text/html', body: '<title>ISBN destination fixture</title>' }));
  for (const book of books) {
    await page.getByRole('button', { name: /版・入手先/ }).click();
    const card = page.getByRole('group', { name: `版候補: ${book.label}`, exact: true });
    const start = card.getByRole('button', { name: 'この版で読書を始める', exact: true });
    const viewport = page.viewportSize()!;
    await page.mouse.move(viewport.width / 2, viewport.height * .65);
    for (let attempt = 0; attempt < 12 && await start.count() === 0; attempt++) {
      await page.mouse.wheel(0, 280);
      await page.waitForTimeout(200);
    }
    await expect(start).toHaveCount(1);
    const popupPromise = page.waitForEvent('popup');
    await card.getByRole('button', { name: 'Amazonで書籍を検索（ISBN）', exact: true }).click();
    const popup = await popupPromise;
    await popup.waitForLoadState('domcontentloaded');
    expect(new URL(popup.url()).searchParams.get('k')).toBe(book.isbn);
    await popup.close();
    await start.click();
    await restoredField(page, /^出版社/, book.publisher);
    await restoredField(page, /^訳者/, book.translator);
    await restoredField(page, /^ISBN/, book.isbn);
    await restoredField(page, /^巻・版の名前/, book.volume);
    await restoredField(page, /^編集者・編者/, '');
    await restoredField(page, /^版情報の出典URL/, book.source);
    await restoredField(page, /^書籍・購入URL/, book.purchase);
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
    // Return to the collapsed heading before selecting the next edition.
    await page.getByRole('button', { name: /Back|戻る/ }).click();
    await openWork(page, '論語');
  }
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '論語');
  const edits = page.getByRole('button', { name: '版を編集', exact: true });
  for (let i = 0; i < books.length; i++) {
    const book = books[i];
    await edits.nth(i).click();
    await restoredField(page, /^出版社/, book.publisher);
    await restoredField(page, /^訳者/, book.translator);
    await restoredField(page, /^ISBN/, book.isbn);
    await restoredField(page, /^巻・版の名前/, book.volume);
    await restoredField(page, /^版情報の出典URL/, book.source);
    await restoredField(page, /^書籍・購入URL/, book.purchase);
    if (i === 0) await field(page, /^編集者・編者/, '手元の版の編集者');
    else await restoredField(page, /^編集者・編者/, '');
    await page.getByRole('button', { name: '保存', exact: true }).click();
  }
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '論語');
  await edits.nth(0).click();
  await restoredField(page, /^編集者・編者/, '手元の版の編集者');
  await restoredField(page, /^ISBN/, books[0].isbn);
  await capture(page, info, 'japanese-edition-restored');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await edits.nth(1).click();
  await restoredField(page, /^編集者・編者/, '');
  await restoredField(page, /^ISBN/, books[1].isbn);
  await capture(page, info, 'second-japanese-edition-restored');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('tab', { name: '進捗', exact: true }).click();
  await expect(page.getByRole('tabpanel')).toMatchAriaSnapshot(`
- tabpanel:
  - group:
    - text: /.*収録済み著作全体.*読了 0 . 80 著作.*/
`);
  expect(errors).toEqual([]);
});

test('invalid page range and failed save preserve input; retry, edit history and deletion work', async ({ page }, info) => {
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '省察');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^総ページ数/, '20');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.getByRole('button', { name: '記録を追加', exact: true }).click();
  await field(page, /^開始ページ/, '1'); await field(page, /^終了ページ/, '30');
  await field(page, /^感想/, '失敗して再試行');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('総ページ数を超えています', { exact: true })).toBeVisible();
  await field(page, /^終了ページ/, '10');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('保存できませんでした。入力を保持しています。再試行してください', { exact: true }).first()).toBeVisible();
  await field(page, /^感想/, '失敗して再試行');
  await capture(page, info, 'failure-kept-input');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 失敗して再試行/ }).last()).toBeVisible();
  await page.getByRole('button', { name: '記録を編集', exact: true }).click();
  await field(page, /^感想/, '読み直して理解した');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 読み直して理解した.*編集前の記録（1件）/ }).last()).toBeVisible();
  await capture(page, info, 'edit-history');
  await page.getByRole('button', { name: '記録を削除', exact: true }).click();
  await page.getByRole('button', { name: '削除', exact: true }).click();
  await expect(page.getByRole('group', { name: /感想: 読み直して理解した/ }).last()).toHaveCount(0);
});

test('guest author-to-work navigation, compound filters, empty state and keyboard input', async ({ page }, info) => {
  await page.goto('/?guest=1');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await page.getByRole('button', { name: /^プラトン / }).click();
  await expect(page.getByRole('button', { name: /^国家 / })).toBeVisible();
  await page.getByRole('button', { name: /^国家 / }).click();
  await expect(page.getByRole('button', { name: '読書を始める', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('button', { name: '分類を解除', exact: true }).click();
  await choose(page, /成立世紀/, '紀元前4世紀');
  await choose(page, /国／地域/, '古代ギリシア');
  await choose(page, /ジャンル/, '政治哲学');
  await expect(page.getByRole('button', { name: /^国家 / })).toBeVisible();
  await expect(page.getByRole('button', { name: /^論語 / })).toHaveCount(0);
  await field(page, /^著者・著作を検索/, '該当しない著作');
  await page.getByRole('textbox', { name: /^著者・著作を検索/ }).press('Tab');
  await expect(page.getByText('条件に一致する著作はありません', { exact: true })).toBeVisible();
  await capture(page, info, 'guest-empty');
});
