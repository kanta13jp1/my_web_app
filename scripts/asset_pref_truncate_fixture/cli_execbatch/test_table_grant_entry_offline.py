"""Offline mocks for fixed table-GRANT orchestration; never starts subprocesses."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('table_entry_review',HERE/'table_grant_entry.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def run():
    try:m.fixed_module('bad','table_grant.py','0'*64)
    except RuntimeError:pass
    else:raise AssertionError('wrong hash accepted')
    secret='SYNTHETIC_SECRET_MUST_NOT_ESCAPE'
    def chained():
        try:raise ValueError('inner '+secret)
        except ValueError as exc:raise RuntimeError('outer '+secret) from exc
    with mock.patch.object(m,'_run',side_effect=chained),contextlib.redirect_stdout(io.StringIO()) as output:
        failure=m.run_safely()
    assert failure=={'status':'failure','error_type':'RuntimeError','cleanup_confirmed':None}
    assert secret not in str(failure) and output.getvalue()==''
    for status,code in (('observations_complete',0),('observation_issue',2),('failure',1),('unknown',1)):
        with mock.patch.object(m,'run_safely',return_value={'status':status}),contextlib.redirect_stdout(io.StringIO()):
            assert m.run_and_exit_code()==code
    class PreflightCleanupError(RuntimeError):
        original_error_type='ValueError';client_cleanup_failed=True;container_cleanup_unconfirmed=True
    with mock.patch.object(m,'_run',side_effect=PreflightCleanupError('raw '+secret)):
        failure=m.run_safely()
    assert failure['original_error_type']=='ValueError' and failure['cleanup_confirmed'] is None
    assert failure['client_cleanup_failed'] and failure['container_cleanup_unconfirmed'] and secret not in str(failure)

    calls=[]
    class Base:
        IMAGE='synthetic-image'
        def candidate_pair(self):return {'pr_do_no_boundaries':b'fixed'}
        def job_identity(self,env):return '123-1'
        def OwnedService(self,docker,env,image,run_id):calls.append(('owned',env));return object()
    base=Base();event=object();phase2=object()
    class Context:
        PARENT=m.CONTEXT_ORIGINAL_PARENT
        def verify_context(self,b,env,candidate):calls.append(('context',candidate));assert b is base
        def command(self,args,env):
            if args[0]=='/usr/bin/docker':return b'[{"Id":"synthetic"}]'
            run_id=int(args[-1].rsplit('/',1)[1]);head=dict(m.PRIOR_RUNS)[run_id]
            return json.dumps({'id':run_id,'head_sha':head,'status':'completed','conclusion':'success',
              'head_branch':m.BRANCH,'event':'workflow_dispatch'}).encode()
    context=Context()
    class Table:
        issue=False;missing_cleanup=False;unobserved=False
        def load_fixed(self):return event,phase2,base
        def run_case(self,service,e,p,b,stage):
            calls.append(('case',stage))
            return {'stage':stage,'cleanup_confirmed':not self.missing_cleanup,
              'grant_first_observation':'deadline' if self.unobserved else 'statement_done',
              'grant':{'status':'sql_error' if self.issue else 'committed'},'cli':{'status':'committed'}}
    table=Table()
    def modules(name,filename,digest):return table if filename=='table_grant.py' else context
    def run_fake():
        with mock.patch.object(m.os,'name','posix'),mock.patch.object(m,'fixed_module',side_effect=modules),\
             mock.patch.object(m,'PARENT','a'*40),mock.patch.dict(m.os.environ,{'GH_TOKEN':'synthetic'}),\
             mock.patch.object(m.tempfile,'TemporaryDirectory') as temp,contextlib.redirect_stdout(io.StringIO()):
            temp.return_value.__enter__.return_value='/fake/config'
            return m.run_safely()
    result=run_fake()
    assert result['status']=='observations_complete' and result['security_review']=='not_assessed'
    assert [x[1] for x in calls if x[0]=='case']==['before_revoke','after_revoke']
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;table.issue=True
    result=run_fake();assert result['status']=='observation_issue'
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;table.issue=False;table.unobserved=True
    result=run_fake();assert result['status']=='observation_issue'
    table.unobserved=False
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;table.issue=False;table.missing_cleanup=True
    result=run_fake();assert result['status']=='failure'
    context.PARENT='wrong';table.missing_cleanup=False
    result=run_fake();assert result['status']=='failure' and result['cleanup_confirmed'] is None
    class BadPrior(Context):
        def command(self,args,env):
            if args[0]=='/usr/bin/docker':return super().command(args,env)
            return json.dumps({'id':0,'head_sha':'x','status':'completed','conclusion':'success',
              'head_branch':m.BRANCH,'event':'workflow_dispatch'}).encode()
    with mock.patch.dict(m.os.environ,{'GH_TOKEN':'synthetic'}):
        try:m.verify_prerequisites(BadPrior(),m.os.environ)
        except RuntimeError:pass
        else:raise AssertionError('wrong prior run accepted')
    print('PASS: fixed prior run, two stages, cleanup, non-success statuses and redacted exceptions')
    print('No Docker, database, CLI, network or subprocess was started.')


if __name__=='__main__':run()
