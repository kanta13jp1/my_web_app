"""UNAPPROVED read-only draft. CLI always exits 2; never authorizes publishing.
Not imported or executed during authoring. Standard library only.
"""
import argparse
import collections
import datetime
import json
import os
import re
import shutil
import subprocess
import threading
import time
import urllib.request

REPO = 'kanta13jp1/my_web_app'
SOURCE = 'fa36e621ea0e445cdfb3b8d145c85184e874685a'
PUBLIC = '399586d0eeda65f157819e21a5b2e47409b7e2ba'
MERGE = 'eead1ff3cf6f0fdbabb012912e0bb43873cb90c1'
PR_HEAD = '35d628c68c77ed55a9e097e517398da2ef895bec'
PR_BASE = '64fff3712ef0c88bc219ec66c7e5043b54b74049'
TREES = {PUBLIC: '503f39b0ebc6ca8402c914da5a9ce9f5260c2b37',
         SOURCE: '81d247963dd8e1fd6df0543e3adc2e5acf0caca3',
         MERGE: '5b4a0272e7bd86ea1367811f07964a48c749d01b'}
RUN = 43176832528
WORKFLOW_ID = 345716266
WORKFLOW_PATH = '.github/workflows/cloud-development.yml'
JOBS = {'full on GitHub runner', 'Platform release checklist E2E',
        'Note search pending E2E', 'Slide number check E2E',
        'Balance timestamp and history E2E', 'Savings and daily life plan E2E'}
# before/after blob identities; all five must remain 100644/blob.
UI_FILES = {
    'lib/pages/asset_management_page.dart': ('beed24eb38de1300d2a3d956ee3817a668c27644', 'db372edfeb9023ea5b822dc9a9a49d1652b254f1'),
    'lib/widgets/asset_calendar_shortfall_details.dart': ('f5b77db8a40e2c146b457cf2dffff410d8ee20ae', 'b302e160dbf18faefc5e79c42d949e3250b7dcec'),
    'lib/widgets/expense_classification_review.dart': ('9a5305c984af7f11fbdf52a93eb219bf7320269b', 'a8dca53e5d9d403b376f38ea3e375c5e60b15412'),
    'lib/widgets/feature_strategy_monitor_panel.dart': ('c2e96ac1a4a8fe5e92662e02c097df78f7e3b694', '3de60c8b064090f7bd8512a5b895de9a99405c94'),
    'lib/widgets/kgi_csf_kpi_panel.dart': ('5f0c5623c6a04da1ab5b68fe2a5999e706e5b1e7', '4d4dd7681d06dd4f27837f354f732ffb6917c935'),
}
DATA_MAIN = '53abbcbd9651583f322d6d3a629718d7e9d919b1'
DATA_PARENT = 'c016faf71750d8058a359ff71d96c72332aa5e36'
DATA_FILES = {'assets/data/kokumin_local_endorsements.json': ('e30c1c974dc90e485ee7135aa3808829397099b8', 'a6a15900b6fbe3eb5ce66c561f1cae68039f0a0a'), 'lib/data/dpj_official_endorsements.dart': ('9363fe777baff6f3cd6c56dd089772b4091904a9', '0538b8229556a6b0100fb1cff58eee002b9acae7')}
FILES = dict(UI_FILES, **DATA_FILES)
PR_FILES = {p: pair[1] for p, pair in UI_FILES.items()}
PR_FILES['docs/GROWTH_STRATEGY_ROADMAP.md'] = 'f3205d16a3597f69bc16c00c60d87cfba3227f0a'
UNRESOLVED = (
    'Owner conditions including PR5967 and this exact asset release unresolved.',
    'Publisher needs atomic nonce ledger, consumed/unknown outcome and rerun rejection.',
    'Controller immutable revision/self-reference and self-run identity not implemented.',
    'Hosting site/config/IAM, production artifact/configuration and rollback unattested.',
    'Out-of-band publishers and read/publish TOCTOU remain unresolved.',
)


class Blocked(Exception):
    pass


def require(condition, label):
    if not condition:
        raise Blocked(label)


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    def nonfinite(value):
        raise Blocked('nonfinite JSON')
    return json.loads(raw.decode('utf-8'), object_pairs_hook=pairs, parse_constant=nonfinite)


