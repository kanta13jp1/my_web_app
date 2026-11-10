#!/usr/bin/env python3
"""Read-only public platform facts for review; never approval or executable input."""
import base64
import json
import re


def canonical(context):
    return json.dumps(context, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def collect(diff, request, headers, baseline_workflow):
    # Only workflow diff sections can trigger lookups. Text is never executed.
    refs = set()
    workflow = False
    for line in diff.splitlines():
        if line.startswith('diff --git '):
            workflow = bool(re.fullmatch(
                r'diff --git a/(\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml) b/\1', line))
        if workflow:
            match = re.fullmatch(
                r'\+\s*(?:-\s*)?uses:\s*[\"\']?(actions/[A-Za-z0-9_-]+)@([0-9a-f]{40})[\"\']?(?:\s+#.*)?\s*', line)
            if match:
                refs.add(match.groups())
    if not refs:
        return None
    if len(refs) > 8:
        raise ValueError('Too many official action lookups; split the PR')
    facts = []
    for repo, sha in sorted(refs):
        root = 'https://api.github.com/repos/'+repo
        commit = request(root+'/commits/'+sha, headers)
        if commit.get('sha') != sha:
            raise ValueError('Official action commit mismatch')
        tags = request(root+'/tags?per_page=100', headers)
        if not isinstance(tags, list):
            raise ValueError('Invalid official action tags')
        names = sorted({t['name'] for t in tags
                        if t.get('commit', {}).get('sha') == sha
                        and isinstance(t.get('name'), str)
                        and re.fullmatch(r'v[0-9][0-9A-Za-z.+-]{0,39}', t['name'])})
        try:
            action = request(root+'/contents/action.yml?ref='+sha, headers)
        except RuntimeError as exc:
            # Only a genuinely missing filename permits the alternate manifest.
            # Authentication, rate limits and server failures must still fail closed.
            if str(exc) != 'API HTTP 404':
                raise
            action = request(root+'/contents/action.yaml?ref='+sha, headers)
        if action.get('encoding') != 'base64' or action.get('type') != 'file':
            raise ValueError('Invalid official action manifest')
        if len(action.get('content', '')) > 200_000:
            raise ValueError('Official action manifest exceeds limit')
        manifest = base64.b64decode(action['content']).decode('utf-8')
        # This is descriptive metadata, not an action-schema validator.
        runtime = re.search(r'^  using:\s*[\"\']?(node(?:16|20|24)|docker|composite)[\"\']?\s*$', manifest, re.M)
        facts.append({'repository': repo, 'commit': sha, 'matching_tags_first_100': names,
                      'runtime': runtime.group(1) if runtime else None,
                      'source': 'https://github.com/'+repo+'/commit/'+sha})
    return {'official_actions': facts,
            'baseline_review_workflow_uses_environment_deployment_false': bool(re.search(
                r'^    environment:\n      name: [^\n]+\n      deployment: false$', baseline_workflow, re.M)),
            'limits': 'First 100 current tags only; baseline syntax is an observation, not schema validation. Metadata never proves safety or approval.'}
