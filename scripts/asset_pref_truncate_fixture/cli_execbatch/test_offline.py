"""Pure offline checks for the unexecuted diagnostic; never launches Docker."""
import ast
import copy
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile
import types

HERE = Path(__file__).resolve().parent

def run():
    ast.parse((HERE / 'runner.py').read_bytes())
    m = runpy.run_path(str(HERE / 'runner.py'), run_name='offline_review')
    pair = m['candidate_pair']()
    assert set(pair) == {'explicit', 'batch', 'pr_head_06505ee4'}
    branch='refs/heads/codex/asset-pref-cli-execbatch-diagnostic-20261104'
    trusted={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':'kanta13jp1/my_web_app',
      'GITHUB_EVENT_NAME':'workflow_dispatch','GITHUB_JOB':'cli-execbatch-isolated','GITHUB_REF':branch,
      'GITHUB_WORKFLOW_REF':'kanta13jp1/my_web_app/.github/workflows/cloud-development.yml@'+branch,
      'GITHUB_RUN_ID':'123','GITHUB_RUN_ATTEMPT':'1','GITHUB_SHA':'a'*40,'SYNTHETIC_EXPECTED_HEAD':'a'*40}
    assert m['job_identity'](trusted)=='123-1'
    for key,value in [('GITHUB_REPOSITORY','wrong/repo'),('RUNNER_ENVIRONMENT','self-hosted'),('GITHUB_REF','refs/heads/main'),
                      ('GITHUB_JOB','wrong'),('GITHUB_EVENT_NAME','push'),('GITHUB_WORKFLOW_REF','wrong'),
                      ('GITHUB_RUN_ID','bad'),('GITHUB_SHA','b'*40),('SYNTHETIC_EXPECTED_HEAD','bad')]:
        bad=dict(trusted);bad[key]=value
        try:m['job_identity'](bad)
        except RuntimeError:pass
        else:raise AssertionError('untrusted workflow accepted '+key)
    elf = bytearray(64); elf[:6] = b'\x7fELF\x02\x01'; elf[18:20] = (62).to_bytes(2, 'little')
    def archive(items):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w:gz') as tf:
            for name, kind, data in items:
                member = tarfile.TarInfo(name)
                if kind == 'file':
                    member.size = len(data); tf.addfile(member, io.BytesIO(data))
                elif kind == 'symlink':
                    member.type = tarfile.SYMTYPE; member.linkname = 'elsewhere'; tf.addfile(member)
                elif kind == 'hardlink':
                    member.type = tarfile.LNKTYPE; member.linkname = 'elsewhere'; tf.addfile(member)
        return stream.getvalue()
    parse = m['extract_binary_from_verified_archive']
    assert parse(archive([('./supabase','file',bytes(elf))])) == bytes(elf)
    unsafe = [
        [('../supabase','file',bytes(elf))], [('/supabase','file',bytes(elf))],
        [('supabase','symlink',b'')], [('supabase','hardlink',b'')],
        [('supabase','file',bytes(elf)),('./supabase','file',bytes(elf))],
        [('supabase','file',b'bad')], [('..\\supabase','file',bytes(elf))],
    ]
    for items in unsafe:
        try: parse(archive(items))
        except RuntimeError: pass
        else: raise AssertionError('unsafe archive accepted: ' + repr(items))
    image = {'Id':'sha256:'+'1'*64, 'RepoDigests':[m['IMAGE']],
             'Config':{'Env':['PGDATA=/var/lib/postgresql/data'],'Entrypoint':['entry'],'Cmd':['postgres'],'User':''}}
    service = m['OwnedService']([], {}, image, '123-1'); service.cid='a'*64; service.nonce='b'*32
    info = {'Id':service.cid,'Image':image['Id'],
      'Config':{'Image':m['IMAGE'],'Labels':{'codex.execbatch.owner':service.nonce,'codex.execbatch.scope':'synthetic','codex.execbatch.run':'123-1'},
        'Env':['PGDATA=/var/lib/postgresql/data','POSTGRES_DB='+m['DB'],'POSTGRES_PASSWORD='+m['FIXTURE_PASSWORD']],
        'Entrypoint':['entry'],'Cmd':m['SERVER_CMD'],'User':'','Tty':False,'OpenStdin':False},
      'HostConfig':{'NetworkMode':'none','IpcMode':'private','PidMode':'','UsernsMode':'',
        'PublishAllPorts':False,'Privileged':False,'Tmpfs':{'/var/lib/postgresql/data':'rw,nosuid,size=256m',
        '/tmp':'rw,nosuid,nodev,exec,size=192m,mode=1777'}},
      'NetworkSettings':{'Networks':{'none':{}},'Ports':{'5432/tcp':None}},'State':{'Running':True},'Mounts':[]}
    service.command = lambda args: types.SimpleNamespace(stdout=json.dumps([info]).encode())
    assert service.inspect(running=True)['Id'] == service.cid
    bad_values = [
      (('HostConfig','NetworkMode'),'bridge'), (('HostConfig','Privileged'),True),
      (('HostConfig','Binds'),['/host:/x']), (('Config','Tty'),True), (('Config','User'),'root'),
      (('Config','Cmd'),['postgres']), (('NetworkSettings','Networks'),{'bridge':{}}),
      (('HostConfig','CapAdd'),['SYS_ADMIN']), (('Config','Labels'),{'codex.execbatch.owner':'wrong'}),
      (('Config','Env'),info['Config']['Env']+['SUPABASE_ACCESS_TOKEN=bad']),
    ]
    for path, value in bad_values:
        bad=copy.deepcopy(info); bad[path[0]][path[1]]=value
        service.command=lambda args,bad=bad: types.SimpleNamespace(stdout=json.dumps([bad]).encode())
        try: service.inspect(running=True)
        except RuntimeError: pass
        else: raise AssertionError('invalid container accepted: ' + repr(path))
    good_mount = '33 1 0:55 / /tmp rw,nosuid,nodev,relatime - tmpfs tmpfs rw,size=196608k,mode=1777\n'
    assert m['parse_tmp_mountinfo'](good_mount)['filesystem'] == 'tmpfs'
    for bad in (good_mount.replace('nodev,',''),good_mount.replace('nosuid,',''),
                good_mount.replace('relatime','noexec'), good_mount.replace('tmpfs tmpfs','overlay overlay'),
                good_mount.replace('tmpfs rw,size','tmpfs rw,noexec,size'),
                good_mount + good_mount, '',good_mount.replace('rw,nosuid','ro,nosuid')):
        try:m['parse_tmp_mountinfo'](bad)
        except RuntimeError:pass
        else:raise AssertionError('unsafe runtime mount accepted')
    cid='d'*64
    for message in ('error: no such object: '+cid,'Error: No Such Container: '+cid,
                    'Error response from daemon: No such object: '+cid):
        assert m['verify_removed'](cid,1,'[]\n',message+'\n',0,'','') is True
    invalid = [(0,'','error: no such object: '+cid,0,'',''),
               (1,'','error: no such object: '+'e'*64,0,'',''),
               (1,'','daemon unavailable: no such object: '+cid,0,'',''),
               (1,'unexpected','error: no such object: '+cid,0,'',''),
               (1,'','error: no such object: '+cid,1,'','daemon failed'),
               (1,'','error: no such object: '+cid,0,'f'*64,'')]
    for args in invalid:
        try:m['verify_removed'](cid,*args)
        except RuntimeError:pass
        else:raise AssertionError('ambiguous removal accepted: '+repr(args))
    binary_service=m['OwnedService']([],{},image,'123-1');binary_service.cid='a'*64;binary_service.nonce='b'*32
    binary_service.cli_binary_sha='1'*64
    def fake_exec(args,**kwargs):
        first=args[0]
        if first=='/bin/cat':value=good_mount
        elif args==['/usr/bin/id','-u']:value='999\n'
        elif args==['/usr/bin/id','-g']:value='999\n'
        elif first=='/usr/bin/stat':value='999|999|700|regular file|1\n'
        elif first=='/usr/bin/sha256sum':value='1'*64+'  /tmp/codex-cli/supabase-cli\n'
        else:raise AssertionError('unexpected pure fake command: '+repr(args))
        return types.SimpleNamespace(stdout=value.encode())
    binary_service.exec=fake_exec
    import contextlib
    with contextlib.redirect_stdout(io.StringIO()):assert binary_service.verify_cli_binary()['sha256']=='1'*64
    def altered(field, replacement):
        def call(args,**kwargs):
            response=fake_exec(args,**kwargs)
            if args[0]==field:return types.SimpleNamespace(stdout=replacement.encode())
            return response
        return call
    for field,value in [('/bin/cat',good_mount.replace('relatime','noexec')),
                        ('/usr/bin/stat','0|999|700|regular file|1\n'),
                        ('/usr/bin/stat','999|999|755|regular file|1\n'),
                        ('/usr/bin/stat','999|999|700|symbolic link|1\n'),
                        ('/usr/bin/sha256sum','2'*64+'  /tmp/codex-cli/supabase-cli\n')]:
        binary_service.exec=altered(field,value)
        try:
            with contextlib.redirect_stdout(io.StringIO()):binary_service.verify_cli_binary()
        except RuntimeError:pass
        else:raise AssertionError('unsafe CLI binary evidence accepted: '+field)
    cleanup=m['OwnedService']([],{},image,'123-1');cleanup.cid=cid;cleanup.nonce='b'*32;cleanup.verified=True
    cleanup.inspect=lambda running=None: {'State':{'Running': running is not False}}
    calls=[]
    def fake_docker(args,**kwargs):
        calls.append(args)
        if args[0]=='inspect':return types.SimpleNamespace(returncode=1,stdout=b'[]\n',stderr=('error: no such object: '+cid+'\n').encode())
        return types.SimpleNamespace(returncode=0,stdout=b'',stderr=b'')
    cleanup.command=fake_docker
    with contextlib.redirect_stdout(io.StringIO()):cleanup.stop_owned()
    assert [args[0] for args in calls]==['stop','rm','inspect','ps']
    assert calls[-1]==['ps','--all','--no-trunc','--filter','id='+cid,'--format','{{.ID}}']
    calls.clear()
    def failed_rm(args,**kwargs):
        calls.append(args)
        if args[0]=='rm':raise subprocess.CalledProcessError(1,args)
        return types.SimpleNamespace(returncode=0,stdout=b'',stderr=b'')
    cleanup.command=failed_rm
    try:cleanup.stop_owned()
    except subprocess.CalledProcessError:pass
    else:raise AssertionError('failed rm accepted')
    assert [args[0] for args in calls]==['stop','rm']
    print('PASS: successful exact owned stop/rm/inspect/ps order and rm-failure short circuit')
    print('PASS: runtime mount, executable ownership/mode/hash, and exact-CID dual absence checks')

    state='synthetic_execbatch|postgres|17|t|t|t|2026-11-04 00:00:00+00|123'
    valid=m['validate_ready_state'](state)
    assert valid['unix_socket'] and valid['not_in_recovery'] and valid['postmaster_pid']=='123'
    for bad in (state.replace('synthetic_execbatch','postgres'),state.replace('|17|','|16|'),
                state.replace('|t|t|t|','|t|f|t|'),state.replace('|t|t|t|','|t|t|f|'),
                state.rsplit('|',1)[0]+'|abc',''):
        try:m['validate_ready_state'](bad)
        except RuntimeError:pass
        else:raise AssertionError('invalid database readiness identity accepted')
    assert m['classify_psql_stderr'](b'FATAL: password authentication failed for private-user')['categories']==['authentication']
    assert 'private-user' not in str(m['FixturePsqlError'](2,b'FATAL: password authentication failed for private-user'))
    assert m['classify_failure'](RuntimeError('postmaster changed during final readiness confirmation'))['categories']==['postmaster_changed']
    tree=ast.parse((HERE/'runner.py').read_bytes())
    case=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='run_case')
    calls=[n.func.attr for n in ast.walk(case) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr in ('wait_final_postmaster','initialize')]
    assert calls.count('wait_final_postmaster')==1 and calls.count('initialize')==1
    summary=m['summarize_server_logs']('FATAL: password authentication failed for private-user\n')
    assert summary['fatal_line_count']==1 and 'private-user' not in repr(summary)
    class ReadyFake:
        def __init__(self, outputs, probes=(0,), logs=None):
            self.outputs=list(outputs);self.probes=list(probes);self.psql_calls=0;self.exec_calls=0
            self.log_lines=list(logs or [m['STARTUP_MARKER']]);self.run_id='123-1';self.nonce='b'*32;self.cid='a'*64
        def logs(self):return self.log_lines.pop(0) if len(self.log_lines)>1 else self.log_lines[0]
        def exec(self,args,**kwargs):
            self.exec_calls+=1;return types.SimpleNamespace(returncode=self.probes.pop(0))
        def psql(self,sql,**kwargs):
            self.psql_calls+=1;out=self.outputs.pop(0)
            if isinstance(out,Exception):raise out
            return out
    from unittest.mock import patch
    import contextlib
    ready=m['OwnedService'].wait_final_postmaster
    with patch.object(m['time'],'sleep',lambda _:None), contextlib.redirect_stdout(io.StringIO()):
        good=ReadyFake([state,state],probes=(1,2,0),logs=['initializing',m['STARTUP_MARKER']])
        assert ready(good)['postmaster_pid']=='123' and good.psql_calls==2 and good.exec_calls==3
        auth=ReadyFake([m['FixturePsqlError'](2,b'FATAL: password authentication failed')])
        try:ready(auth)
        except m['FixturePsqlError']:pass
        else:raise AssertionError('authentication error accepted')
        assert auth.psql_calls==1 and auth.exec_calls==1
        wrong=ReadyFake([state.replace('synthetic_execbatch','postgres')])
        try:ready(wrong)
        except RuntimeError:pass
        else:raise AssertionError('wrong database accepted')
        assert wrong.psql_calls==1
        changed=ReadyFake([state,state.rsplit('|',1)[0]+'|124'])
        try:ready(changed)
        except RuntimeError:pass
        else:raise AssertionError('postmaster restart accepted')
        duplicate=ReadyFake([],logs=[m['STARTUP_MARKER']*2])
        try:ready(duplicate)
        except RuntimeError:pass
        else:raise AssertionError('repeated initialization marker accepted')
        fatal_start=ReadyFake([],logs=['FATAL: password authentication failed for a synthetic role'])
        try:ready(fatal_start)
        except RuntimeError:pass
        else:raise AssertionError('fatal startup authentication error accepted')
        assert fatal_start.exec_calls==0 and fatal_start.psql_calls==0
        fatal_after_marker=ReadyFake([],logs=[m['STARTUP_MARKER'],m['STARTUP_MARKER']+'\nFATAL: password authentication failed'])
        try:ready(fatal_after_marker)
        except RuntimeError:pass
        else:raise AssertionError('fatal immediately after marker accepted')
        assert fatal_after_marker.exec_calls==0 and fatal_after_marker.psql_calls==0
        fatal_after_probe=ReadyFake([],probes=(1,),logs=[m['STARTUP_MARKER'],m['STARTUP_MARKER'],m['STARTUP_MARKER']+'\nFATAL: role "postgres" does not exist'])
        try:ready(fatal_after_probe)
        except RuntimeError:pass
        else:raise AssertionError('fatal after transient readiness probe accepted')
        assert fatal_after_probe.exec_calls==1 and fatal_after_probe.psql_calls==0
        for fatal_line in ('FATAL: database \"synthetic_execbatch\" does not exist', 'FATAL: unidentified failure', 'PANIC: unidentified failure'):
            for lines in ([fatal_line], [m['STARTUP_MARKER'],m['STARTUP_MARKER']+'\n'+fatal_line]):
                fatal_any=ReadyFake([],logs=lines)
                try:ready(fatal_any)
                except RuntimeError:pass
                else:raise AssertionError('unclassified FATAL/PANIC accepted')
                assert fatal_any.exec_calls==0 and fatal_any.psql_calls==0
        post_probe_fatal=ReadyFake([],probes=(0,),logs=[m['STARTUP_MARKER'],m['STARTUP_MARKER'],m['STARTUP_MARKER']+'\nFATAL: unidentified failure'])
        try:ready(post_probe_fatal)
        except RuntimeError:pass
        else:raise AssertionError('fatal after successful readiness probe accepted')
        assert post_probe_fatal.exec_calls==1 and post_probe_fatal.psql_calls==0
        between_selects_fatal=ReadyFake([state],probes=(0,),logs=[m['STARTUP_MARKER'],m['STARTUP_MARKER'],m['STARTUP_MARKER'],m['STARTUP_MARKER']+'\nPANIC: unidentified failure'])
        try:ready(between_selects_fatal)
        except RuntimeError:pass
        else:raise AssertionError('fatal between identity checks accepted')
        assert between_selects_fatal.exec_calls==1 and between_selects_fatal.psql_calls==1
        invalid_probe=ReadyFake([],probes=(3,))
        try:ready(invalid_probe)
        except RuntimeError:pass
        else:raise AssertionError('unexpected pg_isready result accepted')
    print('PASS: final-server marker, transient readiness, two stable identity probes and fail-fast auth/identity/restart')

    class SimulatedService:
        def __init__(self, mode, outcome, bad_route=False):
            self.mode, self.outcome, self.bad_route = mode, outcome, bad_route
            self.executed = False
            self.before = {'owner':'10','rls':True,'force':False,'rows':[], 'policy':[],
                           'hierarchy':[], 'service':True,'anon':True,'authenticated':True,'acl':'initial',
                           'other_acl':[],'other_effective':[],'columns':[],'memberships':[],'role_attributes':[]}
            self.after = dict(self.before)
            if outcome == 'success' or (outcome == 'history_failure' and mode == 'explicit'):
                self.after.update(anon=False,authenticated=False,acl='revoked')
        def create(self): pass
        def wait_final_postmaster(self): pass
        def exec(self, args, **kwargs): return types.SimpleNamespace(returncode=0)
        def initialize(self): pass
        def psql(self, sql):
            if sql == m['SNAPSHOT']: return json.dumps(self.after if self.executed else self.before)
            if 'FROM supabase_migrations.schema_migrations;' in sql:
                return json.dumps([{'version':'20991231000000','name':'synthetic_acl','statement_count':2}]) if self.outcome == 'success' else '[]'
            if 'FROM pg_catalog.pg_stat_activity' in sql:return '0'
            return ''
        def stage(self, binary, migration): pass
        def cli_push(self):
            self.executed=True
            output = {'success':'applied', 'history_failure':'P0001 SYNTHETIC_HISTORY_FAILURE INSERT INTO supabase_migrations.schema_migrations',
                      'candidate_failure':'P0001 inheritance or partition relationship requires separate review'}[self.outcome]
            return types.SimpleNamespace(returncode=0 if self.outcome=='success' else 1,
                                         stdout=output.encode(),stderr=b'')
        def logs(self):
            host = '127.0.0.1' if self.bad_route else '[local]'
            failure = {'success':'', 'history_failure':'SYNTHETIC_HISTORY_FAILURE',
                       'candidate_failure':'inheritance or partition relationship requires separate review'}[self.outcome]
            error = '' if not failure else '[140] ERROR:  P0001: ' + failure + '\n'
            statement = '[140] STATEMENT:  INSERT INTO supabase_migrations.schema_migrations\n' if self.outcome == 'history_failure' else ''
            return ('[140] LOG:  00000: connection received: host=' + host + '\n'
                    '[140] LOG:  00000: connection authorized: user=postgres database=synthetic_execbatch '
                    'application_name=codex_execbatch_cli\n' + error + statement)
    import contextlib
    for mode in ('explicit','batch','pr_head_06505ee4'):
        outcomes = ('success','history_failure') if mode == 'pr_head_06505ee4' else ('success','history_failure','candidate_failure')
        for outcome in outcomes:
            service=SimulatedService(mode,outcome)
            with contextlib.redirect_stdout(io.StringIO()):
                observed=m['run_case'](service,mode,outcome,b'fake',pair[mode])
            if outcome=='history_failure':
                expected = 'only_target_truncate_removed' if mode=='explicit' else 'complete_acl_unchanged'
                assert observed['history_failure_effect'] == expected
            assert observed['history_count']==(1 if outcome=='success' else 0)
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            m['run_case'](SimulatedService('batch','success',bad_route=True),'batch','success',b'fake',pair['batch'])
    except RuntimeError: pass
    else: raise AssertionError('TCP route accepted instead of fixed Unix socket')
    def assert_case_rejected(service, mode, outcome):
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                m['run_case'](service,mode,outcome,b'fake',pair[mode])
        except RuntimeError: return
        raise AssertionError('unsafe case accepted: ' + mode + '/' + outcome)
    for attack in ('statement_only','wrong_error_pid','wrong_insert_pid'):
        service=SimulatedService('batch','history_failure')
        def forged_logs(attack=attack):
            prefix=('[140] LOG:  00000: connection received: host=[local]\n'
                    '[140] LOG:  00000: connection authorized: user=postgres database=synthetic_execbatch '
                    'application_name=codex_execbatch_cli\n')
            if attack=='statement_only': return prefix+'[140] STATEMENT: INSERT INTO supabase_migrations.schema_migrations SYNTHETIC_HISTORY_FAILURE\n'
            if attack=='wrong_error_pid': return prefix+'[141] ERROR: P0001: SYNTHETIC_HISTORY_FAILURE\n[140] STATEMENT: INSERT INTO supabase_migrations.schema_migrations\n'
            return prefix+'[140] ERROR: P0001: SYNTHETIC_HISTORY_FAILURE\n[141] STATEMENT: INSERT INTO supabase_migrations.schema_migrations\n'
        service.logs=forged_logs
        assert_case_rejected(service,'batch','history_failure')
    partial=SimulatedService('batch','history_failure');partial.after.update(anon=False,acl='unexpected-partial')
    assert_case_rejected(partial,'batch','history_failure')
    guard_changed=SimulatedService('batch','candidate_failure');guard_changed.after['acl']='unexpected-acl'
    assert_case_rejected(guard_changed,'batch','candidate_failure')
    print('PASS: same-PID ERROR/INSERT proof, unexpected partial ACL and guard-drift refusals')
    print('PASS: AST; fixed STOP candidate pair/diff; safe synthetic tar; ELF; seven archive, ten container and nine workflow identity rejections')
    print('PASS: eight synthetic result-classification cases and wrong-route refusal')
    print('No Docker, database, CLI, cloud job, or network was started.')

if __name__ == '__main__': run()