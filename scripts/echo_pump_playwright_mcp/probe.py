import asyncio,json,os,re,time
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client

OUT=Path(os.environ.get('MCP_EVIDENCE_DIR','mcp-browser-evidence'))
OUT.mkdir(parents=True,exist_ok=True)
BASE=os.environ.get('MCP_GAME_URL','https://my-web-app-b67f4.web.app/echo-pump')
async def main():
 evidence={'url':BASE,'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'calls':[],'execution':'Codex-orchestrated Actions Python MCP SDK -> Microsoft Playwright MCP -> isolated Chromium'}
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
    snapshot=await call('browser_snapshot',{})
    line=next((s for s in snapshot.splitlines() if label in s and ('button' in s or 'link' in s)),None)
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
   await call('browser_take_screenshot',{'filename':'baseline-desktop.png','fullPage':True})
   await call('browser_console_messages',{'level':'error'})
   await call('browser_close',{})
   evidence['completed']=True
   (OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({'completed':True,'calls':len(evidence['calls']),'tools':len(evidence['tools'])}))
asyncio.run(main())
