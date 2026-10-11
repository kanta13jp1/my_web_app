import { chromium, expect as baseExpect } from '@playwright/test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';

const expect = baseExpect.configure({timeout:45000});
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
  const created = await req('/auth/v1/admin/users', admin, {email,password,email_confirm:true,user_metadata:{purpose:'PR5744 production verification'}});
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
  const input=name.source.startsWith('^パスワード') ? page.locator('input[type="password"]') : name.source==='メールアドレス' ? page.getByRole('textbox',{name:'メールアドレス',exact:true}).last() : page.getByRole('textbox',{name});
  await expect(input).toHaveCount(1);
  await input.focus();
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await input.fill(value);
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await expect(input).toHaveValue(value);
}
async function capture(page,name) {
  await page.evaluate(async()=>{await document.fonts.ready;await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));});
  await page.waitForTimeout(350);
  for(let i=0;i<3;i++) {
    await page.screenshot({path:`reading-production-evidence/${name}-${i}.png`});
    await page.waitForTimeout(200);
  }
}
async function openWork(page,title = '国家') {
  await page.getByRole('tab',{name:'著作',exact:true}).click();
  await expect(page.getByRole('button',{name:/^プラトン /})).toHaveCount(0);
  await expect(page.getByRole('tabpanel')).toHaveCount(1);
  await expect(page.getByRole('textbox',{name:/^著者・著作を検索/})).toHaveCount(1);
  await expect(page.getByRole('textbox',{name:/^著者・著作を検索/})).toBeVisible();
  await field(page,/^著者・著作を検索/,title);
  await page.getByRole('button',{name:new RegExp(`^${title} `)}).click();
}
async function restoredField(page,name,value) {
  const input=page.getByRole('textbox',{name});
  await input.focus();
  await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await expect(input).toHaveValue(value);
}
const bookLinks=[];
async function isbnLink(page) {
  const popupPromise=page.waitForEvent('popup');
  await page.getByRole('button',{name:'Amazonで書籍を検索（ISBN）',exact:true}).click();
  const popup=await popupPromise;
  await popup.waitForURL(/^https:\/\/www\.amazon\.co\.jp\/s\//);
  const destination=new URL(popup.url());
  assert.equal(destination.searchParams.get('k'),'9784480080226','Published ISBN link differs from curated edition');
  bookLinks.push(destination.toString());
  await popup.close();
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
  const cycles=[{id:'qa-cycle',started_at:date,finished_at:null,status:'reading',edition:{total_pages:100,publisher:'QA publisher',translator:'QA translator',editor:'QA editor',book_url:'https://www.chikumashobo.co.jp/product/9784480080226/',source_url:'https://ndlsearch.ndl.go.jp/search?keyword=9784480080226'},entries:[{id:'qa-entry',date,pages:10,start_page:1,end_page:10,understanding:3,impression:'Publication verification',questions:'',concepts:''}]}];
  await action(a.token,{action:'reading.save',id,revision:0,work,cycles});
  const loaded=await action(a.token,{action:'reading.list'});
  assert.equal(loaded.items.find(x=>x.id===id).metadata.cycles[0].entries[0].understanding,3);
  assert.deepEqual(loaded.items.find(x=>x.id===id).metadata.cycles[0].edition,{...cycles[0].edition,volume:'',year:'',language:'',isbn:''});
  const other=await action(b.token,{action:'reading.list'});
  assert(!other.items.some(x=>x.id===id),'Cross-user read leak');
  await action(a.token,{action:'reading.save',id,revision:0,work,cycles},409);
  cycles[0].entries[0].impression='Edited publication verification';
  cycles[0].edition.editor='QA edited editor';
  const edited=await action(a.token,{action:'reading.save',id,revision:1,work,cycles});
  assert.equal(edited.item.metadata.cycles[0].entries[0].history.length,1);
  assert.equal(edited.item.metadata.cycles[0].edition.editor,'QA edited editor');
  await action(key,{action:'reading.list'},401);
  console.log('Production API: save, reload, understanding/impression, edit history, stale revision, ownership and guest rejection passed.');
  const apiCleanup=await fetch(url+`/rest/v1/hub_data?id=eq.${id}&source=eq.reading&metadata->>user_id=eq.${users[0]}`,{method:'DELETE',headers:{apikey:admin,Authorization:`Bearer ${admin}`}});
  assert.equal(apiCleanup.status,204,'API verification record cleanup failed');
  browser=await chromium.launch();
  for(const [name,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]) {
    const context=await browser.newContext({viewport});
    const page=await context.newPage();
    page.setDefaultTimeout(45000);
    await page.goto(base+'/reading-list');await semantics(page);
    await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
    await expect(page.getByRole('tab',{name:'著者',exact:true})).toBeVisible();
    await expect(page.getByText(/共有目録 56 著者・80 著作/)).toBeVisible();
    await capture(page,`${name}-catalog`);
    await openWork(page);
    await expect(page.getByRole('button',{name:'読書を始める',exact:true})).toBeDisabled();
    await capture(page,`${name}-guest-work`);
    await page.goto(base+'/reading-list');await semantics(page);
    await openWork(page,'正法眼蔵随聞記');
    await page.getByRole('button',{name:/版・入手先/}).click();
    await expect(page.getByRole('button',{name:'この版の書誌出典を開く',exact:true})).toBeVisible();
    await isbnLink(page);
    await expect(page.getByRole('button',{name:'この版で読書を始める',exact:true})).toBeDisabled();
    await capture(page,`${name}-book-links`);
    await context.close();
  }
  const context=await browser.newContext({viewport:{width:1440,height:1000}});
  const page=await context.newPage();page.setDefaultTimeout(45000);
  await page.goto(base+'/login');await semantics(page);
  await page.getByRole('button',{name:'ログイン',exact:true}).first().evaluate(e=>e.click());
  const auth=page.getByRole('group',{name:/ログインして続きから再開/});
  await expect(auth).toHaveCount(1);
  await expect(auth.getByRole('button',{name:'Magic Linkでログイン',exact:true})).toBeVisible();
  await field(auth,/メールアドレス/,a.email);
  await auth.getByRole('button',{name:'パスワードを使う',exact:true}).evaluate(e=>e.click());
  await expect(page.getByRole('button',{name:'メールでログイン',exact:true})).toBeVisible();
  await field(page,/^パスワード/,a.password);
  const signedIn=page.waitForResponse(r=>r.url().includes('/auth/v1/token') && r.request().method()==='POST');
  await page.getByRole('button',{name:'メールでログイン',exact:true}).evaluate(e=>e.click());
  assert.equal((await signedIn).status(),200,'Published UI sign-in failed');
  await page.waitForTimeout(1500);
  await page.goto(base+'/reading-list');await semantics(page);
  await expect(page.getByText('哲学書の読書管理',{exact:true})).toBeVisible();
  await openWork(page);
  await page.getByRole('button',{name:'読書を始める',exact:true}).click();
  await field(page,/^総ページ数/,'100');
  await field(page,/^出版社/,'公開確認出版社');
  await field(page,/^訳者/,'公開確認訳者');
  await field(page,/^編集者・編者/,'公開確認編集者');
  await field(page,/^書籍・購入URL/,'https://www.chikumashobo.co.jp/product/9784480080226/');
  await field(page,/^版情報の出典URL/,'https://ndlsearch.ndl.go.jp/search?keyword=9784480080226');
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
  await capture(page,'saved-record');
  await page.reload();await semantics(page);await openWork(page);
  await expect(page.getByRole('group',{name:/感想: 公開後の読書記録確認/}).last()).toBeVisible();
  await page.getByRole('button',{name:'版を編集',exact:true}).click();
  await restoredField(page,/^出版社/,'公開確認出版社');
  await restoredField(page,/^訳者/,'公開確認訳者');
  await restoredField(page,/^編集者・編者/,'公開確認編集者');
  await restoredField(page,/^書籍・購入URL/,'https://www.chikumashobo.co.jp/product/9784480080226/');
  await restoredField(page,/^版情報の出典URL/,'https://ndlsearch.ndl.go.jp/search?keyword=9784480080226');
  await field(page,/^出版社/,'公開確認・編集済出版社');
  await field(page,/^訳者/,'公開確認・編集済訳者');
  await field(page,/^編集者・編者/,'公開確認・編集済編者');
  await field(page,/^書籍・購入URL/,'https://www.kotensinyaku.jp/books/book221/');
  await field(page,/^版情報の出典URL/,'https://ndlsearch.ndl.go.jp/search?keyword=9784334753221');
  await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByRole('textbox',{name:/^出版社/})).toHaveCount(0);
  await page.reload();await semantics(page);await openWork(page);
  await page.getByRole('button',{name:'版を編集',exact:true}).click();
  await restoredField(page,/^出版社/,'公開確認・編集済出版社');
  await restoredField(page,/^訳者/,'公開確認・編集済訳者');
  await restoredField(page,/^編集者・編者/,'公開確認・編集済編者');
  await restoredField(page,/^書籍・購入URL/,'https://www.kotensinyaku.jp/books/book221/');
  await restoredField(page,/^版情報の出典URL/,'https://ndlsearch.ndl.go.jp/search?keyword=9784334753221');
  await capture(page,'edited-edition');
  await page.getByRole('button',{name:'保存',exact:true}).click();
  await page.getByRole('button',{name:/Back|戻る/}).click();
  await page.getByRole('tab',{name:'進捗',exact:true}).click();
  await expect(page.getByRole('button',{name:'著作を追加',exact:true})).toHaveCount(0);
  await expect(page.getByRole('tabpanel')).toHaveCount(1);
  let progressSnapshot='';
  const completedProgress=/収録済み著作全体[\s\S]*読了 1 . 80 著作/;
  for(let attempt=0;attempt<30;attempt++) {
    progressSnapshot=await page.getByRole('tabpanel').ariaSnapshot();
    if(completedProgress.test(progressSnapshot)) break;
    await page.waitForTimeout(200);
  }
  await writeFile('reading-production-evidence/progress-aria.txt',progressSnapshot);
  assert.match(progressSnapshot,completedProgress,'Published completion progress differs from saved work');
  await capture(page,'progress');
  await page.goto(base+'/reading-list');await semantics(page);
  await openWork(page,'正法眼蔵随聞記');
  await page.getByRole('button',{name:/版・入手先/}).click();
  await page.getByRole('button',{name:'この版で読書を始める',exact:true}).click();
  await restoredField(page,/^出版社/,'筑摩書房');
  await restoredField(page,/^訳者/,'水野弥穂子');
  await restoredField(page,/^編集者・編者/,'懐奘（記録・編纂）');
  await page.getByRole('button',{name:'保存',exact:true}).click();
  await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
  await page.reload();await semantics(page);await openWork(page,'正法眼蔵随聞記');
  await expect(page.getByRole('group',{name:/編集者・編者: 懐奘/}).last()).toBeVisible();
  const records=await action(a.token,{action:'reading.list'});
  const dogen=records.items.find(x=>x.metadata.work?.id==='dogen:zuimonki');
  assert(dogen,'Curated edition was not persisted through the published API');
  assert.equal(dogen.metadata.cycles[0].edition.publisher,'筑摩書房');
  assert.equal(dogen.metadata.cycles[0].edition.editor,'懐奘（記録・編纂）');
  await capture(page,'curated-edition');

  const japaneseBooks = [
    {label:'エティカ・中央公論新社（中公クラシックス ; W48）',publisher:'中央公論新社',translator:'工藤喜作・斎藤博',editor:'',isbn:'9784121600943',volume:'中公クラシックス ; W48',source:'https://ndlsearch.ndl.go.jp/books/R100000002-I000008440421',purchase:'https://www.amazon.co.jp/s/?i=stripbooks&k=9784121600943'},
    {label:'スピノザ全集. 3・岩波書店',publisher:'岩波書店',translator:'上野修（翻訳・解説）',editor:'上野修・鈴木泉（編）',isbn:'9784000928533',volume:'3',source:'https://ndlsearch.ndl.go.jp/books/R100000002-I032507023',purchase:'https://www.amazon.co.jp/s/?i=stripbooks&k=9784000928533'},
  ];
  async function reveal(control) {
    for(let i=0;i<20 && await control.count()===0;i++) {
      const size=page.viewportSize();await page.mouse.move(size.width/2,size.height*.65);
      await page.mouse.wheel(0,240);await page.waitForTimeout(250);
    }
    await expect(control).toHaveCount(1);
  }
  async function editBook(book) {
    const cycle=page.getByRole('group',{name:new RegExp(`ISBN: ${book.isbn}`)}).filter({has:page.getByRole('button',{name:'版を編集',exact:true})}).last();
    const edit=cycle.getByRole('button',{name:'版を編集',exact:true});await reveal(edit);await edit.click();
  }
  async function verifyBook(book,editor=book.editor) {
    for(const [name,value] of [[/^出版社/,book.publisher],[/^訳者/,book.translator],[/^ISBN/,book.isbn],[/^巻・版の名前/,book.volume],[/^編集者・編者/,editor],[/^版情報の出典URL/,book.source],[/^書籍・購入URL/,book.purchase]]) await restoredField(page,name,value);
  }
  const browserErrors=[];page.on('pageerror',e=>browserErrors.push(e.message));
  await page.goto(base+'/reading-list');await semantics(page);await openWork(page,'エチカ');
  for(const book of japaneseBooks) {
    await page.getByRole('button',{name:/版・入手先/}).click();
    const card=page.getByRole('group',{name:`版候補: ${book.label}`,exact:true});
    const start=card.getByRole('button',{name:'この版で読書を始める',exact:true});await reveal(start);
    await capture(page,`japanese-candidate-${book.isbn}`);
    for(const link of ['この版の書誌出典を開く','Amazonで書籍を検索（ISBN）','楽天ブックスで検索（ISBN）','国立国会図書館で探す（ISBN）']) await expect(card.getByRole('button',{name:link,exact:true})).toHaveCount(1);
    const pop=page.waitForEvent('popup');await card.getByRole('button',{name:'Amazonで書籍を検索（ISBN）',exact:true}).click();
    const opened=await pop;await opened.waitForURL(/^https:\/\/www\.amazon\.co\.jp\/s\//);
    assert.equal(new URL(opened.url()).searchParams.get('k'),book.isbn);bookLinks.push(opened.url());await opened.close();await reveal(start);
    for(const [link,target] of [['この版の書誌出典を開く',book.source],['この版の出版社・書店を開く',book.purchase]]) {
      await reveal(start);
      const destinationPromise=page.waitForEvent('popup');await card.getByRole('button',{name:link,exact:true}).click();
      const destination=await destinationPromise;await destination.waitForURL(target);bookLinks.push(destination.url());await destination.close();
    }
    await reveal(start);
    await start.click();
    await field(page,/^出版社/,'検索前の手入力');
    await page.getByRole('button',{name:'書籍情報から自動入力',exact:true}).click();
    const query=book.isbn==='9784121600943'?'エティカ':'978-4000928533';
    await field(page,/^書籍情報を検索/,query);
    await page.getByRole('button',{name:'書籍情報を検索',exact:true}).click();
    const prefix=book.isbn==='9784121600943'?'^エティカ・中央公論新社':'^スピノザ全集';
    await page.getByRole('button',{name:new RegExp(prefix)}).click();
    await expect(page.getByText('この書籍情報を設定しますか？',{exact:true})).toBeVisible();
    await page.getByRole('button',{name:'書籍情報を設定',exact:true}).click();
    await verifyBook(book);
    await capture(page,`lookup-prefill-${book.isbn}`);
    await page.getByRole('button',{name:'保存',exact:true}).click();
    await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
    await page.getByRole('button',{name:/Back|戻る/}).click();await openWork(page,'エチカ');
  }
  for(const [mode,size] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}]]) {
    await page.setViewportSize(size);await page.reload();await semantics(page);await openWork(page,'エチカ');
    for(let i=0;i<japaneseBooks.length;i++) {
      await editBook(japaneseBooks[i]);await verifyBook(japaneseBooks[i],i===0 && mode==='mobile'?'公開確認・desktop編者':japaneseBooks[i].editor);
      if(i===0) await field(page,/^編集者・編者/,`公開確認・${mode}編者`);
      await page.getByRole('button',{name:'保存',exact:true}).click();
    }
    await page.reload();await semantics(page);await openWork(page,'エチカ');
    for(let i=0;i<japaneseBooks.length;i++) {
      await editBook(japaneseBooks[i]);await verifyBook(japaneseBooks[i],i===0?`公開確認・${mode}編者`:japaneseBooks[i].editor);
      await capture(page,`${mode}-japanese-restored-${japaneseBooks[i].isbn}`);
      await page.getByRole('button',{name:'保存',exact:true}).click();
    }
  }
  const japaneseRecords=await action(a.token,{action:'reading.list'});
  const analects=japaneseRecords.items.find(x=>x.metadata.work?.id==='spinoza:ethics');
  assert.equal(analects?.metadata.cycles.length,2,'Two Japanese editions must be separate cycles');
  for(let i=0;i<japaneseBooks.length;i++) {
    const edition=analects.metadata.cycles.find(c=>c.edition.isbn===japaneseBooks[i].isbn)?.edition;
    assert(edition);for(const property of ['publisher','translator','isbn','volume']) assert.equal(edition[property],japaneseBooks[i][property]);
    assert.equal(edition.source_url,japaneseBooks[i].source);assert.equal(edition.book_url,japaneseBooks[i].purchase);
    assert.equal(edition.editor,i===0?'公開確認・mobile編者':japaneseBooks[i].editor);
  }
  assert.deepEqual(browserErrors,[],'Published Japanese edition flow has browser errors');
  console.log('Published title/ISBN lookup and confirmed automatic prefill passed.');
  console.log('Published Japanese editions: desktop/mobile two translations, ISBN purchase destinations, prefill, registration, reload, independent editor changes and genuine API persistence passed.');

  // A personal work, like the reported screen; never infer a shared-work link.
  const personalWork={...work,id:'qa:'+randomUUID(),title:'読書について',author_info:{...work.author_info,id:'qa-schopenhauer',name:'ショーペンハウアー'}};
  const personalId=randomUUID();
  await action(a.token,{action:'reading.add',id:personalId,work:personalWork});
  const readingBook={publisher:'光文社',translator:'鈴木芳子',editor:'',isbn:'9784334752712',volume:'',source:'https://www.kotensinyaku.jp/books/book169/',purchase:'https://www.amazon.co.jp/s/?i=stripbooks&k=9784334752712'};
  for(const [mode,size,query] of [['title',{width:1440,height:1000},'読書について'],['isbn',{width:390,height:844},'978-4-334-75271-2']]) {
    await page.setViewportSize(size);await page.goto(base+'/reading-list');await semantics(page);await openWork(page,'読書について');
    const start=page.getByRole('button',{name:mode==='title'?'読書を始める':'別の版・再読を始める',exact:true});
    await reveal(start);await expect(start).toBeEnabled();await start.click();
    await field(page,/^出版社/,'検索前の手入力');
    await page.getByRole('button',{name:'書籍情報から自動入力',exact:true}).click();
    await field(page,/^書籍情報を検索/,query);
    await page.getByRole('button',{name:'書籍情報を検索',exact:true}).click();
    await page.getByRole('button',{name:/^読書について・光文社/}).click();
    await page.getByRole('button',{name:'書籍情報を設定',exact:true}).click();
    await verifyBook(readingBook);
    await restoredField(page,/^出版年/,'2013');await restoredField(page,/^言語/,'日本語');
    await capture(page,`reading-about-books-${mode}-prefill`);
    await page.getByRole('button',{name:'保存',exact:true}).click();
    await expect(page.getByText('読む版を登録',{exact:true})).toHaveCount(0);
    await page.reload();await semantics(page);await openWork(page,'読書について');
    await editBook(readingBook);await verifyBook(readingBook);
    await field(page,/^編集者・編者/,`公開確認・${mode}編集`);
    await page.getByRole('button',{name:'保存',exact:true}).click();
    await expect(page.getByRole('textbox',{name:/^出版社/})).toHaveCount(0);
    await page.reload();await semantics(page);await openWork(page,'読書について');
    await editBook(readingBook);await verifyBook(readingBook,`公開確認・${mode}編集`);
    await capture(page,`reading-about-books-${mode}-edited-reloaded`);
    await page.getByRole('button',{name:'保存',exact:true}).click();
    await expect(page.getByRole('textbox',{name:/^出版社/})).toHaveCount(0);
  }
  const personalRecords=await action(a.token,{action:'reading.list'});
  const personal=personalRecords.items.find(x=>x.id===personalId);
  assert.equal(personal?.metadata.cycles.length,2);
  for(const [i,mode] of ['title','isbn'].entries()) {
    const edition=personal.metadata.cycles[i].edition;
    for(const property of ['publisher','translator','isbn']) assert.equal(edition[property],readingBook[property]);
    assert.equal(edition.editor,`公開確認・${mode}編集`);
    assert.equal(edition.source_url,readingBook.source);assert.equal(edition.book_url,readingBook.purchase);
  }
  assert.deepEqual(browserErrors,[]);
  console.log('Published Reading About Books: personal work title/ISBN search, confirmed metadata prefill, two registrations, desktop/mobile reload/edit/reload and real API persistence passed.');

  await writeFile('reading-production-evidence/book-links.json',JSON.stringify(bookLinks,null,2));
  await writeFile('reading-production-evidence/result.json',JSON.stringify({commit:version.commit,api:'passed',desktop:'passed',mobile:'passed',authenticatedSaveReloadProgress:'passed',catalog:'56 authors / 80 works',bookLinks:'passed',editionRegistrationEditReload:'passed',curatedEdition:'passed',japaneseEditionSelectionRegistrationEdit:'passed',titleAndIsbnLookupPrefillRegistrationReloadEdit:'passed',readingAboutBooksTitleIsbnRegistrationReloadEdit:'passed',newWork:'spinoza:ethics',verifiedEditions:japaneseBooks.map(b=>({isbn:b.isbn,publisher:b.publisher,source:b.source,purchase:b.purchase}))},null,2));
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
