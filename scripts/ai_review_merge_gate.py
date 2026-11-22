#!/usr/bin/env python3
"""Expose a real trusted review as a PR workflow check; never review or approve."""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import subprocess
import time
import zipfile

CHECK = 'AI Review Gate'
WORKFLOW = '.github/workflows/claude-agent-review.yml'
LIMIT = 1_000_000


class PendingReview(Exception):
    """Only incomplete remote work is retryable."""


def require(condition, message):
    if not condition:
        raise ValueError(message)


def api_bytes(path):
    result = subprocess.run(['gh', 'api', path], capture_output=True, timeout=60)
    require(result.returncode == 0, 'GitHub API request failed; approval unavailable')
    return result.stdout


def api(path):
    return json.loads(api_bytes(path))


def evidence_from_zip(data):
    require(len(data) <= LIMIT, 'Review archive exceeds size limit')
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        entries = archive.infolist()
        require(len(entries) == 1 and entries[0].filename == 'evidence.json',
                'Unexpected review artifact contents')
        require(entries[0].file_size <= LIMIT, 'Review evidence exceeds size limit')
        return json.loads(archive.read(entries[0]))


def verify_evidence(evidence, expected, check, run):
    for key in ('repository', 'pr', 'head', 'base'):
        require(evidence.get(key) == expected[key], 'Review evidence mismatch: '+key)
    require(evidence.get('workflow_sha') == expected['base'], 'Review source is not current trusted base')
    require(evidence.get('run_id') == str(run['id']) and
            evidence.get('run_attempt') == str(run['run_attempt']), 'Review run binding mismatch')
    require(evidence.get('check_id') == check['id'], 'Review check binding mismatch')
    require(evidence.get('status') == 'approved' and evidence.get('complete_diff') is True,
            'Review is not a complete approval')
    require(bool(evidence.get('response_id')), 'Missing actual provider response')
    review = evidence.get('review', {})
    require(review.get('verdict') == 'approve', 'Review did not approve')
    for key in ('head', 'base', 'input_sha256'):
        require(review.get(key) == evidence.get(key), 'Provider review binding mismatch: '+key)
    require(bool(re.fullmatch(r'[0-9a-f]{64}', evidence.get('input_sha256', ''))),
            'Missing review input digest')
    require(not any(f.get('blocking') for f in review.get('findings', [])), 'Blocking review finding')


def observe(expected, get=api, download=api_bytes):
    root = 'repos/'+expected['repository']
    pr = get(root+'/pulls/'+str(expected['pr']))
    require(pr['state'] == 'open' and not pr.get('draft') and pr['base']['ref'] == 'main',
            'PR is not open and ready for main')
    require(pr['head']['sha'] == expected['head'] and pr['base']['sha'] == expected['base'],
            'PR head/base changed; require a new review and gate')
    binding = f"ai-review:{expected['pr']}:{expected['base']}:{expected['head']}"
    checks = []
    page = 1
    while True:
        batch = get(root+'/commits/'+expected['head']+f'/check-runs?per_page=100&page={page}')['check_runs']
        checks.extend(c for c in batch if c.get('name') == CHECK and c.get('external_id') == binding
                      and c.get('head_sha') == expected['head'] and c.get('app', {}).get('id') == 15368)
        if len(batch) < 100:
            break
        page += 1
        require(page <= 10, 'Too many checks to verify safely')
    if not checks:
        raise PendingReview('Waiting for the trusted head/base-bound review')
    check = max(checks, key=lambda c: c['id'])
    if check['status'] != 'completed':
        raise PendingReview('Trusted review is still running')
    require(check.get('conclusion') == 'success', 'Trusted review failed or requested changes')
    pattern = re.escape(f"https://github.com/{expected['repository']}/actions/runs/")+r'([1-9][0-9]*)\)'
    ids = re.findall(pattern, check.get('output', {}).get('summary', ''))
    require(len(ids) == 1, 'Missing unique trusted review run link')
    run = get(root+'/actions/runs/'+ids[0])
    workflow = get(root+'/actions/workflows/claude-agent-review.yml')
    require(run['workflow_id'] == workflow['id'] and run['path'].split('@')[0] == WORKFLOW,
            'Review came from a different workflow')
    require(run['repository']['full_name'] == expected['repository'] and
            run['event'] in {'pull_request_target', 'workflow_dispatch'}, 'Untrusted review run origin')
    if run['status'] != 'completed':
        raise PendingReview('Waiting for trusted review artifact publication')
    require(run.get('conclusion') == 'success', 'Trusted review workflow did not succeed')
    artifacts = get(root+'/actions/runs/'+ids[0]+'/artifacts?per_page=100')['artifacts']
    name = f"ai-review-{run['id']}-{run['run_attempt']}"
    matches = [a for a in artifacts if a['name'] == name]
    require(len(matches) == 1, 'Missing unique review evidence artifact')
    artifact = matches[0]
    require(not artifact['expired'] and 0 < artifact['size_in_bytes'] <= LIMIT,
            'Review artifact expired or unsupported size')
    evidence = evidence_from_zip(download(root+'/actions/artifacts/'+str(artifact['id'])+'/zip'))
    verify_evidence(evidence, expected, check, run)
    return ids[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pr', type=int, required=True)
    parser.add_argument('--head', required=True)
    parser.add_argument('--base', required=True)
    args = parser.parse_args()
    require(args.pr > 0 and all(re.fullmatch(r'[0-9a-f]{40}', v) for v in (args.head, args.base)),
            'Invalid PR/commit binding')
    expected = dict(repository=os.environ['GITHUB_REPOSITORY'], pr=args.pr, head=args.head, base=args.base)
    deadline = time.monotonic()+900
    while True:
        try:
            run_id = observe(expected)
            print(f"Verified trusted AI approval for PR #{args.pr} at {args.head}; review run {run_id}")
            return
        except PendingReview as error:
            require(time.monotonic() < deadline, 'Timed out without verified AI review approval')
            print(str(error), flush=True)
            time.sleep(10)


if __name__ == '__main__':
    main()
