"""Real Jwenv measurement in Chromium's WebGPU (CI only; downloads a 639 MB model).

    python scripts/jwenv_lab/run_lab.py download --dest /tmp/jwenv.gguf
    python scripts/jwenv_lab/run_lab.py measure --model /tmp/jwenv.gguf --out out/jwenv-lab

`measure` drives web/labs/jwenv/ through the same functions as its buttons and writes
results.json, screenshots and the browser console. It never retries a failed inference.
"""
import argparse
import datetime
import functools
import http.server
import json
import os
import platform
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import LAB, ROOT, core_constant, inputs_sha256, manifest, sha256_file  # noqa: E402

MODEL = core_constant('MODEL')
ENGINE = core_constant('ENGINE')
# Tried in order; the first set that yields a WebGPU adapter is recorded in results.json.
FLAG_SETS = [
    ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--use-vulkan=swiftshader',
     '--use-webgpu-adapter=swiftshader', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
     '--ignore-gpu-blocklist', '--disable-vulkan-surface'],
    ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--use-webgpu-adapter=swiftshader',
     '--enable-unsafe-swiftshader'],
    ['--enable-unsafe-webgpu', '--enable-unsafe-swiftshader'],
]


def download(dest):
    url = f"https://huggingface.co/{MODEL['repo']}/resolve/{MODEL['revision']}/{MODEL['file']}"
    dest = Path(dest)
    if not (dest.exists() and dest.stat().st_size == MODEL['bytes']):
        print(f'downloading {url}', flush=True)
        urllib.request.urlretrieve(url, dest)
    size, digest = dest.stat().st_size, sha256_file(dest)
    if size != MODEL['bytes'] or digest != MODEL['sha256']:
        raise SystemExit(f'model mismatch: {size} bytes, sha256 {digest}')
    print(f'verified {dest} ({size} bytes, sha256 {digest})')


def runner_info():
    info = {'platform': platform.platform(), 'python': platform.python_version(), 'cpu_count': os.cpu_count()}
    try:
        lscpu = subprocess.run(['lscpu'], capture_output=True, text=True, check=True).stdout
        info['cpu_model'] = next((l.split(':', 1)[1].strip() for l in lscpu.splitlines() if l.startswith('Model name')), None)
        mem = Path('/proc/meminfo').read_text().splitlines()[0]
        info['memory_total'] = mem.split(':', 1)[1].strip()
    except (OSError, subprocess.CalledProcessError, StopIteration):
        pass
    return info


def network_summary(urls, port):
    from urllib.parse import urlsplit
    origins = sorted({f'{u.scheme}://{u.netloc}' for u in map(urlsplit, urls) if u.scheme in ('http', 'https')})
    local = f'http://127.0.0.1:{port}'
    return {'requests': len(urls), 'origins': origins,
            'external_requests': sorted({u for u in urls if urlsplit(u).scheme in ('http', 'https') and not u.startswith(local)})}


