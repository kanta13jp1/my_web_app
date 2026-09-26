"""Black-box browser checks; screenshots use the committed/measured real report only."""
import functools
import copy
import http.server
import json
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
report_path = ROOT/'web/labs/expense-comparison/results.json'
if report_path.exists():
    report = json.loads(report_path.read_text(encoding='utf-8'))
    measured = True
else:
    measured = False
    fixtures=json.loads((ROOT/'scripts/expense_comparison/fixtures.json').read_text(encoding='utf-8'))
    ids=list(fixtures['categories'])
    answer={'type':'choice','choice':ids[0],'confidence':0.0,'probabilities':{i:1/12 for i in ids}}
    report={'schema_version':1,'synthetic':True,'mode':'saved_real_model_measurement','run_id':'1',
            'categories':fixtures['categories'],'model':'contract_fixture_not_inference',
            'samples':[{**s,'rule':'other','trials':[{'status':'ok','model':'jevbert-poc-nli-ja-en-0.2.0',
                          'answer':answer,'http_ms':1} for _ in range(2)]} for s in fixtures['samples']]}

handler=functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(ROOT/'web'))
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),handler)
thread=threading.Thread(target=server.serve_forever,daemon=True)
thread.start()
out=ROOT/'out/expense-comparison'
out.mkdir(parents=True,exist_ok=True)
try:
    with sync_playwright() as p:
        browser=p.chromium.launch()
        for width,height in [(1280,1000),(390,844)]:
            page=browser.new_page(viewport={'width':width,'height':height})
            errors=[]
            page.on('pageerror',lambda error:errors.append(str(error)))
            failure={'mode':'ok'}
            def respond(route):
                if failure['mode']=='http':
                    route.fulfill(status=503,body='Unavailable')
                elif failure['mode']=='schema':
                    route.fulfill(json={'schema_version':999})
                elif failure['mode']=='inference':
                    failed=copy.deepcopy(report)
                    failed['samples'][0]['trials'][0]={'status':'error','error':'http_500','http_ms':1}
                    route.fulfill(json=failed)
                else:
                    route.fulfill(json=report)
            page.route('**/results.json',respond)
            url=f'http://127.0.0.1:{server.server_port}/labs/expense-comparison/index.html'
            page.goto(url)
            page.locator('#workspace').wait_for(state='visible')
            assert page.locator('#sample option').count()==14
            assert page.locator('.score').count()==12
            for index,sample in enumerate(report['samples']):
                page.locator('#sample').select_option(str(index))
                assert page.locator('#memo').inner_text()==sample['text']
                assert page.locator('#rule').inner_text()==report['categories'][sample['rule']]['label']
                for trial_index,trial in enumerate(sample['trials']):
                    page.locator('#trial').select_option(str(trial_index))
                    if trial['status']=='ok':
                        assert page.locator('#bert').inner_text()==report['categories'][trial['answer']['choice']]['label']
                    else:
                        assert '候補なし' in page.locator('#bert').inner_text()
            page.locator('#sample').select_option('0')
            page.locator('#trial').select_option('0')
            if measured:
                page.screenshot(path=str(out/f'comparison-{width}.png'),full_page=True)
            page.locator('#sample').select_option('12')
            assert '要確認' in page.locator('#review').inner_text()
            page.locator('#trial').select_option('1')
            assert '2回目' in page.locator('#latency').inner_text()
            assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
            failure['mode']='inference'
            page.reload()
            page.locator('#workspace').wait_for(state='visible')
            assert '推論失敗' in page.locator('#bert').inner_text()
            assert page.locator('.score').count()==0
            failure['mode']='http'
            page.reload()
            page.locator('#retry').wait_for(state='visible')
            assert not page.locator('#workspace').is_visible()
            failure['mode']='schema'
            page.locator('#retry').click()
            page.locator('#retry').wait_for(state='visible')
            assert not page.locator('#workspace').is_visible()
            failure['mode']='ok'
            page.locator('#retry').click()
            page.locator('#workspace').wait_for(state='visible')
            assert not errors,errors
            page.close()
        browser.close()
    print('PASS: two widths; all 28 candidates, ambiguous input, trial switch, inference/HTTP/schema error and recovery.')
    print('Evidence: '+('real saved model measurements' if measured else 'mocked HTTP contract ONLY, no model inference or screenshots'))
finally:
    server.shutdown()
    server.server_close()
    thread.join()
