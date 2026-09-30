import {test,expect} from '@playwright/test';
test.beforeEach(async({page})=>{await page.goto('/labs/kinetic-forge/');});
test('sample, pause, resume and reset',async({page},info)=>{
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await page.locator('#sample').click();await expect(page.locator('#line-count')).toContainText('1 /');
  await page.locator('#play').click();await page.waitForTimeout(250);await page.locator('#play').click();
  await expect(page.locator('#phase')).toHaveText('PAUSED');const clock=await page.locator('#clock').innerText();
  await page.waitForTimeout(200);await expect(page.locator('#clock')).toHaveText(clock);
  await page.locator('#play').click();await expect(page.locator('#phase')).toHaveText('ARRIVED',{timeout:20000});
  await page.screenshot({path:info.outputPath('arrived.png'),fullPage:true});
  await page.locator('#retry').click();await expect(page.locator('#clock')).toHaveText('0.00 s');
  expect(errors).toEqual([]);
});
test('empty course fails and retry restores editing',async({page})=>{
  await page.locator('#play').click();await expect(page.locator('#phase')).toHaveText('TRY AGAIN',{timeout:10000});
  await page.locator('#retry').click();await expect(page.locator('#sample')).toBeEnabled();
  await page.locator('#sample').click();await page.locator('#undo').click();await expect(page.locator('#line-count')).toContainText('0 /');
});
test('pointer course, level switch and mobile fit',async({page},info)=>{
  const box=await page.locator('#board').boundingBox();if(!box)throw new Error('No board');
  await page.mouse.move(box.x+box.width*.1,box.y+box.height*.3);await page.mouse.down();
  await page.mouse.move(box.x+box.width*.7,box.y+box.height*.7,{steps:8});await page.mouse.up();
  await expect(page.locator('#line-count')).toContainText('1 /');
  await page.locator('#level').selectOption('2');await expect(page.locator('#line-count')).toContainText('0 /');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:info.outputPath('design.png'),fullPage:true});
  await page.reload();await expect(page.locator('#title')).toHaveText('一筆の坂');
});
test('every sample level reaches its own goal',async({page})=>{
  for(const level of ['0','1','2']){
    await page.locator('#level').selectOption(level);
    await page.locator('#sample').click();
    await page.locator('#play').click();
    await expect(page.locator('#phase')).toHaveText('ARRIVED',{timeout:20000});
    await page.locator('#retry').click();
    await expect(page.locator('#clock')).toHaveText('0.00 s');
    await expect(page.locator('#sample')).toBeEnabled();
  }
});
