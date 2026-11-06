"""REVIEW ONLY: phase3 synthetic table GRANT observation; not executable directly.

The fixed CLI candidate is observed before/after its REVOKE, never production.
A separately reviewed entry/workflow must pin sources, prior event run and FIFO.
"""
import contextlib
import hashlib
import importlib.util
import json
import re
import subprocess
import tempfile
import time
from pathlib import Path

HERE=Path(__file__).resolve().parent
EVENT_SHA='44b6f5d0e8fad7ce77e2fd1a7125ecb0fbd295bd3eb18c5080d3affd29380a10'
BODY_SHA='75191bde9ec18b47cdb9b1b8170245fd150ed653834de585e91b24f256781d4f'
GRANT_SQL='GRANT TRUNCATE ON TABLE public.asset_pref_mirror TO anon;'
GRANT_DONE='SYNTHETIC_TABLE_GRANT_DONE'
COMMIT_DONE='SYNTHETIC_TABLE_GRANT_COMMIT'
OUTPUT_LIMIT=65536
ERROR_CLASSES={
 'tuple concurrently updated':'tuple_concurrently_updated',
 'tuple concurrently deleted':'tuple_concurrently_deleted',
 'could not serialize access due to concurrent update':'serialization_concurrent_update',
 'could not serialize access due to concurrent delete':'serialization_concurrent_delete',
 'canceling statement due to statement timeout':'statement_timeout',
 'canceling statement due to lock timeout':'lock_timeout',
}


def load_fixed():
    path=HERE/'event_preflight.py'
    if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=EVENT_SHA:
        raise RuntimeError('fixed event preflight mismatch')
    spec=importlib.util.spec_from_file_location('fixed_event_preflight_grant',path)
    event=importlib.util.module_from_spec(spec);spec.loader.exec_module(event)
    phase2,base=event.load_fixed()
    return event,phase2,base


def grant_activity_sql(nonce):
    if not re.fullmatch(r'[0-9a-f]{32}',nonce):raise RuntimeError('invalid synthetic grant nonce')
    return ("SELECT coalesce(json_agg(json_build_object('pid',a.pid,'state',a.state,"
      "'wait_type',a.wait_event_type,'blockers',pg_catalog.pg_blocking_pids(a.pid),"
      "'local_socket',a.client_addr IS NULL,'target_oid','public.asset_pref_mirror'::regclass::oid::bigint,"
      "'done_query',pg_catalog.btrim(a.query) = $$SELECT '"+GRANT_DONE+"';$$,"
      "'grant_query',pg_catalog.btrim(a.query) = $$"+GRANT_SQL+"$$)), '[]') "
      "FROM pg_catalog.pg_stat_activity a WHERE a.application_name='codex_grant_"+nonce+"' "
      "AND a.datname='synthetic_execbatch' AND a.usename='postgres';")


def classify_activity(rows,expected_oid,other_pids):
    if not isinstance(rows,list) or len(rows)!=1 or not isinstance(rows[0],dict):
        raise RuntimeError('grant backend identity is not unique')
    x=rows[0];pid=x.get('pid');oid=x.get('target_oid');blockers=x.get('blockers')
    if (type(pid) is not int or pid<=0 or pid in other_pids or type(oid) is not int or oid!=expected_oid
        or not 1<=oid<=4294967295 or x.get('local_socket') is not True
        or not isinstance(blockers,list) or any(type(p) is not int or p<=0 for p in blockers)):
        raise RuntimeError('grant backend, target OID or blocker identity mismatch')
    if x.get('state')=='idle in transaction' and x.get('done_query') is True:
        return {'state':'statement_done','pid':pid,'blockers':blockers}
    if x.get('state')=='active' and x.get('wait_type')=='Lock':
        if x.get('grant_query') is not True:raise RuntimeError('unexpected grant-session lock wait')
        return {'state':'lock_wait','pid':pid,'blockers':blockers}
    return {'state':'pending','pid':pid,'blockers':blockers}


