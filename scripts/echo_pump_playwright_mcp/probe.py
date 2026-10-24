import asyncio,json,os,re,time,urllib.request
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client

OUT=Path(os.environ.get('MCP_EVIDENCE_DIR','mcp-browser-evidence'))
OUT.mkdir(parents=True,exist_ok=True)
BASE=os.environ.get('MCP_GAME_URL','https://my-web-app-b67f4.web.app/echo-pump')
FEATURE=os.environ.get('MCP_EXPECT_KEYBOARD')=='1'
async def main():
 evidence={'url':BASE,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'calls':[],'execution':'Codex-orchestrated Actions Python MCP SDK -> Microsoft Playwright MCP -> isolated Chromium'}
 def public_version():
  request=urllib.request.Request('https://my-web-app-b67f4.web.app/version.json?mcp='+os.environ.get('GITHUB_RUN_ID','0'),headers={'Cache-Control':'no-cache'})
  with urllib.request.urlopen(request,timeout=30) as response:return json.load(response)
 if BASE.startswith('https://my-web-app-b67f4.web.app/'):
  evidence['public_before']=public_version()
  expected=os.environ.get('EXPECTED_PRODUCTION_SHA')
  if expected:assert evidence['public_before']['commit']==expected,evidence['public_before']
 params=StdioServerParameters(command='node',args=['/tmp/echo-mcp/node_modules/@playwright/mcp/cli.js','--headless','--browser','chromium','--isolated','--viewport-size','1440,1000','--output-dir',str(OUT.resolve())])
 async with stdio_client(params) as (read,write):
  async with ClientSession(read,write) as session:
   init=await session.initialize();evidence['server']=init.model_dump(mode='json')
   listing=await session.list_tools();evidence['tools']=[x.model_dump(mode='json') for x in listing.tools]
   async def call(name,args):
    result=await session.call_tool(name,args)
    body='\n'.join(c.text for c in result.content if c.type=='text')
    evidence['calls'].append({'tool':name,'arguments':args,'isError':bool(result.isError),'text':body})
    (OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf8')
    if result.isError:raise RuntimeError(body)
    return body
   await call('browser_navigate',{'url':BASE})
   snapshot=''
   for _ in range(12):
    snapshot=await call('browser_snapshot',{})
    if 'ゲーム開始' in snapshot:break
    await asyncio.sleep(2)
   if 'ゲーム開始' not in snapshot:raise RuntimeError('game title not available')
   tools={t.name:t for t in listing.tools}
   async def click(label):
    nonlocal snapshot
    line=None
    for _ in range(16):
     snapshot=await call('browser_snapshot',{})
     line=next((s for s in snapshot.splitlines() if label in s and any(role in s for role in ['button','link','switch','checkbox'])),None)
     if line is not None:break
     await asyncio.sleep(.5)
    if line is None:raise RuntimeError('missing control '+label)
    ref=re.search(r'\[ref=([^\]]+)\]',line).group(1)
    props=tools['browser_click'].inputSchema['properties']
    args={'element':label,'ref':ref} if 'ref' in props else {'target':ref}
    snapshot=await call('browser_click',args)
   await click('ゲーム開始')
   await click('スキップ')
   before=await call('browser_snapshot',{})
   await call('browser_press_key',{'key':'w'})
   after=await call('browser_snapshot',{})
   (OUT/'before-key.txt').write_text(before,encoding='utf8')
   (OUT/'after-key.txt').write_text(after,encoding='utf8')
   assert 'ターン 0' in before and 'ターン 0' in after
   if FEATURE:
    for label,key,turn in [('キーボード操作を有効にする','w',1)]:
     await click(label)
     await call('browser_wait_for',{'time':1})
     await call('browser_press_key',{'key':key})
     snapshot=await call('browser_snapshot',{})
     assert f'ターン {turn}' in snapshot,snapshot
    await call('browser_press_key',{'key':'i'})
    snapshot=await call('browser_snapshot',{})
    assert '所持品は空' in snapshot,snapshot
    await call('browser_press_key',{'key':'w'})
    await call('browser_press_key',{'key':'b'})
    await click('所持品を閉じる')
    # Dialog route remains non-current during its closing animation.
    await call('browser_wait_for',{'time':1})
    snapshot=await call('browser_snapshot',{})
    assert 'ターン 1' in snapshot,snapshot
    await call('browser_press_key',{'key':'b'})
    snapshot=await call('browser_snapshot',{})
    assert 'ターン 2' in snapshot,snapshot
    (OUT/'keyboard-on.txt').write_text(snapshot,encoding='utf8')
    await call('browser_take_screenshot',{'filename':str((OUT/'keyboard-desktop.png').resolve()),'fullPage':True})
    assert re.search(r'Errors:\s*0\b',await call('browser_console_messages',{'level':'error'}))
    await click('キーボード操作を有効にする')
    await call('browser_wait_for',{'time':1})
    await call('browser_press_key',{'key':'w'})
    snapshot=await call('browser_snapshot',{})
    assert 'ターン 2' in snapshot,snapshot
    await call('browser_resize',{'width':390,'height':1000})
    await call('browser_navigate',{'url':BASE})
    await click('ゲーム開始')
    await click('スキップ')
    await call('browser_press_key',{'key':'w'})
    snapshot=await call('browser_snapshot',{})
    assert 'ターン 0' in snapshot,snapshot
    await click('キーボード操作を有効にする')
    await call('browser_wait_for',{'time':1})
    await call('browser_press_key',{'key':'w'})
    snapshot=await call('browser_snapshot',{})
    assert 'ターン 1' in snapshot,snapshot
    await call('browser_take_screenshot',{'filename':str((OUT/'keyboard-mobile.png').resolve()),'fullPage':True})
    evidence['keyboard_verified']={'desktop':True,'mobile_width':True,'initial_off':True,'off_no_turn':True,'modal_no_turn':True,'reload_off':True}
   await call('browser_take_screenshot',{'filename':str((OUT/'baseline-desktop.png').resolve()),'fullPage':True})
   console=await call('browser_console_messages',{'level':'error'})
   assert re.search(r'Errors:\s*0\b',console),console
   await call('browser_close',{})
   if 'public_before' in evidence:
    evidence['public_after']=public_version()
    assert evidence['public_before']==evidence['public_after'],'Public version changed during MCP verification'
   evidence['completed']=True
   (OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({'completed':True,'calls':len(evidence['calls']),'tools':len(evidence['tools'])}))
asyncio.run(main())
