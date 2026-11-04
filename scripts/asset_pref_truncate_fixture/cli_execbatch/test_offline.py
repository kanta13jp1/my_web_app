"""Pure offline checks for the unexecuted diagnostic; never launches Docker."""
import ast
import copy
import io
import json
from pathlib import Path
import runpy
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
        '/tmp':'rw,nosuid,size=192m,mode=1777'}},
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