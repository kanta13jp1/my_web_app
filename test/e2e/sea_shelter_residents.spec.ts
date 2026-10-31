import { expect, test } from "@playwright/test";
import type { Page } from "@playwright/test";

const key = "my_web_app.sea_shelter.v1";
const issues = new WeakMap<Page, string[]>();
const downloads = new WeakMap<
  Page,
  Promise<{ name: string; body: number; wire: number; error?: string }>[]
>();
const view = (page: Page, name: string) =>
  page.locator(`.tabs [data-view="${name}"]`).click();
async function village(page: Page) {
  await page.locator("#collect").click();
  await page.evaluate((key) => {
    const s = JSON.parse(localStorage.getItem(key)!);
    s.residents = 7;
    s.xp = 99;
    s.wood = 11;
    s.metal = 33;
    s.collected = 20;
    s.claimed = [];
    s.farm.food = 0;
    s.farm.crops = {};
    s.tiles = [
      { x: 2, y: 2, kind: "dock" },
      { x: 1, y: 2, kind: "home" },
      { x: 2, y: 1, kind: "home" },
      { x: 3, y: 2, kind: "home" },
      { x: 1, y: 1, kind: "garden" },
      { x: 3, y: 1, kind: "garden" },
      { x: 2, y: 3, kind: "garden" },
      { x: 1, y: 3, kind: "deck" },
      { x: 3, y: 3, kind: "deck" },
    ];
    localStorage.setItem(key, JSON.stringify(s));
  }, key);
  await page.reload();
  await expect(page.locator(".crew-actor")).toHaveCount(3);
}

test.beforeEach(async ({ page }, info) => {
  const missing = info.title.includes("missing");
  const intentional = (url: string) =>
    missing && /\/residents(?:-original-v2\.png|\.mjs)/.test(url);
  issues.set(page, []);
  if (info.title.startsWith("old seven-person")) downloads.set(page, []);
  page.on("pageerror", (e) => issues.get(page)!.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error" && !intentional(m.location().url)) {
      issues.get(page)!.push(m.text());
    }
  });
  page.on("requestfailed", (r) => {
    if (!intentional(r.url())) issues.get(page)!.push(r.url());
  });
  page.on("response", (r) => {
    if (r.status() >= 500) issues.get(page)!.push(`${r.status()} ${r.url()}`);
    if (
      downloads.has(page) &&
      new URL(r.url()).pathname.startsWith("/labs/sea-shelter/") && r.ok()
    ) {
      downloads.get(page)!.push((async () => {
        try {
          await r.finished();
          const body = (await r.body()).byteLength;
          let wire = 0;
          try {
            wire = (await r.request().sizes()).responseBodySize;
          } catch { /* Raw bytes remain a conservative bound. */ }
          return { name: new URL(r.url()).pathname, body, wire };
        } catch (error) {
          return {
            name: new URL(r.url()).pathname,
            body: 0,
            wire: 0,
            error: String(error),
          };
        }
      })());
    }
  });
  await page.route("**/favicon.ico", (r) => r.fulfill({ status: 204 }));
  if (missing) {
    await page.route(
      "**/residents-original-v2.png",
      (r) => r.fulfill({ status: 404, body: "intentional missing image" }),
    );
  }
  await page.clock.install({ time: new Date("2026-10-30T12:00:00Z") });
  await page.goto("/labs/sea-shelter/index.html");
  await expect(page.locator(".crew-card")).toHaveCount(3);
  await expect.poll(() =>
    page.locator("main").getAttribute("data-resident-art")
  ).toBe(missing ? "missing" : "ready");
});
test.afterEach(async ({ page }, info) => {
  await info.attach("resident-runtime-issues", {
    body: JSON.stringify(issues.get(page)),
    contentType: "application/json",
  });
  expect(issues.get(page)).toEqual([]);
});