class GrantClient:
    def __init__(self,service,base):self.s=service;self.base=base;self.proc=None;self.files=[]

    def start(self):
        if self.proc is not None or not self.s.verified:raise RuntimeError('unverified or duplicate grant client')
        self.s.inspect(running=True)
        if not re.fullmatch(r'[0-9a-f]{32}',self.s.nonce) or not re.fullmatch(r'[0-9a-f-]{36}',self.s.token):
            raise RuntimeError('invalid synthetic grant identity')
        out=tempfile.TemporaryFile();err=tempfile.TemporaryFile();self.files.extend((out,err))
        argv=self.s.docker+['exec','-i','-u','postgres',self.s.cid,'/usr/bin/env','-i',
          'PATH=/usr/local/bin:/usr/bin:/bin','PGAPPNAME=codex_grant_'+self.s.nonce,
          '/usr/lib/postgresql/17/bin/psql','-X','-qAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose',
          '-h','/var/run/postgresql','-U','postgres','-d',self.base.DB]
        self.proc=subprocess.Popen(argv,env=self.s.env,stdin=subprocess.PIPE,stdout=out,stderr=err)
        sql=("SELECT 1/((current_database()='synthetic_execbatch' AND current_user='postgres' "
          "AND EXISTS(SELECT 1 FROM public.codex_execbatch_guard WHERE token='"+self.s.token+"'::uuid))::int);\n"
          "SELECT 'SYNTHETIC_B_READY:'||pg_catalog.pg_backend_pid()::text||':'||'public.asset_pref_mirror'::regclass::oid::bigint::text;\n"
          "SET statement_timeout='10s';\nSET log_statement='all';\nBEGIN;\n"+GRANT_SQL+"\nSELECT '"+GRANT_DONE+"';\n")
        self.proc.stdin.write(sql.encode());self.proc.stdin.flush()

    def bounded(self):
        for f in self.files:
            f.flush()
            if f.seek(0,2)>OUTPUT_LIMIT:raise RuntimeError('grant client output limit exceeded')

    def poll_until(self,deadline,expected_oid,other_pids):
        while time.monotonic()<deadline:
            self.bounded()
            if self.proc.poll() is not None:return {'state':'client_exited'}
            rows=json.loads(self.s.psql(grant_activity_sql(self.s.nonce)))
            if rows:
                x=classify_activity(rows,expected_oid,other_pids)
                if x['state']!='pending':return x
            time.sleep(0.1)
        return {'state':'deadline'}

    def commit(self):
        if self.proc is None or self.proc.poll() is not None:raise RuntimeError('grant client unavailable for commit')
        self.proc.stdin.write(("COMMIT;\nSELECT '"+COMMIT_DONE+"';\n\\q\n").encode());self.proc.stdin.close()

    def finish(self):
        self.proc.wait(timeout=15);self.bounded()
        out,err=self.files;out.seek(0);err.seek(0)
        return self.proc.returncode,out.read().decode('utf8',errors='replace'),err.read().decode('utf8',errors='replace')

    def close(self):
        failed=False
        if self.proc is not None:
            try:
                if self.proc.poll() is None:
                    self.proc.terminate()
                    try:self.proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:self.proc.kill();self.proc.wait(timeout=5)
            except BaseException:failed=True
        for f in self.files:
            try:f.close()
            except BaseException:failed=True
        if failed:raise RuntimeError('owned grant client cleanup failed')


def verify_b_success(pid,oid,out,err,logs,nonce):
    lines=out.splitlines()
    expected=['1','SYNTHETIC_B_READY:'+str(pid)+':'+str(oid),GRANT_DONE,COMMIT_DONE]
    prefix=r'\['+str(pid)+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?'
    auth=prefix+'connection authorized: user=postgres database=synthetic_execbatch application_name=codex_grant_'+nonce+r'(?:\s|$)'
    statement=prefix+r'statement:\s+'+re.escape(GRANT_SQL)
    commit=prefix+r'statement:\s+COMMIT;'
    if lines!=expected or err.strip() or not all(re.search(p,logs) for p in (auth,statement,commit)):
        raise RuntimeError('grant PID, SQL, explicit commit or client evidence mismatch')


