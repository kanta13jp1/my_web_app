"""Allow only sanitized, bounded evidence, never Auth state or browser traces."""
import json
from pathlib import Path
import re
from guard import runtime

root = Path(__file__).resolve().parents[3]
_, work = runtime()
evidence = root / 'shop-real-auth-evidence'
state_file = work / 'state.json'
secrets = []
if state_file.exists():
    state = json.loads(state_file.read_text(encoding='utf-8'))
    secrets = [state['service'], state['anon']] + [u['password'] for u in state['users'].values()]
allowed_json = {'environment.json', 'prepare-checks.json', 'api-checks.json', 'browser-results.json'}
paths = list(evidence.glob('**/*')) if evidence.exists() else []
for path in paths:
    if path.is_dir():
        raise AssertionError('Nested evidence folders are not permitted')
    if path.is_symlink() or path.stat().st_size > 25_000_000:
        raise AssertionError('Unsafe evidence path or size')
    if path.name not in allowed_json and not re.fullmatch(r'(desktop|mobile)-(review-created|review-edited|review-deleted|nonbuyer-read-only)\.png', path.name):
        raise AssertionError('Unexpected artifact type')
    raw = path.read_bytes()
    if any(s.encode() in raw for s in secrets) or re.search(rb'eyJ[\w-]+\.[\w-]+\.[\w-]+', raw):
        raise AssertionError('Sensitive evidence detected; upload must be skipped')
    if path.suffix == '.json':
        json.loads(raw)
print(f'Sanitized evidence allowlist verified: {len(paths)} files. A partial run is not a PASS.')
