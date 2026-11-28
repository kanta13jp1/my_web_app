import { expect, test } from "@playwright/test";

test("cover, return and close unload the real surface while retaining the save", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "ゲームを開く", exact: true }).click();
  const iframe = page.locator('iframe[title="潮灯のシェルター"]');
  const game = page.frameLocator('iframe[title="潮灯のシェルター"]');
  await game.locator("#collect").click();
  const amount = await game.locator("#wood").innerText();
  const old = await (await iframe.elementHandle())!.contentFrame();
  await page.getByRole("button", { name: "別画面", exact: true }).click();
  await expect(iframe).toHaveCount(0);
  await expect.poll(() => old!.isDetached() || old!.url() === "about:blank")
    .toBe(true);
  await page.getByRole("button", { name: "ゲームに戻る", exact: true }).click();
  await expect(game.locator("#wood")).toHaveText(amount);
  await page.getByRole("button", { name: "ゲームを閉じる", exact: true })
    .click();
  await expect(iframe).toHaveCount(0);
  await page.getByRole("button", { name: "ゲームを開く", exact: true }).click();
  await expect(game.locator("#wood")).toHaveText(amount);
});
