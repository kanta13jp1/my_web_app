"""Fail closed before a reviewed, typing-only release on the public lineage."""
import argparse
import json
import os
import re
import subprocess
import urllib.request

REPO = 'kanta13jp1/my_web_app'
SITE = 'https://my-web-app-b67f4.web.app'
GAME = frozenset({
    'docs/typing-game/online-records-plan.md',
    'docs/typing-game/records-schema.draft.sql',
    'lib/models/typing_game.dart',
    'lib/pages/typing_game_page.dart',
    'lib/services/typing_composition_bridge_stub.dart',
    'lib/services/typing_composition_bridge_web.dart',
    'lib/services/typing_score_service.dart',
    'lib/widgets/typing_records_panel.dart',
    'test/e2e/typing_game.spec.ts',
    'test/integration/typing_records_supabase_test.dart',
    'test/models/typing_game_test.dart',
    'test/pages/typing_game_page_test.dart',
    'test/services/typing_score_service_test.dart',
    'test/sql/typing_records_test.sql',
    'test/widgets/typing_records_panel_test.dart',
})
SUPPORT = frozenset({
    '.github/workflows/typing-evolution-release.yml',
    'scripts/typing_evolution_release_guard.py',
    'scripts/typing_evolution_release_guard_test.py',
})
REQUIRED = frozenset({'AI Review Gate', 'Lint, Format, and Test',
                      'Security Check', 'PR minimal E2E declaration',
                      'High-risk ultrareview gate'})



VALIDATION_WORKFLOW_BLOB = '54f7da51525e2f32434b5e0b06c7ed0c1e81f966'
VALIDATION_STEPS = {
    'database': {'Test draft in disposable PostgreSQL only'},
    'typing': {'Format candidate and preserve patch', 'Analyze typing implementation',
               'Typing model and widget tests', 'Build standalone game',
               'Desktop and emulated mobile browser input', 'Build integrated app',
               'Existing published game model regressions',
               'Integrated new route and existing published game', 'Require clean formatting'},
    'real-auth': {'Start disposable local auth stack',
                  'Apply only typing draft to disposable database',
                  'Real Auth and PostgREST integration', 'Require clean auth test formatting'},
}


def validation_evidence(run, head, workflow_blob, jobs):
    if (run.get('head_sha') != head or run.get('conclusion') != 'success' or
            run.get('head_repository', {}).get('full_name') != REPO or
            run.get('path') != '.github/workflows/cloud-development.yml' or
            run.get('event') not in {'push', 'workflow_dispatch'} or
            workflow_blob != VALIDATION_WORKFLOW_BLOB):
        raise ValueError('Validation is not the exact reviewed workflow and candidate')
    for name, required in VALIDATION_STEPS.items():
        matching = [j for j in jobs if j.get('name') == name]
        if len(matching) != 1 or matching[0].get('conclusion') != 'success':
            raise ValueError('Missing successful validation job: ' + name)
        successful = {s['name'] for s in matching[0].get('steps', [])
                      if s.get('conclusion') == 'success'}
        if not required <= successful:
            raise ValueError('Required validation steps did not execute: ' + name)


def command(*args):
    return subprocess.check_output(args, text=True, encoding='utf-8').strip()


def api(path):
    return json.loads(command('gh', 'api', 'repos/' + REPO + '/' + path))


def sha(value):
    if not re.fullmatch('[0-9a-f]{40}', value):
        raise ValueError('Expected immutable lowercase SHA')
    return value


def reviewed(pr, checks, head, base, extra_required=()):
    if (pr.get('state') != 'closed' or not pr.get('merged') or
            pr['base']['ref'] != 'main' or pr['base']['sha'] != base or
            pr['head']['repo']['full_name'] != REPO or
            pr['head']['sha'] != head or not pr.get('merge_commit_sha')):
        raise ValueError('PR is not the merged, exact source selection')
    approved = False
    successful = set()
    latest = {}
    evidence = []
    for index, check in enumerate(checks):
        if check.get('app', {}).get('id') != 15368:
            continue
        summary = check.get('output', {}).get('summary') or ''
        if check['name'] == 'AI Review Gate' and head in summary and base in summary and 'Result:' in summary:
            evidence.append((check.get('id', index), check))
        previous = latest.get(check['name'])
        if previous is None or check.get('id', index) > previous.get('id', -1):
            latest[check['name']] = check
    for check in latest.values():
        if check.get('conclusion') == 'success':
            successful.add(check['name'])
    if evidence:
        review = max(evidence, key=lambda pair: pair[0])[1]
        approved = (review.get('conclusion') == 'success' and
                    'Result: **approved**.' in (review.get('output', {}).get('summary') or ''))
    public = latest.get('Public E2E stability smoke')
    if public is None or public.get('conclusion') not in {'success', 'skipped'}:
        raise ValueError('Missing or failed required public smoke check')
    if not approved or not (REQUIRED | set(extra_required)) <= successful:
        raise ValueError('Missing genuine head/base-bound review or required CI')


