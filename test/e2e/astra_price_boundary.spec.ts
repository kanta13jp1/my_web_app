import { expect, test } from "@playwright/test";

test("normal boundary calculation and 15-case self-check", async ({ page }, info) => {
  await page.goto("/labs/astra-price-boundary/index.html");
  const status = page.getByRole("status").first();
  await expect(status).toContainText("5.51502 USD");
  await expect(status).toContainText("2.74501 USD");
  await expect(page.getByRole("alert")).toBeEmpty();

  await page.getByRole("button", { name: "原記事の例 (300K / 30K)", exact: true }).click();
  await expect(status).toContainText("8.25 USD");
  await expect(status).toContainText("3.75 USD");

  await page.getByRole("button", { name: "15ケース一括セルフチェックを実行", exact: true }).click();
  const selfcheckStatus = page.getByRole("status").nth(1);
  await expect(selfcheckStatus).toContainText("15 / 15 件合格");
  await expect(page.locator("#selfcheck-body tr")).toHaveCount(15);
  await page.screenshot({ path: info.outputPath("normal-15cases.png"), fullPage: true });
});

test("error path and recovery", async ({ page }, info) => {
  await page.goto("/labs/astra-price-boundary/index.html");
  const alert = page.getByRole("alert");
  const status = page.getByRole("status").first();

  await page.getByRole("button", { name: "不正例: 内数超過", exact: true }).click();
  await expect(alert).toContainText("超えています");

  await page.getByRole("button", { name: "不正例: 小数入力", exact: true }).click();
  await expect(alert).toContainText("半角整数");

  await page.getByRole("button", { name: "境界ちょうど (272,000)", exact: true }).click();
  await expect(alert).toBeEmpty();
  await expect(status).toContainText("2.77 USD");
  await expect(status).toContainText("通常単価");
  await page.screenshot({ path: info.outputPath("error-recovery.png"), fullPage: true });
});

test("zero external requests, zero console/page errors, and no horizontal overflow", async ({ page }) => {
  const consoleErrors = [];
  const pageErrors = [];
  const externalRequests = [];
  const postLoadRequests = [];

  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => {
    pageErrors.push(String(err));
  });
  page.on("request", (req) => {
    const url = req.url();
    if (!url.startsWith("http://127.0.0.1") && !url.startsWith("https://my-web-app-b67f4.web.app")) {
      externalRequests.push(url);
    }
  });

  await page.goto("/labs/astra-price-boundary/index.html");
  page.on("request", (req) => postLoadRequests.push(req.url()));

  await page.getByRole("button", { name: "15ケース一括セルフチェックを実行", exact: true }).click();
  await page.getByRole("button", { name: "キャッシュ読み長文", exact: true }).click();
  await expect(page.getByRole("status").first()).toContainText("4.65 USD");

  const overflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(overflow.scrollWidth).toBeLessThanOrEqual(overflow.clientWidth);
  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
  expect(externalRequests).toEqual([]);
  expect(postLoadRequests).toEqual([]);
});