test(
  "old seven-person village gets three original residents, conversations and collection/construction reactions",
  async ({ page }, info) => {
    // The virtual frame clock supplies no ResourceTiming sizes. Read actual
    // completed browser responses; decoded bodies conservatively bound transfer.
    const resources = await Promise.all(downloads.get(page)!);
    downloads.delete(page);
    expect(resources.filter((r) => r.error)).toEqual([]);
    const transfer = {
      resources,
      bodyBytes: resources.reduce((n, r) => n + r.body, 0),
      wireBytes: resources.reduce((n, r) => n + r.wire, 0),
    };
    expect(transfer.bodyBytes).toBeGreaterThan(2269800);
    expect(transfer.bodyBytes).toBeLessThan(3 * 1024 * 1024);
    await info.attach("initial-game-surface-transfer", {
      body: JSON.stringify(transfer),
      contentType: "application/json",
    });
    await village(page);
    await expect(page.locator("#residents")).toHaveText("7 / 7");
    await expect(page.locator("#wood")).toHaveText("11");
    await page.locator("#collect").click();
    await expect(page.locator("#wood")).toHaveText("16");
    await expect(page.locator("#placement-label")).toContainText("ミオ");
    await view(page, "build");
    await page.locator('[data-kind="deck"]').click();
    await page.locator('#board button[data-x="0"][data-y="2"]').click();
    await expect(page.locator("#wood")).toHaveText("12");
    await expect(page.locator("#placement-label")).toContainText("足場");
    await expect(page.locator("#board button")).toHaveCount(25);
    const saved = await page.evaluate((key) => localStorage.getItem(key), key);
    await view(page, "residents");
    for (const name of ["ミオ", "ゲン", "リク"]) {
      const card = page.getByRole("button", {
        name: new RegExp(`^${name} .*と話す$`),
      });
      await card.focus();
      await page.keyboard.press("Enter");
      await expect(page.locator("#status")).toContainText(`${name}「`);
      await expect(card).toBeFocused();
    }
    expect(await page.evaluate((key) => localStorage.getItem(key), key)).toBe(
      saved,
    );
    await page.screenshot({
      path: info.outputPath("resident-conversations.png"),
      fullPage: true,
      animations: "disabled",
    });
    await view(page, "quests");
    for (const id of ["supplies", "shelter", "community"]) {
      await page.locator(`#quest-${id}`).click();
    }
    await view(page, "board");
    await expect(page.locator(".crew-lantern")).toBeVisible();
    await page.screenshot({
      path: info.outputPath("residents-in-old-village.png"),
      fullPage: true,
      animations: "disabled",
    });
  },
);

