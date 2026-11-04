"""Fixed workflow-dispatch wrapper for the synthetic PR fixture only.

Never fakes pull_request identity or calls the product runner's main().
GitHub service stop is verified by its existing Service, not deletion.
"""
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

REPO = 'kanta13jp1/my_web_app'
BRANCH = 'refs/heads/codex/asset-pref-cli-execbatch-diagnostic-20261104'
WORKFLOW = REPO+'/.github/workflows/cloud-development.yml@'+BRANCH
PR_HEAD = 'e765b12e38a8b4ffdf185a940a763dc789946c4f'
PR_BASE = '44bb4105e0a1ceef2815461e95677972911839e8'
ROOT = Path(__file__).resolve().parents[2]
RUNNER = 'scripts/asset_pref_truncate_fixture/runner.py'
MIGRATION = 'supabase/migrations/20261103063701_restrict_asset_pref_mirror_truncate.sql'
PREFIX = 'scripts/asset_pref_truncate_fixture/'
INPUTS = {
 RUNNER:'2a0ce9a1479ab45e0f153d557a117fc24189af64eab13b283fd19be0b4fba3ee',
 MIGRATION:'24e38d3b06d1aeb5d5fd6bfea2bec64c303d4fdad9a45b51f0af980a48cf9db8',
 PREFIX+'fixture_setup.sql.txt':'d0635f7b249e26e93b3f2c2775b249e332653681e00698780f72a742affbb92d',
 PREFIX+'revoke_fixture_setup_v5_review_stopped.sql.txt':'f2742dd2ec380e9dfba2133e9c9f63a5d6f9a596a181e7b747758221c8042679',
 PREFIX+'revoke_fixture_negative_v3_review_stopped.sql.txt':'b0fb6feb4c3913091a6f705459bae129cd9b06923e85ff19fcf93614d75c75e3',
 PREFIX+'revoke_fixture_positive_v3_review_stopped.sql.txt':'cdce6814db69af24d04345673f0743a257d225e4681702495ae9539f1bd37465',
 PREFIX+'revoke_truncate_candidate_review_stopped.sql.txt':'1baae5293834c0b7afd524947512013e8ac339aca5195b3f7528dae26ff9f36f',
 PREFIX+'revoke_non_target_privilege_matrix_review_stopped.sql.txt':'19428281a309c45eb4d7ba92577f984d6ab7caf36842f3ea47792f94fbe8cbf3',
}
STOP = b"\\set ON_ERROR_STOP on\ndo $review_stop$ begin raise exception 'REVIEW ONLY: execution prohibited'; end $review_stop$;\n"


class FixtureFailure(RuntimeError):
    def __init__(self, failure, cleanup):
        self.failure, self.cleanup = failure, cleanup
        super().__init__('fixture_failure='+str(failure)+'; service_cleanup='+cleanup)


def verify_identity(env):
    run, attempt = env.get('GITHUB_RUN_ID',''), env.get('GITHUB_RUN_ATTEMPT','')
    head, expected = env.get('GITHUB_SHA',''), env.get('EXPECTED_DIAGNOSTIC_HEAD','')
    if (env.get('GITHUB_ACTIONS') != 'true' or env.get('RUNNER_ENVIRONMENT') != 'github-hosted'
        or env.get('GITHUB_REPOSITORY') != REPO or env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'
        or env.get('GITHUB_JOB') != 'privilege_regression' or env.get('GITHUB_REF') != BRANCH
        or env.get('GITHUB_WORKFLOW_REF') != WORKFLOW or not re.fullmatch(r'[0-9]+',run)
        or not re.fullmatch(r'[0-9]+',attempt) or not re.fullmatch(r'[0-9a-f]{40}',head)
        or expected != head):
        raise RuntimeError('untrusted dispatch identity')
    return run+'-'+attempt


def verify_inputs():
    contents = {}
    for name, digest in INPUTS.items():
        path = ROOT/name
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(ROOT):
            raise RuntimeError('invalid fixed input path')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError('fixed input hash mismatch')
        contents[name] = data
    if contents[PREFIX+'revoke_truncate_candidate_review_stopped.sql.txt'] != STOP+contents[MIGRATION]:
        raise RuntimeError('STOP candidate differs from current PR migration')
    return contents


