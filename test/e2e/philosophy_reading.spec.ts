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
async function expectReadingSummary(page: Page, text: string) {
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Flutter exposes static card text as its accessible name rather than a text node.
  const summary = page.getByRole('group', { name: new RegExp(escaped) })
    .or(page.getByText(text)).last();
  await expect(summary).toBeVisible();
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

async function revealReadingControl(page: Page, control: ReturnType<Page['getByRole']>) {
  const viewport = page.viewportSize()!;
  const touch = test.info().project.use.isMobile
    ? await page.context().newCDPSession(page) : undefined;
  try {
    for (let attempt = 0; attempt < 16 && await control.count() === 0; attempt++) {
      if (touch) {
        const x = viewport.width / 2;
        const bottom = viewport.height * .82;
        const top = viewport.height * .30;
        await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: bottom }] });
        for (let step = 1; step <= 12; step++) {
          await touch.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: bottom - (bottom - top) * step / 12 }] });
          await page.waitForTimeout(30);
        }
        await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      } else {
        await page.mouse.move(viewport.width / 2, viewport.height * .65);
        await page.mouse.wheel(0, 240);
      }
      await page.waitForTimeout(250);
    }
    await expect(control).toHaveCount(1);
  } finally {
    await touch?.detach();
  }
}
async function editRegisteredEdition(page: Page, isbn: string) {
  const cycle = page.getByRole('group', { name: new RegExp(`ISBN: ${isbn}`) })
    .filter({ has: page.getByRole('button', { name: '版を編集', exact: true }) }).last();
  const edit = cycle.getByRole('button', { name: '版を編集', exact: true });
  await revealReadingControl(page, edit);
  await edit.click();
}

test.setTimeout(60000);

test.beforeEach(async ({ request, page }) => {
  // Automatic title lookups stay deterministic; each external scenario overrides this route.
  await page.route('https://ndlsearch.ndl.go.jp/api/opensearch?**', route =>
    route.fulfill({ contentType: 'application/xml', body: '<rss><channel/></rss>' }));
  const reset = await request.post('http://127.0.0.1:7359', { data: { action: 'fixture.reset' } });
  expect(reset.ok()).toBeTruthy();
});

