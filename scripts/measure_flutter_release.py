"""Cloud-only release artifact comparison; never publishes to production."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--entry', choices=['normal', 'isolated'], required=True)
    args = parser.parse_args()
    if sys.platform != 'linux' or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise SystemExit('Release measurement requires an isolated Linux GitHub runner')
    root = Path(__file__).resolve().parents[1]
    output = root / '.ci-logs/release-prototype'
    output.mkdir(parents=True, exist_ok=True)
    target = 'lib/main.dart' if args.entry == 'normal' else 'test/fixtures/echo_pump_app.dart'
    command = ['flutter', 'build', 'web', '--release', '--pwa-strategy=none',
               '--no-web-resources-cdn', '--base-href=/prototype/echo-pump/',
               '--target=' + target, '--dart-define=ENVIRONMENT=development',
               '--dart-define=SUPABASE_URL=http://127.0.0.1:7366',
               '--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_local_benchmark_only']
    report = {'schema': 1, 'entry': args.entry, 'head_sha': os.environ['GITHUB_SHA'],
              'command': command, 'result': 'failure',
              'conditions': {'mode': 'release', 'samples': 1, 'fresh_runner': True,
                             'dependencies_and_queue_excluded': True,
                             'backend': 'loopback synthetic only', 'production_published': False}}
    start = time.monotonic()
    with (output / 'build.log').open('w') as log:
        code = subprocess.call(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    report['build_seconds'] = time.monotonic() - start
    report['exit_code'] = code
    if code == 0:
        web = root / 'build/web'
        files = []
        for item in sorted(web.rglob('*')):
            if item.is_file():
                data = item.read_bytes()
                files.append({'path': item.relative_to(web).as_posix(), 'bytes': len(data),
                              'sha256': hashlib.sha256(data).hexdigest()})
        main_js = (web / 'main.dart.js').read_bytes()
        report.update(result='success', files=files, file_count=len(files),
                      total_bytes=sum(f['bytes'] for f in files),
                      asset_bytes=sum(f['bytes'] for f in files if f['path'].startswith('assets/')),
                      main_js_bytes=len(main_js), main_js_gzip_bytes=len(gzip.compress(main_js, mtime=0)))
    (output / 'BUILD.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k not in ['files', 'command']}))
    raise SystemExit(code)


if __name__ == '__main__':
    main()
