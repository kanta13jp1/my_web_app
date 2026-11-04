"""Mocks only; no PostgreSQL, Docker, CLI, network or subprocess."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import types
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('membership_before_review',HERE/'membership_before.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
table,event,phase2,base=m.load_fixed()


def rejects(fn):
    try:
        with contextlib.redirect_stdout(io.StringIO()):fn()
    except RuntimeError:return
    raise AssertionError('unsafe membership observation accepted')


def run():
    attrs=[[10,'postgres',True,True,True,True,True,True,True],
           [301,'synthetic_acl_parent',False,True,False,False,False,False,False]]
    initial={'target_oid':303,'parent_oid':301,'anon_oid':302,'parent_truncate':True,'parent_other':False,
      'anon_truncate':True,'authenticated_truncate':True,'member':False,'usage':False,'set':False,
      'direct_anon':True,'direct_authenticated':True,'membership':[],'other_memberships':[],'role_attributes':attrs}
    granted=dict(initial,member=True,usage=True,membership=[[301,302,10,False,True,False]])
    m.verify_membership(initial,False,303,301,302);m.verify_membership(granted,True,303,301,302)
    for bad in (dict(granted,parent_oid=304),dict(granted,usage=False),dict(granted,set=True),
                dict(granted,membership=[[301,302,11,False,True,False]]),
                dict(granted,membership=[[301,302,10,True,True,False]]),dict(granted,parent_other=True)):
        rejects(lambda bad=bad:m.verify_membership(bad,True,303,301,302))
    superrole=[attrs[0],[301,'synthetic_acl_parent',True,True,False,False,False,False,False]]
    rejects(lambda:m.verify_membership(dict(granted,role_attributes=superrole),True,303,301,302))
    assert "'synthetic_acl_parent'::regrole::oid::bigint" in m.snapshot_sql()
    assert 'pg_has_role' in m.snapshot_sql() and 'pg_auth_members' in m.snapshot_sql()
    row={'pid':404,'target_oid':303,'parent_oid':301,'local_socket':True,'state':'idle in transaction',
         'wait_type':'Client','blockers':[],'done_query':True,'grant_query':False}
    assert m.classify_activity([row],303,301,{101,202})['state']=='statement_done'
    waiting=dict(row,state='active',wait_type='Lock',done_query=False,grant_query=True,blockers=[202])
    assert m.classify_activity([waiting],303,301,{101,202})['state']=='lock_wait'
    for field,value in [('pid',202),('target_oid',304),('parent_oid',305),('local_socket',False),('blockers',['202'])]:
        rejects(lambda field=field,value=value:m.classify_activity([dict(row,**{field:value})],303,301,{101,202}))
    nonce='b'*32
    logs=('[404] LOG: 00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_member_'+nonce+'\n'
      '[404] LOG: 00000: statement: '+m.GRANT_SQL+'\n'
      "[404] LOG: 00000: statement: SELECT '"+m.DONE+"';\n"
      '[404] LOG: 00000: statement: COMMIT;\n')
    out='1\nSYNTHETIC_MEMBER_READY:404:303:301\n'+m.DONE+'\n'+m.COMMITTED+'\n'
    m.verify_statement(404,logs,nonce);m.verify_success(404,303,301,out,'',logs,nonce)
    rejects(lambda:m.verify_success(404,303,305,out,'',logs,nonce))
    rejects(lambda:m.verify_success(404,303,301,out.replace(m.COMMITTED,''),'',logs,nonce))
    errorlog=logs+'[404] ERROR: 42501: synthetic refusal\n[404] STATEMENT: '+m.GRANT_SQL+'\n'
    found=m.verify_error(table,1,'1\nSYNTHETIC_MEMBER_READY:404:303:301\n','ERROR: 42501: failed',errorlog,nonce,303,301,{101,202})
    assert found['sqlstate']=='42501' and found['message_diagnostic']['class']=='unknown'
    badlog=logs+'[404] ERROR: 42501: synthetic refusal\n[404] STATEMENT: SET log_statement=all;\n'
    rejects(lambda:m.verify_error(table,1,'1\nSYNTHETIC_MEMBER_READY:404:303:301\n','ERROR: 42501: failed',badlog,nonce,303,301,{101,202}))

    candidate=base.candidate_pair()['locked_single_do']
    known='truncate privilege reachable through role membership'
    marker='[202] ERROR: P0001: '+known+'\n[202] STATEMENT: '+candidate.decode('utf8')+'\n'
    check=m.verify_cli_candidate_error(202,'P0001 failure',marker,candidate)
    assert check['message_diagnostic']['class']=='membership_reachable' and check['sqlstate']=='P0001'
    unknown='SYNTHETIC_PRIVATE_UNKNOWN'
    x=m.verify_cli_candidate_error(202,'P0001 failure',marker.replace(known,unknown,1),candidate)
    assert x['message_diagnostic']['class']=='unknown' and unknown not in str(x)
    for bad in (marker.replace('[202] STATEMENT:', '[203] STATEMENT:'), marker.replace('[202] ERROR:', '[203] ERROR:'), marker.replace('STATEMENT:','STATEMENT: SELECT 1;\n[202] LOG:'), marker+marker):
        rejects(lambda bad=bad:m.verify_cli_candidate_error(202,'P0001 failure',bad,candidate))
    rejects(lambda:m.verify_cli_candidate_error(202,'P0001 failure',marker+'SELECT 1;\n',candidate))
    rejects(lambda:m.verify_cli_candidate_error(202,'P0001 failure',marker+'SELECT 1; [333] LOG: disguised\n',candidate))
    rejects(lambda:m.verify_cli_candidate_error(202,'P0001 failure',marker+'[202] ERROR: P0001: other failure\n[202] STATEMENT: SELECT 1;\n',candidate))
    rejects(lambda:m.verify_cli_candidate_error(202,'42501 failure',marker,candidate))
    rejects(lambda:m.verify_cli_candidate_error(202,'P0001 failure',marker,candidate+b'bad'))

    base_table={'owner':1,'rls':True,'force':False,'rows':[],'policy':[],'other_acl':[],
      'other_effective':[],'columns':[],'memberships':[],'role_attributes':[],'hierarchy':[],
      'service':True,'anon':True,'authenticated':True,'acl':'old'}
    class Service:
        cid='a'*64;nonce='b'*32;token='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';run_id='123-1';verified=True
        def __init__(self,cli_fails=False):
            self.cli_fails=cli_fails;self.finished=False;self.member_committed=False;self.stopped=False;self.released=False;self.member_fails=False
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
                value=dict(base_table)
                if self.finished and not self.cli_fails:value.update(acl='revoked',authenticated=False)
                return json.dumps(value)
            if sql==m.snapshot_sql():
                value=dict(granted if self.member_committed else initial)
                if self.finished and not self.cli_fails:value.update(direct_anon=False,direct_authenticated=False,authenticated_truncate=False,anon_truncate=self.member_committed)
                return json.dumps(value)
            if 'pg_stat_activity WHERE pid IN' in sql:return '0'
            if 'jsonb_agg(jsonb_build_object' in sql:
                return '[]' if self.cli_fails else json.dumps([{'version':base.VERSION,'name':'synthetic_acl','statement_count':1}])
            return ''
        def logs(self):
            cli=('[202] LOG: 00000: connection received: host=127.0.0.1 port=123\n'
                 '[202] LOG: 00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli\n')
            extra=('[202] ERROR: P0001: synthetic failure\n[202] STATEMENT: '+candidate.decode('utf8')+'\n') if self.cli_fails else ''
            if self.member_fails:extra+='[404] ERROR: 42501: synthetic refusal\n[404] STATEMENT: '+m.GRANT_SQL+'\n'
            return '\n'.join(x['fatal_line'] for x in self.verified_negative_fatals)+'\n'+cli+logs+extra
    waiter={'pid':202,'target_oid':303}
    class Clients:
        def __init__(self,s,b):self.s=s
        def start_coordinator(self):return 101
        def start_cli(self):pass
        def release(self):self.s.released=True
        def finish_cli(self):self.s.finished=True;return (1,'P0001 synthetic failure') if self.s.cli_fails else (0,'')
        def close(self):pass
    class Member:
        def __init__(self,s,b):self.s=s
        def start(self):pass
        def poll_until(self,*args):return {'state':'statement_done','pid':404,'blockers':[]}
        def commit(self):self.s.member_committed=True
        def finish(self):return 0,out,''
        def close(self):pass
    with mock.patch.object(base,'OwnedService',Service),mock.patch.object(base,'safe_cli_binary',return_value=b'fake'),\
         mock.patch.object(phase2,'OwnedClients',Clients),mock.patch.object(m,'MemberClient',Member),\
         mock.patch.object(event,'wait_for_event',return_value=waiter),mock.patch.object(event,'prove_event_log'):
        for fails in (False,True):
            service=Service(fails)
            with contextlib.redirect_stdout(io.StringIO()):result=m.run_before(service,table,event,phase2,base)
            assert result['membership_grant']['status']=='committed' and result['membership_commit_before_cli_release']
            assert result['final_member'] and result['final_effective_anon_truncate'] and service.stopped
            assert result['cli']['status']==('sql_error' if fails else 'committed')
            assert result['history_count']==(0 if fails else 1)
            assert result['final_direct_anon_truncate']==fails
        class WaitingMember(Member):
            def __init__(self,s,b):super().__init__(s,b);self.calls=0
            def poll_until(self,*args):
                self.calls+=1
                return {'state':'lock_wait','pid':404,'blockers':[202]} if self.calls==1 else {'state':'statement_done','pid':404,'blockers':[]}
        waiting_service=Service()
        with mock.patch.object(m,'MemberClient',WaitingMember),contextlib.redirect_stdout(io.StringIO()):
            result=m.run_before(waiting_service,table,event,phase2,base)
        assert result['first_observation']=='lock_wait' and result['blocker_pids']==[202]
        assert not result['membership_commit_before_cli_release'] and waiting_service.released
        class FailedMember(Member):
            def poll_until(self,*args):return {'state':'client_exited'}
            def finish(self):return 1,'1\nSYNTHETIC_MEMBER_READY:404:303:301\n','ERROR: 42501: synthetic refusal'
        failed_service=Service();failed_service.member_fails=True
        with mock.patch.object(m,'MemberClient',FailedMember),contextlib.redirect_stdout(io.StringIO()):
            result=m.run_before(failed_service,table,event,phase2,base)
        assert result['membership_grant']['status']=='sql_error' and result['membership_grant']['sqlstate']=='42501'
        assert not result['final_member'] and not result['final_effective_anon_truncate'] and failed_service.stopped
        missing=Service()
        with mock.patch.object(event,'wait_for_event',return_value=None):rejects(lambda:m.run_before(missing,table,event,phase2,base))
        assert missing.stopped
        class Deadline(Member):
            def poll_until(self,*args):return {'state':'deadline'}
        timed=Service()
        with mock.patch.object(m,'MemberClient',Deadline):rejects(lambda:m.run_before(timed,table,event,phase2,base))
        assert timed.stopped
        class BrokenMember(Member):
            def close(self):raise RuntimeError('secret')
        bad_cleanup=Service();bad_cleanup.stop_owned=lambda:(_ for _ in ()).throw(RuntimeError('other-secret'))
        with mock.patch.object(m,'MemberClient',BrokenMember),contextlib.redirect_stdout(io.StringIO()):
            try:m.run_before(bad_cleanup,table,event,phase2,base)
            except event.PreflightCleanupError as exc:
                assert exc.client_cleanup_failed and exc.container_cleanup_unconfirmed and 'secret' not in str(exc)
            else:raise AssertionError('combined cleanup failure accepted')
    with mock.patch.object(subprocess,'Popen',side_effect=AssertionError('unexpected process')):
        rejects(lambda:m.MemberClient(types.SimpleNamespace(verified=False),base).start())
    process=mock.Mock();process.poll.return_value=None;process.wait.side_effect=[subprocess.TimeoutExpired('fake',5),0]
    owned=m.MemberClient(types.SimpleNamespace(),base);owned.proc=process
    owned.close();process.terminate.assert_called_once();process.kill.assert_called_once()
    print('PASS: mocked membership options, same PID/commit, A commit/rollback, timeout and cleanup')
    print('No Docker, database, CLI, network or subprocess was started.')


if __name__=='__main__':run()
