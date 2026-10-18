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
test('touch drag creates a playable course without scrolling',async({page,context},info)=>{
  test.skip(info.project.name!=='mobile-chrome','Touch-capable mobile project');
  const board=page.locator('#board');await board.scrollIntoViewIfNeeded();
  const box=await board.boundingBox();if(!box)throw new Error('No board');
  const scroll=await page.evaluate(()=>scrollY);
  const session=await context.newCDPSession(page);
  const point=(x:number,y:number)=>({x:box.x+x/900*box.width,y:box.y+y/540*box.height});
  await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point(80,180)]});
  for(let i=1;i<=12;i++)await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[point(80+680*i/12,180+260*i/12)]});
  await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await session.detach();
  await expect(page.locator('#line-count')).toContainText('1 /');
  expect(await page.evaluate(()=>scrollY)).toBe(scroll);
  await page.locator('#play').click();
  await expect(page.locator('#phase')).toHaveText('ARRIVED',{timeout:20000});
});
test('hidden document pauses and resumes only by explicit action',async({page})=>{
  await page.locator('#sample').click();await page.locator('#play').click();
  await page.waitForTimeout(200);
  // Controlled lifecycle input: not evidence of an OS-level background tab.
  await page.evaluate(()=>{
    Object.defineProperty(document,'hidden',{configurable:true,value:true});
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.locator('#phase')).toHaveText('PAUSED');
  const clock=await page.locator('#clock').innerText();await page.waitForTimeout(250);
  await expect(page.locator('#clock')).toHaveText(clock);
  await page.evaluate(()=>{
    Object.defineProperty(document,'hidden',{configurable:true,value:false});
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.locator('#phase')).toHaveText('PAUSED');
  await page.locator('#play').click();
  await expect(page.locator('#phase')).toHaveText('ARRIVED',{timeout:20000});
});
test('coordinate input supports keyboard course and validation',async({page})=>{
  await page.locator('summary').focus();await page.keyboard.press('Enter');
  await page.locator('#x1').fill('-1');await page.locator('#add-line').focus();await page.keyboard.press('Enter');
  await expect(page.locator('#status')).toContainText('0〜900');
  await expect(page.locator('#line-count')).toContainText('0 /');
  await page.locator('#x1').fill('80');await page.locator('#add-line').focus();await page.keyboard.press('Enter');
  await expect(page.locator('#line-count')).toContainText('1 /');
  await page.locator('#play').focus();await page.keyboard.press('Enter');
  await expect(page.locator('#phase')).toHaveText('ARRIVED',{timeout:20000});
});
