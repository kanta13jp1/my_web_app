import { expect, test } from "@playwright/test";

test("normal path and 12-case selfcheck", async ({ page }, info) => {
  await page.goto("/labs/sns-csv-check/index.html");
  const status = page.getByRole("status");
  await expect(status).toContainText("1.0000%");
  await expect(status).toContainText("5.0000%");
  await expect(page.getByRole("alert")).toBeEmpty();

  await page.getByRole("button", { name: "12ケース一括セルフチェックを実行", exact: true }).click();
  await expect(status).toContainText("12 / 12 件合格");
  await expect(page.locator("tbody tr")).toHaveCount(12);
  await page.screenshot({ path: info.outputPath("normal-12cases.png"), fullPage: true });
});

test("error path, recovery, and X Analytics diagnostics", async ({ page }, info) => {
  await page.goto("/labs/sns-csv-check/index.html");
  const alert = page.getByRole("alert");
  const status = page.getByRole("status");

  await page.getByRole("button", { name: "全角数字 １００", exact: true }).click();
  await expect(alert).toContainText("全角数字");

  await page.getByRole("button", { name: "BOM・引用符・空行", exact: true }).click();
  await expect(alert).toBeEmpty();
  await expect(status).toContainText("10.0000%");

  await page.getByRole("button", { name: "X Analytics 境界例", exact: true }).click();
  await expect(alert).toBeEmpty();
  await expect(status).toContainText("重複Post id除外 1 件");
  await expect(page.locator(".warning-list")).toContainText("non_ascii_digit");
  await expect(page.locator(".warning-list")).toContainText("negative_numeric");
  await expect(page.locator(".warning-list")).toContainText("duplicate_header");
  await page.screenshot({ path: info.outputPath("x-analytics-diagnostics.png"), fullPage: true });
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

  await page.goto("/labs/sns-csv-check/index.html");
  page.on("request", (req) => postLoadRequests.push(req.url()));

  await page.getByRole("button", { name: "12ケース一括セルフチェックを実行", exact: true }).click();
  await page.getByRole("button", { name: "X Analytics 境界例", exact: true }).click();

  expect(externalRequests).toEqual([]);
  expect(postLoadRequests).toEqual([]);
  expect(consoleErrors).toEqual([]);
  expect(pageErrors).toEqual([]);
  const noOverflow = await page.evaluate(
    () => document.documentElement.scrollWidth <= window.innerWidth,
  );
  expect(noOverflow).toBe(true);
});
