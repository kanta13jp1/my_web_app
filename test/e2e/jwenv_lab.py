"""Black-box checks of web/labs/jwenv without a model or GPU (normal, failure, recovery, narrow screen).

Real inference is covered by scripts/jwenv_lab/run_lab.py in the measure job. The saved-record
fixture below only exercises rendering; screenshots are taken only from a real results.json.
"""
import copy
import functools
import http.server
import json
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'web/labs/jwenv'
saved_path = LAB / 'results.json'
reference = json.loads((ROOT / 'web/labs/expense-comparison/results.json').read_text(encoding='utf-8'))
core = (LAB / 'core.mjs').read_text(encoding='utf-8')
model_sha = core.split("sha256: '")[1].split("'")[0]
engine_rev = core.split("revision: '")[2].split("'")[0]

if saved_path.exists():
    saved = json.loads(saved_path.read_text(encoding='utf-8'))
    measured = True
else:
    measured = False
    rows = [{'id': s['id'], 'text': s['text'], 'expected': s['expected'], 'review_required': s['review_required'],
             'rule': s['rule'], 'bert': None, 'jwenv': 'other', 'p_yes': 0.1, 'review': True, 'top3': [], 'ms': 1,
             'input_tokens': 1} for s in reference['samples']]
    answer = {'type': 'choice', 'choice': 'food', 'confidence': 0, 'probabilities': {}}
    saved = {'schema_version': 1, 'mode': 'saved_browser_webgpu_measurement', 'synthetic': True, 'run_id': '1',
             'recorded_at': 'contract-fixture', 'model': {'sha256': model_sha}, 'engine': {'revision': engine_rev},
             'environment': {'adapter': 'contract fixture, not inference', 'browser': 'n/a'}, 'load_ms': 1,
             'article_example': {'ms': 1, 'response': {'answers': {'category': answer}}},
             'limit_check': {'rejected': True, 'code': 'too_many_options', 'status': 422},
             'slice_checks': [{'max_abs_diff': 0}],
             'expense': {'runs': [{'pass': 1, 'rows': rows, 'median_ms': 1}],
                         'agreement': {k: {'referenced': 11, 'matches': 0} for k in ('jwenv', 'rule', 'bert')}}}

# Rendering fixture for the real-GPU section (schema 2). A committed results-gpu.json replaces it.
gpu_path = LAB / 'results-gpu.json'
if gpu_path.exists():
    gpu_saved = json.loads(gpu_path.read_text(encoding='utf-8'))
else:
    def method_row(s):
        return {'set': 'original', 'id': s['id'], 'text': s['text'], 'expected': s['expected'],
                'a': {'choice': 'other', 'p': 0.1, 'review': True, 'top3': []},
                'b': {'choice': 'other', 'p': 0.2, 'review': True, 'expected_in_top8': None},
                'stage1_ms': 1, 'stage2_ms': 1}
    counts = {'referenced': 11, 'matches': 0, 'false_reviews': 11, 'review_required': 3, 'flagged': 3}
    gpu_saved = {'schema_version': 2, 'mode': 'saved_browser_webgpu_measurement', 'synthetic': True,
                 'recorded_at': 'contract-fixture', 'model': {'sha256': model_sha}, 'engine': {'revision': engine_rev},
                 'environment': {'adapter': 'contract fixture, not inference', 'browser': 'n/a'}, 'load_ms': 1,
                 'article_example': {'ms': 1, 'response': {'answers': {'category': {'choice': 'food'}}}},
                 'methods': {'rows': [method_row(s) for s in reference['samples']],
                             'summary': {'original': {'a': counts, 'b': counts, 'b_expected_in_top8': 0}},
                             'adoption': None, 'timing': {'stage1_median_ms': 1, 'stage2_median_ms': 1}}}

handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'web'))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f'http://127.0.0.1:{server.server_port}/labs/jwenv/index.html'
out = ROOT / 'out/jwenv-lab-e2e'
out.mkdir(parents=True, exist_ok=True)
tmp = out / 'inputs'
tmp.mkdir(exist_ok=True)
(tmp / 'notes.txt').write_text('not a model', encoding='utf-8')
(tmp / 'broken.gguf').write_bytes(b'NOT A GGUF FILE')

