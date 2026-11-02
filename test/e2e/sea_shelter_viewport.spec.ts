import { expect, test } from "@playwright/test";

test(
  "long recovery warnings do not overlap the board and keyboard construction keeps focus",
  async ({ page }, info) => {
    const issues: string[] = [];
    page.on("pageerror", (error) => issues.push(error.message));
    await page.setViewportSize({ width: 320, height: 568 });
    await page.goto("/labs/sea-shelter/index.html");
    await page.locator("#collect").click();
    await page.evaluate(() => {
      const key = "my_web_app.sea_shelter.v1";
      const saved = JSON.parse(localStorage.getItem(key)!);
      saved.farm.food = -1;
      localStorage.setItem(key, JSON.stringify(saved));
    });
    await page.reload();
    await expect(page.locator("#status")).toContainText("農園だけを初期化");
    await expect.poll(async () => {
      const board = await page.locator("#board").boundingBox();
      const tabs = await page.locator(".tabs").boundingBox();
      const status = await page.locator("#status").boundingBox();
      const collect = await page.locator("#collect").boundingBox();
      return board!.y + board!.height <= tabs!.y &&
        tabs!.y + tabs!.height <= status!.y &&
        status!.y + status!.height <= collect!.y;
    }).toBe(true);
    await page.screenshot({
      path: info.outputPath("recovery-320-568.png"),
      fullPage: true,
    });
    for (let i = 0; i < 23; i++) await page.locator("#collect").click();
    await page.locator('.tabs [data-view="build"]').focus();
    await page.keyboard.press("Enter");
    for (let i = 0; i < 5; i++) await page.keyboard.press("Tab");
    await expect(page.locator('[data-kind="deck"]')).toBeFocused();
    await page.keyboard.press("Tab");
    await page.keyboard.press("Tab");
    await expect(page.locator('[data-kind="garden"]')).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page.locator("#board button.near").first()).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page.locator("#board button:focus")).toContainText("菜園");
    await page.keyboard.press("Enter");
    await expect(page.getByRole("button", { name: "種をまく 木材2" }))
      .toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page.locator("#status")).toBeFocused();
    await expect(page.locator("#status")).toContainText("種をまきました");
    expect(issues).toEqual([]);
  },
);

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
      const contrasts = await page.evaluate(() => {
        const luminance = (color: string) => {
          const rgb = color.match(/[\d.]+/g)!.slice(0, 3).map(Number).map(
            (n) => {
              const v = n / 255;
              return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
            },
          );
          return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722;
        };
        const ratio = (a: string, b: string) => {
          const [lo, hi] = [luminance(a), luminance(b)].sort((x, y) => x - y);
          return (hi + 0.05) / (lo + 0.05);
        };
        return ["#board button.sea:not(.near)", "#edit-profile", "#collect"]
          .map((selector) => {
            const style = getComputedStyle(document.querySelector(selector)!);
            return {
              selector,
              text: ratio(style.color, style.backgroundColor),
              border: ratio(style.borderColor, style.backgroundColor),
            };
          });
      });
      for (const contrast of contrasts) {
        expect(contrast.text).toBeGreaterThanOrEqual(4.5);
      }
      expect(contrasts[0].border).toBeGreaterThanOrEqual(3);
      await info.attach(`contrast-${width}-${height}`, {
        body: JSON.stringify(contrasts),
        contentType: "application/json",
      });
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
      for (const view of ["build", "residents", "quests", "farm", "storage"]) {
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
