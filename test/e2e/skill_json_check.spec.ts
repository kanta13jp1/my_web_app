import { expect, test } from "@playwright/test";

test("normal fenced csv evaluation and 20-trial self-check", async ({ page }, info) => {
  await page.goto("/labs/skill-json-check/index.html");
  const status = page.getByRole("status").first();
  await expect(status).toContainText("自動修正 (remediated)");
  await expect(status).toContainText("修正前 trim 判定: 誤ブロック対象 (delimiter)");
  await expect(page.getByRole("alert")).toBeEmpty();

  await page.getByRole("button", { name: "保存済み20応答を一括検証する", exact: true }).click();
  const selfcheckStatus = page.getByRole("status").nth(1);
  await expect(selfcheckStatus).toContainText("A（ラベルなし）: 素JSON 7/10");
  await expect(selfcheckStatus).toContainText("B（ラベルあり）: 素JSON 9/10");
  await expect(selfcheckStatus).toContainText("修正後ブロック 0/10");
  await expect(page.locator("#selfcheck-body tr")).toHaveCount(20);
  await page.screenshot({ path: info.outputPath("normal-20trials.png"), fullPage: true });
});

test("error detection and recovery to valid deploy JSON", async ({ page }, info) => {
  await page.goto("/labs/skill-json-check/index.html");
  const alert = page.getByRole("alert");
  const status = page.getByRole("status").first();

  await page.getByRole("button", { name: "異常例: サンプル値コピー＋必須キー欠落", exact: true }).click();
  await expect(alert).toContainText("サンプル値と同一の値");
  await expect(alert).toContainText("必須JSONフィールド「health_path」が欠落");
  await page.screenshot({ path: info.outputPath("error-copied-missing.png"), fullPage: true });

  await page.getByRole("button", { name: "異常例: 指定外キー混入＋壊れたJSON", exact: true }).click();
  await expect(alert).toContainText("JSON構文のパースに失敗");

  await page.getByRole("button", { name: "正常例: deploy JSON（フェンスなし）", exact: true }).click();
  await expect(alert).toBeEmpty();
  await expect(status).toContainText("通過 (passed)");
  await expect(status).toContainText("素の JSON 解釈: 合格");
  await page.screenshot({ path: info.outputPath("recovered-deploy.png"), fullPage: true });
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

  await page.goto("/labs/skill-json-check/index.html");
  page.on("request", (req) => postLoadRequests.push(req.url()));

  await page.getByRole("button", { name: "保存済み20応答を一括検証する", exact: true }).click();
  await page.getByRole("button", { name: "実例: csv フェンス付き＋タブ区切り", exact: true }).click();
  await expect(page.getByRole("status").first()).toContainText("自動修正 (remediated)");

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
