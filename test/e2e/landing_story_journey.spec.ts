import { expect, Page, test } from '@playwright/test';

const landingPath = '/?lp_hypothesis=h03&lp_variant=treatment';

test.describe('Landing story journey', () => {
  test.describe.configure({ timeout: 120_000 });

  test('moves from the scattered state to the final actionable chapter', async ({
    page,
  }, testInfo) => {
    const layoutIssues: string[] = [];
    page.on('pageerror', error => layoutIssues.push(error.message));
    page.on('console', message => {
      if (/overflowed by|RenderFlex|unbounded|BoxConstraints forces/.test(message.text())) layoutIssues.push(message.text());
    });
    await openLanding(page);
    const story = await focusStory(page);

    await expect(story).toHaveAccessibleName(/1 \/ 4/);

    for (const [index, label] of ['分散', '集約', '整理', '実行'].entries()) {
      await activateChapter(page, label);
      await expect(story).toHaveAccessibleName(new RegExp(`${index + 1} / 4`));
      await page.waitForTimeout(650);
      await page.screenshot({ path: testInfo.outputPath(`story-${index + 1}.png`), scale: 'css' });
    }

    const originalViewport = page.viewportSize()!;
    for (const width of [768, 1024]) {
      await page.setViewportSize({ width, height: 1024 });
      for (const [index, label] of [[1, '分散'], [4, '実行']] as const) {
        await activateChapter(page, label);
        await expect(story).toHaveAccessibleName(new RegExp(`${index} / 4`));
        await page.waitForTimeout(650);
        await page.screenshot({ path: testInfo.outputPath(`story-${width}-${index}.png`), scale: 'css' });
      }
    }
    await page.setViewportSize(originalViewport);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    expect(await page.evaluate(() => window.matchMedia('(prefers-reduced-motion: reduce)').matches)).toBe(true);
    for (const [index, label] of [[1, '分散'], [4, '実行']] as const) {
      await activateChapter(page, label);
      await expect(story).toHaveAccessibleName(new RegExp(`${index} / 4`));
      await page.waitForTimeout(650);
      await page.screenshot({ path: testInfo.outputPath(`story-reduced-${index}.png`), scale: 'css' });
    }
    expect(layoutIssues).toEqual([]);

    await expect(story).toHaveAccessibleName(/4 \/ 4/);
    await expect(
      story.getByRole('button', { name: '無料で保存を始める' }),
    ).toBeVisible();
    await expect(
      story.getByRole('button', { name: '登録なしで1件試す' }),
    ).toBeVisible();
    for (const name of ['無料で保存を始める', '登録なしで1件試す']) {
      const action = story.getByRole('button', { name, exact: true });
      await expect(action).toBeInViewport();
      const bounds = await action.boundingBox();
      expect(bounds).not.toBeNull();
      expect(bounds!.height).toBeGreaterThanOrEqual(44);
    }

  });

  test('connects the final chapter to the existing no-signup trial', async ({
    page,
  }) => {
    await openLanding(page);
    const story = await focusStory(page);
    await activateChapter(page, '実行');

    await story.getByRole('button', { name: '登録なしで1件試す' }).click();

    await expect(
      page.getByRole('textbox', { name: /例: 今日いちばん詰まっていること|いま詰まっていること/ }),
    ).toBeInViewport();
    await expect(
      page.getByRole('button', { name: '今やる1件を試す', exact: true }),
    ).toBeInViewport();
  });

  test('lets the user return to the first chapter after reaching the end', async ({
    page,
  }) => {
    await openLanding(page);
    const story = await focusStory(page);
    await activateChapter(page, '実行');
    await expect(story).toHaveAccessibleName(/4 \/ 4/);

    await activateChapter(page, '分散');

    await expect(story).toHaveAccessibleName(/1 \/ 4/);
    await expect(
      story.getByRole('button', { name: '無料で保存を始める' }),
    ).toHaveCount(0);
  });
});

async function openLanding(page: Page) {
  await page.route('**/rest/v1/app_analytics*', async (route) => {
    const isRead = route.request().method() === 'GET';
    await route.fulfill({
      status: isRead ? 200 : 204,
      contentType: 'application/json',
      headers: isRead ? { 'content-range': '0-0/0' } : undefined,
      body: isRead ? '[]' : '',
    });
  });

  const response = await page.goto(landingPath, {
    waitUntil: 'domcontentloaded',
  });
  expect(response?.ok()).toBeTruthy();
  await expect(page).toHaveTitle(
    '自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ',
    { timeout: 60_000 },
  );
  await expect(page.locator('#seo-shell')).toBeHidden({ timeout: 30000 });
}

async function focusStory(page: Page) {
  const story = page.getByRole('group', {
    name: /自分株式会社で、迷いが今日の1件に変わるまで/,
  });
  await expect(story).toBeVisible({ timeout: 60_000 });
  return story;
}

async function activateChapter(page: Page, label: string) {
  const chapterButton = page.getByRole('button', {
    name: `${label}の章へ移動`,
  });
  await chapterButton.evaluate((element: HTMLElement) => element.click());
}
