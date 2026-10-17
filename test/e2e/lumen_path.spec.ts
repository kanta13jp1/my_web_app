import {test,expect} from '@playwright/test';
const failures = new WeakMap<object, string[]>();
test.beforeEach(async({page})=>{
  const errors:string[]=[];failures.set(page,errors);
  page.on('pageerror',error=>errors.push(error.message));
  page.on('requestfailed',request=>errors.push(`request failed: ${request.url()}`));
  page.on('response',response=>{if(response.status()>=400)errors.push(`HTTP ${response.status()}: ${response.url()}`);});
  await page.goto('/labs/lumen-path/');
});
test.afterEach(async({page})=>{expect(failures.get(page)).toEqual([]);});
test('rotate, solve, undo and reset',async({page},info)=>{
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await expect(page.locator('#next')).toBeDisabled();
  await page.getByRole('button',{name:/鏡 1/}).click();
  await expect(page.locator('#lit')).toHaveText('1 / 1 LIGHTS');
  await expect(page.locator('#next')).toBeEnabled();
  await page.getByRole('button',{name:'一手戻す'}).click();
  await expect(page.locator('#next')).toBeDisabled();
  await page.getByRole('button',{name:/鏡 1/}).click();
  await page.getByRole('button',{name:'最初から'}).click();
  await expect(page.locator('#moves')).toHaveText('0');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:info.outputPath('initial.png'),fullPage:true});expect(errors).toEqual([]);
});
test('hints guide but never change the board themselves',async({page})=>{
  await page.locator('#level').selectOption('1');
  for(let i=0;i<3;i++){
    const before=await page.locator('#moves').innerText();
    await page.getByRole('button',{name:'ヒント',exact:true}).click();
    await expect(page.locator('#moves')).toHaveText(before);
    await page.locator('button.hinted').click();
  }
  await expect(page.locator('#lit')).toHaveText('1 / 1 LIGHTS');
  await page.getByRole('button',{name:'次の部屋へ'}).click();
  await expect(page.locator('#title')).toHaveText('三つの灯台');
});
test('three colors solve and reload returns a clean initial state',async({page},info)=>{
  await page.locator('#level').selectOption('2');
  for(let i=1;i<=3;i++)await page.getByRole('button',{name:new RegExp(`鏡 ${i}、`)}).click();
  await expect(page.locator('#lit')).toHaveText('3 / 3 LIGHTS');
  await expect(page.locator('#status')).toContainText('3色すべて点灯');
  const bounds=await page.locator('#board').boundingBox();
  expect(bounds).not.toBeNull();
  for(const source of await page.locator('.piece.source').all()){
    const glyph=await source.boundingBox();expect(glyph).not.toBeNull();
    expect(glyph!.x).toBeGreaterThanOrEqual(bounds!.x);
    expect(glyph!.x+glyph!.width).toBeLessThanOrEqual(bounds!.x+bounds!.width);
  }
  if(!info.project.name.includes('mobile')){
    const stage=await page.locator('.stage').boundingBox();
    expect(stage!.y+stage!.height).toBeLessThanOrEqual(page.viewportSize()!.height);
  }
  await page.screenshot({path:info.outputPath('solved.png'),fullPage:true});
  await page.reload();await expect(page.locator('#moves')).toHaveText('0');
  await expect(page.locator('#title')).toHaveText('最初の反射');
});
