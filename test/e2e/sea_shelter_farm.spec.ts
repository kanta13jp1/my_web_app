import { expect, test } from "@playwright/test";

async function buildGarden(page: import("@playwright/test").Page) {
  for (let i = 0; i < 24; i++) await page.locator("#collect").click();
  await page.locator('.tabs [data-view="build"]').click();
  await page.locator('[data-kind="garden"]').click();
  await page.locator('#board [data-x="3"][data-y="2"]').click();
  await page.locator('.tabs [data-view="farm"]').click();
  await expect(page.locator("#crops")).toContainText("種まきできます");
}
test.beforeEach(async ({ page }) => {
  await page.clock.install({ time: new Date("2026-10-30T12:00:00Z") });
  await page.goto("/labs/sea-shelter/index.html");
});

test("grow, reload, harvest once and deliver to the residents", async ({ page }) => {
  await buildGarden(page);
  await page.getByRole("button", { name: "種をまく 木材2" }).click();
  await expect(page.locator("#crops")).toContainText("収穫まで");
  await page.clock.fastForward(61000);
  await page.reload();
  await page.locator('.tabs [data-view="farm"]').click();
  await expect(page.locator("#crops")).toContainText("収穫できます");
  const beforeHarvest = await page.locator("#wood").textContent();
  await page.getByRole("button", { name: "収穫する", exact: true }).dblclick();
  await expect(page.locator("#food")).toHaveText("3");
  await expect(page.locator("#wood")).toHaveText(beforeHarvest!);
  await expect(page.getByRole("button", { name: "収穫する", exact: true }))
    .toBeDisabled();
  const wood = Number(await page.locator("#wood").textContent());
  await page.locator("#donate-food").click();
  await expect(page.locator("#food")).toHaveText("0");
  await expect(page.locator("#wood")).toHaveText(String(wood + 4));
  await page.reload();
  await page.locator('.tabs [data-view="farm"]').click();
  await expect(page.locator("#food")).toHaveText("0");
  await expect(page.locator("#crops")).toContainText("種まきできます");
});

test("early and repeated harvesting and empty delivery give no rewards", async ({ page }) => {
  await page.locator('.tabs [data-view="farm"]').click();
  await page.locator("#donate-food").click();
  await expect(page.locator("#status")).toContainText("食料3が必要");
  await expect(page.locator("#farm-empty")).toBeVisible();
  await buildGarden(page);
  await page.getByRole("button", { name: "種をまく 木材2" }).click();
  const wood = await page.locator("#wood").textContent();
  await page.getByRole("button", { name: "収穫する", exact: true }).dblclick();
  await expect(page.locator("#food")).toHaveText("0");
  await expect(page.locator("#wood")).toHaveText(wood!);
  await expect(page.locator("#status")).toContainText("収穫まで");
});

test("clock reversal pauses growth and reset cancels or clears the crop", async ({ page }) => {
  await buildGarden(page);
  await page.getByRole("button", { name: "種をまく 木材2" }).click();
  await page.clock.setSystemTime(new Date("2026-10-29T12:00:00Z"));
  await page.getByRole("button", { name: "収穫する", exact: true }).click();
  await expect(page.locator("#status")).toContainText("時計を確認");
  await expect(page.locator("#food")).toHaveText("0");
  const protectedWood = await page.locator("#wood").textContent();
  await page.evaluate(() => {
    const key = "my_web_app.sea_shelter.v1";
    const saved = JSON.parse(localStorage.getItem(key)!);
    saved.farm.food = -1;
    localStorage.setItem(key, JSON.stringify(saved));
  });
  await page.reload();
  await expect(page.locator("#status")).toContainText("農園だけを初期化");
  await expect(page.locator("#wood")).toHaveText(protectedWood!);
  await page.locator('.tabs [data-view="farm"]').click();
  await expect(page.locator("#crops")).toContainText("種まきできます");
  await page.getByRole("button", { name: "種をまく 木材2" }).click();
  if (!(await page.locator("#help-dialog").isVisible())) {
    await page.locator("#help").click();
  }
  await page.locator("#reset").click();
  await page.locator("#cancel-reset").click();
  await expect(page.locator("#crops")).toContainText("菜園");
  if (!(await page.locator("#help-dialog").isVisible())) {
    await page.locator("#help").click();
  }
  await page.locator("#reset").click();
  await page.locator("#confirm-reset").click();
  await page.reload();
  await page.locator('.tabs [data-view="farm"]').click();
  await expect(page.locator("#crops")).toBeEmpty();
  await expect(page.locator("#food")).toHaveText("0");
});