def verify_pr(contents, token, config_dir):
    if not token:
        raise RuntimeError('read-only GitHub token unavailable')
    env={'PATH':'/usr/local/bin:/usr/bin:/bin','LANG':'C','HOME':config_dir,
         'GH_CONFIG_DIR':config_dir,'GH_TOKEN':token}
    def api(path):
        result=subprocess.run(['gh','api','repos/'+REPO+'/'+path],env=env,
                              capture_output=True,timeout=30,check=False)
        if result.returncode != 0: raise RuntimeError('PR read-only API failed')
        return json.loads(result.stdout)
    pr=api('pulls/5980')
    if (pr['state']!='open' or pr['head']['sha']!=PR_HEAD or pr['base']['sha']!=PR_BASE
        or pr['head']['repo']['full_name']!=REPO
        or pr['head']['ref']!='codex/asset-pref-truncate-migration-20261103'):
        raise RuntimeError('PR head, base or ownership changed')
    obj=api('contents/'+MIGRATION+'?ref='+PR_HEAD)
    if obj.get('encoding')!='base64' or base64.b64decode(obj['content'],validate=False)!=contents[MIGRATION]:
        raise RuntimeError('PR migration bytes changed')


def run_owned(module, build_service, verify_pr_now, sources, stopped_setup):
    service=None
    failure=None
    cleanup='unconfirmed'
    try:
        verify_pr_now()
        service=build_service()
        service.initialize(sources,stopped_setup)
        verify_pr_now()
        module.revoke_checks(service,sources)
        module.matrix_checks(service,sources)
        verify_pr_now()
    except BaseException as exc:
        failure=type(exc).__name__
    finally:
        if service is not None:
            try:
                service.stop_owned()
                cleanup='stopped'
            except BaseException as exc:
                cleanup='stop_failed_'+type(exc).__name__
    if failure is None and cleanup=='stopped':
        try: verify_pr_now()
        except BaseException as exc: failure=type(exc).__name__
    if failure is not None or cleanup!='stopped':
        raise FixtureFailure(failure,cleanup)
    return {'service_stopped':True,'service_removal':'github_actions_cleanup_unverified'}


def run():
    label=verify_identity(os.environ)
    cid=os.environ.get('FIXTURE_SEQUENTIAL_ID','')
    network=os.environ.get('FIXTURE_NETWORK_NAME','')
    if not re.fullmatch(r'[0-9a-f]{64}',cid) or not re.fullmatch(r'github_network_[0-9a-f]{32}',network):
        raise RuntimeError('invalid GitHub service identity')
    contents=verify_inputs()
    spec=importlib.util.spec_from_file_location('fixed_synthetic_runner',ROOT/RUNNER)
    if spec is None or spec.loader is None: raise RuntimeError('runner load failed')
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sources,stopped_setup=module.load_sources()
    # GH API token is confined to an isolated process environment; never printed.
    token=os.environ.get('GH_TOKEN','')
    env={'PATH':'/usr/local/bin:/usr/bin:/bin','LANG':'C'}
    with tempfile.TemporaryDirectory(prefix='synthetic-diagnostic-') as config:
        docker=['/usr/bin/docker','--config',config,'--host','unix:///var/run/docker.sock']
        image=json.loads(subprocess.run(docker+['image','inspect',module.IMAGE],env=env,
            capture_output=True,text=True,check=True,timeout=15).stdout)[0]
        if module.IMAGE not in (image.get('RepoDigests') or []):
            raise RuntimeError('pinned service image missing')
        def build(): return module.Service(cid,'sequential',label,docker,env,image,network)
        def check_pr(): verify_pr(contents,token,config)
        result=run_owned(module,build,check_pr,sources,stopped_setup)
    print('SYNTHETIC_DISPATCH_COMPLETE '+json.dumps({'diagnostic_head':os.environ['GITHUB_SHA'],
        'pr_head':PR_HEAD,'result':result,'scope':'guarded psql PG17; not CLI or production'},sort_keys=True),flush=True)


