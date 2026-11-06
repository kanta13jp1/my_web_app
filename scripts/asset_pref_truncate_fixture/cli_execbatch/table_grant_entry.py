"""REVIEW ONLY: synthetic concurrent table-GRANT entry; direct execution disabled.

The unchanged phase2 context is repinned in memory to the fixed phase3 parent.
The future workflow must use run_and_exit_code(), pin inputs and preserve FIFO.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import tempfile

HERE=Path(__file__).resolve().parent
TABLE_SHA='d94a40d01de858131cca42f17119bcf3c36a6b3ccf4811cc495aa750080922a6'
CONTEXT_SHA='199c3301e01124b9e9eac5c291d07d7c44eccdc34fc0a498075a2da69640c8c7'
CONTEXT_ORIGINAL_PARENT='24b629750575eb64cc06abea060987dcc01e684b'
PARENT='946701ca3c224821d98c2f7ce984041c7d873c2b'
PRIOR_RUNS=((41778403633,'836e6dcc8dab204b955d8c5303cb78260435193f'),
            (41775837475,'b885c5f8c2e76cbe820b0539ba032d18bcf888ab'))
BRANCH='codex/asset-pref-cli-execbatch-diagnostic-20261104'


def fixed_module(name,filename,digest):
    path=HERE/filename
    if path.is_symlink() or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
        raise RuntimeError('fixed grant module mismatch')
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def verify_prerequisites(context,env):
    token=env.get('GH_TOKEN','')
    if not token:raise RuntimeError('prior run read token unavailable')
    read_env={'PATH':'/usr/bin:/bin','LANG':'C','GH_TOKEN':token}
    for run_id,head in PRIOR_RUNS:
        obj=json.loads(context.command(['/usr/bin/gh','api',
          'repos/kanta13jp1/my_web_app/actions/runs/'+str(run_id)],read_env))
        if (obj.get('id')!=run_id or obj.get('head_sha')!=head or obj.get('status')!='completed'
            or obj.get('conclusion')!='success' or obj.get('head_branch')!=BRANCH
            or obj.get('event')!='workflow_dispatch'):
            raise RuntimeError('prior synthetic success evidence mismatch')


class EntryPostCleanupError(RuntimeError):
    def __init__(self,original):
        self.original_error_type=type(original).__name__;self.cleanup_confirmed=True
        super().__init__('post-cleanup context validation failed')


def _run():
    if os.name!='posix':raise RuntimeError('isolated Docker runner must be Linux')
    table=fixed_module('fixed_table_grant','table_grant.py',TABLE_SHA)
    context=fixed_module('fixed_phase2_context','phase2_entry.py',CONTEXT_SHA)
    if context.PARENT!=CONTEXT_ORIGINAL_PARENT or not re.fullmatch(r'[0-9a-f]{40}',PARENT):
        raise RuntimeError('diagnostic parent not pinned')
    context.PARENT=PARENT
    event,phase2,base=table.load_fixed()
    candidates=base.candidate_pair();run_id=base.job_identity(os.environ)
    context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
    verify_prerequisites(context,os.environ)
    env={'PATH':'/usr/bin:/bin','LANG':'C'};results=[]
    with tempfile.TemporaryDirectory(prefix='codex-table-grant-docker-') as config:
        docker=['/usr/bin/docker','--config',config,'--host','unix:///var/run/docker.sock']
        image=json.loads(context.command(docker+['image','inspect',base.IMAGE],env))[0]
        for stage in ('before_revoke','after_revoke'):
            context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
            verify_prerequisites(context,os.environ)
            service=base.OwnedService(docker,env,image,run_id)
            result=table.run_case(service,event,phase2,base,stage)
            if result.get('cleanup_confirmed') is not True:
                raise RuntimeError('owned cleanup unconfirmed')
            try:
                context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
                verify_prerequisites(context,os.environ)
            except BaseException as exc:raise EntryPostCleanupError(exc) from None
            results.append(result)
            print('SYNTHETIC_TABLE_GRANT_CASE '+json.dumps(result,sort_keys=True),flush=True)
    if [r.get('stage') for r in results]!=['before_revoke','after_revoke']:
        raise RuntimeError('incomplete stage sequence')
    if any(r.get('grant',{}).get('status')!='committed' or r.get('cli',{}).get('status')!='committed'
           or r.get('grant_first_observation') not in ('statement_done','lock_wait')
           for r in results):
        status='observation_issue'
    else:status='observations_complete'
    return {'status':status,'cases':results,'security_review':'not_assessed',
      'scope':'synthetic table GRANT observation only; role membership and production unverified'}


def run_safely():
    try:return _run()
    except BaseException as exc:
        name=type(exc).__name__
        if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,63}',name):name='Error'
        result={'status':'failure','error_type':name,'cleanup_confirmed':None}
        if name in ('PreflightRunError','PreflightCleanupError','EntryPostCleanupError'):
            original=getattr(exc,'original_error_type',None)
            if isinstance(original,str) and re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,63}',original):
                result['original_error_type']=original
            if name in ('PreflightRunError','EntryPostCleanupError') and getattr(exc,'cleanup_confirmed',None) is True:
                result['cleanup_confirmed']=True
            if name=='PreflightCleanupError':
                result['client_cleanup_failed']=getattr(exc,'client_cleanup_failed',False) is True
                result['container_cleanup_unconfirmed']=getattr(exc,'container_cleanup_unconfirmed',False) is True
        return result


def run_and_exit_code():
    result=run_safely()
    print('SYNTHETIC_TABLE_GRANT_RESULT '+json.dumps(result,sort_keys=True),flush=True)
    return 0 if result.get('status')=='observations_complete' else 2 if result.get('status')=='observation_issue' else 1


if __name__=='__main__':raise SystemExit('REVIEW ONLY: direct execution disabled')
