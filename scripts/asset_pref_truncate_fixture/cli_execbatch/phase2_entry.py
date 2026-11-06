"""REVIEW ONLY: phase2 entry pinned to the designated diagnostic parent.

No direct execution. A separately reviewed workflow must pin this file and its
inputs and preserve FIFO. Parent, PR and immutable inputs are checked at runtime.
"""
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
PHASE2_SHA='4d0d8487057ef223c888f706c7b09fad1be623c54e989466c95ab6f016842346'
PR_HEAD='85394a8e938a7c4bda08e32dd4cfff9ede623e57'
PR_BASE='f420ca99541125452407e974958e7704f1d5b429'
MIGRATION='supabase/migrations/20261103063701_restrict_asset_pref_mirror_truncate.sql'
PARENT='24b629750575eb64cc06abea060987dcc01e684b'


def load_fixed():
    path=HERE/'phase2.py'
    if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=PHASE2_SHA:
        raise RuntimeError('fixed phase2 module mismatch')
    spec=importlib.util.spec_from_file_location('fixed_phase2',path)
    phase2=importlib.util.module_from_spec(spec);spec.loader.exec_module(phase2)
    return phase2,phase2.load_runner()


def command(args,env):
    result=subprocess.run(args,env=env,capture_output=True,check=False,timeout=40)
    if result.returncode!=0 or len(result.stdout)>1024*1024 or len(result.stderr)>65536:
        raise RuntimeError('fixed context command failed')
    return result.stdout


def verify_context(base, env, candidate):
    if not re.fullmatch(r'[0-9a-f]{40}',PARENT):
        raise RuntimeError('diagnostic parent has not been reviewed and pinned')
    base.job_identity(env)
    head=env.get('GITHUB_SHA','')
    git_env={'PATH':'/usr/bin:/bin','LANG':'C'}
    parents=command(['/usr/bin/git','rev-list','--parents','-n','1','HEAD'],git_env).decode('ascii').strip()
    if parents != head+' '+PARENT:
        raise RuntimeError('diagnostic head or single parent changed')
    token=env.get('GH_TOKEN','')
    if not token:raise RuntimeError('PR read token unavailable')
    gh_env=dict(git_env,GH_TOKEN=token)
    pr=json.loads(command(['/usr/bin/gh','api','repos/kanta13jp1/my_web_app/pulls/5980'],gh_env))
    if (pr.get('state')!='open' or pr['head']['sha']!=PR_HEAD or pr['base']['sha']!=PR_BASE
        or pr['head']['repo']['full_name']!='kanta13jp1/my_web_app'):
        raise RuntimeError('PR source state changed')
    source=json.loads(command(['/usr/bin/gh','api','repos/kanta13jp1/my_web_app/contents/'+MIGRATION+'?ref='+PR_HEAD],gh_env))
    if source.get('encoding')!='base64':raise RuntimeError('PR source encoding mismatch')
    data=base64.b64decode(''.join(source['content'].split()),validate=True)
    if hashlib.sha256(data).hexdigest()!='24e38d3b06d1aeb5d5fd6bfea2bec64c303d4fdad9a45b51f0af980a48cf9db8' or candidate!=data:
        raise RuntimeError('PR migration and reference differ')
    return head


def run_matrix():
    if os.name!='posix':raise RuntimeError('isolated Docker runner must be Linux')
    phase2,base=load_fixed()
    candidates=base.candidate_pair()  # fixed STOP and candidate/body hashes; returns STOP-stripped bytes
    run_id=base.job_identity(os.environ)
    verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
    binary=base.safe_cli_binary()  # pinned official release/archive and binary checks
    env={'PATH':'/usr/bin:/bin','LANG':'C'}
    results=[]
    with tempfile.TemporaryDirectory(prefix='codex-phase2-docker-') as config:
        docker=['/usr/bin/docker','--config',config,'--host','unix:///var/run/docker.sock']
        image=json.loads(command(docker+['image','inspect',base.IMAGE],env))[0]
        for outcome in ('success','history_failure'):
            verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
            service=base.OwnedService(docker,env,image,run_id)
            result=phase2.run_case(service,base,binary,candidates['locked_single_do'],outcome)
            # run_case returns only after successful owned-container cleanup.
            verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
            results.append(result)
            print('SYNTHETIC_PHASE2_CASE '+json.dumps(result,sort_keys=True),flush=True)
    if [r['outcome'] for r in results]!=['success','history_failure']:
        raise RuntimeError('incomplete phase2 result sequence')
    return {'run_id':run_id,'cases':results,'not_verified':['real DB','Auth','other PG versions',
      'concurrent GRANT or membership','all moments of commit','CLI RR/serializable after RESET ALL'],
      'scope':'pinned CLI and synthetic PG17; cleanup required for each case'}


if __name__=='__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')
