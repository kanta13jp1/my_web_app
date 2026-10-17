import {test,expect} from '@playwright/test';
test('archived measurements compare and export without sending input',async({page},info)=>{
  const errors:string[]=[]; const sends:string[]=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('request',r=>{if(['xhr','fetch'].includes(r.resourceType()))sends.push(r.url());});
  await page.goto('/labs/ai-usage-compare/index.html');
  await page.getByRole('button',{name:'記事の18試行を読み込む'}).click();
  await page.getByRole('button',{name:'入力を確認する'}).click();
  await page.getByRole('button',{name:'比較する',exact:true}).click();
  await expect(page.locator('#summary')).toContainText('172,169.5');
  await expect(page.locator('#summary')).toContainText('236,966.66667');
  const download=page.waitForEvent('download');
  await page.getByRole('button',{name:'比較結果をJSONで保存'}).click();
  const d=await download; const stream=await d.createReadStream(); let body='';
  for await(const chunk of stream!)body+=chunk.toString();
  const report=JSON.parse(body);expect(report.rows).toHaveLength(18);expect(report.causalEffect).toBeNull();
  expect(report.summary[0].meanInput).toBe(172169.5);
  await page.evaluate(()=>document.fonts.ready); await page.waitForTimeout(500);
  await page.screenshot({path:info.outputPath('comparison.png'),fullPage:true});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
  expect(sends).toEqual([]); expect(errors).toEqual([]);
});
test('editing clears results and invalid input recovers',async({page})=>{
  await page.goto('/labs/ai-usage-compare/index.html');
  await page.locator('#sample').click();await page.locator('#read').click();await page.locator('#calculate').click();
  const data=JSON.parse(await page.locator('#data').inputValue());data[0].input=-1;
  await page.locator('#data').fill(JSON.stringify(data));await expect(page.locator('#results')).toBeHidden();
  await page.locator('#read').click();await expect(page.getByRole('alert')).toContainText('整数');
  await page.locator('#sample').click();await page.locator('#read').click();await page.locator('#calculate').click();
  await expect(page.locator('#results')).toBeVisible();
  await page.reload();await expect(page.locator('#data')).toHaveValue('');
});
test('zero base and hostile labels are rendered as text',async({page})=>{
  await page.goto('/labs/ai-usage-compare/index.html');
  const row={id:'x',condition:'<img src=x onerror=alert(1)>',model:'example',input:0,cacheWrite:0,cacheRead:0,output:0,turns:1,modelUSD:0,runUSD:0};
  await page.locator('#data').fill(JSON.stringify([row]));await page.locator('#read').click();await page.locator('#calculate').click();
  await expect(page.locator('#summary')).toContainText('基準0のため保留');
  await expect(page.locator('#summary img')).toHaveCount(0);
});
