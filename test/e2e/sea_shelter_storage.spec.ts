import { expect, test } from "@playwright/test";
import type { Page } from "@playwright/test";
import { readFileSync } from "node:fs";

const key = "my_web_app.sea_shelter.v1";
const issues = new WeakMap<Page, string[]>();
const view = (page: Page, name: string) =>
  page.locator(`.tabs [data-view="${name}"]`).click();
async function collect(page: Page, count: number) {
  for (let n = 0; n < count; n++) await page.locator("#collect").click();
}
test.beforeEach(async ({ page }) => {
  issues.set(page, []);
  page.on("pageerror", (error) => issues.get(page)!.push(error.message));
  page.on("console", (m) => {
    if (m.type() === "error") issues.get(page)!.push(m.text());
  });
  page.on("requestfailed", (request) => {
    if (!request.url().startsWith("blob:")) {
      issues.get(page)!.push(request.url());
    }
  });
  page.on("response", (response) => {
    if (response.status() >= 500) {
      issues.get(page)!.push(`${response.status()} ${response.url()}`);
    }
  });
  await page.route("**/favicon.ico", (route) => route.fulfill({ status: 204 }));
  await page.clock.install({ time: new Date("2026-10-30T12:00:00Z") });
  await page.goto("/labs/sea-shelter/index.html");
});
test.afterEach(async ({ page }, info) => {
  await info.attach("runtime-issues", {
    body: JSON.stringify(issues.get(page)),
    contentType: "application/json",
  });
  expect(issues.get(page)).toEqual([]);
});

test(
  "show shortages, build one dock warehouse even on a full map, reload and navigate by keyboard",
  async ({ page }, info) => {
    await view(page, "storage");
    await page.locator("#warehouse-build").click();
    await expect(page.locator("#warehouse-requirements")).toContainText(
      "木材あと30 / 金属あと15",
    );
    await expect(page.locator("#wood")).toHaveText("0");
    await page.locator("#storage-collect").click();
    await expect(page.locator("#collect")).toBeFocused();
    await collect(page, 12);
    // A documented v1 full-map fixture avoids hundreds of unrelated setup taps.
    await page.evaluate((saveKey) => {
      const s = JSON.parse(localStorage.getItem(saveKey)!);
      while (s.tiles.length < 25) {
        let added = false;
        for (let y = 0; y < 5 && !added; y++) {
          for (let x = 0; x < 5 && !added; x++) {
            if (
              !s.tiles.some((t: { x: number; y: number }) =>
                t.x === x && t.y === y
              ) && s.tiles.some((t: { x: number; y: number }) =>
                Math.abs(t.x - x) + Math.abs(t.y - y) === 1
              )
            ) {
              s.tiles.push({ x, y, kind: "deck" });
              added = true;
            }
          }
        }
      }
      localStorage.setItem(saveKey, JSON.stringify(s));
    }, key);
    await page.reload();
    await expect(page.locator("#board .built")).toHaveCount(25);
    await view(page, "build");
    await page.locator("#choose-warehouse").click();
    await expect(page.locator("#warehouse-requirements")).toContainText(
      "25区画でも増設できます",
    );
    await page.locator("#warehouse-build").dblclick();
    await expect(page.locator("#wood")).toHaveText("6");
    await expect(page.locator("#metal")).toHaveText("9");
    await expect(page.locator("#xp")).toHaveText("12");
    await expect(page.locator("#residents")).toHaveText("1 / 1");
    await expect(page.locator("#warehouse-build")).toBeDisabled();
    await expect(page.locator("#storage-wood")).toHaveText("6 / 199,998");
    await page.reload();
    await expect(page.locator("#board .built")).toHaveCount(25);
    await expect(page.locator('#board [data-x="2"][data-y="2"]')).toContainText(
      "倉庫",
    );
    await page.locator('.tabs [data-view="storage"]').focus();
    await page.keyboard.press("Enter");
    await expect(page.locator('[data-panel="storage"]')).toBeVisible();
    await page.locator("#storage-collect").focus();
    await page.keyboard.press("Space");
    await expect(page.locator("#collect")).toBeFocused();
    await view(page, "storage");
    await page.screenshot({
      path: info.outputPath("warehouse-full-map.png"),
      fullPage: true,
    });
  },
);

