"""REVIEW ONLY. Isolated lock-through-history experiment; direct execution disabled.

No live DB, workflow, CI or GitHub write. `run_phase2` requires the exact owned,
network-none fixture of the pinned runner and a separately reviewed workflow.
The coordinator and CLI are locally owned docker clients, never arbitrary PIDs.
"""
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNNER_SHA = 'e6608a9faecfb84fa4ced6a8185a89a5f56bff024f6180f561cb288eef52691d'
KEY = 700000000017
KEY_HIGH, KEY_LOW = KEY >> 32, KEY & 0xffffffff
OUTPUT_LIMIT = 65536


def load_runner():
    path = HERE / 'runner.py'
    if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != RUNNER_SHA:
        raise RuntimeError('fixed phase1 runner mismatch')
    spec = importlib.util.spec_from_file_location('fixed_phase1_runner', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def add_barrier(gate):
    marker = " IF (SELECT mode FROM public.codex_execbatch_mode) = 'fail' THEN"
    if gate.count(marker) != 1:
        raise RuntimeError('history trigger template changed')
    start = gate.index('CREATE FUNCTION supabase_migrations.synthetic_history_gate()')
    end = gate.index('\nCREATE TRIGGER synthetic_history_gate', start)
    function = gate[start:end].replace('CREATE FUNCTION ', 'CREATE OR REPLACE FUNCTION ', 1)
    return function.replace(marker, ' PERFORM pg_catalog.pg_advisory_xact_lock(' + str(KEY) + ');\n' + marker, 1)


def activity_sql(app):
    if not re.fullmatch(r'codex_coord_[0-9a-f]{32}', app):
        raise RuntimeError('invalid coordinator name')
    return ("SELECT coalesce(json_agg(json_build_object('pid',a.pid,'granted',l.granted)), '[]') "
      "FROM pg_catalog.pg_stat_activity a JOIN pg_catalog.pg_locks l ON l.pid=a.pid "
      "WHERE a.application_name='"+app+"' AND a.datname='synthetic_execbatch' AND a.usename='postgres' "
      "AND l.locktype='advisory' AND l.database=(SELECT oid FROM pg_catalog.pg_database WHERE datname=current_database()) "
      "AND l.classid="+str(KEY_HIGH)+" AND l.objid="+str(KEY_LOW)+" AND l.objsubid=1 AND l.mode='ExclusiveLock';")


def waiting_sql():
    return ("SELECT coalesce(json_agg(json_build_object('pid',a.pid,'blocked_by',pg_catalog.pg_blocking_pids(a.pid),"
      "'query_insert',position('INSERT INTO supabase_migrations.schema_migrations' in a.query)>0,"
      "'loopback',a.client_addr='127.0.0.1'::inet,'state',a.state,'wait_type',a.wait_event_type,'wait',a.wait_event,"
      "'target_oid','public.asset_pref_mirror'::regclass::oid::bigint,"
      "'target_lock',EXISTS(SELECT 1 FROM pg_catalog.pg_locks t WHERE t.pid=a.pid AND t.locktype='relation' "
      "AND t.database=(SELECT oid FROM pg_catalog.pg_database WHERE datname=current_database()) "
      "AND t.relation='public.asset_pref_mirror'::regclass AND t.mode='AccessExclusiveLock' AND t.granted),"
      "'barrier_wait',EXISTS(SELECT 1 FROM pg_catalog.pg_locks w WHERE w.pid=a.pid AND w.locktype='advisory' "
      "AND w.database=(SELECT oid FROM pg_catalog.pg_database WHERE datname=current_database()) "
      "AND w.classid="+str(KEY_HIGH)+" AND w.objid="+str(KEY_LOW)+" AND w.objsubid=1 "
      "AND w.mode='ExclusiveLock' AND NOT w.granted))), '[]') FROM pg_catalog.pg_stat_activity a "
      "WHERE a.application_name='codex_execbatch_cli' AND a.datname='synthetic_execbatch' AND a.usename='postgres';")


def only_coordinator(rows):
    if (not isinstance(rows,list) or len(rows)!=1 or type(rows[0].get('pid')) is not int
        or rows[0]['pid']<=0 or rows[0].get('granted') is not True):
        raise RuntimeError('coordinator lock identity not unique')
    return rows[0]['pid']


def emit_wait_diagnostic(rows, coord, stage):
    """Emit only bounded synthetic IDs, booleans and counts; never raw fields."""
    if stage not in ('history_wait','before_probe','after_probe','history_timeout'):
        raise RuntimeError('invalid diagnostic stage')
    def safe_id(value, maximum=2147483647):
        return value if type(value) is int and 0 < value <= maximum else None
    safe_rows=[]
    if isinstance(rows,list):
        for row in rows[:4]:
            if not isinstance(row,dict):
                safe_rows.append({'row_is_object':False});continue
            blockers=row.get('blocked_by')
            oid=row.get('target_oid')
            oid_type=('null' if oid is None else 'integer' if type(oid) is int else
                      'string' if type(oid) is str else 'other')
            valid_blockers=isinstance(blockers,list) and all(safe_id(x) is not None for x in blockers)
            safe_rows.append({'row_is_object':True,'cli_pid':safe_id(row.get('pid')),
              'target_oid_type':oid_type,'target_oid_in_range':type(oid) is int and 1 <= oid <= 4294967295,
              'blockers_valid':valid_blockers,
              'blocker_count':len(blockers) if valid_blockers else None,
              'sole_blocker_is_coordinator':valid_blockers and blockers==[coord],
              'query_insert':row.get('query_insert') is True,'loopback':row.get('loopback') is True,
              'state_active':row.get('state')=='active','wait_type_lock':row.get('wait_type')=='Lock',
              'wait_advisory':row.get('wait')=='advisory','target_lock':row.get('target_lock') is True,
              'barrier_wait':row.get('barrier_wait') is True})
    evidence={'stage':stage,'coordinator_pid':safe_id(coord),
              'rows_are_list':isinstance(rows,list),'row_count':len(rows) if isinstance(rows,list) else None,
              'rows':safe_rows}
    print('SYNTHETIC_PHASE2_WAIT_DIAGNOSTIC '+json.dumps(evidence,sort_keys=True),flush=True)


def only_waiter(rows, coord, stage='history_wait'):
    if not isinstance(rows,list) or len(rows)!=1:
        emit_wait_diagnostic(rows,coord,stage)
        raise RuntimeError('CLI waiter is not unique')
    row=rows[0]
    if not isinstance(row,dict):
        emit_wait_diagnostic(rows,coord,stage)
        raise RuntimeError('CLI waiter is not an object')
    if (type(row.get('pid')) is not int or row['pid']<=0 or row['pid']==coord
        or row.get('blocked_by') != [coord] or row.get('query_insert') is not True
        or row.get('loopback') is not True or row.get('state') != 'active'
        or row.get('wait_type') != 'Lock' or row.get('wait') != 'advisory'
        or type(row.get('target_oid')) is not int or not 1 <= row['target_oid'] <= 4294967295
        or row.get('target_lock') is not True or row.get('barrier_wait') is not True):
        emit_wait_diagnostic(rows,coord,stage)
        raise RuntimeError('CLI backend, target lock or advisory wait mismatch')
    return row


class OwnedClients:
    def __init__(self, service, base):
        self.s=service; self.base=base; self.coord=None; self.cli=None
        self.files=[]

    def spawn(self, args, *, stdin):
        if not self.s.verified: raise RuntimeError('unverified service cannot start clients')
        self.s.inspect(running=True)
        out=tempfile.TemporaryFile(); err=tempfile.TemporaryFile(); self.files.extend((out,err))
        process=subprocess.Popen(args, env=self.s.env, stdin=stdin, stdout=out, stderr=err)
        return process,out,err

    def bounded(self, files):
        for f in files:
            f.flush()
            if f.seek(0,2)>OUTPUT_LIMIT: raise RuntimeError('synthetic client output limit exceeded')

    def start_coordinator(self):
        if self.coord is not None or not re.fullmatch(r'[0-9a-f]{32}',self.s.nonce):
            raise RuntimeError('invalid coordinator state')
        if not re.fullmatch(r'[0-9a-f-]{36}',self.s.token): raise RuntimeError('invalid fixture token')
        app='codex_coord_'+self.s.nonce
        argv=self.s.docker+['exec','-i','-u','postgres',self.s.cid,'/usr/bin/env','-i',
          'PATH=/usr/local/bin:/usr/bin:/bin','HOME=/tmp/codex-cli','PGAPPNAME='+app,
          '/usr/lib/postgresql/17/bin/psql','-X','-qAt','-v','ON_ERROR_STOP=1',
          '-h','/var/run/postgresql','-U','postgres','-d',self.base.DB]
        self.coord=self.spawn(argv,stdin=subprocess.PIPE)
        p,out,err=self.coord
        sql=("SELECT 1/((current_database()='synthetic_execbatch' AND current_user='postgres' "
          "AND EXISTS(SELECT 1 FROM public.codex_execbatch_guard WHERE token='"+self.s.token+"'::uuid))::int);\n"
          "SELECT 'LOCKED:'||pg_catalog.pg_advisory_lock("+str(KEY)+")::text;\n")
        p.stdin.write(sql.encode());p.stdin.flush()
        end=time.monotonic()+10
        while time.monotonic()<end:
            self.bounded((out,err))
            if p.poll() is not None: raise RuntimeError('coordinator exited before lock acquisition')
            rows=json.loads(self.s.psql(activity_sql(app)))
            if rows: return only_coordinator(rows)
            time.sleep(0.1)
        raise RuntimeError('coordinator acquisition deadline exceeded')

    def start_cli(self):
        if self.cli is not None or self.coord is None: raise RuntimeError('invalid asynchronous CLI state')
        self.s.psql('SELECT 1;');self.s.verify_cli_binary();self.s.verify_project_tree('before_push')
        argv=self.s.docker+['exec','-i','-u','postgres','--workdir','/tmp/codex-cli',self.s.cid,
          '/usr/bin/env','-i','PATH=/usr/local/bin:/usr/bin:/bin','HOME=/tmp/codex-cli','PGSSLMODE=disable',
          '/tmp/codex-cli/supabase-cli','db','push','--db-url',self.base.DB_URL,
          '--include-all','--yes','--workdir','/tmp/codex-cli']
        self.cli=self.spawn(argv,stdin=subprocess.DEVNULL)

    def wait_barrier(self, coord):
        p,out,err=self.cli;end=time.monotonic()+30;rows=[]
        while time.monotonic()<end:
            self.bounded((out,err))
            if p.poll() is not None: raise RuntimeError('CLI exited before history barrier')
            rows=json.loads(self.s.psql(waiting_sql()))
            if rows and rows[0].get('barrier_wait'):
                row=only_waiter(rows,coord)
                if only_coordinator(json.loads(self.s.psql(activity_sql('codex_coord_'+self.s.nonce)))) != coord:
                    raise RuntimeError('coordinator identity changed')
                return row
            time.sleep(0.1)
        emit_wait_diagnostic(rows,coord,'history_timeout')
        raise RuntimeError('history barrier deadline exceeded')

    def release(self):
        p,out,err=self.coord
        if p.poll() is not None: raise RuntimeError('coordinator exited before explicit release')
        p.stdin.write(("SELECT CASE WHEN pg_catalog.pg_advisory_unlock("+str(KEY)+") THEN 'UNLOCKED' ELSE 'FAILED' END;\n\\q\n").encode())
        p.stdin.close();p.wait(timeout=10);self.bounded((out,err))
        out.seek(0); lines=out.read().decode('utf8').splitlines()
        if p.returncode != 0 or lines != ['1','LOCKED:','UNLOCKED']:
            raise RuntimeError('coordinator unlock not confirmed')

    def finish_cli(self):
        p,out,err=self.cli;p.wait(timeout=60);self.bounded((out,err))
        out.seek(0);err.seek(0)
        return p.returncode, out.read().decode('utf8',errors='replace') + err.read().decode('utf8',errors='replace')

    def close(self):
        errors=[]
        for item in (self.cli,self.coord):
            if item is None: continue
            p=item[0]
            try:
                if p.poll() is None:
                    p.terminate()
                    try: p.wait(timeout=5)
                    except subprocess.TimeoutExpired: p.kill();p.wait(timeout=5)
            except Exception as exc: errors.append(type(exc).__name__)
        for f in self.files:
            try:f.close()
            except Exception as exc:errors.append(type(exc).__name__)
        if errors: raise RuntimeError('owned client cleanup failed: '+','.join(errors))


def conflict_probe(service, base, waiter, coord):
    """Only a new fixed socket backend may attempt ACCESS SHARE NOWAIT."""
    app='codex_probe_'+service.nonce
    if not re.fullmatch(r'codex_probe_[0-9a-f]{32}',app): raise RuntimeError('invalid probe identity')
    before=service.logs()
    sql=("SELECT 1/((current_database()='synthetic_execbatch' AND current_user='postgres' AND EXISTS "
      "(SELECT 1 FROM public.codex_execbatch_guard WHERE token='"+service.token+"'::uuid))::int);\n"
      "SELECT pg_catalog.pg_backend_pid()::text || '|' || 'public.asset_pref_mirror'::regclass::oid::text;\nBEGIN;\n"
      "LOCK TABLE ONLY public.asset_pref_mirror IN ACCESS SHARE MODE NOWAIT;\n")
    args=['PGAPPNAME='+app,'/usr/lib/postgresql/17/bin/psql','-X','-qAt',
      '-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-h','/var/run/postgresql',
      '-U','postgres','-d',base.DB]
    result=service.exec(args,input=sql.encode(),timeout=10,check=False)
    output=result.stdout.decode('utf8',errors='replace').splitlines()
    error=result.stderr.decode('utf8',errors='replace')
    marker='could not obtain lock on relation "public.asset_pref_mirror"'
    identity=re.fullmatch(r'([1-9][0-9]*)\|([1-9][0-9]*)',output[1]) if len(output)==2 else None
    if (result.returncode==0 or len(output)!=2 or output[0]!='1' or identity is None
        or int(identity.group(1)) in (coord,waiter['pid']) or int(identity.group(2))!=waiter['target_oid']
        or '55P03' not in error or marker not in error):
        raise RuntimeError('distinct conflict probe did not fail with expected 55P03')
    after=service.logs()
    if not after.startswith(before): raise RuntimeError('cannot isolate probe server log delta')
    delta=after[len(before):];pid=re.escape(identity.group(1))
    auth=r'\['+pid+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection authorized: user=postgres database=synthetic_execbatch application_name='+re.escape(app)+r'(?:\s|$)'
    failure=r'\['+pid+r'\] ERROR:\s+55P03:\s+'+re.escape(marker)
    if not re.search(auth,delta) or not re.search(failure,delta):
        raise RuntimeError('probe PID authorization and 55P03 server evidence mismatch')
    return int(identity.group(1))


def run_case(service, base, binary, migration, outcome):
    if outcome not in ('success','history_failure'): raise RuntimeError('unapproved phase2 case')
    clients=OwnedClients(service,base)
    original=None
    try:
        service.create();service.wait_final_postmaster();service.initialize();service.configure_synthetic_loopback()
        service.psql(add_barrier(base.HISTORY_GATE))
        if outcome=='history_failure':service.psql(base.HISTORY_FAILURE)
        before=json.loads(service.psql(base.SNAPSHOT));service.stage(binary,migration)
        coordinator=clients.start_coordinator();clients.start_cli()
        waiter=clients.wait_barrier(coordinator)
        server=service.logs()
        auth=r'\['+str(waiter['pid'])+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli(?:\s|$)'
        received=r'\['+str(waiter['pid'])+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection received: host=127\.0\.0\.1 port=[0-9]+(?:\s|$)'
        if not re.search(auth,server) or not re.search(received,server):
            raise RuntimeError('waiting PID is not the authenticated loopback CLI backend')
        probe_pid=conflict_probe(service,base,waiter,coordinator)
        after_probe=only_waiter(json.loads(service.psql(waiting_sql())),coordinator,'after_probe')
        if after_probe != waiter:
            emit_wait_diagnostic([waiter],coordinator,'before_probe')
            emit_wait_diagnostic([after_probe],coordinator,'after_probe')
            raise RuntimeError('barrier state changed during probe')
        clients.release();code,output=clients.finish_cli()
        if service.psql("SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE pid="+str(waiter['pid'])+";").strip() != '0':
            raise RuntimeError('CLI backend remains after exit')
        after=json.loads(service.psql(base.SNAPSHOT))
        history=json.loads(service.psql("SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,'statement_count',coalesce(array_length(statements,1),0)) ORDER BY version),'[]') FROM supabase_migrations.schema_migrations;"))
        if outcome=='success':
            if (code!=0 or len(history)!=1 or history[0].get('version')!=base.VERSION
                or history[0].get('name')!='synthetic_acl' or type(history[0].get('statement_count')) is not int
                or history[0]['statement_count']<=0 or after['anon'] or after['authenticated'] or not after['service']):
                raise RuntimeError('phase2 success or history verification failed')
            stable=('owner','rls','force','rows','policy','other_acl','other_effective','columns','memberships','role_attributes','hierarchy','service')
            if any(before[k]!=after[k] for k in stable): raise RuntimeError('unrelated table state changed')
        else:
            logs=service.logs()
            error=r'\['+str(waiter['pid'])+r'\] ERROR:\s+P0001:\s+SYNTHETIC_HISTORY_FAILURE'
            statement=r'\['+str(waiter['pid'])+r'\] STATEMENT:\s+INSERT INTO supabase_migrations\.schema_migrations'
            if (code==0 or history!=[] or before!=after or 'P0001' not in output
                or 'SYNTHETIC_HISTORY_FAILURE' not in output or not re.search(error,logs) or not re.search(statement,logs)):
                raise RuntimeError('phase2 rollback or same-PID history failure unproven')
        reacquired=service.psql("BEGIN; LOCK TABLE ONLY public.asset_pref_mirror IN ACCESS SHARE MODE NOWAIT; SELECT 'REACQUIRED'; ROLLBACK;")
        if reacquired.strip()!='REACQUIRED':raise RuntimeError('post-CLI table lock release unconfirmed')
        summary=base.summarize_control_fatals(service.logs(),service.verified_negative_fatals)
        if summary['verified_negative_control_fatals']!=2 or summary['unexpected_fatal_count']!=0:
            raise RuntimeError('unexpected FATAL or missing negative-control evidence')
        return {'outcome':outcome,'coordinator_pid':coordinator,'cli_pid':waiter['pid'],'target_oid':waiter['target_oid'],
          'probe_pid':probe_pid,'barrier_blocked':True,'target_access_exclusive_granted':True,
          'probe_55p03':True,'cli_exit':code,'history_count':len(history),'post_exit_lock_reacquired':True,
          'scope':'synthetic PG17 and pinned CLI; does not prove concurrent GRANT, membership, real DB or all commit moments'}
    except BaseException as exc:
        original=exc
        raise
    finally:
        failures=[]
        try:clients.close()
        except Exception as exc:failures.append('owned clients: '+type(exc).__name__)
        if service.cid is not None:
            try:service.stop_owned()
            except Exception as exc:failures.append('owned container: '+type(exc).__name__)
        if failures:
            raise RuntimeError('phase2 cleanup unconfirmed: '+', '.join(failures)+
                ('; original failure: '+type(original).__name__ if original else '')) from original


if __name__ == '__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')
