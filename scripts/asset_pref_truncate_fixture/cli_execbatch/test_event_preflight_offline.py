"""Pure mocks for event preflight; never starts DB, Docker, CLI or network."""
import hashlib
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import types
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('event_preflight_review',HERE/'event_preflight.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
phase2,base=m.load_fixed()


def rejects(fn):
    try:
        with contextlib.redirect_stdout(io.StringIO()):fn()
    except (RuntimeError,ValueError,subprocess.TimeoutExpired):return
    raise AssertionError('invalid case accepted')


def run():
    candidate=base.candidate_pair()['locked_single_do']
    assert hashlib.sha256(candidate).hexdigest()==m.CANDIDATE_BODY_SHA
    gate=m.gate_sql('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',phase2.KEY)
    assert "WHEN TAG IN ('REVOKE')" in gate and 'ddl_command_start' in gate
    assert "l.mode='AccessExclusiveLock' AND l.granted" in gate
    assert 'SYNTHETIC_REVOKE_EVENT_START' in gate and str(phase2.KEY) in gate
    rejects(lambda:m.gate_sql('not-a-token',phase2.KEY))
    rejects(lambda:m.gate_sql('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',99))
    good={'pid':202,'blocked_by':[101],'loopback':True,'state':'active',
      'wait_type':'Lock','wait':'advisory','target_oid':303,'target_lock':True,'barrier_wait':True}
    assert m.only_event_waiter([good],101)==good
    for field,value in [('pid',101),('blocked_by',[999]),('loopback',False),('state','idle'),
      ('wait_type','Client'),('wait','other'),('target_oid','303'),('target_oid',0),
      ('target_oid',4294967296),('target_lock',False),('barrier_wait',False)]:
        bad=dict(good);bad[field]=value;rejects(lambda bad=bad:m.only_event_waiter([bad],101))
    log=('[202] LOG: 00000: connection received: host=127.0.0.1 port=123\n'
         '[202] LOG: 00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli\n'
         '[202] LOG: 00000: SYNTHETIC_REVOKE_EVENT_START target_oid=303\n')
    m.prove_event_log(log,good)
    for bad in (log.replace('target_oid=303','target_oid=304'),log.replace('[202] LOG: 00000: SYNTHETIC','[203] LOG: 00000: SYNTHETIC'),
                log.replace('host=127.0.0.1','host=other')):
        rejects(lambda bad=bad:m.prove_event_log(bad,good))
    assert "::regclass::oid::bigint" in m.event_wait_sql(phase2)
    assert str(phase2.KEY_HIGH) in m.event_wait_sql(phase2) and str(phase2.KEY_LOW) in m.event_wait_sql(phase2)
    fake_clients=types.SimpleNamespace(cli=(types.SimpleNamespace(poll=lambda:None),None,None),bounded=lambda files:None)
    with mock.patch.object(m.time,'monotonic',side_effect=[0,31]):
        rejects(lambda:m.wait_for_event(types.SimpleNamespace(),fake_clients,phase2,101))

    before={'owner':1,'rls':True,'force':False,'rows':[],'policy':[],'other_acl':[],
      'other_effective':[],'columns':[],'memberships':[],'role_attributes':[],'hierarchy':[],
      'service':True,'anon':True,'authenticated':True,'acl':'old'}
    after=dict(before,anon=False,authenticated=False,acl='revoked')
    class Service:
        cid='a'*64;nonce='b'*32;token='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';run_id='123-1';verified=True
        def __init__(self,fired):
            self.fired=fired;self.finished=False;self.stopped=False
            self.verified_negative_fatals=[{'pid':'120','sqlstate':'28000','fatal_line':'[120] FATAL:  28000: expected database refusal'},
                                           {'pid':'121','sqlstate':'28P01','fatal_line':'[121] FATAL:  28P01: expected password refusal'}]
        def create(self):pass
        def wait_final_postmaster(self):pass
        def initialize(self):pass
        def configure_synthetic_loopback(self):pass
        def stage(self,*args):assert args[1]==candidate
        def stop_owned(self):
            self.stopped=True
            print('SYNTHETIC_EXECBATCH_TEARDOWN '+json.dumps({'run_id':self.run_id,'nonce':self.nonce,'container_id':self.cid,
              'stopped_removed':True,'inspect_absent':True,'ps_absent':True,'holder_client_stopped':True,'extra':'DO_NOT_OUTPUT_TOKEN'}))
        def logs(self):
            data='\n'.join(x['fatal_line'] for x in self.verified_negative_fatals)+'\n'+log
            return data if self.fired else data.replace('[202] LOG: 00000: SYNTHETIC_REVOKE_EVENT_START target_oid=303\n','')
        def psql(self,sql):
            if sql==base.SNAPSHOT:return json.dumps(after if self.finished else before)
            if 'pg_stat_activity WHERE pid IN' in sql:return '0'
            if 'jsonb_agg(jsonb_build_object' in sql:return json.dumps([{'version':base.VERSION,'name':'synthetic_acl','statement_count':1}])
            return ''
    closed=[]
    class Clients:
        def __init__(self,s,b):self.s=s
        def start_coordinator(self):return 101
        def start_cli(self):pass
        def release(self):pass
        def finish_cli(self):self.s.finished=True;return 0,''
        def close(self):closed.append(True)
    service=Service(True)
    marker={'run_id':service.run_id,'nonce':service.nonce,'container_id':service.cid,'stopped_removed':True,
      'inspect_absent':True,'ps_absent':True,'holder_client_stopped':True}
    checked=m.validate_teardown('SYNTHETIC_EXECBATCH_TEARDOWN '+json.dumps(dict(marker,extra='DO_NOT_OUTPUT_TOKEN')),service)
    assert checked==marker and 'DO_NOT_OUTPUT_TOKEN' not in str(checked)
    for key in ('run_id','nonce','container_id','stopped_removed','inspect_absent','ps_absent','holder_client_stopped'):
        bad=dict(marker);bad[key]=False
        rejects(lambda bad=bad:m.validate_teardown('SYNTHETIC_EXECBATCH_TEARDOWN '+json.dumps(bad),service))
    rejects(lambda:m.validate_teardown('',service))
    with mock.patch.object(base,'safe_cli_binary',return_value=b'fixed-fake'),mock.patch.object(phase2,'OwnedClients',Clients),mock.patch.object(base,'OwnedService',Service):
        for fired in (True,False):
            service=Service(fired)
            with mock.patch.object(m,'wait_for_event',return_value=good if fired else None):
                with contextlib.redirect_stdout(io.StringIO()) as out:
                    result=m.run_preflight(service,phase2,base)
            assert result['outcome']==('fired' if fired else 'not_observed')
            assert result['ready_for_competition']==fired and result['cleanup_confirmed'] is True and service.stopped
            output=out.getvalue();prefix='SYNTHETIC_EVENT_OWNED_TEARDOWN '
            assert output.startswith(prefix) and 'DO_NOT_OUTPUT_TOKEN' not in output
            record=json.loads(output[len(prefix):]);assert record==dict(marker,client_cleanup_confirmed=True)
        timed=Service(True)
        with mock.patch.object(m,'wait_for_event',side_effect=subprocess.TimeoutExpired('fake',30)):
            rejects(lambda:m.run_preflight(timed,phase2,base))
        assert timed.stopped
        unknown=Service(True)
        with mock.patch.object(m,'wait_for_event',return_value=None):
            rejects(lambda:m.run_preflight(unknown,phase2,base))
        assert unknown.stopped
        bad_cleanup=Service(True);bad_cleanup.stop_owned=lambda:(_ for _ in ()).throw(RuntimeError('cleanup'))
        with mock.patch.object(m,'wait_for_event',return_value=good):
            rejects(lambda:m.run_preflight(bad_cleanup,phase2,base))
        gate_error=Service(True);original_psql=gate_error.psql
        def fail_gate(sql):
            if 'CREATE FUNCTION public.codex_revoke_event_gate' in sql:
                raise base.FixturePsqlError(1,('synthetic SQL token='+gate_error.token).encode())
            return original_psql(sql)
        gate_error.psql=fail_gate
        with contextlib.redirect_stdout(io.StringIO()):
            try:m.run_preflight(gate_error,phase2,base)
            except m.PreflightRunError as exc:
                assert gate_error.token not in str(exc) and exc.original_error_type=='FixturePsqlError' and exc.cleanup_confirmed is True and gate_error.stopped
            else:raise AssertionError('gate failure accepted')
        missing=Service(True);missing.stop_owned=lambda:setattr(missing,'stopped',True)
        with mock.patch.object(m,'wait_for_event',return_value=good):
            try:m.run_preflight(missing,phase2,base)
            except m.PreflightCleanupError as exc:
                assert exc.cleanup_confirmed is None and exc.container_cleanup_unconfirmed
            else:raise AssertionError('missing teardown marker accepted')
        both=Service(True);both.stop_owned=lambda:(_ for _ in ()).throw(RuntimeError('raw-secret'))
        class BrokenClients(Clients):
            def close(self):raise RuntimeError('client-raw-secret')
        only_client=Service(True)
        with mock.patch.object(phase2,'OwnedClients',BrokenClients),mock.patch.object(m,'wait_for_event',return_value=good),contextlib.redirect_stdout(io.StringIO()) as out:
            try:m.run_preflight(only_client,phase2,base)
            except m.PreflightCleanupError as exc:
                assert exc.client_cleanup_failed and not exc.container_cleanup_unconfirmed
            else:raise AssertionError('client cleanup failure accepted')
        prefix='SYNTHETIC_EVENT_OWNED_TEARDOWN '
        assert json.loads(out.getvalue()[len(prefix):])==dict(marker,client_cleanup_confirmed=False)
        assert 'DO_NOT_OUTPUT_TOKEN' not in out.getvalue() and 'raw-secret' not in out.getvalue()
        with mock.patch.object(phase2,'OwnedClients',BrokenClients),mock.patch.object(m,'wait_for_event',side_effect=ValueError('original-raw-secret')):
            try:m.run_preflight(both,phase2,base)
            except m.PreflightCleanupError as exc:
                assert exc.original_error_type=='ValueError' and exc.client_cleanup_failed and exc.container_cleanup_unconfirmed
                assert 'raw-secret' not in str(exc)
            else:raise AssertionError('combined failures accepted')
    assert len(closed)>=6
    nonowned=types.SimpleNamespace(verified=False)
    rejects(lambda:m.run_preflight(nonowned,phase2,base))
    with mock.patch.object(subprocess,'Popen',side_effect=AssertionError('unexpected subprocess')):
        rejects(lambda:phase2.OwnedClients(nonowned,base).spawn([],stdin=None))
    print('PASS: fake fired/not-observed/inconclusive, PID/OID, deadline and owned cleanup')
    print('No Docker, database, CLI, network or subprocess was started.')


if __name__=='__main__':run()
