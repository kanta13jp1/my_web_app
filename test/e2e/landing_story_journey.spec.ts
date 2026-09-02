import { expect, Page, test } from '@playwright/test';

const landingPath = '/?lp_hypothesis=h03&lp_variant=treatment';

test.describe('Landing story journey', () => {
  test.describe.configure({ timeout: 120_000 });

  test('moves from the scattered state to the final actionable chapter', async ({
    page,
  }) => {
    await openLanding(page);
    const story = await focusStory(page);

    await expect(story).toHaveAccessibleName(/1 \/ 4/);

    await activateChapter(page, '実行');

    await expect(story).toHaveAccessibleName(/4 \/ 4/);
    await expect(
      story.getByRole('button', { name: '無料で保存を始める' }),
    ).toBeVisible();
    await expect(
      story.getByRole('button', { name: '登録なしで1件試す' }),
    ).toBeVisible();
  });

  test('connects the final chapter to the existing no-signup trial', async ({
    page,
  }) => {
    await openLanding(page);
    const story = await focusStory(page);
    await activateChapter(page, '実行');

    await story.getByRole('button', { name: '登録なしで1件試す' }).click();

    await expect(
      page.getByRole('textbox', { name: /登録なしで試す/ }),
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
