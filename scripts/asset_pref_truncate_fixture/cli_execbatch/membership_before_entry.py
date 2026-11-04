"""REVIEW ONLY: synthetic membership-before entry; direct execution disabled.

An unpinned diagnostic parent intentionally stops execution. The future workflow
must use run_and_exit_code(), pin inputs and preserve the shared FIFO.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import tempfile

HERE=Path(__file__).resolve().parent
MEMBER_SHA='6aecae88dcd7e58ace633201da947e4038aa44693ba62eafd07ab7599f614263'
CONTEXT_SHA='750a6e79bf5ec0ac2258b3929dbe37b6f8dab9507a37d3a7ae93c82b5018e7da'
CONTEXT_ORIGINAL_PARENT='24b629750575eb64cc06abea060987dcc01e684b'
PARENT='4f1593e0cf15d078753f7bf7a096424f46ac58ac'
PRIOR_RUNS=((41778403633,'836e6dcc8dab204b955d8c5303cb78260435193f','success'),
            (41775837475,'b885c5f8c2e76cbe820b0539ba032d18bcf888ab','success'),
            (41781365481,'4f1593e0cf15d078753f7bf7a096424f46ac58ac','failure'))
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
    for run_id,head,conclusion in PRIOR_RUNS:
        obj=json.loads(context.command(['/usr/bin/gh','api',
          'repos/kanta13jp1/my_web_app/actions/runs/'+str(run_id)],read_env))
        if (obj.get('id')!=run_id or obj.get('head_sha')!=head or obj.get('status')!='completed'
            or obj.get('conclusion')!=conclusion or obj.get('head_branch')!=BRANCH
            or obj.get('event')!='workflow_dispatch'):
            raise RuntimeError('prior synthetic success evidence mismatch')


class EntryPostCleanupError(RuntimeError):
    def __init__(self,original):
        self.original_error_type=type(original).__name__;self.cleanup_confirmed=True
        super().__init__('post-cleanup context validation failed')


def _run():
    if os.name!='posix':raise RuntimeError('isolated Docker runner must be Linux')
    member=fixed_module('fixed_membership_before','membership_before.py',MEMBER_SHA)
    context=fixed_module('fixed_phase2_context','phase2_entry.py',CONTEXT_SHA)
    if context.PARENT!=CONTEXT_ORIGINAL_PARENT or not re.fullmatch(r'[0-9a-f]{40}',PARENT):
        raise RuntimeError('diagnostic parent not pinned')
    context.PARENT=PARENT
    table,event,phase2,base=member.load_fixed()
    candidates=base.candidate_pair();run_id=base.job_identity(os.environ)
    context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
    verify_prerequisites(context,os.environ)
    env={'PATH':'/usr/bin:/bin','LANG':'C'};results=[]
    with tempfile.TemporaryDirectory(prefix='codex-table-grant-docker-') as config:
        docker=['/usr/bin/docker','--config',config,'--host','unix:///var/run/docker.sock']
        image=json.loads(context.command(docker+['image','inspect',base.IMAGE],env))[0]
        context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
        verify_prerequisites(context,os.environ)
        service=base.OwnedService(docker,env,image,run_id)
        result=member.run_before(service,table,event,phase2,base)
        if result.get('cleanup_confirmed') is not True:
            raise RuntimeError('owned cleanup unconfirmed')
        try:
            context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
            verify_prerequisites(context,os.environ)
        except BaseException as exc:raise EntryPostCleanupError(exc) from None
    if result.get('stage')!='before_revoke':raise RuntimeError('incorrect membership stage')
    if (result.get('membership_grant',{}).get('status')!='committed'
        or result.get('cli',{}).get('status')!='committed'
        or result.get('first_observation') not in ('statement_done','lock_wait')):
        status='observation_issue'
    else:status='observation_complete'
    return {'status':status,'case':result,'security_review':'not_assessed',
      'scope':'synthetic membership before REVOKE only; after-stage, fixed-history rollback and production unverified'}



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
    print('SYNTHETIC_MEMBERSHIP_BEFORE_RESULT '+json.dumps(result,sort_keys=True),flush=True)
    return 0 if result.get('status')=='observation_complete' else 2 if result.get('status')=='observation_issue' else 1


if __name__=='__main__':raise SystemExit('REVIEW ONLY: direct execution disabled')
