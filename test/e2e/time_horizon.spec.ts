import { test, expect } from '@playwright/test';
test.beforeEach(async({page})=>{await page.goto('/labs/time-horizon/index.html');});
test('thresholds and provenance',async({page},info)=>{
  for(const [p,t] of [['50','120.00'],['80','60.00'],['90','40.00']]){
    await page.getByRole('button',{name:`${p}%で試す`,exact:true}).click();
    await expect(page.getByRole('status')).toContainText(`${t} 分`);
  }
  await expect(page.getByText('METRは、現行の課題群では16時間超の測定は信頼性が低いと注意しています。',{exact:true})).toBeVisible();
  await page.screenshot({path:info.outputPath('thresholds.png'),fullPage:true});
});
test('invalid input and recovery',async({page},info)=>{
  const input=page.getByLabel('必要な成功率（%）');
  for(const bad of ['0','100','-1','']){await input.fill(bad);await page.getByRole('button',{name:'計算する',exact:true}).click();await expect(page.getByRole('alert')).not.toBeEmpty();await expect(page.getByRole('status')).toHaveText('計算結果はありません。');}
  await input.fill('80');await page.getByRole('button',{name:'計算する',exact:true}).click();await expect(page.getByRole('status')).toContainText('60.00 分');await expect(page.getByRole('alert')).toBeEmpty();
  await input.fill('90');await expect(page.getByRole('status')).toHaveText('入力を変更しました。計算してください。');
  await page.screenshot({path:info.outputPath('recovery.png'),fullPage:true});
});
test('interaction submits no requests',async({page})=>{
  const requests:string[]=[]; page.on('request',r=>requests.push(r.url()));
  await page.getByRole('button',{name:'80%で試す',exact:true}).click();
  await expect(page.getByRole('status')).toContainText('60.00 分');
  expect(requests).toEqual([]);
  expect(await page.evaluate(()=>({local:localStorage.length,session:sessionStorage.length}))).toEqual({local:0,session:0});
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
});
