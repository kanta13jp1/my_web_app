"""Only mocks. Never starts a container, database, CLI, network or subprocess."""
import copy
import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import types
from unittest import mock

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('review_phase2',HERE/'phase2.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
base=m.load_runner()


def rejects(fn):
    try: fn()
    except (RuntimeError,ValueError): return
    raise AssertionError('invalid case was accepted')


def run():
    replaced=m.add_barrier(base.HISTORY_GATE)
    assert replaced.count('pg_advisory_xact_lock('+str(m.KEY)+')')==1
    assert replaced.index('pg_advisory_xact_lock') < replaced.index('SYNTHETIC_HISTORY_FAILURE')
    assert 'SYNTHETIC_ROUTE_OR_HISTORY_MISMATCH' in replaced
    rejects(lambda:m.add_barrier('different trigger'))
    assert m.only_coordinator([{'pid':101,'granted':True}])==101
    for bad in ([],[{'pid':0,'granted':True}],[{'pid':101,'granted':False}],
                [{'pid':101,'granted':True},{'pid':102,'granted':True}]):
        rejects(lambda bad=bad:m.only_coordinator(bad))
    good={'pid':202,'blocked_by':[101],'query_insert':True,'loopback':True,'state':'active',
          'wait_type':'Lock','wait':'advisory','target_oid':303,'target_lock':True,'barrier_wait':True}
    assert m.only_waiter([good],101)==good
    for field,value in [('pid',101),('blocked_by',[999]),('query_insert',False),('loopback',False),
                        ('state','idle'),('wait_type','Client'),('wait','other'),('target_oid',0),
                        ('target_lock',False),('barrier_wait',False)]:
        bad=dict(good);bad[field]=value;rejects(lambda bad=bad:m.only_waiter([bad],101))
    rejects(lambda:m.only_waiter([good,good],101))
    assert 'classid='+str(m.KEY_HIGH) in m.activity_sql('codex_coord_'+'a'*32)
    assert 'objid='+str(m.KEY_LOW) in m.waiting_sql()
    rejects(lambda:m.activity_sql('untrusted'))

    class Probe:
        nonce='a'*32;token='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        def __init__(self):self.log_count=0;self.bad=''
        def logs(self):
            self.log_count+=1
            if self.log_count==1:return 'prior\n'
            pid='999' if self.bad=='wrong_pid' else '404'
            auth='[404] LOG:  00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_probe_'+self.nonce+'\n'
            err='['+pid+'] ERROR:  55P03: could not obtain lock on relation "public.asset_pref_mirror"\n'
            return 'prior\n'+auth+err
        def exec(self,args,**kwargs):
            assert args[0]=='PGAPPNAME=codex_probe_'+self.nonce and kwargs['timeout']==10
            return types.SimpleNamespace(returncode=1,stdout=b'1\n404|303\n',stderr=b'ERROR: 55P03: could not obtain lock on relation "public.asset_pref_mirror"')
    assert m.conflict_probe(Probe(),base,good,101)==404
    wrong=Probe();wrong.bad='wrong_pid';rejects(lambda:m.conflict_probe(wrong,base,good,101))
    overlapping=Probe();rejects(lambda:m.conflict_probe(overlapping,base,dict(good,pid=404),101))
    wrong_target=Probe();rejects(lambda:m.conflict_probe(wrong_target,base,dict(good,target_oid=304),101))

    before={'owner':1,'rls':True,'force':False,'rows':[],'policy':[],'other_acl':[],
      'other_effective':[],'columns':[],'memberships':[],'role_attributes':[],'hierarchy':[],
      'service':True,'anon':True,'authenticated':True,'acl':'old'}
    after=dict(before,anon=False,authenticated=False,acl='revoked')
    class Service:
        cid='a'*64;nonce='b'*32;token='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        verified=True
        def __init__(self,outcome):
            self.outcome=outcome;self.stopped=False;self.finished=False
            self.verified_negative_fatals=[{'pid':'120','sqlstate':'28000','fatal_line':'[120] FATAL:  28000: expected database refusal'},
                                           {'pid':'121','sqlstate':'28P01','fatal_line':'[121] FATAL:  28P01: expected password refusal'}]
        def create(self):pass
        def wait_final_postmaster(self):pass
        def initialize(self):pass
        def configure_synthetic_loopback(self):pass
        def stage(self,*args):pass
        def stop_owned(self):self.stopped=True
        def psql(self,sql):
            if sql==base.SNAPSHOT:return json.dumps(after if self.finished and self.outcome=='success' else before)
            if sql==m.waiting_sql():return json.dumps([good])
            if 'pg_stat_activity WHERE pid=' in sql:return '0'
            if 'jsonb_agg(jsonb_build_object' in sql:
                return json.dumps([{'version':base.VERSION,'name':'synthetic_acl','statement_count':1}]) if self.outcome=='success' else '[]'
            if 'REACQUIRED' in sql:return 'REACQUIRED'
            return ''
        def logs(self):
            return ('\n'.join(x['fatal_line'] for x in self.verified_negative_fatals)+'\n'
              '[202] LOG: 00000: connection received: host=127.0.0.1 port=123\n'
              '[202] LOG: 00000: connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli\n'
              '[202] ERROR: P0001: SYNTHETIC_HISTORY_FAILURE\n'
              '[202] STATEMENT: INSERT INTO supabase_migrations.schema_migrations\n')
    class Clients:
        def __init__(self,s,base):self.s=s
        def start_coordinator(self):return 101
        def start_cli(self):pass
        def wait_barrier(self,coord):return good
        def release(self):pass
        def finish_cli(self):
            self.s.finished=True
            return (0,'') if self.s.outcome=='success' else (1,'P0001 SYNTHETIC_HISTORY_FAILURE')
        def close(self):pass
    with mock.patch.object(m,'OwnedClients',Clients),mock.patch.object(m,'conflict_probe',return_value=404):
        for outcome in ('success','history_failure'):
            service=Service(outcome);result=m.run_case(service,base,b'',b'',outcome)
            assert result['post_exit_lock_reacquired'] and result['cli_pid']==202 and service.stopped
        bad=Service('success');bad.logs=lambda:''
        rejects(lambda:m.run_case(bad,base,b'',b'','success'));assert bad.stopped
        failed_cleanup=Service('success')
        failed_cleanup.stop_owned=lambda:(_ for _ in ()).throw(RuntimeError('fake cleanup failure'))
        rejects(lambda:m.run_case(failed_cleanup,base,b'',b'','success'))
    closed=[]
    class TimeoutClients(Clients):
        def wait_barrier(self,coord):raise subprocess.TimeoutExpired('fake CLI',30)
        def close(self):closed.append(True)
    timed=Service('success')
    with mock.patch.object(m,'OwnedClients',TimeoutClients):
        try:m.run_case(timed,base,b'',b'','success')
        except subprocess.TimeoutExpired:pass
        else:raise AssertionError('deadline failure accepted')
    assert closed==[True] and timed.stopped
    process=mock.Mock();process.poll.return_value=None;process.wait.side_effect=[subprocess.TimeoutExpired('fake',5),0]
    client=m.OwnedClients(types.SimpleNamespace(),base);client.cli=(process,None,None)
    client.close();process.terminate.assert_called_once();process.kill.assert_called_once()

    spec=importlib.util.spec_from_file_location('review_entry',HERE/'phase2_entry.py')
    entry=importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
    phase,verified_base=entry.load_fixed()
    assert phase.KEY==m.KEY and verified_base.IMAGE==base.IMAGE
    reference=base.candidate_pair()['pr_do_no_boundaries']
    env={'GITHUB_SHA':'1'*40,'GH_TOKEN':'synthetic'}
    with mock.patch.object(entry,'PARENT','REVIEW_REQUIRED_DIAGNOSTIC_PARENT'):
        rejects(lambda:entry.verify_context(base,env,reference))  # Unpinned parent must fail before any command.
    pr={'state':'open','head':{'sha':entry.PR_HEAD,'repo':{'full_name':'kanta13jp1/my_web_app'}},'base':{'sha':entry.PR_BASE}}
    source={'encoding':'base64','content':base64.b64encode(reference).decode()}
    def fake_context(args,env):
        if args[0]=='/usr/bin/git':return (('1'*40)+' '+('2'*40)+'\n').encode()
        return json.dumps(pr if args[-1].endswith('/pulls/5980') else source).encode()
    with mock.patch.object(entry,'PARENT','2'*40),mock.patch.object(entry,'command',side_effect=fake_context),mock.patch.object(base,'job_identity',return_value='123-1'):
        assert entry.verify_context(base,env,reference)=='1'*40
        rejects(lambda:entry.verify_context(base,env,b'wrong'))
        pr['head']['sha']='3'*40
        rejects(lambda:entry.verify_context(base,env,reference))
    print('PASS: mock barrier identity, 55P03 PID, success/rollback and cleanup failures')
    print('No Docker, database, CLI, cloud job, network or subprocess was started.')


if __name__=='__main__':run()