class Reader:
    """Only explicit GitHub GET. Trusted installed gh/config/auth is an external boundary."""
    def __init__(self):
        self.gh = shutil.which('gh')
        require(self.gh is not None, 'trusted gh installation missing')
        self.deadline = time.monotonic() + 240
        self.calls = 0

    def get(self, path):
        require(re.fullmatch(r'[A-Za-z0-9_./?=&%-]+', path) is not None and
                not path.startswith(('/', '-')) and '..' not in path, 'invalid internal endpoint')
        require(self.calls < 100 and time.monotonic() < self.deadline, 'GET budget exhausted')
        self.calls += 1
        argv = [self.gh, 'api', '--hostname', 'github.com', '--method', 'GET',
                'repos/' + REPO + '/' + path, '--header', 'Accept: application/vnd.github+json',
                '--header', 'Cache-Control: no-cache']
        proc = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, shell=False)
        buffers = [bytearray(), bytearray()]
        failed = threading.Event()
        def drain(stream, index, limit):
            try:
                while True:
                    chunk = stream.read(65536)
                    if not chunk:
                        break
                    if len(buffers[index]) + len(chunk) > limit:
                        failed.set()
                        proc.kill()
                        break
                    buffers[index].extend(chunk)
            except Exception:
                failed.set()
                proc.kill()
            finally:
                stream.close()
        threads = [threading.Thread(target=drain, args=(proc.stdout, 0, 8_000_000), daemon=True),
                   threading.Thread(target=drain, args=(proc.stderr, 1, 65536), daemon=True)]
        for thread in threads:
            thread.start()
        try:
            proc.wait(timeout=max(0.01, min(35, self.deadline-time.monotonic())))
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)
            raise Blocked('GitHub GET timeout; do not retry') from None
        finally:
            for thread in threads:
                thread.join(timeout=5)
        require(not any(t.is_alive() for t in threads), 'GET pipe failed to close')
        require(proc.returncode == 0 and not failed.is_set(), 'GET failed/oversized')
        return strict_json(bytes(buffers[0]))

    def collection(self, path, key):
        items, total = [], None
        for page in range(1, 11):
            sep = '&' if '?' in path else '?'
            value = self.get(path + sep + 'per_page=100&page=' + str(page))
            require(type(value.get('total_count')) is int, 'missing collection total')
            if total is None:
                total = value['total_count']
            require(0 <= total <= 1000 and value['total_count'] == total, 'collection changed/oversized')
            batch = value[key]
            require(type(batch) is list and len(batch) <= 100, 'invalid collection page')
            items.extend(batch)
            if len(items) == total:
                require(len({x['id'] for x in items}) == total, 'duplicate collection IDs')
                return items
            require(len(batch) == 100 and len(items) < total, 'incomplete collection')
        raise Blocked('pagination limit')


def leaves(reader, sha, expected_tree=None):
    require(re.fullmatch(r'[0-9a-f]{40}', sha) is not None, 'invalid commit SHA')
    commit = reader.get('git/commits/' + sha)
    require(commit['sha'] == sha, 'wrong commit')
    tree = commit['tree']['sha']
    require(re.fullmatch(r'[0-9a-f]{40}', tree) is not None, 'invalid tree SHA')
    require(expected_tree is None or tree == expected_tree, 'fixed tree mismatch')
    result = reader.get('git/trees/' + tree + '?recursive=1')
    require(result['sha'] == tree and result['truncated'] is False, 'wrong/truncated tree')
    entries = result['tree']
    require(type(entries) is list and len(entries) <= 30000, 'tree entry bound')
    require(len({x['path'] for x in entries}) == len(entries), 'duplicate tree path')
    out = {}
    for entry in entries:
        path = entry['path']
        require(type(path) is str and path and not path.startswith('/') and
                all(part not in ('', '.', '..') for part in path.split('/')), 'invalid path')
        require(re.fullmatch(r'[0-9a-f]{40}', entry['sha']) is not None, 'invalid leaf SHA')
        if entry['type'] != 'tree':
            require((entry['type'], entry['mode']) in {('blob', '100644'), ('blob', '100755'),
                    ('blob', '120000'), ('commit', '160000')}, 'unknown leaf mode/type')
            out[path] = {key: entry[key] for key in ('sha', 'mode', 'type')}
    return commit, out


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise Blocked('manifest redirect rejected')


def manifest():
    url = 'https://my-web-app-b67f4.web.app/version.json?asset_preflight=' + str(time.time_ns())
    request = urllib.request.Request(url, method='GET', headers={'Cache-Control': 'no-cache'})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=15) as response:
        require(response.status == 200, 'manifest HTTP status')
        raw = response.read(65537)
    require(len(raw) <= 65536, 'manifest size bound')
    value = strict_json(raw)
    require(value.get('commit') == PUBLIC and value.get('version') == '1.0.2278' and
            value.get('buildNumber') == '5836', 'public changed; stop and reconcile history')
    return {key: value[key] for key in ('commit', 'version', 'buildNumber')}