def selection(changed, candidate_blobs, source_blobs, support_blobs):
    if set(changed) != GAME | SUPPORT:
        raise ValueError('Release includes missing or unrelated files')
    for path in GAME:
        if candidate_blobs[path] != source_blobs[path]:
            raise ValueError('Game differs from reviewed source: ' + path)
    for path in SUPPORT:
        if candidate_blobs[path] != support_blobs[path]:
            raise ValueError('Release tooling differs from reviewed source: ' + path)


def git(*args):
    return command('git', *args)


def blobs(ref, paths):
    result = {}
    for path in paths:
        row = git('ls-tree', ref, '--', path).split()
        if len(row) < 4 or row[0] != '100644' or row[1] != 'blob':
            raise ValueError('Missing or non-regular selected file: ' + path)
        result[path] = row[2]
    return result


def production_hold(value):
    # Actions exposes repository variables through vars, not GITHUB_TOKEN REST.
    # Missing/empty values must stop a release just like an explicit hold.
    if value != 'false':
        raise ValueError('Production hold is active or not explicitly disabled')


def run(args):
    for value in [args.expected_head, args.public_base, args.source_head,
                  args.source_base, args.support_head, args.support_base,
                  args.validation_head]:
        sha(value)
    if git('rev-parse', 'HEAD') != args.expected_head:
        raise ValueError('Checkout drift')
    request = urllib.request.Request(SITE + '/version.json?typing=' + args.expected_head,
                                    headers={'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(request, timeout=30) as response:
        public = json.load(response)
    if public.get('commit') != args.public_base:
        raise ValueError('Public base changed; rebuild and revalidate selection')
    if api('actions/workflows/deploy-prod.yml')['state'] != 'disabled_manually':
        raise ValueError('Normal deployment must remain disabled')
    production_hold(os.environ.get('PRODUCTION_DEPLOY_HOLD'))
    for number, head, base in [(args.source_pr, args.source_head, args.source_base),
                               (args.support_pr, args.support_head, args.support_base)]:
        pr = api('pulls/' + str(number))
        checks = json.loads(command('gh', 'api', '--paginate', '--slurp',
            'repos/' + REPO + '/commits/' + head + '/check-runs?per_page=100'))
        reviewed(pr, [c for page in checks for c in page['check_runs']], head, base,
                 {'Typing release guard tests'} if number == args.support_pr else set())
        git('merge-base', '--is-ancestor', pr['merge_commit_sha'], 'origin/main')
    git('merge-base', '--is-ancestor', args.public_base, args.expected_head)
    changed = git('diff', '--name-only', args.public_base, args.expected_head).splitlines()
    selection(changed, blobs(args.expected_head, GAME | SUPPORT),
              blobs(args.source_head, GAME), blobs(args.support_head, SUPPORT))
    validation = api('actions/runs/' + str(args.validation_run))
    if (validation['head_sha'] != args.validation_head or
            validation['conclusion'] != 'success' or validation['event'] not in {'workflow_dispatch', 'push'} or
            validation['path'] != '.github/workflows/cloud-development.yml'):
        raise ValueError('Missing successful immutable public-base validation')
    validation_evidence(validation, args.validation_head, git('rev-parse', args.validation_head + ':.github/workflows/cloud-development.yml'), api('actions/runs/' + str(args.validation_run) + '/jobs?per_page=100')['jobs'])
    # The previously tested public-base tree may differ only in reviewed release
    # tooling and its isolated validation workflow; all runtime bytes must match.
    differences = set(git('diff', '--name-only', args.validation_head,
                          args.expected_head).splitlines())
    # The final PR also fixes the existing test-only route registry. Its blob
    # is bound to the reviewed source above and does not alter runtime code.
    if not differences <= SUPPORT | {'.github/workflows/cloud-development.yml'}:
        raise ValueError('Candidate differs from tested public application tree')
    print(json.dumps({'public_base': args.public_base, 'candidate': args.expected_head,
                      'source_pr': args.source_pr, 'support_pr': args.support_pr,
                      'selected_game_files': len(GAME), 'validation_run': args.validation_run}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['expected-head', 'public-base', 'source-head', 'source-base',
                 'support-head', 'support-base', 'validation-head']:
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--source-pr', type=int, required=True)
    parser.add_argument('--support-pr', type=int, required=True)
    parser.add_argument('--validation-run', type=int, required=True)
    run(parser.parse_args())
