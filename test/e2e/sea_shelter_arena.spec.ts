import { expect, test } from "@playwright/test";
import type { Page } from "@playwright/test";
test.use({ launchOptions: { args: ["--enable-unsafe-swiftshader"] } });
test.setTimeout(240000);
const key = "my_web_app.sea_shelter.v1";
const arena = "/labs/sea-shelter/arena/index.html";
async function ready(page: Page) {
  await page.locator("#start").click();
  await expect(page.locator("#scene canvas")).toHaveCount(1);
  await expect(page.locator("#attack")).toBeEnabled();
}
async function snapshot(page: Page) {
  return await page.evaluate(() => JSON.stringify({ ...localStorage }));
}
test(
  "old village enters lazy 3D, guards and special win without changing saved assets",
  async ({ page }, info) => {
    await page.addInitScript(() => {
      const original = WebGL2RenderingContext.prototype.clear;
      (window as unknown as { arenaPaints: number[] }).arenaPaints = [];
      WebGL2RenderingContext.prototype.clear = function (mask) {
        (window as unknown as { arenaPaints: number[] }).arenaPaints.push(
          performance.now(),
        );
        return original.call(this, mask);
      };
    });
    const requests: string[] = [];
    const resources: Promise<{ path: string; bytes: number }>[] = [];
    page.on("request", (r) => requests.push(r.url()));
    page.on("response", (r) => {
      if (r.url().includes("/arena/") && r.ok()) {
        resources.push(
          r.body().then((b) => ({
            path: new URL(r.url()).pathname,
            bytes: b.length,
          })),
        );
      }
    });
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => {
      if (m.type() === "error") errors.push(m.text());
    });
    await page.route("**/favicon.ico", (r) => r.fulfill({ status: 204 }));
    await page.clock.install({ time: new Date("2026-10-31T12:00:00Z") });
    await page.goto("/labs/sea-shelter/index.html");
    await page.locator("#collect").click();
    await page.evaluate((key) => {
      const s = JSON.parse(localStorage.getItem(key)!);
      s.residents = 7;
      s.xp = 99;
      s.tiles = [{ x: 2, y: 2, kind: "dock" }, { x: 1, y: 2, kind: "home" }, {
        x: 2,
        y: 1,
        kind: "home",
      }, { x: 3, y: 2, kind: "home" }];
      localStorage.setItem(key, JSON.stringify(s));
    }, key);
    await page.reload();
    await page.locator('.tabs [data-view="residents"]').click();
    await expect(page.locator("#residents")).toHaveText("7 / 7");
    expect(requests.some((u) => u.includes("/arena/vendor/"))).toBe(false);
    await page.locator(".training-entry").click();
    const saved = await snapshot(page);
    await expect(page.locator("#sound")).not.toBeChecked();
    expect(requests.some((u) => u.includes("/arena/vendor/"))).toBe(false);
    await page.setViewportSize({ width: 375, height: 667 });
    await page.locator("summary").click();
    await page.locator("#low").check();
    await page.locator("summary").click();
    await page.clock.pauseAt(new Date("2026-10-31T12:01:00Z"));
    await ready(page);
    await page.clock.runFor(250);
    await page.screenshot({
      path: info.outputPath("arena-original-models.png"),
    });
    let elapsed = 250, handled = false, specials = 0;
    while (
      elapsed < 90000 &&
      await page.locator("body").getAttribute("data-status") === "running"
    ) {
      const warning =
        await page.locator("#cue").getAttribute("data-warning") === "true";
      if (warning && !handled) {
        await page.clock.runFor(300);
        elapsed += 300;
        if (await page.locator("#guard").isEnabled()) {
          await page.locator("#guard").click();
        }
        handled = true;
      }
      if (!warning) handled = false;
      if (await page.locator("#special").isEnabled()) {
        if (specials === 0) {
          const charge = await page.locator("#charge").innerText();
          await page.locator("#return").focus();
          await page.keyboard.press("s");
          await expect(page.locator("#charge")).toHaveText(charge);
          await page.locator("summary").focus();
          await page.keyboard.press("s");
          await expect(page.locator("#charge")).toHaveText(charge);
        }
        await page.locator("#special").click();
        specials++;
        await page.clock.runFor(150);
        elapsed += 150;
        if (specials === 1) {
          await page.screenshot({
            path: info.outputPath("arena-special-camera.png"),
          });
        }
      } else if (await page.locator("#attack").isEnabled()) {
        await page.locator("#attack").click();
      }
      await page.clock.runFor(200);
      elapsed += 200;
    }
    await expect(page.locator("body")).toHaveAttribute("data-status", "won");
    const endStart = await page.evaluate(() =>
      (window as unknown as { arenaPaints: number[] }).arenaPaints.length
    );
    await page.clock.runFor(1200);
    const endPaints = await page.evaluate(() =>
      (window as unknown as { arenaPaints: number[] }).arenaPaints.length
    );
    expect(endPaints - endStart).toBeLessThanOrEqual(37);
    await expect(page.locator("#hp")).toHaveText("5 / 5");
    expect(specials).toBeGreaterThan(0);
    await expect(page.locator("#cue")).toContainText("訓練成功");
    expect(await snapshot(page)).toBe(saved);
    const files = await Promise.all(resources);
    expect(files.reduce((sum, r) => sum + r.bytes, 0)).toBeLessThan(2000000);
    await info.attach("lazy-3d-transfer", {
      body: JSON.stringify(files),
      contentType: "application/json",
    });
    await info.attach("render-budget", {
      body: (await page.locator("#metrics").textContent()) ?? "",
      contentType: "text/plain",
    });
    await page.screenshot({ path: info.outputPath("arena-victory.png") });
    await page.locator("#retry").click();
    await expect(page.locator("#hp")).toHaveText("5 / 5");
    await expect(page.locator("#enemy-hp")).toHaveText("60 / 60");
    await page.locator("#return").click();
    await expect(page.locator("#residents")).toHaveText("7 / 7");
    expect(errors).toEqual([]);
  },
);