def non_docs(values):
    return {path: value for path, value in values.items() if not path.startswith('docs/')}


SOURCE_CHECKS = {130978576707: ('Audit stale EF references',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823643/job/130978576707'),
 130978576710: ('Compare reviewed Flutter baselines',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823605/job/130978576710'),
 130978576890: ('validate',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823642/job/130978576890'),
 130978576909: ('focused',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823664/job/130978576909'),
 130978577049: ('ownership-contract',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823646/job/130978577049'),
 130978577106: ('PR minimal E2E declaration',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823670/job/130978577106'),
 130978577108: ('High-risk ultrareview gate',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823823/job/130978577108'),
 130978577331: ('flutter-focused',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823646/job/130978577331'),
 130978577468: ('browser',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823860/job/130978577468'),
 130978577513: ('browser',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823846/job/130978577513'),
 130978577561: ('preflight',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823781/job/130978577561'),
 130978577563: ('audit',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823884/job/130978577563'),
 130978577568: ('GitHub Actions syntax',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130978577568'),
 130978577617: ('Playwright evidence contract',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823670/job/130978577617'),
 130978577687: ('AI Review Gate',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823883/job/130978577687'),
 130978577859: ('VM tests (0)',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130978577859'),
 130978577864: ('Security Check',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130978577864'),
 130978577905: ('VM tests (1)',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130978577905'),
 130978577917: ('Check ROADMAP destructive rewrite',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823958/job/130978577917'),
 130978577969: ('mario-lab / browser',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823881/job/130978577969'),
 130978577992: ('Static checks and web',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130978577992'),
 130978577996: ('mario-lab / contract',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823881/job/130978577996'),
 130978578104: ('quota',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823881/job/130978578104'),
 130978578150: ('browser',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823881/job/130978578150'),
 130978578241: ('deployment-scope',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823670/job/130978578241'),
 130978578419: ('Public E2E stability smoke',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823670/job/130978578419'),
 130978578498: ('Claude ultrareview (opt-in)',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823823/job/130978578498'),
 130978578727: ('Run trusted AI review',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823823/job/130978578727'),
 130978579876: ('mario-lab / course-audit',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823881/job/130978579876'),
 130978580662: ('Run trusted AI review',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823652/job/130978580662'),
 130978582738: ('High-risk ultrareview gate',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823652/job/130978582738'),
 130978583061: ('Claude ultrareview (opt-in)',
                'skipped',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823652/job/130978583061'),
 130978821222: ('AI Review Gate', 'success', 'https://github.com/kanta13jp1/my_web_app/runs/130978821222'),
 130981598210: ('Lint, Format, and Test',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130981598210'),
 130981626329: ('PR Comment',
                'success',
                'https://github.com/kanta13jp1/my_web_app/actions/runs/43156823853/job/130981626329')}
REQUIRED_CONTEXTS = ('AI Review Gate', 'Lint, Format, and Test', 'PR minimal E2E declaration', 'Public E2E stability smoke', 'Security Check')


def source_pr_checks(reader):
    """Bind historical merged-source checks to exact IDs, app, head and outcome.
    The one required Public E2E smoke was skipped at merge; it is NOT a browser pass.
    This observation does not authorize publishing or replace other release conditions.
    """
    def policy():
        value = reader.get('branches/main/protection/required_status_checks')
        require(value.get('strict') is True, 'strict source check protection changed')
        contexts = value.get('contexts')
        checks = value.get('checks')
        require(type(contexts) is list and len(contexts) == len(REQUIRED_CONTEXTS) and
                set(contexts) == set(REQUIRED_CONTEXTS), 'required source contexts changed')
        require(type(checks) is list and len(checks) == len(REQUIRED_CONTEXTS) and
                {(x.get('context'), x.get('app_id')) for x in checks} ==
                {(name, 15368) for name in REQUIRED_CONTEXTS}, 'required check provider changed')
    policy()
    rows = reader.collection('commits/' + PR_HEAD + '/check-runs?filter=all', 'check_runs')
    require(len(rows) == len(SOURCE_CHECKS) and
            {x['id'] for x in rows} == set(SOURCE_CHECKS), 'source check inventory changed')
    for row in rows:
        name, conclusion, details_url = SOURCE_CHECKS[row['id']]
        require(row.get('head_sha') == PR_HEAD and row.get('status') == 'completed' and
                row.get('name') == name and row.get('conclusion') == conclusion and
                row.get('app', {}).get('id') == 15368 and row.get('details_url') == details_url,
                'source check identity/provider/head/outcome mismatch')
    for context in REQUIRED_CONTEXTS:
        expected = [outcome for name, outcome, url in SOURCE_CHECKS.values() if name == context]
        require(expected and all(outcome == ('skipped' if context == 'Public E2E stability smoke'
                                           else 'success') for outcome in expected),
                'required source check expected outcome mismatch')
    policy()
    return {'head': PR_HEAD, 'checks': len(rows), 'success': 28, 'skipped': 7,
            'required_contexts': len(REQUIRED_CONTEXTS), 'app_id': 15368,
            'public_e2e_smoke': 'skipped_not_browser_success', 'publication_allowed': False}


def preserving_data(reader, before, after, merged):
    """Exact two-leaf provenance exception, separate from current-main equality."""
    require(len(UI_FILES) == 5 and len(DATA_FILES) == 2 and
            not set(UI_FILES) & set(DATA_FILES) and len(FILES) == 7,
            'source scope constants mismatch')
    data_commit, data_main = leaves(reader, DATA_MAIN)
    require([x['sha'] for x in data_commit['parents']] == [DATA_PARENT],
            'fixed data source sole parent mismatch')
    _, data_parent = leaves(reader, DATA_PARENT)
    changed = {p for p in data_main.keys() | data_parent.keys()
               if data_main.get(p) != data_parent.get(p)}
    require(changed == set(DATA_FILES), 'fixed data source delta not exact two files')
    candidate_non_docs, merged_non_docs = non_docs(after), non_docs(merged)
    differences = {p for p in candidate_non_docs.keys() | merged_non_docs.keys()
                   if candidate_non_docs.get(p) != merged_non_docs.get(p)}
    require(differences == set(DATA_FILES), 'reviewed merge exception not exact two data leaves')
    for path, (old, new) in DATA_FILES.items():
        old_leaf = dict(sha=old, mode='100644', type='blob')
        new_leaf = dict(sha=new, mode='100644', type='blob')
        require(before.get(path) == merged.get(path) == data_parent.get(path) == old_leaf and
                after.get(path) == data_main.get(path) == new_leaf,
                'fixed data before/after provenance mismatch')
    return {'source': DATA_MAIN, 'sole_parent': DATA_PARENT, 'files': sorted(DATA_FILES),
            'publication_allowed': False}


def full_run(reader):
    run = reader.get('actions/runs/' + str(RUN))
    require(run['id'] == RUN and run['head_sha'] == SOURCE and run['run_attempt'] == 1 and
            run['workflow_id'] == WORKFLOW_ID and run['path'] == WORKFLOW_PATH and
            run['name'] == 'Cloud Development Checks' and run['event'] == 'workflow_dispatch' and
            run['head_branch'] == 'codex/asset-material-source-preserved-20261112' and
            run['status'] == 'completed' and run['conclusion'] == 'success' and
            run['repository']['full_name'] == REPO and run['head_repository']['full_name'] == REPO,
            'candidate full identity/result/attempt mismatch')
    jobs = reader.collection('actions/runs/' + str(RUN) + '/attempts/1/jobs', 'jobs')
    require(len(jobs) == 6 and collections.Counter(x['name'] for x in jobs) ==
            collections.Counter(JOBS), 'candidate six-job multiset mismatch')
    require(all(x['run_id'] == RUN and x['run_attempt'] == 1 and x['head_sha'] == SOURCE and
                x['status'] == 'completed' and x['conclusion'] == 'success' for x in jobs),
            'candidate jobs not successful exact attempt')
    full = next(x for x in jobs if x['name'] == 'full on GitHub runner')
    steps = {x['name']: x for x in full['steps']}
    require(all(steps.get(name, {}).get('conclusion') == 'success' for name in
                ('Analyze in cloud', 'Test in cloud', 'Build Flutter Web in cloud')),
            'full profile core steps missing/not successful')


def release_state(reader, self_run):
    require(reader.get('actions/variables/PRODUCTION_DEPLOY_HOLD')['value'] == 'false',
            'hold missing/not false; never change hold')
    require(reader.get('actions/workflows/deploy-prod.yml')['state'] == 'disabled_manually',
            'normal production workflow not disabled')
    # Conservative: every other active run blocks, including nonproduction runs.
    for status in ('queued', 'in_progress', 'waiting', 'pending', 'requested'):
        runs = reader.collection('actions/runs?status=' + status, 'workflow_runs')
        require(all(x['id'] == self_run for x in runs), 'other active GitHub run')


def observe(nonce):
    """Returns observations with publication_allowed=False, NEVER authorization."""
    require(re.fullmatch(r'[0-9a-f]{32}', nonce or '') is not None, 'invalid nonce syntax')
    run_text = os.environ.get('GITHUB_RUN_ID', '')
    require(re.fullmatch(r'[1-9][0-9]{0,19}', run_text) is not None and
            os.environ.get('GITHUB_RUN_ATTEMPT') == '1', 'publisher ID/attempt1 missing; rerun forbidden')
    self_run = int(run_text)
    require(self_run != RUN, 'nonprod validation is not publisher')
    reader = Reader()
    start = manifest()
    release_state(reader, self_run)
    _, before = leaves(reader, PUBLIC, TREES[PUBLIC])
    commit, after = leaves(reader, SOURCE, TREES[SOURCE])
    require([x['sha'] for x in commit['parents']] == [PUBLIC], 'candidate sole parent mismatch')
    require(len(before) == len(after) == 10906, 'public/candidate count mismatch')
    delta = {p for p in before.keys() | after.keys() if before.get(p) != after.get(p)}
    require(delta == set(FILES), 'out-of-scope source change')
    for path, (old, new) in FILES.items():
        require(before[path] == dict(sha=old, mode='100644', type='blob') and
                after[path] == dict(sha=new, mode='100644', type='blob'), 'before/after leaf mismatch')
    pr = reader.get('pulls/6021')
    require(pr['number'] == 6021 and pr['merged'] is True and pr['state'] == 'closed' and
            pr['merge_commit_sha'] == MERGE and pr['head']['sha'] == PR_HEAD and
            pr['base']['sha'] == PR_BASE and pr['base']['ref'] == 'main' and
            pr['head']['repo']['full_name'] == REPO and pr['base']['repo']['full_name'] == REPO,
            'source PR fixed head/base/merge mismatch')
    _, source_pr = leaves(reader, PR_HEAD)
    _, source_base = leaves(reader, PR_BASE)
    merge_commit, merged = leaves(reader, MERGE, TREES[MERGE])
    require([x['sha'] for x in merge_commit['parents']] == [PR_BASE, PR_HEAD], 'merge parents mismatch')
    require({p for p in source_base.keys() | source_pr.keys() if source_base.get(p) != source_pr.get(p)}
            == set(PR_FILES), 'source PR six-file inventory mismatch')
    require(all(source_pr[p] == dict(sha=blob, mode='100644', type='blob') and
                merged[p] == source_pr[p] for p, blob in PR_FILES.items()), 'source PR leaf mismatch')
    data_provenance = preserving_data(reader, before, after, merged)
    source_checks = source_pr_checks(reader)
    full_run(reader)
    main_sha = reader.get('git/ref/heads/main')['object']['sha']
    _, current_main = leaves(reader, main_sha)
    require(non_docs(after) == non_docs(current_main), 'current main non-doc changed; re-review')
    docs_count = sum(after.get(p) != current_main.get(p) for p in after.keys() | current_main.keys())
    full_run(reader)  # reject rerun begun during observation
    release_state(reader, self_run)
    require(source_pr_checks(reader) == source_checks, 'source check observations changed')
    require(manifest() == start and time.monotonic() < reader.deadline, 'freshness changed/exhausted')
    return {'status': 'read_observations_only_release_blocked', 'publication_allowed': False,
            'source': SOURCE, 'public': PUBLIC, 'source_PR_merge': MERGE, 'latest_main': main_sha,
            'latest_main_docs_difference_count': docs_count, 'nonprod_full': RUN, 'attempt': 1,
            'jobs_success': 6, 'source_pr_checks': source_checks, 'preserved_main_data': data_provenance,
            'unresolved': list(UNRESOLVED),
            'observed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--operation-nonce', required=True)
    args = parser.parse_args()
    try:
        result = observe(args.operation_nonce)
    except Blocked as error:
        # Blocked messages are fixed internal labels, never external payloads.
        result = {'status': 'blocked_guard_failure', 'publication_allowed': False,
                  'safe_reason': str(error), 'unresolved': list(UNRESOLVED), 'retry_allowed': False}
    except Exception as error:
        # Never print external exception text, remote payload, stderr, env or nonce.
        result = {'status': 'blocked_read_error_or_guard_failure', 'publication_allowed': False,
                  'safe_exception_type': type(error).__name__,
                  'unresolved': list(UNRESOLVED), 'retry_allowed': False}
    print(json.dumps(result, ensure_ascii=True, sort_keys=True))
    return 2  # Intentionally cannot signal release-ready success.


if __name__ == '__main__':
    raise SystemExit(main())