class UnitTests(unittest.TestCase):
    def test_fixed_inputs_and_pr_reader(self):
        contents=verify_inputs()
        self.assertEqual(len(contents),8)
        pr={'state':'open','head':{'sha':PR_HEAD,'ref':'codex/asset-pref-truncate-migration-20261103',
                                   'repo':{'full_name':REPO}},'base':{'sha':PR_BASE}}
        def fake_run(cmd,**kwargs):
            self.assertEqual(kwargs['env']['GH_TOKEN'],'synthetic-token')
            if cmd[-1].endswith('/pulls/5980'):out=pr
            else:out={'encoding':'base64','content':base64.b64encode(contents[MIGRATION]).decode('ascii')}
            return types.SimpleNamespace(returncode=0,stdout=json.dumps(out).encode(),stderr=b'')
        with patch.object(subprocess,'run',side_effect=fake_run):
            verify_pr(contents,'synthetic-token','/tmp/synthetic-mock')
            pr['head']['sha']='b'*40
            with self.assertRaises(RuntimeError):verify_pr(contents,'synthetic-token','/tmp/synthetic-mock')

    def test_identity_fails_closed(self):
        env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':REPO,
             'GITHUB_EVENT_NAME':'workflow_dispatch','GITHUB_JOB':'privilege_regression',
             'GITHUB_REF':BRANCH,'GITHUB_WORKFLOW_REF':WORKFLOW,'GITHUB_RUN_ID':'1',
             'GITHUB_RUN_ATTEMPT':'2','GITHUB_SHA':'a'*40,'EXPECTED_DIAGNOSTIC_HEAD':'a'*40}
        self.assertEqual(verify_identity(env),'1-2')
        for key in ('GITHUB_EVENT_NAME','GITHUB_JOB','GITHUB_REF','GITHUB_WORKFLOW_REF',
                    'GITHUB_REPOSITORY','RUNNER_ENVIRONMENT','EXPECTED_DIAGNOSTIC_HEAD'):
            bad=dict(env);bad[key]='wrong'
            with self.subTest(key=key),self.assertRaises(RuntimeError):verify_identity(bad)

    def test_stop_and_failure_paths(self):
        calls=[]
        class Service:
            def initialize(self,*args):calls.append('initialize')
            def stop_owned(self):calls.append('stop')
        class Module:
            @staticmethod
            def revoke_checks(*args):calls.append('revoke')
            @staticmethod
            def matrix_checks(*args):calls.append('matrix')
        def check():calls.append('pr')
        out=run_owned(Module,Service,check,{},'')
        self.assertEqual(calls,['pr','initialize','pr','revoke','matrix','pr','stop','pr'])
        self.assertEqual(out['service_removal'],'github_actions_cleanup_unverified')
        calls.clear()
        def bad_build():raise RuntimeError('unverified service')
        with self.assertRaisesRegex(RuntimeError,'service_cleanup=unconfirmed'):
            run_owned(Module,bad_build,check,{},'')
        self.assertNotIn('stop',calls)
        calls.clear()
        class BadModule(Module):
            @staticmethod
            def matrix_checks(*args):raise RuntimeError('fixture failure')
        with self.assertRaisesRegex(RuntimeError,'fixture_failure=RuntimeError; service_cleanup=stopped'):
            run_owned(BadModule,Service,check,{},'')
        self.assertIn('stop',calls)
        calls.clear()
        class BadStop(Service):
            def stop_owned(self):raise RuntimeError('stop failed')
        with self.assertRaisesRegex(RuntimeError,'service_cleanup=stop_failed_RuntimeError'):
            run_owned(Module,BadStop,check,{},'')
        for fail_at in (1,3,4):
            calls.clear()
            count=[0]
            def changed_pr():
                count[0]+=1;calls.append('pr')
                if count[0]==fail_at: raise RuntimeError('head changed')
            with self.subTest(fail_at=fail_at),self.assertRaises(FixtureFailure) as raised:
                run_owned(Module,Service,changed_pr,{},'')
            self.assertEqual(raised.exception.cleanup,'unconfirmed' if fail_at==1 else 'stopped')
            self.assertEqual('stop' in calls,fail_at!=1)


if __name__=='__main__':
    if sys.argv[1:]==['--self-test']:
        unittest.main(argv=[sys.argv[0]])
    elif sys.argv[1:]==[]:
        try: run()
        except FixtureFailure as exc:
            print('SYNTHETIC_DISPATCH_FAILURE fixture_type='+str(exc.failure)+
                  '; service_cleanup='+exc.cleanup+'; GH removal unverified',file=sys.stderr)
            sys.exit(1)
        except BaseException as exc:
            # Prior to verified Service construction, the GH service is not touched.
            print('SYNTHETIC_DISPATCH_FAILURE type='+type(exc).__name__+
                  '; see checked service status; GH cleanup may be unconfirmed',file=sys.stderr)
            sys.exit(1)
    else:
        raise SystemExit('unsupported invocation')
