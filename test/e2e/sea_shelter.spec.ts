import { expect, test } from "@playwright/test";

const runtimeIssues = new WeakMap<object, string[]>();
test.beforeEach(async ({ page }) => {
  const issues: string[] = [];
  runtimeIssues.set(page, issues);
  page.on("pageerror", (error) => issues.push(error.message));
  page.on("console", (message) => {
    if (message.type() === "error") issues.push(message.text());
  });
  page.on("requestfailed", (request) => issues.push(request.url()));
  page.on("response", (response) => {
    if (response.status() >= 500) {
      issues.push(`${response.status()} ${response.url()}`);
    }
  });
  await page.route("**/favicon.ico", (route) => route.fulfill({ status: 204 }));
  await page.goto("/labs/sea-shelter/index.html");
});

test.afterEach(async ({ page }, info) => {
  const issues = runtimeIssues.get(page) ?? [];
  await info.attach("runtime-issues", {
    body: JSON.stringify(issues),
    contentType: "application/json",
  });
  expect(issues).toEqual([]);
});

test(
  "complete the loop, reload, customize and reset without horizontal overflow",
  async ({ page }, info) => {
    test.setTimeout(60000);
    const collect = page.getByRole("button", { name: "漂流物を回収" });
    const cell = (row: number, col: number) =>
      page.getByRole("button", { name: new RegExp(`^${row}行${col}列`) });
    await page.locator('.tabs [data-view="build"]').click();
    await page.locator('[data-kind="deck"]').click();
    await cell(1, 1).click();
    await expect(page.getByRole("status").first()).toContainText("隣接");
    await cell(3, 4).click();
    await expect(page.getByRole("status").first()).toContainText("資材不足");
    await expect(page.locator("#wood")).toHaveText("0");
    for (let i = 0; i < 3; i++) await collect.click();
    await page.locator('.tabs [data-view="quests"]').click();
    await page.locator("#quest-supplies").click();
    await expect(page.locator("#quest-supplies")).toBeDisabled();
    await page.locator('.tabs [data-view="build"]').click();
    await page.getByRole("button", { name: "⌂ 住居" }).click();
    await cell(3, 4).click();
    await expect(cell(3, 4)).toHaveAttribute("class", "built");
    const afterBuild = await page.locator("#wood").textContent();
    await cell(3, 4).click();
    await expect(page.locator("#wood")).toHaveText(afterBuild!);
    await page.locator('.tabs [data-view="quests"]').click();
    await page.locator("#quest-shelter").click();
    for (let i = 0; i < 5; i++) await collect.click();
    await page.locator('.tabs [data-view="residents"]').click();
    await page.locator("#invite").click();
    await page.locator('.tabs [data-view="residents"]').click();
    await page.locator("#invite").click();
    await page.locator('.tabs [data-view="residents"]').click();
    await page.locator("#invite").click();
    await expect(page.locator("#residents")).toHaveText("3 / 3");
    await page.locator('.tabs [data-view="build"]').click();
    await page.getByRole("button", { name: "♧ 菜園" }).click();
    await cell(4, 3).click();
    await page.locator('.tabs [data-view="quests"]').click();
    await page.locator("#quest-community").click();
    await expect(page.locator("#guide")).toContainText("3件の依頼達成");
    await page.reload();
    await expect(page.locator("#residents")).toHaveText("3 / 3");
    await expect(page.locator("#quest-community")).toBeDisabled();
    await page.getByRole("button", { name: "プロフィール", exact: true })
      .click();
    await page.getByLabel("名前（16文字まで）").fill("<船長>");
    await page.getByLabel("アイコン").selectOption("貝");
    await page.getByLabel("枠", { exact: true }).selectOption("星");
    await page.getByLabel("吹き出し（40文字まで）").fill("この海で暮らそう");
    await page.getByLabel("称号", { exact: true }).selectOption("潮灯の守り手");
    await page.getByRole("button", { name: "保存", exact: true }).click();
    await expect(page.locator("#captain-name")).toHaveText("<船長>");
    await page.reload();
    await expect(page.locator("#captain-title")).toHaveText("潮灯の守り手");
    if (!(await page.locator("#help-dialog").isVisible())) {
      await page.locator("#help").click();
    }
    await page.getByRole("button", { name: "最初からやり直す" }).click();
    await page.getByRole("button", { name: "キャンセル", exact: true }).click();
    await page.locator("#close-help").click();
    await page.locator('.tabs [data-view="board"]').click();
    expect(
      await page.locator("html").evaluate((e) =>
        e.scrollWidth <= e.clientWidth
      ),
    ).toBe(true);
    await page.evaluate(async () => {
      await Promise.all(
        document.getAnimations({ subtree: true }).filter((a) =>
          a.effect?.getTiming().iterations !== Infinity
        ).map((a) => a.finished.catch(() => {})),
      );
    });
    for (let frame = 0; frame < 3; frame++) {
      await page.screenshot({
        path: info.outputPath(`motion-${frame}.png`),
        fullPage: true,
      });
      await page.waitForTimeout(250);
    }
    await page.screenshot({
      path: info.outputPath("sea-shelter-complete.png"),
      fullPage: true,
    });
    if (!(await page.locator("#help-dialog").isVisible())) {
      await page.locator("#help").click();
    }
    await page.getByRole("button", { name: "最初からやり直す" }).click();
    await page.getByRole("button", { name: "やり直す", exact: true }).click();
    await page.reload();
    await expect(page.locator("#wood")).toHaveText("0");
    await expect(page.locator("#residents")).toHaveText("1 / 1");
  },
);

test("storage denial remains playable and corruption is explained", async ({ page }) => {
  await page.locator("#edit-profile").click();
  await page.locator('input[name="name"]').fill(" ");
  await page.locator('#profile-form button[type="submit"]').click();
  await expect(page.locator("#profile-error")).toContainText("名前");
  await expect(page.locator("#profile-dialog")).toBeVisible();
  await page.locator("#cancel-profile").click();
  await page.evaluate(() =>
    localStorage.setItem("my_web_app.sea_shelter.v1", "{bad")
  );
  await page.reload();
  await expect(page.locator("#save-status")).toContainText(
    "保存を読み込めません",
  );
  await page.evaluate(() => {
    Storage.prototype.setItem = () => {
      throw new DOMException("denied", "SecurityError");
    };
  });
  await page.locator("#collect").click();
  await expect(page.locator("#wood")).toHaveText("3");
  await expect(page.locator("#save-status")).toContainText("保存できません");
  await page.locator("#collect").click();
  await expect(page.locator("#wood")).toHaveText("6");
});

test("320px width and keyboard controls remain usable", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 720 });
  await page.locator("#collect").focus();
  await page.keyboard.press("Enter");
  await expect(page.locator("#wood")).toHaveText("3");
  expect(
    await page.locator("html").evaluate((e) => e.scrollWidth <= e.clientWidth),
  ).toBe(true);
  const target = await page.locator("#board button").first().boundingBox();
  expect(target!.width).toBeGreaterThanOrEqual(44);
  expect(target!.height).toBeGreaterThanOrEqual(44);
});