test(
  "new player can lose, pause and resume with accessible low-motion controls and no resource writes",
  async ({ page }, info) => {
    await page.clock.install({ time: new Date("2026-10-31T12:00:00Z") });
    await page.emulateMedia({ reducedMotion: "reduce" });
    await page.goto(arena);
    await page.clock.pauseAt(new Date("2026-10-31T12:01:00Z"));
    const saved = await snapshot(page);
    await expect(page.locator("#quiet")).toBeChecked();
    await ready(page);
    await page.screenshot({
      path: info.outputPath("arena-default-quality.png"),
    });
    await page.locator("summary").focus();
    await page.keyboard.press("g");
    expect(await page.locator("#guard").isEnabled()).toBe(true);
    await page.locator("#return").focus();
    await page.keyboard.press("a");
    await page.clock.runFor(250);
    await expect(page.locator("#enemy-hp")).toHaveText("60 / 60");
    await page.locator("#attack").focus();
    await page.keyboard.press("Shift+A");
    await page.clock.runFor(250);
    await expect(page.locator("#enemy-hp")).toHaveText("60 / 60");
    await page.keyboard.press("a");
    await page.keyboard.press("a");
    await expect(page.locator(".actions")).toBeFocused();
    await page.locator("#pause").click();
    await page.clock.runFor(20000);
    await expect(page.locator("#enemy-hp")).toHaveText("60 / 60");
    await page.locator("#pause").click();
    await page.clock.runFor(250);
    await expect(page.locator("#enemy-hp")).toHaveText("59 / 60");
    await page.locator("#pause").click();
    const health = await page.locator("#hp").innerText();
    await page.clock.setSystemTime(new Date("2035-01-01T00:00:00Z"));
    await page.clock.runFor(20000);
    await expect(page.locator("#hp")).toHaveText(health);
    await expect(page.locator("#attack")).toBeDisabled();
    await page.locator("#pause").click();
    await page.locator("#attack").focus();
    for (let i = 0; i < 120; i++) {
      await page.keyboard.press("a");
      await page.clock.runFor(200);
    }
    await expect(page.locator("body")).toHaveAttribute("data-status", "lost");
    expect(await snapshot(page)).toBe(saved);
    await page.locator("#retry").click();
    await page.clock.runFor(200);
    await page.evaluate(() => {
      Object.defineProperty(document, "hidden", {
        configurable: true,
        value: true,
      });
      document.dispatchEvent(new Event("visibilitychange"));
    });
    await page.clock.runFor(10000);
    await expect(page.locator("body")).toHaveAttribute("data-status", "paused");
    await page.evaluate(() => {
      Object.defineProperty(document, "hidden", {
        configurable: true,
        value: false,
      });
      document.dispatchEvent(new Event("visibilitychange"));
    });
    await expect(page.locator("body")).toHaveAttribute("data-status", "paused");
    await page.locator("#pause").click();
    for (
      const size of [
        { width: 1280, height: 720 },
        { width: 1366, height: 768 },
        { width: 320, height: 568 },
        { width: 360, height: 640 },
        { width: 390, height: 844 },
        { width: 375, height: 667 },
        { width: 667, height: 375 },
      ]
    ) {
      await page.setViewportSize(size);
      await page.clock.runFor(50);
      for (const id of ["attack", "guard", "special", "pause", "return"]) {
        const box = await page.locator(`#${id}`).boundingBox();
        expect(box).not.toBeNull();
        expect(box!.x).toBeGreaterThanOrEqual(0);
        expect(box!.x + box!.width).toBeLessThanOrEqual(size.width + 1);
        if (size.height >= 568) {
          expect(box!.y + box!.height).toBeLessThanOrEqual(size.height + 1);
        }
        expect(box!.height).toBeGreaterThanOrEqual(44);
      }
    }
    await page.setViewportSize({ width: 320, height: 568 });
    await page.evaluate(() => document.documentElement.style.fontSize = "24px");
    await page.locator("#return").scrollIntoViewIfNeeded();
    await page.locator("#pause").scrollIntoViewIfNeeded();
    await page.screenshot({
      path: info.outputPath("arena-large-text.png"),
      fullPage: true,
    });
    await page.reload();
    await expect(page.locator("#start")).toBeVisible();
    expect(await snapshot(page)).toBe(saved);
  },
);

