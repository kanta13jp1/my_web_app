"""Pure offline checks for the unexecuted diagnostic; never launches Docker."""
import ast
import copy
import hashlib
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
    history_gate=m['HISTORY_GATE']
    route_conditions=("inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet",
                      "inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet",
                      'inet_server_port() IS DISTINCT FROM 5432')
    assert all(history_gate.count(condition)==1 for condition in route_conditions)
    assert 'inet_client_addr() IS NOT NULL' not in history_gate and 'inet_server_addr() IS NOT NULL' not in history_gate
    # Model SQL IS DISTINCT FROM, including NULL; no database is started.
    def mocked_route_allowed(client, server, port):
        return not (client != '127.0.0.1' or server != '127.0.0.1' or port != 5432)
    assert mocked_route_allowed('127.0.0.1','127.0.0.1',5432)
    for bad_route in ((None,None,None),('127.0.0.2','127.0.0.1',5432),
                      ('127.0.0.1','127.0.0.2',5432),('127.0.0.1','127.0.0.1',5433),
                      ('127.0.0.1','127.0.0.1',None),('::1','::1',5432)):
        assert not mocked_route_allowed(*bad_route)
    print('PASS: mocked history route allows fixed IPv4/port and rejects socket/non-loopback/other ports')
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

    def encoded_records(items):
        return b''.join((kind+'\0'+mode+'\0'+str(size)+'\0'+path+'\0').encode('utf-8') for kind,mode,size,path in items)
    root='/tmp/codex-cli/supabase/'
    good_records=[('d','700',40,root+'migrations'),('f','600',3,root+'config.toml'),
                  ('f','600',4,root+'migrations/20991231000000_synthetic_acl.sql')]
    parsed=m['parse_project_tree'](encoded_records(good_records))
    assert {e['path'] for e in parsed}=={'migrations','config.toml','migrations/20991231000000_synthetic_acl.sql'}
    for bad in (b'',b'f\0',encoded_records([('f','600',1,'/etc/passwd')]),
                encoded_records([('f','600',1,root+'../secret')]),
                encoded_records([('f','600',1,root+'config.toml')]*2),
                encoded_records([('f','999',1,root+'x')]),encoded_records([('f','600',1,root+str(i)) for i in range(101)]),
                encoded_records([('f','600',1,root+'x'*513)]),b'x'*65537):
        try:m['parse_project_tree'](bad)
        except RuntimeError:pass
        else:raise AssertionError('unsafe project tree metadata accepted')
    known={'path':'.temp/cli-latest','type':'f','mode':'644','length':0}
    unknown={'path':'private\n::error::sensitive','type':'f','mode':'600','length':2}
    assert m['redacted_project_entry'](known,detailed=False)=={'path':'.temp/cli-latest','type':'f'}
    redacted=m['redacted_project_entry'](unknown,detailed=True)
    assert 'path' not in redacted and redacted['path_sha256']==hashlib.sha256(unknown['path'].encode()).hexdigest()
    assert unknown['path'] not in json.dumps(redacted,ensure_ascii=True)
    buf=bytearray();m['append_bounded'](buf,b'x'*65536,65536)
    try:m['append_bounded'](buf,b'x',65536)
    except RuntimeError:pass
    else:raise AssertionError('stream cap exceeded without error')
    # Fake selector/Popen tests exercise streaming limits without starting a process.
    class FakePipe:
        def __init__(self,fd):self.fd=fd;self.closed=False
        def fileno(self):return self.fd
        def close(self):self.closed=True
    class FakeProcess:
        next_exit=0
        def __init__(self,argv,*args,**kwargs):
            assert argv[-10:-7]==['/usr/bin/find','-P','/tmp/codex-cli/supabase'] and '-xdev' in argv
            assert kwargs['env']=={'PATH':'/usr/bin:/bin','LANG':'C'}
            self.stdout=FakePipe(31);self.stderr=FakePipe(32);self.code=None;self.terminated=False
        def poll(self):return self.code
        def wait(self,timeout=None):
            if self.code is None:self.code=self.next_exit
            return self.code
        def terminate(self):self.terminated=True;self.code=-15
        def kill(self):self.terminated=True;self.code=-9
    class FakeSelector:
        def __init__(self):self.entries={}
        def register(self,pipe,event,data):self.entries[pipe.fd]=types.SimpleNamespace(fd=pipe.fd,fileobj=pipe,data=data)
        def get_map(self):return self.entries
        def select(self,timeout):return [(v,1) for v in list(self.entries.values())]
        def unregister(self,pipe):self.entries.pop(pipe.fd)
        def close(self):pass
    class StreamService:
        def __init__(self):self.docker=['/usr/bin/docker','--config','/tmp/fake','--host','unix:///var/run/docker.sock'];self.cid='a'*64;self.env={'PATH':'/usr/bin:/bin','LANG':'C'};self.inspected=False
        def inspect(self,**kwargs):self.inspected=True
    from unittest.mock import patch
    def run_stream(stdout_chunks,stderr_chunks):
        sequences={31:list(stdout_chunks)+[b''],32:list(stderr_chunks)+[b'']};created=[]
        def spawn(*args,**kwargs):
            process=FakeProcess(*args,**kwargs);created.append(process);return process
        def fake_read(fd,size):return sequences[fd].pop(0)
        service=StreamService()
        with patch.object(m['subprocess'],'Popen',spawn), patch.object(m['selectors'],'DefaultSelector',FakeSelector), patch.object(m['os'],'read',fake_read):
            try:return m['OwnedService'].bounded_tree_find(service),created[0],service
            except RuntimeError as exc:return exc,created[0],service
    stream,proc,svc=run_stream([b'abc'],[])
    assert stream==b'abc' and svc.inspected and proc.stdout.closed and proc.stderr.closed
    stream,proc,svc=run_stream([b'x'*4096]*17,[])
    assert isinstance(stream,RuntimeError) and proc.terminated and proc.stdout.closed
    stream,proc,svc=run_stream([], [b'x'*4096,b'y'])
    assert isinstance(stream,RuntimeError) and proc.terminated and proc.stderr.closed
    FakeProcess.next_exit=1
    stream,proc,svc=run_stream([], [b'private-daemon-detail'])
    FakeProcess.next_exit=0
    assert isinstance(stream,RuntimeError) and 'private-daemon-detail' not in str(stream) and 'stderr_sha256=' in str(stream)
    assert m['classify_failure'](RuntimeError('bounded synthetic metadata stream exceeded limit'))['categories']==['project_tree_limit']
    print('PASS: unknown-name redaction and mocked bounded streaming/overflow/daemon-error teardown')

    class TreeFake:
        def __init__(self,with_link=False):
            self.run_id='123-1';self.nonce='b'*32;self.with_link=with_link;self.hash_paths=[]
        def inspect(self,**kwargs):return {}
        def bounded_tree_find(self):
            items=good_records+([('l','777',5,root+'outside')] if self.with_link else [])
            return encoded_records(items)
        def exec(self,args,**kwargs):
            if args==['/usr/bin/id','-u']:return types.SimpleNamespace(stdout=b'999\n',returncode=0,stderr=b'')
            if args[0]=='/usr/bin/find':
                items=good_records+([('l','777',5,root+'outside')] if self.with_link else [])
                return types.SimpleNamespace(stdout=encoded_records(items),returncode=0,stderr=b'')
            if args[0]=='/usr/bin/stat':
                path=args[-1]
                if path in ('/tmp/codex-cli','/tmp/codex-cli/supabase'):
                    assert args[2]=='%f|%u'
                    return types.SimpleNamespace(stdout=b'41c0|999\n',returncode=0,stderr=b'')
                size={root+'config.toml':3,root+'migrations/20991231000000_synthetic_acl.sql':4}[path]
                return types.SimpleNamespace(stdout=f'regular file|999|600|{size}|1\n'.encode(),returncode=0,stderr=b'')
            if args[0]=='/usr/bin/sha256sum':
                self.hash_paths.append(args[-1]);return types.SimpleNamespace(stdout=(('1'*64)+'  '+args[-1]+'\n').encode(),returncode=0,stderr=b'')
            raise AssertionError('unexpected pure fake command: '+repr(args))
    import contextlib
    fake=TreeFake()
    with contextlib.redirect_stdout(io.StringIO()) as capture:
        items=m['OwnedService'].project_tree_evidence(fake,'after_version')
    assert len(items)==3 and fake.hash_paths==[] and all('sha256' not in e for e in items)
    linked=TreeFake(with_link=True)
    try:
        with contextlib.redirect_stdout(io.StringIO()):m['OwnedService'].project_tree_evidence(linked,'after_version')
    except RuntimeError:pass
    else:raise AssertionError('symlink entry accepted')
    assert linked.hash_paths==[]
    print('PASS: root-scoped tree metadata without file hashing or symlink traversal')
    class LoopbackFake:
        def __init__(self, fault=None):
            self.fault=fault; self.token='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; self.calls=[]; self.load=0
            self.run_id='synthetic-mock';self.nonce='synthetic-mock'
            self.log='synthetic server start\n';self.probe_count=0
        def logs(self):return self.log
        def psql(self, sql):
            self.calls.append(('psql',sql))
            if "current_setting('listen_addresses')" in sql:
                return '0.0.0.0|5432|/var/lib/postgresql/data/pg_hba.conf' if self.fault=='listener' else '127.0.0.1|5432|/var/lib/postgresql/data/pg_hba.conf'
            if 'pg_conf_load_time' in sql:
                self.load+=1; return str(self.load)
            if 'pg_reload_conf' in sql:return 't'
            if 'pg_hba_file_rules' in sql:return 'f' if self.fault=='rules' else 't'
            if 'pg_catalog.pg_database' in sql:return 'f' if self.fault=='missing_db' else 't'
            return '1'
        def exec(self, args, **kwargs):
            self.calls.append(('exec',args))
            if args[0]=='/usr/bin/id':out=b'999\n'
            elif args[0]=='/usr/bin/stat':out=b'a1ff|999|1\n' if self.fault=='hba_symlink' else b'8180|999|1\n'
            elif args[0]=='/bin/sh':
                assert kwargs['input']==b'local synthetic_execbatch postgres trust\nhost synthetic_execbatch postgres 127.0.0.1/32 scram-sha-256\n';out=b''
            else:
                assert args[0]=='/usr/bin/env' and args[2]=='PGSSLMODE=disable'
                assert args[args.index('-h')+1]=='127.0.0.1'
                database=args[args.index('-d')+1]
                if 'VERBOSITY=verbose' in args:
                    assert database in ('postgres','synthetic_execbatch')
                    if self.fault=='negative_success':return types.SimpleNamespace(stdout=b'1\n',stderr=b'',returncode=0)
                    if self.fault=='negative_wrong_error':return types.SimpleNamespace(stdout=b'',stderr=b'FATAL:  3D000: other\n',returncode=2)
                    if database=='synthetic_execbatch' and self.fault=='wrong_password_success':
                        return types.SimpleNamespace(stdout=b'1\n',stderr=b'',returncode=0)
                    if database=='synthetic_execbatch' and self.fault=='wrong_password_other':
                        return types.SimpleNamespace(stdout=b'',stderr=b'FATAL:  28000: other\n',returncode=2)
                    if database=='postgres':
                        assert args[1]=='PGPASSWORD='+m['FIXTURE_PASSWORD']
                        state='28000';message='no pg_hba.conf entry for host "127.0.0.1", user "postgres", database "postgres", no encryption'
                    else:
                        assert args[1]=='PGPASSWORD=synthetic-deliberately-wrong-only'
                        state='28P01';message='password authentication failed for user "postgres"'
                    pid='140' if database=='postgres' or self.fault=='duplicate_pid' else '141'
                    received_pid='142' if self.fault=='pid_mismatch' else pid
                    if self.fault=='log_rewind':self.log='rewound\n'
                    if self.fault!='missing_log':
                        host='127.0.0.2' if self.fault=='wrong_control_route' else '127.0.0.1'
                        self.log+='['+received_pid+'] LOG:  00000: connection received: host='+host+' port=48392\n'
                        self.log+='['+pid+'] FATAL:  '+('3D000' if self.fault=='server_wrong_state' else state)+':  '+message+'\n'
                    if self.fault=='unexpected_fatal':self.log+='[999] FATAL:  XX000: unexpected\n'
                    error=('FATAL:  '+message+'\n').encode()
                    return types.SimpleNamespace(stdout=b'',stderr=error,returncode=2)
                assert args[1]=='PGPASSWORD='+m['FIXTURE_PASSWORD']
                if self.fault=='late_fatal':self.log+='[999] FATAL:  XX000: unexpected\n'
                out=b'f\n' if self.fault=='probe' else b't\n'
            return types.SimpleNamespace(stdout=out,stderr=b'',returncode=0)
    m['OwnedService'].configure_synthetic_loopback(LoopbackFake())
    for fault in ('listener','hba_symlink','rules','missing_db','negative_success','negative_wrong_error',
                  'wrong_password_success','wrong_password_other','probe','pid_mismatch','missing_log',
                  'unexpected_fatal','server_wrong_state','log_rewind','late_fatal','duplicate_pid','wrong_control_route'):
        try:m['OwnedService'].configure_synthetic_loopback(LoopbackFake(fault))
        except RuntimeError:pass
        else:raise AssertionError('unsafe loopback fixture accepted: '+fault)
    print('PASS: mocked loopback listener, synthetic hba and guarded preflight refusals')

    class StageFake:
        def __init__(self):
            self.run_id='123-1';self.nonce='b'*32;self.find_count=0;self.calls=[];self.cli_binary_sha=None
            self.expected_migration_sha=None;self.expected_migration_length=None
            self.binary=b'fictional-binary';self.migration=b'fictional-sql';self.fault=None
            self.files={root+'config.toml':m['PROJECT_CONFIG'],
                        root+'migrations/20991231000000_synthetic_acl.sql':self.migration,
                        root+'.temp/cli-latest':b'', '/tmp/codex-cli/supabase-cli':self.binary}
        def inspect(self,**kwargs):return {}
        def psql(self,*args,**kwargs):return '1'
        def verify_cli_binary(self):return {}
        def project_tree_evidence(self,phase):return m['OwnedService'].project_tree_evidence(self,phase)
        def verify_project_tree(self,phase):return m['OwnedService'].verify_project_tree(self,phase)
        def bounded_tree_find(self):
            self.find_count+=1
            latest_kind = 'l' if self.fault=='symlink' else 'f'
            latest_mode = '600' if self.fault=='mode' else '644'
            latest_size = 1 if self.fault=='nonempty' else 0
            items=[('d','700',40,root+'migrations'),('f','600',len(self.files[root+'config.toml']),root+'config.toml'),
                   ('f','600',len(self.migration),root+'migrations/20991231000000_synthetic_acl.sql')]
            if self.find_count>1:items += [('d','755',40,root+'.temp'),(latest_kind,latest_mode,latest_size,root+'.temp/cli-latest')]
            if self.fault=='unknown':items.append(('f','600',1,root+'sensitive-unknown-name'))
            return encoded_records(items)
        def exec(self,args,**kwargs):
            self.calls.append(args)
            if args[0]=='/bin/sh':return types.SimpleNamespace(stdout=b'',stderr=b'',returncode=0)
            if args[0]=='/usr/bin/id':return types.SimpleNamespace(stdout=b'999\n',stderr=b'',returncode=0)
            if args[0]=='/usr/bin/stat':
                path=args[-1]
                if path in ('/tmp/codex-cli','/tmp/codex-cli/supabase'):
                    assert args[2]=='%f|%u';out='41c0|999\n'
                else:
                    info={root+'migrations':('directory','700','2',40),root+'.temp':('directory','755','2',40),
                          root+'config.toml':('regular file','600','1',len(self.files[root+'config.toml'])),
                          root+'migrations/20991231000000_synthetic_acl.sql':('regular file','600','1',len(self.migration)),
                          root+'.temp/cli-latest':('regular file','644','1',0)}
                    kind,mode,links,size=info[path]
                    if self.fault=='owner' and path.endswith('/cli-latest'):user='0'
                    else:user='999'
                    if self.fault=='hardlink' and path.endswith('/cli-latest'):links='2'
                    group='0' if self.fault=='group' and path.endswith('/cli-latest') else '999'
                    bits=(0o040000 if kind=='directory' else 0o100000) | int(mode,8)
                    if self.fault=='stat_type' and path.endswith('/cli-latest'):bits=0o120777
                    if self.fault=='special' and path.endswith('/cli-latest'):bits |= 0o4000
                    if self.fault=='stat_size' and path.endswith('/cli-latest'):size=1
                    # GNU stat %F calls an empty regular file 'regular empty file';
                    # the production path must use only %f, whose bits are size independent.
                    if args[2]=='%F|%u|%g|%a|%h|%s':
                        kind='regular empty file' if kind=='regular file' and size==0 else kind
                        out='|'.join((kind,user,group,mode,links,str(size)))+'\n'
                    else:
                        assert args[2]=='%f|%u|%g|%h|%s'
                        out='|'.join((format(bits,'x'),user,group,links,str(size)))+'\n'
                return types.SimpleNamespace(stdout=out.encode(),stderr=b'',returncode=0)
            if args[0]=='/usr/bin/sha256sum':
                path=args[-1];digest=hashlib.sha256(self.files[path]).hexdigest()
                return types.SimpleNamespace(stdout=(digest+'  '+path+'\n').encode(),stderr=b'',returncode=0)
            if args[0]=='/tmp/codex-cli/supabase-cli':
                if args==['/tmp/codex-cli/supabase-cli','--version']:
                    return types.SimpleNamespace(stdout=b'2.84.2\n',stderr=b'',returncode=0)
            if args[:5]==['/usr/bin/env','PGSSLMODE=disable','/tmp/codex-cli/supabase-cli','db','push']:
                return types.SimpleNamespace(stdout=b'synthetic push',stderr=b'',returncode=0)
            raise AssertionError('unexpected stage command '+repr(args))
    stage_fake=StageFake()
    with contextlib.redirect_stdout(io.StringIO()) as captured:
        m['OwnedService'].stage(stage_fake,stage_fake.binary,stage_fake.migration)
        m['OwnedService'].cli_push(stage_fake)
    # Reproduce GNU's empty-file wording, while proving the runner used numeric mode.
    project_stats=[args for args in stage_fake.calls if args[0]=='/usr/bin/stat']
    assert all('%F' not in args[2] for args in project_stats)
    empty_path=root+'.temp/cli-latest'
    textual=stage_fake.exec(['/usr/bin/stat','-c','%F|%u|%g|%a|%h|%s','--',empty_path]).stdout.decode()
    numeric=stage_fake.exec(['/usr/bin/stat','-c','%f|%u|%g|%h|%s','--',empty_path]).stdout.decode()
    assert textual.startswith('regular empty file|') and int(numeric.split('|')[0],16)==0o100644
    records=[json.loads(line.split(' ',1)[1]) for line in captured.getvalue().splitlines() if line.startswith('SYNTHETIC_EXECBATCH_PROJECT_TREE ')]
    assert [(r['phase'],r['status']) for r in records]==[('before_version','paths'),('before_version','metadata'),('after_version','paths'),('after_version','metadata'),('before_push','paths'),('before_push','metadata')]
    latest=next(e for e in records[-1]['entries'] if e.get('path')=='.temp/cli-latest')
    assert latest['type']=='f' and latest['mode']=='644' and latest['length']==0 and 'sha256' not in latest
    assert sum(args[:5]==['/usr/bin/env','PGSSLMODE=disable','/tmp/codex-cli/supabase-cli','db','push'] for args in stage_fake.calls)==1
    for fault in ('unknown','symlink','mode','nonempty','owner','group','hardlink','stat_type','special','stat_size'):
        bad=StageFake();bad.fault=fault
        try:
            with contextlib.redirect_stdout(io.StringIO()) as capture:
                m['OwnedService'].stage(bad,bad.binary,bad.migration)
        except RuntimeError:pass
        else:raise AssertionError('unsafe project tree accepted: '+fault)
        assert not any(args[:5]==['/usr/bin/env','PGSSLMODE=disable','/tmp/codex-cli/supabase-cli','db','push'] for args in bad.calls)
        assert 'sensitive-unknown-name' not in capture.getvalue()
        assert 'SYNTHETIC_EXECBATCH_PROJECT_MISMATCH ' in capture.getvalue()
        expected_reason={'unknown':'unexpected','symlink':'type','mode':'mode','nonempty':'size',
                         'owner':'owner','group':'group','hardlink':'link_count',
                         'stat_type':'type','special':'mode','stat_size':'size'}[fault]
        mismatch=[json.loads(line.split(' ',1)[1]) for line in capture.getvalue().splitlines()
                  if line.startswith('SYNTHETIC_EXECBATCH_PROJECT_MISMATCH ')]
        assert mismatch[-1]['reason']==expected_reason
        assert mismatch[-1]['path']==('<unknown>' if fault=='unknown' else '.temp/cli-latest')
    for fixed in (root+'config.toml',root+'migrations/20991231000000_synthetic_acl.sql'):
        bad=StageFake()
        with contextlib.redirect_stdout(io.StringIO()):m['OwnedService'].stage(bad,bad.binary,bad.migration)
        data=bad.files[fixed];bad.files[fixed]=bytes([data[0]^1])+data[1:]
        try:
            with contextlib.redirect_stdout(io.StringIO()):m['OwnedService'].cli_push(bad)
        except RuntimeError:pass
        else:raise AssertionError('changed fixed project file accepted')
        assert not any(args[:5]==['/usr/bin/env','PGSSLMODE=disable','/tmp/codex-cli/supabase-cli','db','push'] for args in bad.calls)
    print('PASS: exact observed five-entry tree, fixed hashes and fail-closed mutations before db push')


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
        def configure_synthetic_loopback(self):
            self.verified_negative_fatals=[{'pid':'120','sqlstate':'28000','fatal_line':'[120] FATAL:  28000: expected database refusal'},
                                           {'pid':'121','sqlstate':'28P01','fatal_line':'[121] FATAL:  28P01: expected password refusal'}]
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
            host = '[local]' if self.bad_route else '127.0.0.1 port=48392'
            failure = {'success':'', 'history_failure':'SYNTHETIC_HISTORY_FAILURE',
                       'candidate_failure':'inheritance or partition relationship requires separate review'}[self.outcome]
            error = '' if not failure else '[140] ERROR:  P0001: ' + failure + '\n'
            statement = '[140] STATEMENT:  INSERT INTO supabase_migrations.schema_migrations\n' if self.outcome == 'history_failure' else ''
            return ('\n'.join(e['fatal_line'] for e in self.verified_negative_fatals)+'\n'
                    '[140] LOG:  00000: connection received: host=' + host + '\n'
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
    else: raise AssertionError('non-loopback route accepted')
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
