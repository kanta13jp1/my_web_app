"""Offline entry mocks: never starts DB, Docker, CLI, network or subprocess."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('membership_entry_review',HERE/'membership_before_entry.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def run():
    try:m.fixed_module('bad','membership_before.py','0'*64)
    except RuntimeError:pass
    else:raise AssertionError('wrong membership module hash accepted')
    secret='SYNTHETIC_SECRET_DO_NOT_PRINT'
    def chained():
        try:raise ValueError('inner '+secret)
        except ValueError as exc:raise RuntimeError('outer '+secret) from exc
    with mock.patch.object(m,'_run',side_effect=chained),contextlib.redirect_stdout(io.StringIO()) as output:
        failure=m.run_safely()
    assert failure=={'status':'failure','error_type':'RuntimeError','cleanup_confirmed':None}
    assert secret not in str(failure) and output.getvalue()==''
    for status,code in (('observation_complete',0),('observation_issue',2),('failure',1),('unknown',1)):
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
    base=Base();event=object();phase2=object();table=object()
    class Context:
        PARENT=m.CONTEXT_ORIGINAL_PARENT
        def verify_context(self,b,env,candidate):calls.append(('context',candidate));assert b is base
        def command(self,args,env):
            if args[0]=='/usr/bin/docker':return b'[{"Id":"synthetic"}]'
            run_id=int(args[-1].rsplit('/',1)[1]);item=next(x for x in m.PRIOR_RUNS if x[0]==run_id);head,conclusion=item[1:]
            return json.dumps({'id':run_id,'head_sha':head,'status':'completed','conclusion':conclusion,
              'head_branch':m.BRANCH,'event':'workflow_dispatch'}).encode()
    context=Context()
    class Member:
        issue=False;cli_issue=False;missing_cleanup=False;unobserved=False
        def load_fixed(self):return table,event,phase2,base
        def run_before(self,service,t,e,p,b):
            calls.append(('case','before_revoke'))
            return {'stage':'before_revoke','cleanup_confirmed':not self.missing_cleanup,
              'first_observation':'deadline' if self.unobserved else 'statement_done',
              'membership_grant':{'status':'sql_error' if self.issue else 'committed'},
              'cli':{'status':'sql_error' if self.cli_issue else 'committed'}}
    member=Member()
    def modules(name,filename,digest):return member if filename=='membership_before.py' else context
    def run_fake():
        with mock.patch.object(m.os,'name','posix'),mock.patch.object(m,'fixed_module',side_effect=modules),\
             mock.patch.object(m,'PARENT','a'*40),mock.patch.dict(m.os.environ,{'GH_TOKEN':'synthetic'}),\
             mock.patch.object(m.tempfile,'TemporaryDirectory') as temp,contextlib.redirect_stdout(io.StringIO()):
            temp.return_value.__enter__.return_value='/fake/config'
            return m.run_safely()
    result=run_fake();assert result['status']=='observation_complete' and result['security_review']=='not_assessed'
    assert [x[1] for x in calls if x[0]=='case']==['before_revoke']
    assert 'after-stage' in result['scope'] and 'fixed-history rollback' in result['scope']
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;member.issue=True
    assert run_fake()['status']=='observation_issue'
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;member.issue=False;member.cli_issue=True
    assert run_fake()['status']=='observation_issue'
    member.cli_issue=False
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;member.issue=False;member.unobserved=True
    assert run_fake()['status']=='observation_issue'
    context.PARENT=m.CONTEXT_ORIGINAL_PARENT;member.unobserved=False;member.missing_cleanup=True
    assert run_fake()['status']=='failure'
    class BadPrior(Context):
        def command(self,args,env):
            return json.dumps({'id':0,'head_sha':'x','status':'completed','conclusion':'success',
              'head_branch':m.BRANCH,'event':'workflow_dispatch'}).encode()
    try:m.verify_prerequisites(BadPrior(),{'GH_TOKEN':'synthetic'})
    except RuntimeError:pass
    else:raise AssertionError('wrong prior run accepted')
    class MislabelledFailure(Context):
        target=None
        def command(self,args,env):
            data=json.loads(super().command(args,env))
            if data['id']==self.target:data['conclusion']='success'
            return json.dumps(data).encode()
    for run_id in (41781365481,41783344737,41784488437):
        wrong=MislabelledFailure();wrong.target=run_id
        try:m.verify_prerequisites(wrong,{'GH_TOKEN':'synthetic'})
        except RuntimeError:pass
        else:raise AssertionError('prior failure relabelled as success: '+str(run_id))
    context.PARENT='f'*40;member.missing_cleanup=False
    assert run_fake()['status']=='failure'
    print('PASS: prior runs, single before stage, cleanup, non-success statuses and redacted errors')
    print('No Docker, database, CLI, network or subprocess was started.')


if __name__=='__main__':run()
