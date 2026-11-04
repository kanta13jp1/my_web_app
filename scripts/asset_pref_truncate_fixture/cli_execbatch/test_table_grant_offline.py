"""Pure mocks; never starts PostgreSQL, Docker, CLI, network or subprocess."""
import contextlib
import importlib.util
import io
import json
import subprocess
from pathlib import Path
import types
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('table_grant_review',HERE/'table_grant.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
event,phase2,base=m.load_fixed()


def rejects(fn):
    try:
        with contextlib.redirect_stdout(io.StringIO()):fn()
    except RuntimeError:return
    raise AssertionError('unsafe grant observation accepted')


def run():
    good={'pid':404,'target_oid':303,'local_socket':True,'state':'idle in transaction',
          'wait_type':'Client','blockers':[],'done_query':True,'grant_query':False}
    assert m.classify_activity([good],303,{101,202})['state']=='statement_done'
    waiting=dict(good,state='active',wait_type='Lock',done_query=False,grant_query=True,blockers=[202])
    assert m.classify_activity([waiting],303,{101,202})['state']=='lock_wait'
    for field,value in [('pid',202),('target_oid',304),('local_socket',False),('blockers',['202'])]:
        rejects(lambda field=field,value=value:m.classify_activity([dict(good,**{field:value})],303,{101,202}))
    rejects(lambda:m.classify_activity([dict(waiting,grant_query=False)],303,{101,202}))
    rejects(lambda:m.classify_activity([good,good],303,{101,202}))
    rejects(lambda:m.grant_activity_sql('invalid'))
    nonce='b'*32
    logs=('[404] LOG: 00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_grant_'+nonce+'\n'
      '[404] LOG: 00000: statement: '+m.GRANT_SQL+'\n'
      "[404] LOG: 00000: statement: SELECT '"+m.GRANT_DONE+"';\n"
      '[404] LOG: 00000: statement: COMMIT;\n')
    out='1\nSYNTHETIC_B_READY:404:303\n'+m.GRANT_DONE+'\n'+m.COMMIT_DONE+'\n'
    m.verify_b_statement(404,logs,nonce);m.verify_b_success(404,303,out,'',logs,nonce)
    rejects(lambda:m.verify_b_statement(405,logs,nonce))
    rejects(lambda:m.verify_b_success(404,304,out,'',logs,nonce))
    rejects(lambda:m.verify_b_success(404,303,out.replace(m.COMMIT_DONE,''),'',logs,nonce))
    rejects(lambda:m.verify_b_success(404,303,out,'',logs.replace('statement: COMMIT;','statement: ROLLBACK;'),nonce))
    errorlog=logs+'[404] ERROR: 55P03: synthetic refusal\n[404] STATEMENT: '+m.GRANT_SQL+'\n'
    assert m.verify_b_error(1,'1\nSYNTHETIC_B_READY:404:303\n','ERROR: 55P03: failed',errorlog,nonce,303,{101,202})['sqlstate']=='55P03'
    rejects(lambda:m.verify_b_error(1,'1\nSYNTHETIC_B_READY:404:303\n','ERROR: 42501: failed',errorlog,nonce,303,{101,202}))
    rejects(lambda:m.verify_b_error(1,'1\nSYNTHETIC_B_READY:404:303\n','ERROR: 55P03: failed',errorlog,nonce,303,{404}))
    setup_error=logs+'[404] ERROR: 42501: synthetic refusal\n[404] STATEMENT: SET log_statement=all;\n'
    rejects(lambda:m.verify_b_error(1,'1\nSYNTHETIC_B_READY:404:303\n','ERROR: 42501: failed',setup_error,nonce,303,{101,202}))
    cli_log=('[202] LOG: 00000: connection received: host=127.0.0.1 port=123\n'
      '[202] LOG: 00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli\n')
    m.verify_cli_auth(202,cli_log)
    rejects(lambda:m.verify_cli_auth(203,cli_log))
    rejects(lambda:m.verify_cli_auth(202,cli_log.replace('host=127.0.0.1','host=other')))

    class Service:
        cid='a'*64;nonce='b'*32;token='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';run_id='123-1';verified=True
        def __init__(self,stage):
            self.case_stage=stage;self.finished=False;self.released=False;self.stopped=False;self.grant_committed=False;self.cli_failed=False
            self.verified_negative_fatals=[{'pid':'120','sqlstate':'28000','fatal_line':'[120] FATAL:  28000: expected database refusal'},
                                           {'pid':'121','sqlstate':'28P01','fatal_line':'[121] FATAL:  28P01: expected password refusal'}]
        def create(self):pass
        def wait_final_postmaster(self):pass
        def initialize(self):pass
        def configure_synthetic_loopback(self):pass
        def stage(self,*args):pass
        def stop_owned(self):
            self.stopped=True
            print('SYNTHETIC_EXECBATCH_TEARDOWN '+json.dumps({'run_id':self.run_id,'nonce':self.nonce,'container_id':self.cid,
              'stopped_removed':True,'inspect_absent':True,'ps_absent':True,'holder_client_stopped':True}))
        def psql(self,sql):
            if sql==base.SNAPSHOT:
                return json.dumps(dict(owner=1,rls=True,force=False,rows=[],policy=[],other_acl=[],other_effective=[],
                  columns=[],memberships=[],role_attributes=[],hierarchy=[],service=True,
                  anon=(self.finished and not self.cli_failed) or self.case_stage=='after_revoke',authenticated=not self.finished or self.cli_failed))
            if 'pg_stat_activity WHERE pid IN' in sql:return '0'
            if 'jsonb_agg(jsonb_build_object' in sql:
                return '[]' if self.cli_failed else json.dumps([{'version':base.VERSION,'name':'synthetic_acl','statement_count':1}])
            return ''
        def logs(self):
            extra=('[404] ERROR: 42501: synthetic failure\n[404] STATEMENT: '+m.GRANT_SQL+'\n[202] ERROR: P0001: synthetic failure\n') if self.cli_failed else ''
            return '\n'.join(x['fatal_line'] for x in self.verified_negative_fatals)+'\n'+cli_log+logs+extra
    waiter={'pid':202,'target_oid':303}
    class Clients:
        def __init__(self,s,b):self.s=s
        def start_coordinator(self):return 101
        def start_cli(self):pass
        def wait_barrier(self,coord):return waiter
        def release(self):self.s.released=True
        def finish_cli(self):self.s.finished=True;return 0,''
        def close(self):pass
    class Grant:
        def __init__(self,s,b):self.s=s;self.n=0
        def start(self):pass
        def poll_until(self,deadline,oid,other):
            self.n+=1
            if self.s.case_stage=='after_revoke' and self.n==1:return {'state':'lock_wait','pid':404,'blockers':[202]}
            return {'state':'statement_done','pid':404,'blockers':[]}
        def commit(self):self.s.grant_committed=True
        def finish(self):return 0,out,''
        def close(self):pass
    snapshot={'oid':303,'anon':False,'authenticated':True,'service':True}
    def fake_catalog(s):return dict(snapshot,anon=(s.finished and not s.cli_failed) or s.grant_committed or s.case_stage=='after_revoke',authenticated=not s.finished or s.cli_failed)
    with mock.patch.object(base,'OwnedService',Service),mock.patch.object(base,'safe_cli_binary',return_value=b'fake'),\
         mock.patch.object(phase2,'OwnedClients',Clients),mock.patch.object(m,'GrantClient',Grant),\
         mock.patch.object(event,'wait_for_event',return_value=waiter),mock.patch.object(event,'prove_event_log'),\
         mock.patch.object(m,'catalog_snapshot',side_effect=fake_catalog):
        for stage in ('before_revoke','after_revoke'):
            s=Service(stage)
            with contextlib.redirect_stdout(io.StringIO()) as output:
                try:result=m.run_case(s,event,phase2,base,stage)
                except event.PreflightRunError as exc:raise AssertionError('mock original type: '+exc.original_error_type) from None
            assert result['grant']['status']=='committed' and result['cli']['status']=='committed'
            assert result['observed_lock_wait']==(stage=='after_revoke')
            assert result['grant_commit_before_cli_release']==(stage=='before_revoke')
            assert s.stopped and result['cleanup_confirmed'] and 'SYNTHETIC_GRANT_OWNED_TEARDOWN' in output.getvalue()
        s=Service('before_revoke')
        with mock.patch.object(event,'wait_for_event',return_value=None):
            rejects(lambda:m.run_case(s,event,phase2,base,'before_revoke'))
        assert s.stopped
        class DeadlineGrant(Grant):
            def poll_until(self,*args):return {'state':'deadline'}
        s=Service('after_revoke')
        with mock.patch.object(m,'GrantClient',DeadlineGrant):
            rejects(lambda:m.run_case(s,event,phase2,base,'after_revoke'))
        assert s.stopped
        class FailedGrant(Grant):
            def poll_until(self,*args):return {'state':'client_exited'}
            def finish(self):return 1,'1\nSYNTHETIC_B_READY:404:303\n','ERROR: 42501: synthetic failure'
        class FailedClients(Clients):
            def finish_cli(self):self.s.finished=True;self.s.cli_failed=True;return 1,'P0001 synthetic failure'
        s=Service('before_revoke');s.cli_failed=True
        with mock.patch.object(m,'GrantClient',FailedGrant),mock.patch.object(phase2,'OwnedClients',FailedClients),contextlib.redirect_stdout(io.StringIO()):
            result=m.run_case(s,event,phase2,base,'before_revoke')
        assert result['grant']['status']=='sql_error' and result['grant']['sqlstate']=='42501'
        assert result['cli']['status']=='sql_error' and result['cli']['sqlstate']=='P0001' and result['history_count']==0
        assert not result['grant_commit_before_cli_release'] and s.stopped
        class BrokenGrant(Grant):
            def close(self):raise RuntimeError('synthetic-secret')
        s=Service('after_revoke');s.stop_owned=lambda:(_ for _ in ()).throw(RuntimeError('container-secret'))
        with mock.patch.object(m,'GrantClient',BrokenGrant),contextlib.redirect_stdout(io.StringIO()):
            try:m.run_case(s,event,phase2,base,'after_revoke')
            except event.PreflightCleanupError as exc:
                assert exc.client_cleanup_failed and exc.container_cleanup_unconfirmed and 'secret' not in str(exc)
            else:raise AssertionError('combined cleanup failure accepted')
    with mock.patch.object(subprocess,'Popen',side_effect=AssertionError('unexpected spawn')):
        rejects(lambda:m.GrantClient(types.SimpleNamespace(verified=False),base).start())
    process=mock.Mock();process.poll.return_value=None;process.wait.side_effect=[subprocess.TimeoutExpired('fake',5),0]
    owned=m.GrantClient(types.SimpleNamespace(),base);owned.proc=process
    owned.close();process.terminate.assert_called_once();process.kill.assert_called_once()
    print('PASS: mock before/after ordering, same PID/SQL/commit, observed wait, deadline and cleanup')
    print('No Docker, database, CLI, network or subprocess was started.')


if __name__=='__main__':run()
