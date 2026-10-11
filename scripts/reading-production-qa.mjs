import { chromium, expect } from '@playwright/test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';

const base = 'https://my-web-app-b67f4.web.app';
const url = process.env.SUPABASE_URL_PROD;
const key = process.env.SUPABASE_PUBLISHABLE_KEY_PROD || process.env.SUPABASE_ANON_KEY_PROD;
const admin = process.env.SUPABASE_SERVICE_ROLE_KEY;
assert(url && key && admin, 'Required production configuration unavailable');
const users = [];
let browser;
await mkdir('reading-production-evidence', {recursive:true});
async function req(path, token, data, method = 'POST') {
  const res = await fetch(url + path, {method, headers:{apikey:key, Authorization:`Bearer ${token}`, 'Content-Type':'application/json'}, ...(data === undefined ? {} : {body:JSON.stringify(data)})});
  const body = await res.json().catch(()=>({}));
  return {status:res.status,body};
}
async function user() {
  const email = `reading-qa-${randomUUID()}@example.invalid`;
  const password = randomUUID() + '!aA1';
  const created = await req('/auth/v1/admin/users', admin, {email,password,email_confirm:true,user_metadata:{purpose:'PR5730 production verification'}});
  assert.equal(created.status,200,'Test user creation failed');
  users.push(created.body.id);
  const signed = await req('/auth/v1/token?grant_type=password', key, {email,password});
  assert.equal(signed.status,200,'Test sign-in failed');
  console.log(`::add-mask::${password}`);
  console.log(`::add-mask::${signed.body.access_token}`);
  console.log(`::add-mask::${signed.body.refresh_token}`);
  return {email,password,token:signed.body.access_token};
}
async function action(token, body, status = 200) {
  const result = await req('/functions/v1/tools-hub',token,body);
  assert.equal(result.status,status,`Reading API ${body.action} returned unexpected status`);
  if(status === 200) assert.equal(result.body.success,true);
  return result.body;
}
async function semantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder').first();
  await placeholder.waitFor({state:'attached',timeout:15000}).catch(()=>{});
  if(await placeholder.count()) await placeholder.evaluate(e=>e.click());
}
async function field(page,name,value) {
  const input=page.getByRole('textbox',{name});
  await input.focus();
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await input.fill(value);
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await expect(input).toHaveValue(value);
}
async function openWork(page) {
  await page.getByRole('tab',{name:'著作',exact:true}).click();
  await expect(page.getByRole('button',{name:'著作を追加',exact:true})).toBeVisible();
  await field(page,/^著者・著作を検索/,'国家');
  await page.getByRole('button',{name:/^国家 /}).click();
}
try {
  const version = await (await fetch(`${base}/version.json?qa=${Date.now()}`)).json();
  assert.equal(version.commit,process.env.EXPECTED_PRODUCTION_SHA,'Published version differs from merged commit');
  const a=await user(),b=await user();
  // Use genuine Auth tokens and the published Edge Function, never fixture responses.
  const work={id:'qa:'+randomUUID(),title:'Production reading verification',author_info:{id:'qa-author',name:'QA',aliases:[],centuries:['21'],regions:['QA'],traditions:[],source:'',note:''},original_title:'',centuries:['21'],genres:['QA'],source:'',note:''};
  const id=randomUUID();
  await action(a.token,{action:'reading.add',id,work});
  const date=new Date().toISOString().slice(0,10);
  const cycles=[{id:'qa-cycle',started_at:date,finished_at:null,status:'reading',edition:{total_pages:100},entries:[{id:'qa-entry',date,pages:10,start_page:1,end_page:10,understanding:3,impression:'Publication verification',questions:'',concepts:''}]}];
  await action(a.token,{action:'reading.save',id,revision:0,work,cycles});
  const loaded=await action(a.token,{action:'reading.list'});
  assert.equal(loaded.items.find(x=>x.id===id).metadata.cycles[0].entries[0].understanding,3);
  const other=await action(b.token,{action:'reading.list'});
  assert(!other.items.some(x=>x.id===id),'Cross-user read leak');
  await action(a.token,{action:'reading.save',id,revision:0,work,cycles},409);
  cycles[0].entries[0].impression='Edited publication verification';
  const edited=await action(a.token,{action:'reading.save',id,revision:1,work,cycles});
  assert.equal(edited.item.metadata.cycles[0].entries[0].history.length,1);
  await action(key,{action:'reading.list'},401);
  console.log('Production API: save, reload, understanding/impression, edit history, stale revision, ownership and guest rejection passed.');
  browser=await chromium.launch();
  for(const [name,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]) {
    const context=await browser.newContext({viewport});
    const page=await context.newPage();
    page.setDefaultTimeout(45000);
    await page.goto(base+'/reading-list');await semantics(page);
    await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
    await expect(page.getByRole('tab',{name:'著者',exact:true})).toBeVisible();
    await page.screenshot({path:`reading-production-evidence/${name}-catalog.png`});
    await openWork(page);
    await expect(page.getByRole('button',{name:'読書を始める',exact:true})).toBeDisabled();
    await page.screenshot({path:`reading-production-evidence/${name}-guest-work.png`});
    await context.close();
  }
  const context=await browser.newContext({viewport:{width:1440,height:1000}});
  const page=await context.newPage();page.setDefaultTimeout(45000);
  await page.goto(base+'/login');await semantics(page);
  await page.getByRole('button',{name:'ログイン',exact:true}).last().click();
  await field(page,/メールアドレス/,a.email);
  await page.getByRole('button',{name:'パスワードを使う',exact:true}).click();
  await field(page,/^パスワード/,a.password);
  await page.getByRole('button',{name:'メールでログイン',exact:true}).click();
  await expect(page.getByRole('button',{name:'メールでログイン',exact:true})).toHaveCount(0,{timeout:60000});
  await page.goto(base+'/reading-list');await semantics(page);
  await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
  await openWork(page);
  await page.getByRole('button',{name:'読書を始める',exact:true}).click();
  await field(page,/^総ページ数/,'100');
  await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
  await page.getByRole('button',{name:'記録を追加',exact:true}).click();
  await field(page,/^開始ページ/,'1');await field(page,/^終了ページ/,'10');
  await field(page,/^感想/,'公開後の読書記録確認');
  await page.getByRole('button',{name:/未評価/}).click();
  await page.getByRole('menuitem',{name:'3 要点を理解した',exact:true}).click();
  await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByRole('group',{name:/感想: 公開後の読書記録確認/}).last()).toBeVisible();
  await page.getByRole('button',{name:'読了にする',exact:true}).click();
  await page.screenshot({path:'reading-production-evidence/saved-record.png'});
  await page.reload();await semantics(page);await openWork(page);
  await expect(page.getByRole('group',{name:/感想: 公開後の読書記録確認/}).last()).toBeVisible();
  await page.getByRole('button',{name:/Back|戻る/}).click();
  await page.getByRole('tab',{name:'進捗',exact:true}).click();
  await expect(page.getByRole('tabpanel')).toHaveCount(1);
  await expect(page.getByRole('tabpanel')).toMatchAriaSnapshot(`
- tabpanel:
  - group:
    - text: /.*収録済み著作全体.*読了 1 . 17 著作.*/
`);
  await page.screenshot({path:'reading-production-evidence/progress.png'});
  await writeFile('reading-production-evidence/result.json',JSON.stringify({commit:version.commit,api:'passed',desktop:'passed',mobile:'passed',authenticatedSaveReloadProgress:'passed'},null,2));
  console.log('Published browser: desktop/mobile catalog and guest protection, genuine user login, pages/understanding/impression save, reload and completion progress passed.');
} finally {
  if(browser) await browser.close();
  for(const id of users) {
    // Only exact IDs created in this run; never clear other users' data.
    const rows=await fetch(url+`/rest/v1/hub_data?metadata->>user_id=eq.${id}&source=in.(reading,reading_author)`,{method:'DELETE',headers:{apikey:admin,Authorization:`Bearer ${admin}`}});
    assert.equal(rows.status,204,'Test reading cleanup failed');
    const deleted=await req('/auth/v1/admin/users/'+id,admin,undefined,'DELETE');
    assert.equal(deleted.status,200,'Test account cleanup failed');
  }
  console.log(`Cleaned up ${users.length} dedicated test accounts and their reading records.`);
}