test('record pages, understanding and impression persists across reload; reread keeps one completed work', async ({ page }, info) => {
  test.setTimeout(120000);
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
  await expect(page.getByRole('group', { name: /状態: 読了/ }).last()).toBeVisible();
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
  await expect(page.getByRole('textbox', { name: /^出版社/ })).toHaveCount(0);
  // Reopen the work from its list so the repeat-reading action is in the viewport.
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await openWork(page, '国家');
  await page.getByRole('button', { name: '別の版・再読を始める', exact: true }).click();
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  const secondCycle=page.getByRole('group', { name: /第2回/ }).last();
  await revealReadingControl(page,secondCycle);
  await expect(secondCycle).toBeVisible();
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
    await revealReadingControl(page, start);
    await capture(page, info, `japanese-edition-candidates-${book.isbn}`);
    const popupPromise = page.waitForEvent('popup');
    await card.getByRole('button', { name: 'Amazonで書籍を検索（ISBN）', exact: true }).click();
    const popup = await popupPromise;
    await popup.waitForLoadState('domcontentloaded');
    expect(new URL(popup.url()).searchParams.get('k')).toBe(book.isbn);
    await popup.close();
    // Returning from the popup can restore the mobile viewport to the top.
    await revealReadingControl(page, start);
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
  for (let i = 0; i < books.length; i++) {
    const book = books[i];
    await editRegisteredEdition(page, book.isbn);
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
  await editRegisteredEdition(page, books[0].isbn);
  await restoredField(page, /^編集者・編者/, '手元の版の編集者');
  await restoredField(page, /^ISBN/, books[0].isbn);
  await capture(page, info, 'japanese-edition-restored');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await editRegisteredEdition(page, books[1].isbn);
  await restoredField(page, /^編集者・編者/, '');
  await restoredField(page, /^ISBN/, books[1].isbn);
  await capture(page, info, 'second-japanese-edition-restored');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('tab', { name: '進捗', exact: true }).click();
  const progress = page.getByRole('tabpanel').filter({
    has: page.getByText('長期目標: すべての哲学書を読破する', { exact: true }),
  });
  await expect(progress).toHaveCount(1);
  await expect(progress).toMatchAriaSnapshot(`
- tabpanel:
  - group:
    - text: /.*収録済み著作全体.*読了 0 . 80 著作.*/
`);
  expect(errors).toEqual([]);
});

test('choose new Ethics editions including collected editors, persist and edit independently', async ({ page, context }, info) => {
  test.setTimeout(120000);
  const errors: string[] = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  const books = [
    {"label": "エティカ・中央公論新社（中公クラシックス ; W48）", "publisher": "中央公論新社", "translator": "工藤喜作・斎藤博", "isbn": "9784121600943", "volume": "中公クラシックス ; W48", "editor": "", "source": "https://ndlsearch.ndl.go.jp/books/R100000002-I000008440421", "purchase": "https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600943"},
    {"label": "スピノザ全集. 3・岩波書店", "publisher": "岩波書店", "translator": "上野修（翻訳・解説）", "isbn": "9784000928533", "volume": "3", "editor": "上野修・鈴木泉（編）", "source": "https://ndlsearch.ndl.go.jp/books/R100000002-I032507023", "purchase": "https://www.amazon.co.jp/s/?i=stripbooks&k=9784000928533"},
  ];
  await context.route('https://www.amazon.co.jp/**', route => route.fulfill({ contentType: 'text/html', body: '<title>ISBN destination fixture</title>' }));
  for (const book of books) {
    await page.getByRole('button', { name: /版・入手先/ }).click();
    const card = page.getByRole('group', { name: `版候補: ${book.label}`, exact: true });
    const start = card.getByRole('button', { name: 'この版で読書を始める', exact: true });
    await revealReadingControl(page, start);
    await capture(page, info, `ethics-edition-candidates-${book.isbn}`);
    const popupPromise = page.waitForEvent('popup');
    await card.getByRole('button', { name: 'Amazonで書籍を検索（ISBN）', exact: true }).click();
    const popup = await popupPromise;
    await popup.waitForLoadState('domcontentloaded');
    expect(new URL(popup.url()).searchParams.get('k')).toBe(book.isbn);
    await popup.close();
    // Returning from the popup can restore the mobile viewport to the top.
    await revealReadingControl(page, start);
    await start.click();
    await restoredField(page, /^出版社/, book.publisher);
    await restoredField(page, /^訳者/, book.translator);
    await restoredField(page, /^ISBN/, book.isbn);
    await restoredField(page, /^巻・版の名前/, book.volume);
    await restoredField(page, /^編集者・編者/, book.editor);
    await restoredField(page, /^版情報の出典URL/, book.source);
    await restoredField(page, /^書籍・購入URL/, book.purchase);
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
    // Return to the collapsed heading before selecting the next edition.
    await page.getByRole('button', { name: /Back|戻る/ }).click();
    await openWork(page, 'エチカ');
  }
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  for (let i = 0; i < books.length; i++) {
    const book = books[i];
    await editRegisteredEdition(page, book.isbn);
    await restoredField(page, /^出版社/, book.publisher);
    await restoredField(page, /^訳者/, book.translator);
    await restoredField(page, /^ISBN/, book.isbn);
    await restoredField(page, /^巻・版の名前/, book.volume);
    await restoredField(page, /^版情報の出典URL/, book.source);
    await restoredField(page, /^書籍・購入URL/, book.purchase);
    if (i === 0) await field(page, /^編集者・編者/, '手元の版の編集者');
    else await restoredField(page, /^編集者・編者/, book.editor);
    await page.getByRole('button', { name: '保存', exact: true }).click();
  }
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  await editRegisteredEdition(page, books[0].isbn);
  await restoredField(page, /^編集者・編者/, '手元の版の編集者');
  await restoredField(page, /^ISBN/, books[0].isbn);
  await capture(page, info, 'ethics-edition-restored');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await editRegisteredEdition(page, books[1].isbn);
  await restoredField(page, /^編集者・編者/, books[1].editor);
  await restoredField(page, /^ISBN/, books[1].isbn);
  await capture(page, info, 'second-ethics-edition-restored');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.getByRole('button', { name: /Back|戻る/ }).click();
  await page.getByRole('tab', { name: '進捗', exact: true }).click();
  const progress = page.getByRole('tabpanel').filter({
    has: page.getByText('長期目標: すべての哲学書を読破する', { exact: true }),
  });
  await expect(progress).toHaveCount(1);
  await expect(progress).toMatchAriaSnapshot(`
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

test('search a book and apply edition metadata before saving, reloading and editing', async ({ page }, info) => {
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await field(page, /^書籍情報を検索/, '978-4121600943');
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await page.getByRole('button', { name: /^エティカ・中央公論新社/ }).click();
  await page.getByRole('button', { name: '書籍情報を設定', exact: true }).click();
  await restoredField(page, /^出版社/, '中央公論新社');
  await restoredField(page, /^訳者/, '工藤喜作・斎藤博');
  await restoredField(page, /^ISBN/, '9784121600943');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, 'エチカ');
  await editRegisteredEdition(page, '9784121600943');
  await restoredField(page, /^版情報の出典URL/, 'https://ndlsearch.ndl.go.jp/books/R100000002-I000008440421');
  await field(page, /^編集者・編者/, '検索後の修正');
  await capture(page, info, 'searched-edition-edit');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, 'エチカ');
  await editRegisteredEdition(page, '9784121600943');
  await restoredField(page, /^編集者・編者/, '検索後の修正');
});

test('failed external book search preserves input and recovers with catalog search', async ({ page }) => {
  await page.route('https://api.openbd.jp/**', route => route.fulfill({ status: 503, body: '' }));
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^出版社/, '手入力を保持');
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await field(page, /^書籍情報を検索/, '9781234567897');
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await expect(page.getByText('書籍情報を取得できませんでした。再検索または手入力できます。', { exact: true })).toBeVisible();
  await field(page, /^書籍情報を検索/, 'エティカ');
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await page.getByRole('button', { name: /^エティカ・中央公論新社/ }).click();
  await page.getByRole('button', { name: 'キャンセル', exact: true }).last().click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await restoredField(page, /^出版社/, '手入力を保持');
});

test('external ISBN metadata populates known fields and leaves unknown contributors empty', async ({ page }, info) => {
  await page.route('https://api.openbd.jp/**', route => route.fulfill({
    status: 200, contentType: 'application/json', headers: { 'access-control-allow-origin': '*' },
    body: JSON.stringify([{ summary: { isbn: '9781234567897', title: '検索した日本語版', publisher: '取得した出版社', pubdate: '202610' },
      onix: { DescriptiveDetail: { Contributor: [{ ContributorRole: ['A01'], PersonName: { content: '著者を訳者にしない' } }], Extent: [{ ExtentUnit: '03', ExtentValue: '240' }] } } }]),
  }));
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await field(page, /^書籍情報を検索/, '9781234567897');
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await page.getByRole('button', { name: /^検索した日本語版/ }).click();
  await page.getByRole('button', { name: '書籍情報を設定', exact: true }).click();
  await restoredField(page, /^出版社/, '取得した出版社');
  await restoredField(page, /^総ページ数/, '240');
  await restoredField(page, /^訳者/, '');
  await restoredField(page, /^編集者・編者/, '');
  await field(page, /^訳者/, '手元の本で補完した訳者');
  await capture(page, info, 'external-book-prefill');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, 'エチカ');
  await editRegisteredEdition(page, '9781234567897');
  await restoredField(page, /^訳者/, '手元の本で補完した訳者');
  await restoredField(page, /^版情報の出典URL/, 'https://api.openbd.jp/v1/get?isbn=9781234567897');
});

test('reading-about-books title prefills and persists the publisher edition', async ({ page }, info) => {
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await field(page, /^書籍情報を検索/, '読書について');
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await page.getByRole('button', { name: /^読書について・光文社/ }).click();
  await page.getByRole('button', { name: '書籍情報を設定', exact: true }).click();
  await restoredField(page, /^出版社/, '光文社');
  await restoredField(page, /^訳者/, '鈴木芳子');
  await restoredField(page, /^ISBN/, '9784334752712');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, 'エチカ');
  await editRegisteredEdition(page, '9784334752712');
  await restoredField(page, /^出版社/, '光文社');
  await restoredField(page, /^版情報の出典URL/, 'https://www.kotensinyaku.jp/books/book169/');
  await capture(page, info, 'reading-title-restored');
});

const ndlTitleXml = `<rss xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcndl="http://ndl.go.jp/dcndl/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><channel>
<item><dc:title>目録にない外部書名</dc:title><link>https://ndlsearch.ndl.go.jp/books/R100000002-IQA001</link><dc:publisher>外部出版社A</dc:publisher><dc:creator>原著者 著</dc:creator><dc:creator>訳者A 訳</dc:creator><dc:creator>編者A 編</dc:creator><dc:extent>180p</dc:extent><dcterms:issued>2012.3</dcterms:issued><dc:language>jpn</dc:language><dc:identifier xsi:type="dcndl:ISBN">978-4-569-80487-3</dc:identifier></item>
<item><dc:title>目録にない外部書名</dc:title><link>https://ndlsearch.ndl.go.jp/books/R100000002-IQA002</link><dc:publisher>外部出版社B</dc:publisher><dc:creator>訳者B 訳</dc:creator><dc:extent>240 p</dc:extent><dcterms:issued>2009.8</dcterms:issued><dc:identifier xsi:type="dcndl:ISBN">978-4-569-70783-9</dc:identifier></item>
</channel></rss>`;

test('external title returns two editions; selected metadata persists and edits independently', async ({ page }, info) => {
  await page.route('https://ndlsearch.ndl.go.jp/api/opensearch?**', route => {
    if (new URL(route.request().url()).searchParams.get('title') !== '目録にない外部書名') {
      return route.fulfill({ contentType: 'application/xml', body: '<rss><channel/></rss>' });
    }
    return route.fulfill({ contentType: 'application/xml', body: ndlTitleXml });
  });
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  const books = [
    { publisher: '外部出版社A', translator: '訳者A', isbn: '9784569804873', pages: '180', source: 'https://ndlsearch.ndl.go.jp/books/R100000002-IQA001' },
    { publisher: '外部出版社B', translator: '訳者B', isbn: '9784569707839', pages: '240', source: 'https://ndlsearch.ndl.go.jp/books/R100000002-IQA002' },
  ];
  for (let i = 0; i < books.length; i++) {
    const book = books[i];
    await page.getByRole('button', { name: i === 0 ? '読書を始める' : '別の版・再読を始める', exact: true }).click();
    await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
    await field(page, /^書籍情報を検索/, '目録にない外部書名');
    await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
    await expect(page.getByRole('button', { name: /^目録にない外部書名/ })).toHaveCount(2);
    await page.getByRole('button', { name: new RegExp('^目録にない外部書名[\\s\\S]*' + book.publisher) }).click();
    await page.getByRole('button', { name: '書籍情報を設定', exact: true }).click();
    await restoredField(page, /^出版社/, book.publisher);
    await restoredField(page, /^訳者/, book.translator);
    await restoredField(page, /^ISBN/, book.isbn);
    await restoredField(page, /^総ページ数/, book.pages);
    await restoredField(page, /^版情報の出典URL/, book.source);
    await restoredField(page, /^書籍・購入URL/, 'https://www.amazon.co.jp/s/?i=stripbooks&k=' + book.isbn);
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
    await page.reload();
    await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
    await openWork(page, 'エチカ');
    await editRegisteredEdition(page, book.isbn);
    await restoredField(page, /^出版社/, book.publisher);
    await restoredField(page, /^総ページ数/, book.pages);
    await field(page, /^出版社/, book.publisher + '・編集済み');
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByRole('textbox', { name: /^出版社/ })).toHaveCount(0);
  }
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, 'エチカ');
  for (const book of books) {
    await editRegisteredEdition(page, book.isbn);
    await restoredField(page, /^出版社/, book.publisher + '・編集済み');
    await restoredField(page, /^訳者/, book.translator);
    await restoredField(page, /^ISBN/, book.isbn);
    await restoredField(page, /^総ページ数/, book.pages);
    await restoredField(page, /^版情報の出典URL/, book.source);
    await capture(page, info, 'external-title-restored-' + book.isbn);
    await page.getByRole('button', { name: '保存', exact: true }).click();
    await expect(page.getByRole('textbox', { name: /^出版社/ })).toHaveCount(0);
  }
});

test('external title failure and empty results preserve manual input; retry and cancel work', async ({ page }) => {
  let calls = 0;
  await page.route('https://ndlsearch.ndl.go.jp/api/opensearch?**', route => {
    if (new URL(route.request().url()).searchParams.get('title') !== '目録にない外部書名') {
      return route.fulfill({ contentType: 'application/xml', body: '<rss><channel/></rss>' });
    }
    calls++;
    return route.fulfill(calls === 1 ? { status: 503, body: '' } : {
      contentType: 'application/xml', body: calls === 2 ? '<rss><channel/></rss>' : ndlTitleXml,
    });
  });
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, 'エチカ');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^出版社/, '保持する出版社');
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await field(page, /^書籍情報を検索/, '目録にない外部書名');
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await expect(page.getByText('書籍情報を取得できませんでした。再検索または手入力できます。', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await expect(page.getByText('見つかりませんでした。書名を短くするか、ISBNで検索してください。手入力もできます。', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '外部の版も検索', exact: true }).click();
  await page.getByRole('button', { name: /^目録にない外部書名/ }).first().click();
  await page.getByRole('button', { name: 'キャンセル', exact: true }).last().click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  await restoredField(page, /^出版社/, '保持する出版社');
});

test('current title searches automatically and Iwanami edition registers, reloads and edits', async ({ page }, info) => {
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await field(page, /^著者・著作を検索/, 'ショーペンハウアー');
  await page.getByRole('button', { name: /^ショーペンハウアー / }).click();
  await page.getByRole('button', { name: '著作を追加', exact: true }).click();
  await field(page, /^著作名/, '読書について');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('著作を追加（自分の目録）', { exact: true })).toHaveCount(0);
  await openWork(page, '読書について');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  // No typing and no search-button click: the current work seeds the lookup.
  await revealReadingControl(page, page.getByRole('button', { name: /^読書について 他二篇・岩波文庫/ }));
  await page.getByRole('button', { name: /^読書について 他二篇・岩波文庫/ }).click();
  await page.getByRole('button', { name: '書籍情報を設定', exact: true }).click();
  await restoredField(page, /^出版社/, '岩波書店');
  await restoredField(page, /^訳者/, '斎藤忍随');
  await restoredField(page, /^総ページ数/, '160');
  await restoredField(page, /^ISBN/, '9784003363225');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, '読書について');
  await editRegisteredEdition(page, '9784003363225');
  await restoredField(page, /^出版社/, '岩波書店');
  await field(page, /^巻・版の名前/, '岩波文庫 青632-2・手元の版');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('textbox', { name: /^出版社/ })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, '読書について');
  await editRegisteredEdition(page, '9784003363225');
  await restoredField(page, /^出版社/, '岩波書店');
  await restoredField(page, /^訳者/, '斎藤忍随');
  await restoredField(page, /^総ページ数/, '160');
  await restoredField(page, /^ISBN/, '9784003363225');
  await restoredField(page, /^巻・版の名前/, '岩波文庫 青632-2・手元の版');
  await restoredField(page, /^書籍・購入URL/, 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003363225');
  await restoredField(page, /^版情報の出典URL/, 'https://www.hanmoto.com/bd/isbn/9784003363225');
  await capture(page, info, 'iwanami-auto-reloaded');
});

test('page number alone saves progress, adds a delta, corrects and survives reload', async ({ page }, info) => {
  test.setTimeout(120000);
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '国家');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await field(page, /^総ページ数/, '160');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  const input=page.getByRole('textbox',{name:/^読んだページ/});
  await revealReadingControl(page,input);
  for (const value of ['85','100','100','80']) {
    // Clear prior feedback before retrying the same page, so an old success cannot satisfy this update.
    await field(page,/^読んだページ/,'');
    await expect(page.getByText(/^\d+ページまでの進捗を保存しました$/)).toHaveCount(0);
    await field(page,/^読んだページ/,value);
    await page.getByRole('button',{name:'進捗を更新',exact:true}).click();
    await expect(page.getByText(value+'ページまでの進捗を保存しました',{exact:true})).toBeVisible();
    await expectReadingSummary(page, value+'ページまで／全160ページ・'+(Number(value)/160*100).toFixed(1)+'％');
  }
  await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
  await openWork(page,'国家');
  await revealReadingControl(page,input);
  await restoredField(page,/^読んだページ/,'80');
  await expectReadingSummary(page, '80ページまで／全160ページ・50.0％');
  await field(page,/^読んだページ/,'161');
  await page.getByRole('button',{name:'進捗を更新',exact:true}).click();
  await expect(page.getByText('総ページ数（160ページ）を超えています',{exact:true})).toBeVisible();
  await field(page,/^読んだページ/,'160');
  await page.getByRole('button',{name:'進捗を更新',exact:true}).click();
  await expect(page.getByText('160ページまでの進捗を保存しました',{exact:true})).toBeVisible();
  await revealReadingControl(page,page.getByRole('button',{name:'読了にする',exact:true}));
  await expect(page.getByRole('button',{name:'読了にする',exact:true})).toBeVisible();
  await expectReadingSummary(page, '160ページまで／全160ページ・100.0％');
  await capture(page,info,'quick-page-progress');
  await page.getByRole('button',{name:/Back|戻る/}).click();
  await page.getByRole('tab',{name:'進捗',exact:true}).click();
  await expectReadingSummary(page, '読書中 1 著作・読了 0 著作');
  await capture(page,info,'reading-work-counts');
  await openWork(page,'国家');
  await revealReadingControl(page,page.getByRole('button',{name:'読了にする',exact:true}));
  await page.getByRole('button',{name:'読了にする',exact:true}).click();
  await page.getByRole('button',{name:/Back|戻る/}).click();
  await page.getByRole('tab',{name:'進捗',exact:true}).click();
  await expectReadingSummary(page, '読書中 0 著作・読了 1 著作');
  await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
  await page.getByRole('tab',{name:'進捗',exact:true}).click();
  await expectReadingSummary(page, '読書中 0 著作・読了 1 著作');
  await capture(page,info,'completed-work-counts-reloaded');
});

test('quick page update preserves a detailed impression and rejects moving behind it', async ({page},info) => {
  await page.goto('/');await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible({timeout:60000});
  await openWork(page,'国家');
  await page.getByRole('button',{name:'読書を始める',exact:true}).click();
  await field(page,/^総ページ数/,'160');await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
  await page.getByRole('button',{name:'記録を追加',exact:true}).click();
  await field(page,/^開始ページ/,'1');await field(page,/^終了ページ/,'20');await field(page,/^感想/,'詳細の感想を保持');
  await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByText('読書記録を追加',{exact:true})).toHaveCount(0);
  await field(page,/^読んだページ/,'85');await page.getByRole('button',{name:'進捗を更新',exact:true}).click();
  await expect(page.getByText('85ページまでの進捗を保存しました',{exact:true})).toBeVisible();
  await field(page,/^読んだページ/,'10');await page.getByRole('button',{name:'進捗を更新',exact:true}).click();
  await expect(page.getByText('詳細記録の終了ページより前には戻せません。記録の編集で修正してください',{exact:true})).toBeVisible();
  await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();await openWork(page,'国家');
  await restoredField(page,/^読んだページ/,'85');
  const note=page.getByRole('group',{name:/感想: 詳細の感想を保持/}).last();
  await revealReadingControl(page,note);await expect(note).toBeVisible();
  await capture(page,info,'quick-progress-detailed-note');
});


test('Spinoza political treatise automatically selects a sourced Iwanami edition, reloads and edits', async ({ page }, info) => {
  test.setTimeout(120000);
  const externalQueries: URL[] = [];
  await page.route('https://ndlsearch.ndl.go.jp/api/opensearch?**', route => {
    externalQueries.push(new URL(route.request().url()));
    return route.fulfill({ contentType: 'application/xml', body: '<rss><channel/></rss>' });
  });
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await field(page, /^著者・著作を検索/, 'スピノザ');
  await page.getByRole('button', { name: /^スピノザ / }).click();
  await page.getByRole('button', { name: '著作を追加', exact: true }).click();
  await field(page, /^著作名/, '国家論');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('著作を追加（自分の目録）', { exact: true })).toHaveCount(0);
  await openWork(page, '国家論');
  await page.getByRole('button', { name: '読書を始める', exact: true }).click();
  await page.getByRole('button', { name: '書籍情報から自動入力', exact: true }).click();
  const candidate = page.getByRole('button', { name: /^国家論・岩波文庫（スピノザ/ });
  await revealReadingControl(page, candidate);
  await page.getByRole('button', { name: '外部の版も検索', exact: true }).click();
  await expect.poll(() => externalQueries.length).toBe(1);
  expect(externalQueries[0].searchParams.get('title')).toBe('国家論');
  expect(externalQueries[0].searchParams.get('creator')).toBe('スピノザ');
  await expect(page.getByText('見つかりませんでした。書名を短くするか、ISBNで検索してください。手入力もできます。', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: '書籍情報を検索', exact: true }).click();
  await revealReadingControl(page, candidate);
  await candidate.click();
  await page.getByRole('button', { name: '書籍情報を設定', exact: true }).click();
  await restoredField(page, /^出版社/, '岩波書店');
  await restoredField(page, /^訳者/, '畠中尚志');
  await restoredField(page, /^総ページ数/, '213');
  await restoredField(page, /^ISBN/, '9784003361566');
  await restoredField(page, /^版情報の出典URL/, 'https://ndlsearch.ndl.go.jp/books/R100000002-I000002440109');
  await restoredField(page, /^書籍・購入URL/, 'https://www.amazon.co.jp/s/?i=stripbooks&k=9784003361566');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, '国家論');
  await editRegisteredEdition(page, '9784003361566');
  await restoredField(page, /^ISBN/, '9784003361566');
  await field(page, /^巻・版の名前/, '手元の刷を確認済み');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, '国家論');
  await editRegisteredEdition(page, '9784003361566');
  await restoredField(page, /^訳者/, '畠中尚志');
  await restoredField(page, /^巻・版の名前/, '手元の刷を確認済み');
  await capture(page, info, 'spinoza-iwanami-restored');
});


for (const book of [
  {title:'道徳経',candidate:'老子・岩波文庫',publisher:'岩波書店',translator:'蜂屋邦夫（訳注）',isbn:'9784003320518',source:'https://www.hanmoto.com/bd/isbn/9784003320518',pages:''},
  {title:'哲学の諸問題',candidate:'哲学入門・筑摩書房',publisher:'筑摩書房',translator:'高村夏輝',isbn:'9784480089045',source:'https://www.chikumashobo.co.jp/product/9784480089045/',pages:'288'},
  {title:'メノイケウス宛の手紙',candidate:'自然について他・京都大学学術出版会',publisher:'京都大学学術出版会',translator:'朴一功・和田利博',isbn:'9784814005598',source:'https://ndlsearch.ndl.go.jp/books/R100000002-I034002308',pages:''},
  {title:'有徳都市の住民の見解',candidate:'中世思想原典集成11 イスラーム哲学・平凡社',publisher:'平凡社',translator:'竹下政孝',isbn:'9784582734218',source:'https://catalog.library.metro.tokyo.lg.jp/winj/opac/switch-detail-iccap.do?bibid=1105284612',pages:'1161'},
]) {
  test(`catalog alternate title automatically finds and persists the Japanese edition: ${book.title}`, async ({ page }, info) => {
    test.setTimeout(120000);
    const errors: string[] = [];page.on('pageerror', error => errors.push(error.message));
    await page.goto('/');
    await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible({timeout:60000});
    await openWork(page,book.title);
    await page.getByRole('button',{name:'読書を始める',exact:true}).click();
    await page.getByRole('button',{name:'書籍情報から自動入力',exact:true}).click();
    await restoredField(page,/^書籍情報を検索/,book.title);
    const candidate=page.getByRole('button',{name:new RegExp('^'+book.candidate)});
    await revealReadingControl(page,candidate);await candidate.click();
    if(book.title==='有徳都市の住民の見解') await expect(page.getByText(/版の注記: .*1161ページは巻全体/).last()).toBeVisible();
    await page.getByRole('button',{name:'書籍情報を設定',exact:true}).click();
    await restoredField(page,/^出版社/,book.publisher);
    await restoredField(page,/^訳者/,book.translator);
    await restoredField(page,/^ISBN/,book.isbn);
    await restoredField(page,/^総ページ数/,book.pages);
    await restoredField(page,/^版情報の出典URL/,book.source);
    await restoredField(page,/^書籍・購入URL/,'https://www.amazon.co.jp/s/?i=stripbooks&k='+book.isbn);
    await page.getByRole('button',{name:'保存',exact:true}).click();
    await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
    await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
    await openWork(page,book.title);await editRegisteredEdition(page,book.isbn);
    await restoredField(page,/^出版社/,book.publisher);
    await restoredField(page,/^訳者/,book.translator);
    await restoredField(page,/^ISBN/,book.isbn);
    await field(page,/^巻・版の名前/,'手元の版を確認・'+book.title);
    await page.getByRole('button',{name:'保存',exact:true}).click();
    await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
    await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
    await openWork(page,book.title);await editRegisteredEdition(page,book.isbn);
    await restoredField(page,/^訳者/,book.translator);
    await restoredField(page,/^巻・版の名前/,'手元の版を確認・'+book.title);
    await restoredField(page,/^版情報の出典URL/,book.source);
    await capture(page,info,'catalog-alias-'+book.isbn+'-edited-reloaded');
    expect(errors).toEqual([]);
  });
}

test('long work memo persists without a reading cycle and accepts another append', async ({ page }, info) => {
  test.setTimeout(120000);
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  await openWork(page, '論語');
  await page.getByRole('button', { name: '著作にメモを追記', exact: true }).click();
  const memo = '長文確認' + '本'.repeat(3000) + '長文末尾';
  await field(page, /^追記するメモ/, memo);
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('textbox', { name: /^追記するメモ/ })).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible();
  await openWork(page, '論語');
  await expect(page.getByText(/長文確認.*長文末尾/)).toHaveCount(1);
  await page.getByRole('button', { name: '著作にメモを追記', exact: true }).click();
  await field(page, /^追記するメモ/, '12〜15頁追記確認');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByRole('textbox', { name: /^追記するメモ/ })).toHaveCount(0);
  await expect(page.getByText(/長文末尾.*12〜15頁追記確認/s)).toHaveCount(1);
  await revealReadingControl(page, page.getByText(/既存の状態: 未読/));
  await expect(page.getByText(/既存の状態: 未読/)).toBeVisible();
  await capture(page, info, 'long-work-memo-no-cycle');
});


test('unknown total shows reached page and gains percentage after editing the edition',async ({page},info)=>{
  test.setTimeout(120000);
  await page.goto('/');await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible({timeout:60000});
  await openWork(page,'国家');await page.getByRole('button',{name:'読書を始める',exact:true}).click();
  await page.getByRole('button',{name:'保存',exact:true}).click();await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
  const add=page.getByRole('button',{name:'記録を追加',exact:true});await revealReadingControl(page,add);await add.click();
  await field(page,/^今回読んだページ数/,'5');await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByText('読書記録を追加',{exact:true})).toHaveCount(0);
  await expectReadingSummary(page,'ページ位置未登録');
  const input=page.getByRole('textbox',{name:/^読んだページ/});await revealReadingControl(page,input);
  await field(page,/^読んだページ/,'11');await page.getByRole('button',{name:'進捗を更新',exact:true}).click();
  await expectReadingSummary(page, '11ページまで読んだ');
  await expectReadingSummary(page, '総ページ数未登録。「版を編集」で登録すると進捗率を表示します。');
  await expect(page.getByRole('progressbar',{name:'ページ位置の進捗',exact:true})).toHaveCount(0);
  await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();await openWork(page,'国家');
  await expectReadingSummary(page, '11ページまで読んだ');
  await capture(page,info,'unknown-total-position-reloaded');
  const edit=page.getByRole('button',{name:'版を編集',exact:true});await revealReadingControl(page,edit);await edit.click();
  await field(page,/^総ページ数/,'100');await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByRole('textbox',{name:/^総ページ数/})).toHaveCount(0);
  await expectReadingSummary(page, '11ページまで／全100ページ・11.0％');
  await page.reload();await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();await openWork(page,'国家');
  await expectReadingSummary(page, '11ページまで／全100ページ・11.0％');
  await restoredField(page,/^読んだページ/,'11');
  await capture(page,info,'total-added-position-reloaded');
});

test('author title and spelling searches preserve legacy reading data across reload', async ({ request, page }, info) => {
  test.setTimeout(120000);
  const id = '44444444-4444-4444-8444-444444444444';
  const work = { id: 'legacy:reading-about-books', title: '読書について', original_title: 'On Reading',
    author_info: { id: 'legacy:schopenhauer', name: 'ショーペンハウエル', aliases: [], centuries: ['不明'], regions: ['不明'], traditions: [], source: '', note: '' },
    centuries: ['不明'], genres: ['認識論'], source: '', note: '既存の著作メモ' };
  const added = await request.post('http://127.0.0.1:7359', { data: { action: 'reading.add', id, work } });
  expect(added.ok()).toBeTruthy();
  const saved = await request.post('http://127.0.0.1:7359', { data: { action: 'reading.save', id, revision: 0, work,
    cycles: [{ id: 'legacy-cycle', started_at: '2026-10-12', status: 'reading', edition: { total_pages: 160, translator: '斎藤忍随', publisher: '岩波書店', isbn: '9784003363225' },
      entries: [{ id: 'legacy-entry', date: '2026-10-14', pages: 91, start_page: 1, end_page: 91, understanding: 3, impression: '既存の感想を保持', questions: '既存の疑問', concepts: '既存の概念' }] }] } });
  expect(saved.ok()).toBeTruthy();
  const list = async () => (await (await request.post('http://127.0.0.1:7359', { data: { action: 'reading.list' } })).json()).items.find((r: { id: string }) => r.id === id);
  const original = await list();
  await page.goto('/');
  await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
  for (const query of ['読書について', 'On Reading', 'ショーペンハウエル', 'ショーペンハウアー']) {
    await field(page, /^著者・著作を検索/, query);
    const author = page.getByRole('button', { name: /^ショーペンハウアー / });
    await expect(author).toHaveCount(1);
    await expect(page.getByRole('button', { name: /^ショーペンハウエル / })).toHaveCount(0);
    await expect(author).toBeVisible();
  }
  await field(page, /^著者・著作を検索/, '読書について');
  await expect(page.getByRole('button', { name: /該当する著作: 読書について/ })).toHaveCount(1);
  await capture(page, info, 'author-title-search');
  await page.getByRole('button', { name: /^ショーペンハウアー / }).click();
  await expect(page.getByRole('button', { name: /^意志と表象としての世界 / })).toHaveCount(0);
  await page.getByRole('button', { name: /^読書について ショーペンハウアー/ }).click();
  await expectReadingSummary(page, '91ページまで／全160ページ・56.9％');
  await expect(page.getByRole('group', { name: /既存の感想を保持/ }).last()).toBeVisible();
  await page.reload();
  await field(page, /^著者・著作を検索/, '読書について');
  await page.getByRole('button', { name: /^ショーペンハウアー / }).click();
  await page.getByRole('button', { name: /^読書について ショーペンハウアー/ }).click();
  await expectReadingSummary(page, '91ページまで／全160ページ・56.9％');
  await capture(page, info, 'legacy-record-reloaded');
  expect(await list()).toEqual(original);
});

test('duplicate shared and legacy works preserve both reading cycles across search and reload', async ({ request, page }, info) => {
  test.setTimeout(180000);
  const ids = ['55555555-5555-4555-8555-555555555555', '66666666-6666-4666-8666-666666666666'];
  for (let i = 0; i < ids.length; i++) {
    const work = { id: i === 0 ? 'plato:republic' : 'legacy:republic', title: '国家', original_title: 'Republic',
      author_info: { id: i === 0 ? 'plato' : 'legacy:plato', name: i === 0 ? 'プラトン' : 'Plato' },
      note: i === 0 ? '共有側メモ' : '既存側メモ' };
    expect((await request.post('http://127.0.0.1:7359', { data: { action: 'reading.add', id: ids[i], work } })).ok()).toBeTruthy();
    expect((await request.post('http://127.0.0.1:7359', { data: { action: 'reading.save', id: ids[i], revision: 0, work,
      cycles: [{ id: 'same-cycle', started_at: i === 0 ? '2026-10-12' : '2026-10-14', status: i === 0 ? 'read' : 'reading',
        edition: { total_pages: i === 0 ? 100 : 160, publisher: i === 0 ? '保持版A' : '保持版B', translator: '保持訳者', isbn: i === 0 ? '9784003363225' : '9784003361566' },
        entries: [{ id: 'entry-' + i, date: '2026-10-14', pages: (i + 1) * 10, start_page: 1, end_page: (i + 1) * 10, understanding: 3, impression: i === 0 ? '保持感想A' : '保持感想B' }] }] } })).ok()).toBeTruthy();
  }
  const list = async () => (await (await request.post('http://127.0.0.1:7359', { data: { action: 'reading.list' } })).json()).items;
  const before = await list();
  const search = async () => {
    await expect(page.getByText('哲学書の読書管理', { exact: true })).toBeVisible({ timeout: 60000 });
    await field(page, /^著者・著作を検索/, '国家');
    await expect(page.getByRole('button', { name: /^プラトン / })).toHaveCount(1);
    await page.getByRole('tab', { name: '著作', exact: true }).click();
    await expect(page.getByRole('button', { name: /^国家 プラトン/ })).toHaveCount(1);
    await expect(page.getByRole('button', { name: /^国家 Plato/ })).toHaveCount(0);
  };
  await page.goto('/');
  await search();
  await capture(page, info, 'grouped-work-search');
  await page.getByRole('tab', { name: '進捗', exact: true }).click();
  await expectReadingSummary(page, '読書中 1 著作・読了 1 著作');
  await expectReadingSummary(page, '対象 1 著作');
  await expectReadingSummary(page, '読書記録の合計 30 ページ');
  await capture(page, info, 'grouped-progress');
  await page.getByRole('tab', { name: '著作', exact: true }).click();
  await page.getByRole('button', { name: /^国家 プラトン/ }).click();
  await expect(page.getByText(/同じ著作の記録をまとめて表示/)).toBeVisible();
  await expect(page.getByText('共有側メモ', { exact: true })).toBeVisible();
  await expect(page.getByText('既存側メモ', { exact: true })).toBeVisible();
  await expectReadingSummary(page, '10ページまで／全100ページ・10.0％');
  const second = page.getByRole('group', { name: /保持版B/ }).filter({ has: page.getByRole('button', { name: '版を編集', exact: true }) }).last();
  await revealReadingControl(page, second.getByRole('button', { name: '版を編集', exact: true }));
  await expectReadingSummary(page, '20ページまで／全160ページ・12.5％');
  await capture(page, info, 'grouped-cycles');
  expect(await list()).toEqual(before);
  await second.getByRole('button', { name: '版を編集', exact: true }).click();
  await field(page, /^出版社/, '保持版B編集');
  await page.getByRole('button', { name: '保存', exact: true }).click();
  await expect(page.getByText('読む版を登録', { exact: true })).toHaveCount(0);
  await page.reload();
  await search();
  await page.getByRole('button', { name: /^国家 プラトン/ }).click();
  const edited = page.getByRole('group', { name: /保持版B編集/ }).filter({ has: page.getByRole('button', { name: '版を編集', exact: true }) }).last();
  await revealReadingControl(page, edited.getByRole('button', { name: '版を編集', exact: true }));
  await expectReadingSummary(page, '20ページまで／全160ページ・12.5％');
  await capture(page, info, 'grouped-reloaded');
  const after = await list();
  expect(after.find((record: { id: string }) => record.id === ids[0])).toEqual(before.find((record: { id: string }) => record.id === ids[0]));
  const original = before.find((record: { id: string }) => record.id === ids[1]);
  const changed = after.find((record: { id: string }) => record.id === ids[1]);
  expect(changed.work).toEqual(original.work);
  expect(changed.cycles[0].entries).toEqual(original.cycles[0].entries);
  expect(changed.cycles[0].edition.publisher).toBe('保持版B編集');
});