def serve():
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'web'))
    handler.log_message = lambda *a: None
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def measure(model_path, out, passes):
    from playwright.sync_api import sync_playwright

    model_path = Path(model_path)
    if sha256_file(model_path) != MODEL['sha256']:
        raise SystemExit('model sha256 mismatch; run `download` first')
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    server = serve()
    url = f'http://127.0.0.1:{server.server_port}/labs/jwenv/index.html'
    console = []
    requests = []
    with sync_playwright() as p:
        browser = page = flags = adapter = None
        for candidate in FLAG_SETS:
            b = p.chromium.launch(channel='chromium', args=candidate)
            pg = b.new_page(viewport={'width': 1280, 'height': 1000})
            pg.on('console', lambda m: console.append(f'[{m.type}] {m.text}'))
            pg.on('pageerror', lambda e: console.append(f'[pageerror] {e}'))
            pg.on('request', lambda r: requests.append(r.url))
            pg.goto(url)
            pg.evaluate('window.jwenvLab.ready')
            info = pg.evaluate("""async () => { const a = navigator.gpu && await navigator.gpu.requestAdapter();
                                   return a ? Object.fromEntries(['vendor','architecture','device','description'].map(k => [k, a.info?.[k] ?? ''])) : null; }""")
            print(f'flags {candidate}: adapter {info}', flush=True)
            if info:
                browser, page, flags, adapter = b, pg, candidate, info
                break
            b.close()
        if not page:
            raise SystemExit('no WebGPU adapter with any flag set')

        page.set_input_files('#model-file', str(model_path))
        t0 = time.time()
        page.wait_for_function("['loaded','error'].includes(document.getElementById('model-status').dataset.state)",
                               timeout=30 * 60 * 1000, polling=2000)
        status = page.locator('#model-status').inner_text()
        print(f'model status after {time.time() - t0:.1f}s: {status}', flush=True)
        if page.locator('#model-status').get_attribute('data-state') != 'loaded':
            (out / 'console.log').write_text('\n'.join(console), encoding='utf-8')
            raise SystemExit(f'model load failed: {status}')
        snapshot = page.evaluate('window.jwenvLab.snapshot()')

        def step(name, script):
            t = time.time()
            value = page.evaluate(script)
            print(f'{name}: {time.time() - t:.1f}s', flush=True)
            return value

        example = step('article example', 'window.jwenvLab.runExample()')
        limit = step('limit check', 'window.jwenvLab.runLimit()')
        slices = [step('slice check (article)', 'window.jwenvLab.verifySlice()'),
                  step('slice check (expense)', 'window.jwenvLab.verifySlice(window.jwenvLab.expenseRequestFor(0))')]
        requested_passes = passes
        if example['ms'] > 30_000 and passes > 1:
            passes = 1  # keep the CPU-emulated run inside the job timeout; recorded below
            print(f"article example took {example['ms']:.0f} ms; expense passes reduced to 1", flush=True)
        expense = step('expense batch', f"""window.jwenvLab.runExpense({passes}, (pass, n) => console.log(`expense pass ${{pass}}: ${{n}}/14`))""")

        page.evaluate("""([example, limit, slice, expense]) => {
            const r = window.jwenvLab.render;
            r.show(r.exampleBlock(example), 'example-result');
            r.show(r.limitBlock(limit), 'limit-result');
            r.show(r.sliceBlock(slice), 'slice-result');
            r.show(r.expenseTable(expense), 'live-expense-1');
            document.getElementById('run-status').textContent = 'CIの自動実行で全検証が完了しました。';
        }""", [example, limit, slices[0], expense])
        for width, height in [(1280, 1000), (390, 844)]:
            page.set_viewport_size({'width': width, 'height': height})
            assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth'), f'horizontal overflow at {width}px'
            page.screenshot(path=str(out / f'jwenv-lab-{width}.png'), full_page=True)
        version = browser.version
        browser.close()
    server.shutdown()

    results = {
        'schema_version': 1,
        'synthetic': True,
        'mode': 'saved_browser_webgpu_measurement',
        'recorded_at': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'run_id': os.environ.get('GITHUB_RUN_ID', '0'),
        'app_revision': os.environ.get('GITHUB_SHA', 'local'),
        'inputs_sha256': inputs_sha256(),
        'engine': {**ENGINE, 'vendored_files': len(manifest()['files'])},
        'model': {**MODEL, 'verified_sha256': True},
        'environment': {'browser': f'Chromium {version}', 'flags': flags, 'adapter': snapshot['adapter'],
                        'adapter_info': adapter, 'runner': runner_info(), 'headless': True},
        'timing_scope': 'performance.now() in the page. load_ms covers GGUF parse, CPU-side weight preparation and GPU upload '
                        '(the file is read from local disk). Request ms covers JevClassifier.systemOne: validation, '
                        'tokenization, forward pass and readback. Software WebGPU (SwiftShader) on a CPU runner; not a GPU measurement.',
        'network': network_summary(requests, server.server_port),
        'load_ms': snapshot['load_ms'],
        'model_snapshot': snapshot,
        'article_example': example,
        'limit_check': limit,
        'slice_checks': slices,
        'expense': {**expense, 'passes_requested': requested_passes, 'passes_run': passes},
        'unmeasured': [
            'Real GPU (discrete or integrated) timing: CI runners have no GPU.',
            'Offline start: model and page were served from local disk/loopback, not tested offline.',
            'Model download time from Hugging Face in a browser: the file was selected from local disk.',
            'Accuracy beyond these 14 synthetic memos.',
        ],
    }
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (out / 'console.log').write_text('\n'.join(console), encoding='utf-8')
    print(json.dumps({'load_ms': results['load_ms'], 'example': example['response']['answers'],
                      'limit': limit, 'max_abs_diff': [s['max_abs_diff'] for s in slices],
                      'agreement': expense['agreement'], 'median_ms': [r['median_ms'] for r in expense['runs']]},
                     ensure_ascii=False, indent=2))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)
    d = sub.add_parser('download')
    d.add_argument('--dest', required=True)
    m = sub.add_parser('measure')
    m.add_argument('--model', required=True)
    m.add_argument('--out', default=str(ROOT / 'out/jwenv-lab'))
    m.add_argument('--passes', type=int, default=2)
    a = ap.parse_args()
    if a.cmd == 'download':
        download(a.dest)
    else:
        measure(a.model, a.out, a.passes)


if __name__ == '__main__':
    main()