def verify_b_auth(pid,logs,nonce):
    prefix=r'\['+str(pid)+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?'
    auth=prefix+'connection authorized: user=postgres database=synthetic_execbatch application_name=codex_grant_'+nonce+r'(?:\s|$)'
    if not re.search(auth,logs):raise RuntimeError('grant backend authentication not proven')
    return prefix


def verify_b_statement(pid,logs,nonce):
    prefix=verify_b_auth(pid,logs,nonce)
    statement=prefix+r'statement:\s+'+re.escape(GRANT_SQL)
    done=prefix+r'statement:\s+'+re.escape("SELECT '"+GRANT_DONE+"';")
    if not all(re.search(p,logs) for p in (statement,done)):
        raise RuntimeError('grant statement completion lacks same-PID evidence')


def classify_server_message(message):
    if not isinstance(message,str):raise RuntimeError('invalid server error message')
    raw=message.encode('utf8',errors='strict')
    if not raw or len(raw)>4096:raise RuntimeError('server error message absent or exceeds bound')
    return {'class':ERROR_CLASSES.get(message,'unknown'),'length':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}


def verify_b_error(code,out,err,logs,nonce,oid,other_pids):
    lines=out.splitlines()
    identity=re.fullmatch(r'SYNTHETIC_B_READY:([1-9][0-9]*):([1-9][0-9]*)',lines[1]) if len(lines)>=2 else None
    if code==0 or not lines or lines[0]!='1' or identity is None:
        raise RuntimeError('grant failure lacks guarded backend identity')
    pid=int(identity.group(1))
    if pid in other_pids or int(identity.group(2))!=oid:raise RuntimeError('grant failure identity mismatch')
    states=set(re.findall(r'\b([0-9A-Z]{5}):',err))
    auth=r'\['+str(pid)+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection authorized: user=postgres database=synthetic_execbatch application_name=codex_grant_'+nonce+r'(?:\s|$)'
    errors=[];lines=logs.splitlines()
    error_pattern=re.compile(r'\['+str(pid)+r'\] ERROR:\s+([0-9A-Z]{5}):\s*(.*?)\s*$')
    same_pid=re.compile(r'\['+str(pid)+r'\] ')
    detail=re.compile(r'\['+str(pid)+r'\] (?:DETAIL|HINT|CONTEXT|LOCATION):')
    statement=re.compile(r'\['+str(pid)+r'\] STATEMENT:\s+'+re.escape(GRANT_SQL)+r'(?:\s|$)')
    for i,line in enumerate(lines):
        match=error_pattern.search(line)
        if not match:continue
        for following in lines[i+1:i+9]:
            if statement.search(following):errors.append((match.group(1),match.group(2)));break
            if same_pid.search(following) and not detail.search(following):break
    if not re.search(auth,logs) or len(errors)!=1 or errors[0][0] not in states:
        raise RuntimeError('grant failure SQLSTATE, PID or message pairing unproven')
    state,message=errors[0]
    return {'pid':pid,'sqlstate':state,'message_diagnostic':classify_server_message(message)}


def verify_cli_auth(pid,logs):
    prefix=r'\['+str(pid)+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?'
    received=prefix+r'connection received: host=127\.0\.0\.1 port=[0-9]+(?:\s|$)'
    auth=prefix+r'connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli(?:\s|$)'
    if not re.search(received,logs) or not re.search(auth,logs):
        raise RuntimeError('CLI loopback authentication and waiting PID mismatch')


def catalog_snapshot(service):
    sql=("SET statement_timeout='3s'; SELECT jsonb_build_object('oid',c.oid::bigint,"
      "'anon',pg_catalog.has_table_privilege('anon',c.oid,'TRUNCATE'),"
      "'authenticated',pg_catalog.has_table_privilege('authenticated',c.oid,'TRUNCATE'),"
      "'service',pg_catalog.has_table_privilege('service_role',c.oid,'TRUNCATE')) "
      "FROM pg_catalog.pg_class c WHERE c.oid='public.asset_pref_mirror'::regclass;")
    data=json.loads(service.psql(sql))
    if (not isinstance(data,dict) or type(data.get('oid')) is not int or not 1<=data['oid']<=4294967295
        or any(type(data.get(k)) is not bool for k in ('anon','authenticated','service'))):
        raise RuntimeError('invalid synthetic catalog snapshot')
    return data


