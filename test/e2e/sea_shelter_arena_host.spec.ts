import { expect, test } from "@playwright/test";
test.use({ launchOptions: { args: ["--enable-unsafe-swiftshader"] } });
test(
  "covering the real Flutter host unloads a 3D session and retains settlement assets",
  async ({ page }, info) => {
    await page.goto("/");
    await page.getByRole("button", { name: "ゲームを開く", exact: true })
      .click();
    const iframe = page.locator('iframe[title="潮灯のシェルター"]');
    const game = page.frameLocator('iframe[title="潮灯のシェルター"]');
    await game.locator("#collect").click();
    const amount = await game.locator("#wood").innerText();
    await game.locator('.tabs [data-view="residents"]').click();
    await game.locator(".training-entry").click();
    await game.locator("#start").click();
    await expect(game.locator("#scene canvas")).toHaveCount(1);
    await game.locator("#attack").click();
    await page.screenshot({
      path: info.outputPath("arena-in-flutter-host.png"),
    });
    const old = await (await iframe.elementHandle())!.contentFrame();
    await page.getByRole("button", { name: "別画面", exact: true }).click();
    await expect(iframe).toHaveCount(0);
    await expect.poll(() => old!.isDetached() || old!.url() === "about:blank")
      .toBe(true);
    await page.getByRole("button", { name: "ゲームに戻る", exact: true })
      .click();
    await expect(game.locator("#wood")).toHaveText(amount);
    await game.locator('.tabs [data-view="residents"]').click();
    await game.locator(".training-entry").click();
    await expect(game.locator("#start")).toBeVisible();
    await expect(game.locator("#scene canvas")).toHaveCount(0);
    await page.getByRole("button", { name: "ゲームを閉じる", exact: true })
      .click();
    await expect(iframe).toHaveCount(0);
  },
);