test(
  "missing engine and real context loss explain recovery and preserve settlement",
  async ({ page }, info) => {
    await page.goto("/labs/sea-shelter/index.html");
    await page.locator("#collect").click();
    const saved = await snapshot(page);
    await page.route(
      "**/arena/vendor/**",
      (r) => r.fulfill({ status: 404, body: "intentional unavailable engine" }),
    );
    await page.goto(arena);
    await page.locator("#start").click();
    await expect(page.locator("#cue")).toContainText("読み込めません");
    await expect(page.locator("#return")).toBeVisible();
    expect(await snapshot(page)).toBe(saved);
    await page.unroute("**/arena/vendor/**");
    await page.locator("#reload").click();
    await ready(page);
    await page.evaluate(() => {
      const canvas = document.querySelector("canvas")!;
      const gl = canvas.getContext("webgl2")!;
      const extension = gl.getExtension("WEBGL_lose_context");
      if (!extension) throw Error("Context loss test extension missing");
      extension.loseContext();
    });
    await expect(page.locator("#cue")).toContainText("接続が切れました");
    await expect(page.locator("#scene canvas")).toHaveCount(0);
    await expect(page.locator("#cleanup")).toContainText("描画を終了しました");
    expect(await snapshot(page)).toBe(saved);
    await page.screenshot({
      path: info.outputPath("arena-context-recovery.png"),
    });
    await page.locator("#retry").click();
    await expect(page.locator("#scene canvas")).toHaveCount(1);
    await page.locator("#return").click();
    await expect(page.locator("#collect")).toBeVisible();
  },
);