try:
    with sync_playwright() as p:
        browser = p.chromium.launch()  # no WebGPU flags: exercises the unavailable path
        for width, height in [(1280, 1000), (390, 844)]:
            page = browser.new_page(viewport={'width': width, 'height': height})
            errors = []
            page.on('pageerror', lambda e: errors.append(str(e)))
            mode = {'saved': 'ok', 'reference': 'ok', 'gpu': 'ok'}

            def saved_route(route):
                if mode['saved'] == 'missing':
                    route.fulfill(status=404, body='')
                elif mode['saved'] == 'html':
                    route.fulfill(status=200, body='<!doctype html><title>app</title>', content_type='text/html')
                elif mode['saved'] == 'schema':
                    route.fulfill(json={'schema_version': 999})
                else:
                    route.fulfill(json=saved)

            def reference_route(route):
                if mode['reference'] == 'down':
                    route.fulfill(status=503, body='Unavailable')
                else:
                    route.fulfill(json=reference)

            def gpu_route(route):
                if mode['gpu'] == 'missing':
                    route.fulfill(status=404, body='')
                elif mode['gpu'] == 'schema':
                    route.fulfill(json={'schema_version': 2})
                else:
                    route.fulfill(json=gpu_saved)

            page.route('**/labs/jwenv/results.json', saved_route)
            page.route('**/labs/jwenv/results-gpu.json', gpu_route)
            page.route('**/labs/expense-comparison/results.json', reference_route)

            # Normal load: saved record renders, model-dependent actions stay disabled.
            page.goto(url)
            page.evaluate('window.jwenvLab.ready')
            page.wait_for_function("!document.getElementById('gpu-status').textContent.includes('確認しています')")
            assert page.locator('#gpu-status').get_attribute('data-state') in ('ok', 'unavailable')
            for button in ('#run-example', '#run-expense', '#verify-slice'):
                assert page.locator(button).is_disabled(), button
            assert page.locator('#run-limit').is_enabled()
            assert page.locator('#saved-expense-1 tbody tr').count() == 14
            assert 'GitHub Actions 実行' in page.locator('#saved-status').inner_text()
            assert page.locator('#gpu-saved-methods-original tbody tr').count() == 14
            assert '実機GPU' in page.locator('#gpu-saved-status').inner_text()

            # The 8-option limit is enforced by the vendored validator even without a model.
            page.locator('#run-limit').click()
            page.locator('#limit-result').wait_for()
            text = page.locator('#limit-result').inner_text()
            assert '12択' in text and 'too_many_options' in text and '422' in text, text

            # Wrong file type is rejected before touching WebGPU; the picker stays usable (recovery).
            page.set_input_files('#model-file', str(tmp / 'notes.txt'))
            page.wait_for_function("document.getElementById('model-status').dataset.state === 'error'")
            assert 'GGUFファイル' in page.locator('#model-status').inner_text()
            page.set_input_files('#model-file', str(tmp / 'broken.gguf'))
            page.wait_for_function("document.getElementById('model-status').dataset.state === 'error' && "
                                   "!document.getElementById('model-status').textContent.includes('GGUFファイル（')")
            assert page.locator('#model-file').is_enabled()
            assert page.locator('#run-example').is_disabled()
            assert page.locator('#progress').is_hidden()

            assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), f'overflow at {width}px'
            if measured:
                page.screenshot(path=str(out / f'jwenv-lab-saved-{width}.png'), full_page=True)

            # Missing / HTML-fallback / malformed saved records and an unavailable reference.
            for m, expected in [('missing', 'まだありません'), ('html', 'まだありません'), ('schema', '形式が正しくありません')]:
                mode['saved'] = m
                page.reload()
                page.evaluate('window.jwenvLab.ready')
                assert expected in page.locator('#saved-status').inner_text(), (m, page.locator('#saved-status').inner_text())
                assert page.locator('#saved-expense-1').count() == 0
            for m, expected in [('missing', 'まだありません'), ('schema', '形式が正しくありません')]:
                mode['gpu'] = m
                page.reload()
                page.evaluate('window.jwenvLab.ready')
                assert expected in page.locator('#gpu-saved-status').inner_text(), (m, page.locator('#gpu-saved-status').inner_text())
                assert page.locator('#gpu-saved-methods').count() == 0
            mode['gpu'] = 'ok'
            mode['saved'], mode['reference'] = 'ok', 'down'
            page.reload()
            page.evaluate('window.jwenvLab.ready')
            assert '参照データを読み込めません' in page.locator('#run-status').inner_text()
            assert page.locator('#run-limit').is_disabled()
            mode['reference'] = 'ok'
            page.reload()
            page.evaluate('window.jwenvLab.ready')
            assert page.locator('#run-limit').is_enabled()

            assert not errors, errors
            page.close()
        browser.close()
finally:
    server.shutdown()
print('jwenv lab e2e: ok (measured record)' if measured else 'jwenv lab e2e: ok (contract fixture)')
