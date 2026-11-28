"""Read-only candidate observer. Not a production workflow or published check.

All metadata is fetched through gh's authenticated GitHub API transport. The
caller must run trusted source from a protected base, never from a PR checkout.
"""
import json
import re
import subprocess

from policy import Binding, evaluate, is_high_risk
from provenance import attest


class Pending(Exception):
    pass


def github_bytes(path):
    if not re.fullmatch(r'repos/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/[A-Za-z0-9_./?=&%-]+', path):
        raise ValueError('invalid API path')
    result = subprocess.run(['gh', 'api', path], capture_output=True, timeout=45)
    if result.returncode:
        raise ValueError('GitHub API read failed')
    return result.stdout


def github_json(path):
    return json.loads(github_bytes(path).decode('utf-8'))


def pages(path, key, get=github_json, max_pages=30):
    output = []
    for page in range(1, max_pages + 1):
        sep = '&' if '?' in path else '?'
        obj = get(f'{path}{sep}per_page=100&page={page}')
        items = obj if key is None else obj[key]
        if not isinstance(items, list):
            raise ValueError('invalid page')
        output.extend(items)
        if len(items) < 100:
            return output
    raise ValueError('pagination cap reached')


def observe(binding, get=github_json, download=github_bytes):
    root = 'repos/' + binding.repository
    pr_path = f'{root}/pulls/{binding.pr}'
    pr = get(pr_path)
    def is_current(p):
        return (p.get('state') == 'open' and p.get('draft') is False
                and p['head']['sha'] == binding.head and p['base']['sha'] == binding.base
                and p['base']['ref'] == 'main')
    def unchanged(p):
        return (is_current(p) and p.get('title') == pr.get('title') and p.get('body') == pr.get('body')
                and sorted(x['name'] for x in p.get('labels', [])) == sorted(x['name'] for x in pr.get('labels', [])))
    if not is_current(pr):
        raise ValueError('PR is not ready or its head/base changed')
    files = pages(pr_path + '/files', None, get)
    count = pr.get('changed_files')
    if type(count) is not int or count <= 0 or len(files) != count:
        raise ValueError('changed-file list incomplete')
    paths = []
    risk_paths = []
    for item in files:
        name = item.get('filename')
        if not isinstance(name, str) or not name:
            raise ValueError('missing changed-file path')
        paths.append(name)
        risk_paths.append(name)
        if item.get('status') == 'renamed':
            previous = item.get('previous_filename')
            if not isinstance(previous, str) or not previous:
                raise ValueError('renamed file missing previous path')
            risk_paths.append(previous)
    if not is_high_risk(risk_paths, pr['title'], pr.get('body') or '', [x['name'] for x in pr['labels']]):
        if not unchanged(get(pr_path)):
            raise ValueError('PR changed during evaluation')
        return True, 'no high-risk trigger'

    checks = pages(f'{root}/commits/{binding.head}/check-runs', 'check_runs', get, 10)
    expected = f'ai-review:{binding.pr}:{binding.base}:{binding.head}'
    matches = [c for c in checks if c.get('name') == 'AI Review Gate' and c.get('external_id') == expected
               and c.get('head_sha') == binding.head and (c.get('app') or {}).get('id') == 15368]
    if not matches:
        raise Pending('trusted review check absent')
    check = max(matches, key=lambda c: c['id'])
    if check.get('status') != 'completed':
        raise Pending('trusted review is running')
    if check.get('conclusion') != 'success':
        raise ValueError('trusted review did not approve')
    prefix = f'https://github.com/{binding.repository}/actions/runs/'
    found = re.findall(re.escape(prefix) + r'([1-9][0-9]*)\)', (check.get('output') or {}).get('summary', ''))
    if len(found) != 1:
        raise ValueError('missing unique trusted review run link')
    run = get(f'{root}/actions/runs/{found[0]}')
    workflow = get(f'{root}/actions/workflows/claude-agent-review.yml')
    if run.get('status') != 'completed':
        raise Pending('trusted review run is incomplete')
    artifacts = pages(f"{root}/actions/runs/{run['id']}/artifacts", 'artifacts', get)
    exact = f"ai-review-{run['id']}-{run['run_attempt']}"
    candidates = [a for a in artifacts if a.get('name') == exact]
    if len(candidates) != 1 or type(candidates[0].get('id')) is not int:
        raise ValueError('missing unique review artifact')
    artifact = candidates[0]
    archive = download(f"{root}/actions/artifacts/{artifact['id']}/zip")
    evidence = attest(binding, run, check, artifact, archive, workflow['id'], paths)
    result = evaluate(binding, risk_paths, pr['title'], pr.get('body') or '', [x['name'] for x in pr['labels']], evidence)
    if not unchanged(get(pr_path)):
        raise ValueError('PR changed during evaluation')
    return result
