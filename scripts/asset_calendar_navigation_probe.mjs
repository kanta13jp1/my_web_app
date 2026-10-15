import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
const dir='.ci-logs/calendar-native-navigation';
await mkdir(dir,{recursive:true});
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1440,height:1000}});
const evidence=[];
page.on('pageerror',err=>evidence.push({pageError:String(err)}));
async function prepare(name){
  const response=await page.goto('http://127.0.0.1:4173/');
  if(!response?.ok())throw new Error(`Fixture HTTP status: ${response?.status()}`);
  const next=page.getByRole('button',{name:'次のサイクル',exact:true});
  await next.waitFor({state:'attached',timeout:60000});
  await page.locator('#seo-shell').waitFor({state:'hidden',timeout:30000});
  let rect;
  for(let step=0;step<35;step++){
    rect=await next.boundingBox();
    if(rect && rect.y>=55 && rect.y+rect.height<=995)break;
    await page.mouse.move(900,700);
    await page.mouse.wheel(0,650);
    await page.waitForTimeout(100);
  }
  const share=page.getByRole('button',{name:'今月の返済報告カードを作る（実額を公開）',exact:true});
  const shareRect=await share.boundingBox();
  evidence.push({stage:name,next:rect,share:shareRect});
  await page.screenshot({path:`${dir}/${name}-before.png`});
  if(!rect || rect.y<55 || rect.y+rect.height>995)throw new Error('Next cycle was not visibly placed in viewport');
  return {next,rect};
}
async function verify(name){
  await page.getByText('2026/6/25〜7/24',{exact:true}).waitFor({state:'visible',timeout:5000});
  const dialog=page.getByRole('dialog');
  if(await dialog.count())throw new Error('Unexpected dialog after next cycle');
  await page.screenshot({path:`${dir}/${name}-after.png`});
  evidence.push({stage:name,result:'next cycle changed; no dialog'});
}
try{
  const pointer=await prepare('pointer');
  await page.mouse.click(pointer.rect.x+pointer.rect.width/2,pointer.rect.y+pointer.rect.height/2);
  await verify('pointer');
  await prepare('keyboard');
  let focused=false;
  for(let step=0;step<300;step++){
    await page.keyboard.press('Tab');
    const current=await page.evaluate(()=>({label:document.activeElement?.getAttribute('aria-label'),text:document.activeElement?.textContent}));
    if(current.label==='次のサイクル' || current.text?.trim()==='次のサイクル'){focused=true;break;}
  }
  if(!focused)throw new Error('Keyboard next-cycle focus was not established');
  await page.keyboard.press('Enter');
  await verify('keyboard');
}finally{
  await page.screenshot({path:`${dir}/last-state.png`});
  await writeFile(`${dir}/evidence.json`,JSON.stringify(evidence,null,2));
  await browser.close();
}