test(
  "capacity never silently consumes a crop or a paid reward and partial free collection is explicit",
  async ({ page }, info) => {
    await page.setViewportSize({ width: 320, height: 568 });
    await collect(page, 24);
    await view(page, "storage");
    await page.locator("#warehouse-build").click();
    await view(page, "build");
    await page.locator('[data-kind="garden"]').click();
    await page.locator('#board [data-x="3"][data-y="2"]').click();
    await view(page, "farm");
    await page.getByRole("button", { name: "種をまく 木材2" }).click();
    await page.evaluate((saveKey) => {
      const s = JSON.parse(localStorage.getItem(saveKey)!);
      s.wood = 99999;
      s.metal = 99999;
      s.farm.food = 99999;
      s.storage.reserve = { wood: 99999, metal: 99999, food: 99997 };
      localStorage.setItem(saveKey, JSON.stringify(s));
    }, key);
    await page.clock.fastForward(61000);
    await page.reload();
    await view(page, "farm");
    const xp = await page.locator("#xp").textContent();
    await page.getByRole("button", { name: "収穫する", exact: true }).click();
    await expect(page.locator("#status")).toContainText(
      "作物は収穫せず残しています",
    );
    await expect(page.locator("#food")).toHaveText("199996");
    await view(page, "farm");
    await expect(page.locator("#crops")).toContainText("収穫できます");
    await page.locator("#donate-food").click();
    await expect(page.locator("#status")).toContainText("食料は使っていません");
    await expect(page.locator("#food")).toHaveText("199996");
    await expect(page.locator("#xp")).toHaveText(xp!);
    await page.locator("#share-food").click();
    await page.locator("#cancel-share").click();
    await expect(page.locator("#food")).toHaveText("199996");
    await page.locator("#share-food").click();
    await page.locator("#confirm-share").dblclick();
    await expect(page.locator("#food")).toHaveText("199993");
    await expect(page.locator("#xp")).toHaveText(xp!);
    await view(page, "farm");
    await page.getByRole("button", { name: "収穫する", exact: true })
      .dblclick();
    await expect(page.locator("#food")).toHaveText("199996");
    await expect(page.locator("#wood")).toHaveText("199998");
    await expect(page.getByRole("button", { name: "収穫する", exact: true }))
      .toBeDisabled();
    await page.evaluate((saveKey) => {
      const s = JSON.parse(localStorage.getItem(saveKey)!);
      s.storage.reserve.wood = 99998;
      localStorage.setItem(saveKey, JSON.stringify(s));
    }, key);
    await page.reload();
    await expect(page.locator("#collect")).toContainText("木材 +1 / 金属 +0");
    await page.locator("#collect").click();
    await expect(page.locator("#wood")).toHaveText("199998");
    await expect(page.locator("#metal")).toHaveText("199998");
    await expect(page.locator("#status")).toContainText("回収していません");
    const afterPartialXp = await page.locator("#xp").textContent();
    await page.locator("#collect").click();
    await expect(page.locator('[data-panel="storage"]')).toBeVisible();
    await expect(page.locator("#xp")).toHaveText(afterPartialXp!);
    expect(await page.evaluate(() => document.documentElement.scrollWidth))
      .toBeLessThanOrEqual(320);
    for (const id of ["wood", "metal", "food"]) {
      const metrics = await page.locator(`#${id}`).evaluate((el) => ({
        width: el.clientWidth,
        content: el.scrollWidth,
        height: el.getBoundingClientRect().height,
        line: parseFloat(getComputedStyle(el).lineHeight),
      }));
      expect(metrics.content).toBeLessThanOrEqual(metrics.width);
      expect(metrics.height).toBeLessThanOrEqual(metrics.line + 1);
    }
    await page.screenshot({
      path: info.outputPath("capacity-320-568.png"),
      fullPage: true,
    });
  },
);

test(
  "legacy quantities survive migration and corrupt saves are backed up before overwrite or retained on quota failure",
  async ({ page }, info) => {
    await collect(page, 3);
    await page.evaluate((saveKey) => {
      const old = JSON.parse(localStorage.getItem(saveKey)!);
      delete old.storage;
      localStorage.setItem(saveKey, JSON.stringify(old));
    }, key);
    await page.reload();
    await expect(page.locator("#wood")).toHaveText("9");
    await view(page, "storage");
    await expect(page.locator("#storage-wood")).toHaveText("9 / 99,999");
    const broken = await page.evaluate((saveKey) => {
      const s = JSON.parse(localStorage.getItem(saveKey)!);
      s.storage = {
        version: 1,
        built: false,
        reserve: { wood: 77, metal: -1, food: 9 },
      };
      const raw = JSON.stringify(s);
      localStorage.setItem(saveKey, raw);
      return raw;
    }, key);
    await page.reload();
    await expect(page.locator("#status")).toContainText(
      "元の保存を退避しました",
    );
    await expect(page.locator("#wood")).toHaveText("86");
    await expect(page.locator("#food")).toHaveText("9");
    await page.locator("#collect").click();
    expect(
      await page.evaluate((saveKey) => {
        const name = localStorage.getItem(`${saveKey}.recovery-latest`)!;
        return localStorage.getItem(name);
      }, key),
    ).toBe(broken);
    await page.locator("#help").click();
    const downloadPromise = page.waitForEvent("download");
    await page.locator("#export-recovery").click();
    const download = await downloadPromise;
    const path = info.outputPath("corrupt-original.json");
    await download.saveAs(path);
    expect(readFileSync(path, "utf8")).toBe(broken);
    await page.locator("#close-help").click();
    const blocked = await page.evaluate((saveKey) => {
      const s = JSON.parse(localStorage.getItem(saveKey)!);
      s.storage.reserve.metal = "bad";
      const raw = JSON.stringify(s);
      localStorage.setItem(saveKey, raw);
      return raw;
    }, key);
    await page.addInitScript(() => {
      const original = Storage.prototype.setItem;
      Storage.prototype.setItem = function (name, value) {
        if (
          name.startsWith("my_web_app.sea_shelter.v1.recovery.") ||
          name.endsWith(".recovery-latest")
        ) throw new DOMException("quota", "QuotaExceededError");
        return original.call(this, name, value);
      };
    });
    await page.reload();
    await expect(page.locator("#status")).toContainText(
      "元の保存は上書きしません",
    );
    await page.locator("#collect").click();
    await expect(page.locator("#save-status")).toContainText("保存できません");
    expect(await page.evaluate((saveKey) => localStorage.getItem(saveKey), key))
      .toBe(blocked);
  },
);
