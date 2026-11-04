"""REVIEW ONLY: fixed synthetic event preflight entry; no direct execution.

The unchanged phase2 context is repinned in memory to the fixed phase3 parent.
A separately reviewed workflow must pin all files and permissions, and respect FIFO.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import tempfile

HERE=Path(__file__).resolve().parent
EVENT_SHA='153f3ae82e3421fccd78ac92bf663b967e7c876ff95710a427449403c4797c77'
CONTEXT_SHA='750a6e79bf5ec0ac2258b3929dbe37b6f8dab9507a37d3a7ae93c82b5018e7da'
CONTEXT_ORIGINAL_PARENT='24b629750575eb64cc06abea060987dcc01e684b'
PARENT='b885c5f8c2e76cbe820b0539ba032d18bcf888ab'


class EntryPostCleanupError(RuntimeError):
    def __init__(self,original):
        self.original_error_type=type(original).__name__
        self.cleanup_confirmed=True
        super().__init__('post-cleanup context validation failed')


def fixed_module(name,filename,digest):
    path=HERE/filename
    if path.is_symlink() or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
        raise RuntimeError('fixed preflight module mismatch')
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def _run():
    if os.name!='posix':raise RuntimeError('isolated Docker runner must be Linux')
    event=fixed_module('fixed_event_preflight','event_preflight.py',EVENT_SHA)
    context=fixed_module('fixed_phase2_context','phase2_entry.py',CONTEXT_SHA)
    if context.PARENT!=CONTEXT_ORIGINAL_PARENT or not re.fullmatch(r'[0-9a-f]{40}',PARENT):
        raise RuntimeError('fixed context parent mismatch')
    context.PARENT=PARENT
    phase2,base=event.load_fixed()
    candidates=base.candidate_pair()
    run_id=base.job_identity(os.environ)
    context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
    env={'PATH':'/usr/bin:/bin','LANG':'C'}
    with tempfile.TemporaryDirectory(prefix='codex-event-preflight-docker-') as config:
        docker=['/usr/bin/docker','--config',config,'--host','unix:///var/run/docker.sock']
        image=json.loads(context.command(docker+['image','inspect',base.IMAGE],env))[0]
        context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
        service=base.OwnedService(docker,env,image,run_id)
        result=event.run_preflight(service,phase2,base)
        # The event preflight returns only after the owned service is removed.
        try:context.verify_context(base,os.environ,candidates['pr_do_no_boundaries'])
        except BaseException as exc:raise EntryPostCleanupError(exc) from None
    if result.get('outcome') not in ('fired','not_observed'):
        raise RuntimeError('unknown preflight outcome')
    if result.get('ready_for_competition') is not (result['outcome']=='fired'):
        raise RuntimeError('invalid preflight readiness')
    if result.get('cleanup_confirmed') is not True:
        raise RuntimeError('preflight cleanup not confirmed')
    return {'status':result['outcome'],'result':result}


def run_safely():
    """Return sanitized type only on failure; do not expose exception or logs."""
    try:
        return _run()
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
    """The eventual workflow must use this return value as its process status."""
    result=run_safely()
    print('SYNTHETIC_EVENT_PREFLIGHT '+json.dumps(result,sort_keys=True),flush=True)
    return 0 if result.get('status')=='fired' else 2 if result.get('status')=='not_observed' else 1


if __name__=='__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')