def run_case(service,event,phase2,base,stage):
    if stage not in ('before_revoke','after_revoke'):raise RuntimeError('invalid table grant stage')
    if type(service) is not base.OwnedService:raise RuntimeError('fixed owned service required')
    candidates=base.candidate_pair();body=candidates['locked_single_do']
    if hashlib.sha256(body).hexdigest()!=BODY_SHA:raise RuntimeError('candidate body mismatch')
    binary=base.safe_cli_binary()
    clients=phase2.OwnedClients(service,base);grant=GrantClient(service,base);original=None;result=None
    try:
        service.create();service.wait_final_postmaster();service.initialize();service.configure_synthetic_loopback()
        if stage=='before_revoke':
            service.psql('REVOKE TRUNCATE ON TABLE public.asset_pref_mirror FROM anon;')
        before=json.loads(service.psql(base.SNAPSHOT))
        if (before['anon'] is not (stage=='after_revoke') or before['authenticated'] is not True
            or before['service'] is not True):raise RuntimeError('grant fixture baseline mismatch')
        service.psql(event.gate_sql(service.token,phase2.KEY) if stage=='before_revoke' else phase2.add_barrier(base.HISTORY_GATE))
        service.stage(binary,body);coord=clients.start_coordinator();clients.start_cli()
        waiter=(event.wait_for_event(service,clients,phase2,coord) if stage=='before_revoke'
                else clients.wait_barrier(coord))
        if waiter is None:raise RuntimeError('required pre-revoke event was not observed')
        oid=waiter['target_oid'];cli_pid=waiter['pid']
        verify_cli_auth(cli_pid,service.logs())
        if stage=='before_revoke':event.prove_event_log(service.logs(),waiter)
        initial=catalog_snapshot(service)
        if initial['oid']!=oid:raise RuntimeError('catalog and held target OID mismatch')
        grant.start();first=grant.poll_until(time.monotonic()+3,oid,{coord,cli_pid})
        a_released=False;observed_wait=first['state']=='lock_wait'
        if observed_wait:
            verify_b_auth(first['pid'],service.logs(),service.nonce)
            print('SYNTHETIC_GRANT_LOCK_WAIT '+json.dumps({'stage':stage,'target_oid':oid,
              'cli_pid':cli_pid,'grant_pid':first['pid'],'blocker_pids':first['blockers']},sort_keys=True),flush=True)
        if first['state'] in ('lock_wait','deadline'):
            clients.release();a_released=True
            final=grant.poll_until(time.monotonic()+12,oid,{coord,cli_pid})
        else:final=first
        if final['state']=='statement_done':
            bpid=final['pid'];verify_b_statement(bpid,service.logs(),service.nonce)
            grant.commit();bcode,bout,berr=grant.finish()
            if bcode!=0:raise RuntimeError('grant explicit commit failed')
            verify_b_success(bpid,oid,bout,berr,service.logs(),service.nonce)
            b_result={'status':'committed','pid':bpid,'sqlstate':None}
        elif final['state']=='client_exited':
            bcode,bout,berr=grant.finish()
            b_result={'status':'sql_error',**verify_b_error(bcode,bout,berr,service.logs(),service.nonce,oid,{coord,cli_pid})}
        else:
            raise RuntimeError('grant completion deadline or state unresolved')
        committed_before_release=None
        if b_result['status']=='committed' and not a_released:
            committed_before_release=catalog_snapshot(service)
            if committed_before_release['oid']!=oid or committed_before_release['anon'] is not True:
                raise RuntimeError('target OID or committed grant effect not observed')
        if not a_released:clients.release()
        acode,aoutput=clients.finish_cli();logs=service.logs()
        if service.psql('SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE pid IN ('+str(cli_pid)+','+str(b_result['pid'])+');').strip()!='0':
            raise RuntimeError('CLI or grant backend remains')
        after=json.loads(service.psql(base.SNAPSHOT))
        history=json.loads(service.psql("SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,'statement_count',coalesce(array_length(statements,1),0)) ORDER BY version),'[]') FROM supabase_migrations.schema_migrations;"))
        if acode==0:
            if (len(history)!=1 or history[0].get('version')!=base.VERSION or history[0].get('name')!='synthetic_acl'
                or type(history[0].get('statement_count')) is not int or history[0]['statement_count']<=0
                or after['authenticated'] is not False):
                raise RuntimeError('CLI success history mismatch')
            a_result={'status':'committed','sqlstate':None}
        else:
            if history!=[] or after['authenticated'] is not True:raise RuntimeError('failed CLI left history or target change')
            states=set(re.findall(r'\b([0-9A-Z]{5})\b',aoutput))
            errors=set(re.findall(r'\['+str(cli_pid)+r'\] ERROR:\s+([0-9A-Z]{5}):',logs))
            common=states & errors
            if len(common)!=1:raise RuntimeError('CLI failure SQLSTATE or same PID unproven')
            a_result={'status':'sql_error','sqlstate':next(iter(common))}
        stable=('owner','rls','force','rows','policy','other_acl','other_effective','columns','memberships','role_attributes','hierarchy','service')
        if any(before[k]!=after[k] for k in stable):raise RuntimeError('unrelated synthetic state changed')
        final_catalog=catalog_snapshot(service)
        if (final_catalog['oid']!=oid or final_catalog['anon'] is not after['anon']
            or final_catalog['authenticated'] is not after['authenticated'] or final_catalog['service'] is not after['service']):
            raise RuntimeError('target OID or final catalog snapshot mismatch')
        summary=base.summarize_control_fatals(logs,service.verified_negative_fatals)
        if summary['verified_negative_control_fatals']!=2 or summary['unexpected_fatal_count']!=0:
            raise RuntimeError('unexpected FATAL or missing negative controls')
        result={'stage':stage,'target_oid':oid,'cli_pid':cli_pid,'coordinator_pid':coord,
          'grant_pid':b_result['pid'],'grant_first_observation':first['state'],'observed_lock_wait':observed_wait,
          'blocker_pids':first.get('blockers',[]),'grant':b_result,'cli':a_result,'history_count':len(history),
          'initial_anon_truncate':before['anon'],'after_barrier_anon_truncate':initial['anon'],
          'after_grant_commit_before_cli_release':committed_before_release,
          'final_anon_truncate':after['anon'],'final_catalog_anon_truncate':final_catalog['anon'],
          'grant_commit_before_cli_release':b_result['status']=='committed' and not a_released,
          'scope':'synthetic PG17 and fixed CLI; no membership, production or universal concurrency claim'}
    except BaseException as exc:
        original=exc
    finally:
        grant_failed=False;clients_failed=False;container_unconfirmed=False
        try:grant.close()
        except BaseException:grant_failed=True
        try:clients.close()
        except BaseException:clients_failed=True
        if service.cid is not None:
            try:
                capture=event.BoundedCapture()
                with contextlib.redirect_stdout(capture):service.stop_owned()
                evidence=event.validate_teardown(capture.getvalue(),service)
                evidence.update(grant_client_cleanup_confirmed=not grant_failed,cli_clients_cleanup_confirmed=not clients_failed)
                print('SYNTHETIC_GRANT_OWNED_TEARDOWN '+json.dumps(evidence,sort_keys=True),flush=True)
            except BaseException:container_unconfirmed=True
        else:container_unconfirmed=True
        if grant_failed or clients_failed or container_unconfirmed:
            raise event.PreflightCleanupError(original,grant_failed or clients_failed,container_unconfirmed) from None
    if original is not None:raise event.PreflightRunError(original) from None
    if result is None:raise RuntimeError('grant observation produced no result')
    result['cleanup_confirmed']=True
    return result


if __name__=='__main__':raise SystemExit('REVIEW ONLY: direct execution disabled')
