import {test, expect} from '@playwright/test';

test('published Laya article source, measurement conditions and six results render', async ({page}, info) => {
  const response = await page.goto('https://zenn.dev/kanta13jp1/articles/laya-mlx-on-device-system-one-benchmark', {waitUntil: 'domcontentloaded'});
  expect(response?.status()).toBe(200);
  await expect(page.getByRole('heading', {level: 1})).toContainText('CPU実測とアプリで確認する応答時間');
  await expect(page.getByRole('heading', {name: 'Core MLの「約64%減」は何を測った値か', exact: true})).toBeVisible();
  await expect(page.getByRole('link', {name: '雨夹雪❄️（@mizorewww）', exact: true})).toHaveAttribute('href', 'https://x.com/mizorewww');
  await expect(page.getByText('64.1%', {exact: false}).first()).toBeVisible();
  await expect(page.getByText('49.9%', {exact: false}).first()).toBeVisible();
  await expect(page.getByText('17.75ms', {exact: false}).first()).toBeVisible();
  const results = page.locator('table').filter({hasText: 'SDK時間の範囲'});
  await expect(results.locator('tbody tr')).toHaveCount(6);
  await expect(results).toContainText('29.58%');
  await expect(results).toContainText('385.9〜395.9ms');
  expect(await page.locator('a[href="https://my-web-app-b67f4.web.app/asset-management"]').count()).toBeGreaterThanOrEqual(2);
  expect(await page.locator('strong').filter({hasText: 'Laya'}).count()).toBeGreaterThan(0);
  const embeds = await page.locator('iframe').evaluateAll(nodes => nodes.map(n => ({src:n.getAttribute('src'),title:n.getAttribute('title')})));
  await info.attach('embed-elements', {body:JSON.stringify(embeds,null,2),contentType:'application/json'});
  expect(JSON.stringify(embeds)).toContain('2101473552956555427');
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({path:info.outputPath('laya-zenn-full.png'),fullPage:true});
  await page.getByRole('heading', {name:'Core MLの「約64%減」は何を測った値か',exact:true}).scrollIntoViewIfNeeded();
  await page.screenshot({path:info.outputPath('laya-coreml-conditions.png')});
  await results.scrollIntoViewIfNeeded();
  await page.screenshot({path:info.outputPath('laya-six-results.png')});
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
