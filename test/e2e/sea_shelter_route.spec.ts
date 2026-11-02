import { expect, test } from "@playwright/test";

test("embedded game retains the full compact viewport on small phones", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.goto("/sea-shelter");
  const game = page.frameLocator('iframe[title="潮灯のシェルター"]');
  await expect(game.locator("#collect")).toBeVisible();
  await expect.poll(async () =>
    game.locator("html").evaluate((e) => ({
      width: e.scrollWidth <= e.clientWidth,
      height: e.scrollHeight <= e.clientHeight,
    }))
  ).toEqual({ width: true, height: true });
});

test("integrated route opens the local game and survives browser navigation", async ({ page }) => {
  await page.goto("/sea-shelter");
  const game = page.frameLocator('iframe[title="潮灯のシェルター"]');
  await expect(game.getByRole("heading", { name: "潮灯のシェルター" }))
    .toBeVisible();
  await game.locator("#collect").click();
  const amount = await game.locator("#wood").innerText();
  await page.reload();
  await expect(game.locator("#wood")).toHaveText(amount);
  await page.goto("/focus-capture");
  await expect(page.locator('iframe[title="潮灯のシェルター"]')).toHaveCount(0);
  await page.goBack();
  await expect(game.locator("#wood")).toHaveText(amount);
});
