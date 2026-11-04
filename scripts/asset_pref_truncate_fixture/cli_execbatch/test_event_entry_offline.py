"""Offline mocks for the event preflight entry; never runs subprocesses."""
import contextlib
import importlib.util
import io
from pathlib import Path
import types
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('event_entry_review',HERE/'event_preflight_entry.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def run():
    try:m.fixed_module('bad','event_preflight.py','0'*64)
    except RuntimeError:pass
    else:raise AssertionError('invalid module hash accepted')
    secret='SYNTHETIC_SECRET_MUST_NOT_ESCAPE'
    def chained_failure():
        try:raise ValueError('inner '+secret)
        except ValueError as exc:raise RuntimeError('outer '+secret) from exc
    with mock.patch.object(m,'_run',side_effect=chained_failure),contextlib.redirect_stdout(io.StringIO()) as output:
        result=m.run_safely()
    assert result=={'status':'failure','error_type':'RuntimeError','cleanup_confirmed':None}
    assert secret not in str(result) and secret not in output.getvalue() and output.getvalue()==''
    for status in ('fired','not_observed'):
        with mock.patch.object(m,'_run',return_value={'status':status}):
            assert m.run_safely()=={'status':status}
    for status,code in (('fired',0),('not_observed',2),('failure',1),('unexpected',1)):
        with mock.patch.object(m,'run_safely',return_value={'status':status}),contextlib.redirect_stdout(io.StringIO()):
            assert m.run_and_exit_code()==code
    class PreflightCleanupError(RuntimeError):
        original_error_type='ValueError'
        client_cleanup_failed=True
        container_cleanup_unconfirmed=True
        cleanup_confirmed=None
    with mock.patch.object(m,'_run',side_effect=PreflightCleanupError('raw '+secret)):
        result=m.run_safely()
    assert result=={'status':'failure','error_type':'PreflightCleanupError','cleanup_confirmed':None,
      'original_error_type':'ValueError','client_cleanup_failed':True,'container_cleanup_unconfirmed':True}
    assert secret not in str(result)

    calls=[]
    class Base:
        IMAGE='synthetic-image'
        def candidate_pair(self):return {'pr_do_no_boundaries':b'fixed'}
        def job_identity(self,env):return '123-1'
        def OwnedService(self,docker,env,image,run_id):
            calls.append(('owned',docker[-1],env,run_id));return object()
    base=Base();phase2=object()
    class Context:
        PARENT=m.CONTEXT_ORIGINAL_PARENT
        def verify_context(self,b,env,candidate):calls.append(('context',candidate));assert b is base
        def command(self,args,env):calls.append(('image',args[-1],env));return b'[{"Id":"synthetic"}]'
    context=Context()
    class Event:
        def load_fixed(self):return phase2,base
        def run_preflight(self,service,p,b):
            calls.append(('preflight',p is phase2,b is base))
            return {'outcome':'fired','ready_for_competition':True,'cleanup_confirmed':True}
    event=Event()
    def modules(name,filename,digest):return event if filename=='event_preflight.py' else context
    with mock.patch.object(m.os,'name','posix'),mock.patch.object(m,'fixed_module',side_effect=modules),\
         mock.patch.object(m.tempfile,'TemporaryDirectory') as temp:
        temp.return_value.__enter__.return_value='/fake/config'
        result=m._run()
    assert result['status']=='fired' and [x[0] for x in calls].count('context')==3
    assert context.PARENT==m.PARENT
    assert [x[0] for x in calls].count('preflight')==1
    assert next(x for x in calls if x[0]=='image')[2]=={'PATH':'/usr/bin:/bin','LANG':'C'}
    bad_context=Context();bad_context.PARENT='unexpected'
    def bad_modules(name,filename,digest):return event if filename=='event_preflight.py' else bad_context
    with mock.patch.object(m.os,'name','posix'),mock.patch.object(m,'fixed_module',side_effect=bad_modules):
        assert m.run_safely()=={'status':'failure','error_type':'RuntimeError','cleanup_confirmed':None}
    for index,expected in ((2,None),(3,True)):
        class FailContext(Context):
            PARENT=m.CONTEXT_ORIGINAL_PARENT
            count=0
            def verify_context(self,b,env,candidate):
                self.count+=1
                if self.count==index:raise ValueError('secret '+secret)
        failure_context=FailContext()
        def fail_modules(name,filename,digest):return event if filename=='event_preflight.py' else failure_context
        with mock.patch.object(m.os,'name','posix'),mock.patch.object(m,'fixed_module',side_effect=fail_modules),\
             mock.patch.object(m.tempfile,'TemporaryDirectory') as temp:
            temp.return_value.__enter__.return_value='/fake/config'
            failure=m.run_safely()
        assert failure['status']=='failure' and failure['cleanup_confirmed'] is expected
        assert secret not in str(failure)
    print('PASS: pinned module rejection, sanitized chained errors, isolated environment and post-cleanup context')
    print('No Docker, database, CLI, network or subprocess was started.')


if __name__=='__main__':run()
