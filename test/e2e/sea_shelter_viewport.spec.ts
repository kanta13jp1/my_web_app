import { expect, test } from "@playwright/test";

test(
  "board and persistent controls fit the supported portrait and desktop sizes",
  async ({ page }, info) => {
    test.setTimeout(90000);
    const issues: string[] = [];
    page.on("pageerror", (e) => issues.push(e.message));
    page.on("console", (m) => {
      if (m.type() === "error") issues.push(m.text());
    });
    page.on("requestfailed", (r) => issues.push(r.url()));
    for (
      const [width, height] of [[1280, 720], [1366, 768], [320, 568], [
        360,
        640,
      ], [390, 844]]
    ) {
      await page.setViewportSize({ width, height });
      await page.goto("/labs/sea-shelter/index.html");
      await expect(page.locator("#board button")).toHaveCount(25);
      await page.waitForFunction(() =>
        document.querySelector("#board")?.getAttribute("style")?.includes(
          "--board-size",
        )
      );
      const size = await page.evaluate(() => ({
        width: document.documentElement.scrollWidth,
        height: document.documentElement.scrollHeight,
      }));
      expect(size.width, `${width}x${height} horizontal`).toBeLessThanOrEqual(
        width,
      );
      expect(size.height, `${width}x${height} vertical`).toBeLessThanOrEqual(
        height,
      );
      for (const target of ["#board", "#collect", ".tabs", "#status"]) {
        const box = await page.locator(target).boundingBox();
        expect(box!.y).toBeGreaterThanOrEqual(0);
        expect(box!.y + box!.height, `${target} ${width}x${height}`)
          .toBeLessThanOrEqual(height + 1);
      }
      const cell = await page.locator("#board button").first().boundingBox();
      expect(cell!.width).toBeGreaterThanOrEqual(44);
      expect(cell!.height).toBeGreaterThanOrEqual(44);
      for (const view of ["build", "residents", "quests", "farm"]) {
        await page.locator(`.tabs [data-view="${view}"]`).click();
        await expect(page.locator(`[data-panel="${view}"]`)).toBeVisible();
        await expect(page.locator("#collect")).toBeInViewport();
      }
      await page.locator('.tabs [data-view="build"]').click();
      await page.locator('[data-kind="deck"]').click();
      await expect(page.locator("#placement-label")).toContainText("木材4");
      await page.locator("#cancel-build").click();
      await expect(page.locator("#wood")).toHaveText("0");
      await page.screenshot({
        path: info.outputPath(`viewport-${width}-${height}.png`),
        fullPage: true,
      });
    }
    expect(issues).toEqual([]);
  },
);

test("landscape, large text, long profile and maximum resource labels remain reachable", async ({ page }) => {
  await page.setViewportSize({ width: 568, height: 320 });
  await page.goto("/labs/sea-shelter/index.html");
  await page.locator("#edit-profile").click();
  await page.locator('input[name="name"]').fill(
    "海の仲間と長い船長名あいうえお",
  );
  await page.locator('#profile-form button[type="submit"]').click();
  // A persisted-data fixture stresses label width separately from user-I/O farm tests.
  await page.evaluate(() => {
    const key = "my_web_app.sea_shelter.v1";
    const saved = JSON.parse(localStorage.getItem(key)!);
    saved.wood = 99999;
    saved.metal = 99999;
    saved.xp = 99999;
    localStorage.setItem(key, JSON.stringify(saved));
  });
  await page.reload();
  await expect(page.locator("#wood")).toHaveText("99999");
  await page.addStyleTag({ content: ":root { font-size: 24px; }" });
  await page.locator('.tabs [data-view="residents"]').click();
  await page.locator("#invite").click();
  await expect(page.locator("#status")).toContainText("住居");
  await page.locator("#collect").focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#wood")).toHaveText("99999");
  await page.locator("#help").click();
  await page.locator("#close-help").click();
  expect(await page.evaluate(() => document.documentElement.scrollWidth))
    .toBeLessThanOrEqual(568);
});