test(
  "garden and delivery reactions keep paid actions stable, pause in background and respect reduced motion",
  async ({ page }, info) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await village(page);
    await view(page, "farm");
    await page.getByRole("button", { name: "種をまく 木材2", exact: true })
      .first().click();
    await expect(page.locator("#wood")).toHaveText("9");
    await page.clock.runFor(60000);
    await page.getByRole("button", { name: "収穫する", exact: true }).first()
      .dblclick();
    await expect(page.locator("#food")).toHaveText("3");
    await expect(page.locator("#wood")).toHaveText("9");
    await expect(page.locator("#crew-feedback")).toContainText("よく育った");
    await expect(page.locator("#crew-feedback")).toBeVisible();
    await page.locator("#donate-food").click();
    await expect(page.locator("#food")).toHaveText("0");
    await expect(page.locator("#wood")).toHaveText("13");
    await expect(page.locator("#crew-feedback")).toContainText("温かい食卓");
    for (let i = 0; i < 40; i++) await page.locator("#collect").click();
    await expect(page.locator(".crew-actor")).toHaveCount(3);
    await expect(page.locator(".crew-card")).toHaveCount(3);
    await view(page, "board");
    await page.clock.runFor(6500);
    const saved = await page.evaluate((key) => localStorage.getItem(key), key);
    await page.evaluate(() => {
      Object.defineProperty(document, "hidden", {
        configurable: true,
        get: () => true,
      });
      document.dispatchEvent(new Event("visibilitychange"));
    });
    const location = () =>
      page.locator(".crew-actor").evaluateAll((els) =>
        els.map((el) => ({
          x: (el as HTMLElement).style.left,
          y: (el as HTMLElement).style.top,
        }))
      );
    const hiddenPosition = await location();
    expect(
      await page.locator(".crew-scene").evaluate((el) =>
        el.getAnimations({ subtree: true }).every((a) =>
          a.playState !== "running"
        )
      ),
    ).toBe(true);
    await page.clock.runFor(15000);
    expect(await location()).toEqual(hiddenPosition);
    await page.evaluate(() => {
      delete (document as unknown as Record<string, unknown>).hidden;
      document.dispatchEvent(new Event("visibilitychange"));
    });
    await expect.poll(() =>
      page.locator(".crew-scene").evaluate((el) =>
        el.getAnimations({ subtree: true }).some((a) =>
          a.playState === "running"
        )
      )
    ).toBe(true);
    await page.emulateMedia({ reducedMotion: "reduce" });
    const still = await location();
    await page.clock.runFor(15000);
    expect(await location()).toEqual(still);
    expect(
      await page.locator(".crew-scene").evaluate((el) =>
        el.getAnimations({ subtree: true }).filter((a) =>
          a.playState === "running"
        ).length
      ),
    ).toBe(0);
    expect(await page.evaluate((key) => localStorage.getItem(key), key)).toBe(
      saved,
    );
    await page.reload();
    await expect(page.locator(".crew-actor")).toHaveCount(3);
    await expect(page.locator("#wood")).toHaveText("213");
    expect(await page.evaluate(() => document.documentElement.scrollWidth))
      .toBeLessThanOrEqual(375);
    await page.screenshot({
      path: info.outputPath("residents-mobile-reduced-motion.png"),
      fullPage: true,
    });
    // Narrow + enlarged text + a real long refusal must keep the bottom action
    // after the complete message. Extra page scrolling is intentional here.
    await page.setViewportSize({ width: 320, height: 568 });
    await page.evaluate((key) => {
      const s = JSON.parse(localStorage.getItem(key)!);
      s.wood = 99999;
      s.metal = 99999;
      s.farm.food = 99999;
      s.storage = {
        version: 1,
        built: true,
        reserve: { wood: 99999, metal: 99999, food: 99999 },
      };
      localStorage.setItem(key, JSON.stringify(s));
    }, key);
    await page.reload();
    await expect(page.locator(".crew-actor")).toHaveCount(3);
    await view(page, "farm");
    await page.addStyleTag({ content: ":root { font-size: 24px; }" });
    await page.locator("#donate-food").click();
    await expect(page.locator('[data-panel="storage"]')).toBeVisible();
    await expect(page.locator("#food")).toHaveText("199998");
    await expect.poll(async () => {
      const workspace = await page.locator(".workspace").boundingBox();
      const tabs = await page.locator(".tabs").boundingBox();
      const status = await page.locator("#status").boundingBox();
      const collect = await page.locator("#collect").boundingBox();
      const panel = await page.locator('[data-panel="storage"]').boundingBox();
      const rail = await page.locator("#crew-feedback").boundingBox();
      return workspace!.y + workspace!.height <= status!.y &&
        tabs!.y + tabs!.height <= status!.y &&
        status!.y + status!.height <= collect!.y &&
        panel!.y + panel!.height <= rail!.y;
    }).toBe(true);
    expect(await page.evaluate(() => document.documentElement.scrollWidth))
      .toBeLessThanOrEqual(320);
    await page.locator("#collect").scrollIntoViewIfNeeded();
    await page.screenshot({
      path: info.outputPath("residents-large-text-capacity-recovery.png"),
      fullPage: true,
    });
  },
);

test(
  "missing art and missing optional renderer leave conversations and the saved game operable",
  async ({ page }, info) => {
    await village(page);
    await view(page, "residents");
    await expect(page.locator("#resident-art-note")).toBeVisible();
    await expect(page.locator(".crew-card .resident-fallback")).toHaveCount(3);
    await page.getByRole("button", { name: "ミオ 整備士と話す", exact: true })
      .click();
    await expect(page.locator("#status")).toContainText("ミオ「");
    await page.locator("#collect").click();
    await expect(page.locator("#wood")).toHaveText("16");
    await page.route(
      "**/residents.mjs",
      (r) =>
        r.fulfill({
          status: 404,
          body: "intentional missing optional renderer",
        }),
    );
    await page.reload();
    await view(page, "residents");
    await expect(page.locator("#resident-art-note")).toContainText(
      "集落の操作は続けられます",
    );
    await expect(page.locator("#invite")).toBeVisible();
    await page.locator("#collect").click();
    await expect(page.locator("#wood")).toHaveText("21");
    await expect(page.locator("#residents")).toHaveText("7 / 7");
    await info.attach("saved-fallback-quantities", {
      body: JSON.stringify(
        await page.evaluate(
          (key) => JSON.parse(localStorage.getItem(key)!),
          key,
        ),
      ),
      contentType: "application/json",
    });
  },
);
