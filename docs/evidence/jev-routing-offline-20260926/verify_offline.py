"""Re-score saved synthetic responses; never calls a service or model."""
from pathlib import Path
import hashlib
import json
import math

root = Path(__file__).parent
frozen = json.loads((root / 'frozen.json').read_text(encoding='utf-8'))
for name in ('cases.py', 'PROTOCOL.md'):
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == frozen['sha256'][name], name
cases = {case['id']: case for case in frozen['cases']}
routes = [json.loads(line) for line in (root / 'routes.jsonl.txt').read_text(encoding='utf-8').splitlines()]
records = [json.loads(line) for line in (root / 'responses.jsonl.txt').read_text(encoding='utf-8').splitlines()]
saved = json.loads((root / 'summary.json').read_text(encoding='utf-8'))
assert len(cases) == len(routes) == 12 and len(records) == 24
assert len({r['case_id'] for r in routes}) == 12
assert len({(r['case_id'], r['configuration']) for r in records}) == 24
assert set(cases) == {r['case_id'] for r in routes}

def select(raw):
    if not isinstance(raw, dict) or raw.get('model') != 'jev-1.13.0':
        raise ValueError('model')
    answer = raw['answers']['route']
    probabilities = answer['probabilities']
    if answer['type'] != 'choice' or answer['choice'] not in ('fast', 'strong') or set(probabilities) != {'fast', 'strong'}:
        raise ValueError('shape')
    if not all(type(v) in (int, float) and math.isfinite(v) and 0 <= v <= 1 for v in probabilities.values()):
        raise ValueError('probability')
    if abs(sum(probabilities.values()) - 1) > .01 or probabilities[answer['choice']] < max(probabilities.values()) - 1e-6:
        raise ValueError('distribution')
    return 'fast' if answer['choice'] == 'fast' and probabilities['fast'] >= .8 else 'strong'

def exact(answer, expected):
    try:
        return json.dumps(json.loads(answer), sort_keys=True, ensure_ascii=False) == json.dumps(expected, sort_keys=True, ensure_ascii=False)
    except (ValueError, TypeError):
        return False

for route in routes:
    assert route['selected'] == (select(route['response']) if route['status'] == 'ok' else 'strong')
for record, job in zip(records, frozen['jobs']):
    assert all(record[k] == job[k] for k in ('case_id', 'configuration'))
    assert record['status'] == 'ok' and not record['timeout'] and record['exit_code'] == 0
    assert not record['tool_calls'] and all(not record['init'][k] for k in ('tools', 'mcp_servers', 'skills'))
lookup = {(r['case_id'], r['configuration']): r for r in records}
choices = {r['case_id']: r['selected'] for r in routes}
for policy in ('all_fast', 'all_strong', 'routed'):
    selected = [lookup[c, choices[c] if policy == 'routed' else policy[4:]] for c in cases]
    failures = [r['case_id'] for r in selected if not exact(r['answer'], cases[r['case_id']]['expected'])]
    actual = {'correct': 12 - len(failures), 'cases': 12,
              'cli_reported_usd': sum(r['reported_cost_usd'] for r in selected),
              'generator_elapsed_ms_sum': sum(r['elapsed_ms'] for r in selected), 'failures': failures}
    assert actual == saved['policies'][policy], policy
assert sum(r['status'] == 'ok' for r in routes) == saved['routes_ok']
assert sum(r['selected'] == 'fast' for r in routes) == saved['fast_routes']
assert sum(r.get('response', {}).get('usage', {}).get('input_tokens', 0) for r in routes) == saved['jev_input_tokens']
assert sum(r['reported_cost_usd'] for r in records) == saved['measurement_total_cli_reported_usd']
assert sorted({m for r in records for m in r['actual_models']}) == saved['actual_models']
print('Saved-response replay matched: fast 3/12, strong 12/12, routed 6/12. No service calls.')
