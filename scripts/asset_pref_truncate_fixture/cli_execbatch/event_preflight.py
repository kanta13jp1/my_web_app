"""REVIEW ONLY: synthetic event-trigger preflight; direct execution disabled.

Requires a separately reviewed workflow/entry with pinned PR, head and FIFO.
No role-membership or concurrent GRANT experiment is implemented here.
"""
import hashlib
import importlib.util
import contextlib
import io
import json
import re
import time
from pathlib import Path

HERE=Path(__file__).resolve().parent
PHASE2_SHA='4d0d8487057ef223c888f706c7b09fad1be623c54e989466c95ab6f016842346'
CANDIDATE_BODY_SHA='75191bde9ec18b47cdb9b1b8170245fd150ed653834de585e91b24f256781d4f'


class PreflightRunError(RuntimeError):
    def __init__(self, original):
        self.original_error_type=type(original).__name__
        self.cleanup_confirmed=True
        super().__init__('preflight failed; owned cleanup confirmed')


class PreflightCleanupError(RuntimeError):
    def __init__(self, original, client_failed, container_unconfirmed):
        self.original_error_type=type(original).__name__ if original is not None else None
        self.client_cleanup_failed=client_failed is True
        self.container_cleanup_unconfirmed=container_unconfirmed is True
        self.cleanup_confirmed=None
        super().__init__('preflight cleanup unconfirmed')


class BoundedCapture(io.StringIO):
    def write(self,text):
        if self.tell()+len(text)>8192:raise RuntimeError('teardown output exceeded bound')
        return super().write(text)


def validate_teardown(text,service):
    prefix='SYNTHETIC_EXECBATCH_TEARDOWN '
    lines=text.splitlines()
    if len(lines)!=1 or not lines[0].startswith(prefix):
        raise RuntimeError('owned teardown marker missing or ambiguous')
    data=json.loads(lines[0][len(prefix):])
    if (data.get('run_id')!=service.run_id or data.get('nonce')!=service.nonce
        or data.get('container_id')!=service.cid or data.get('stopped_removed') is not True
        or data.get('inspect_absent') is not True or data.get('ps_absent') is not True
        or data.get('holder_client_stopped') is not True
        or not re.fullmatch(r'[0-9]+-[0-9]+',str(data.get('run_id','')))
        or not re.fullmatch(r'[0-9a-f]{32}',str(data.get('nonce','')))
        or not re.fullmatch(r'[0-9a-f]{64}',str(data.get('container_id','')))):
        raise RuntimeError('owned teardown evidence mismatch')
    return {'run_id':data['run_id'],'nonce':data['nonce'],'container_id':data['container_id'],
      'stopped_removed':True,'inspect_absent':True,'ps_absent':True,'holder_client_stopped':True}


def load_fixed():
    path=HERE/'phase2.py'
    if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=PHASE2_SHA:
        raise RuntimeError('fixed phase2 mismatch')
    spec=importlib.util.spec_from_file_location('fixed_phase2_preflight',path)
    phase2=importlib.util.module_from_spec(spec);spec.loader.exec_module(phase2)
    return phase2,phase2.load_runner()


def gate_sql(token,key):
    if not re.fullmatch(r'[0-9a-f-]{36}',token) or type(key) is not int or key!=700000000017:
        raise RuntimeError('invalid synthetic gate inputs')
    return ("CREATE FUNCTION public.codex_revoke_event_gate() RETURNS event_trigger LANGUAGE plpgsql AS $$ "
      "DECLARE target oid; BEGIN "
      "IF pg_catalog.current_setting('application_name') <> 'codex_execbatch_cli' THEN RETURN; END IF; "
      "target := pg_catalog.to_regclass('public.asset_pref_mirror')::oid; "
      "IF TG_TAG <> 'REVOKE' OR current_database() <> 'synthetic_execbatch' OR current_user <> 'postgres' "
      "OR pg_catalog.current_setting('server_version_num')::integer/10000 <> 17 "
      "OR inet_client_addr() IS DISTINCT FROM '127.0.0.1'::inet "
      "OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet OR inet_server_port() IS DISTINCT FROM 5432 "
      "OR NOT EXISTS (SELECT 1 FROM public.codex_execbatch_guard WHERE token='"+token+"'::uuid) "
      "OR target IS NULL OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_locks l WHERE l.pid=pg_catalog.pg_backend_pid() "
      "AND l.locktype='relation' AND l.relation=target AND l.mode='AccessExclusiveLock' AND l.granted) "
      "THEN RAISE EXCEPTION 'SYNTHETIC_EVENT_GUARD_MISMATCH'; END IF; "
      "RAISE LOG 'SYNTHETIC_REVOKE_EVENT_START target_oid=%', target::bigint; "
      "PERFORM pg_catalog.pg_advisory_xact_lock("+str(key)+"); END $$; "
      "CREATE EVENT TRIGGER codex_revoke_event_gate ON ddl_command_start WHEN TAG IN ('REVOKE') "
      "EXECUTE FUNCTION public.codex_revoke_event_gate();")


def event_wait_sql(phase2):
    return ("SELECT coalesce(json_agg(json_build_object('pid',a.pid,'blocked_by',pg_catalog.pg_blocking_pids(a.pid),"
      "'loopback',a.client_addr='127.0.0.1'::inet,'state',a.state,'wait_type',a.wait_event_type,'wait',a.wait_event,"
      "'target_oid','public.asset_pref_mirror'::regclass::oid::bigint,"
      "'target_lock',EXISTS(SELECT 1 FROM pg_catalog.pg_locks t WHERE t.pid=a.pid AND t.locktype='relation' "
      "AND t.database=(SELECT oid FROM pg_catalog.pg_database WHERE datname=current_database()) "
      "AND t.relation='public.asset_pref_mirror'::regclass AND t.mode='AccessExclusiveLock' AND t.granted),"
      "'barrier_wait',EXISTS(SELECT 1 FROM pg_catalog.pg_locks w WHERE w.pid=a.pid AND w.locktype='advisory' "
      "AND w.database=(SELECT oid FROM pg_catalog.pg_database WHERE datname=current_database()) "
      "AND w.classid="+str(phase2.KEY_HIGH)+" AND w.objid="+str(phase2.KEY_LOW)+" AND w.objsubid=1 "
      "AND w.mode='ExclusiveLock' AND NOT w.granted))), '[]') FROM pg_catalog.pg_stat_activity a "
      "WHERE a.application_name='codex_execbatch_cli' AND a.datname='synthetic_execbatch' AND a.usename='postgres';")


def only_event_waiter(rows,coord):
    if not isinstance(rows,list) or len(rows)!=1 or not isinstance(rows[0],dict):
        raise RuntimeError('event waiter not unique')
    x=rows[0]
    if (type(x.get('pid')) is not int or x['pid']<=0 or x['pid']==coord or x.get('blocked_by')!=[coord]
        or x.get('loopback') is not True or x.get('state')!='active' or x.get('wait_type')!='Lock'
        or x.get('wait')!='advisory' or type(x.get('target_oid')) is not int
        or not 1<=x['target_oid']<=4294967295 or x.get('target_lock') is not True
        or x.get('barrier_wait') is not True):
        raise RuntimeError('event waiter identity, target or lock mismatch')
    return x


def prove_event_log(logs,row):
    pid=re.escape(str(row['pid']));oid=re.escape(str(row['target_oid']))
    required=(r'\['+pid+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection received: host=127\.0\.0\.1 port=[0-9]+(?:\s|$)',
      r'\['+pid+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli(?:\s|$)',
      r'\['+pid+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?SYNTHETIC_REVOKE_EVENT_START target_oid='+oid+r'(?:\s|$)')
    if not all(re.search(pattern,logs) for pattern in required):
        raise RuntimeError('event marker, route, PID or OID not proven')


def wait_for_event(service,clients,phase2,coord):
    process,out,err=clients.cli;deadline=time.monotonic()+30
    while time.monotonic()<deadline:
        clients.bounded((out,err))
        if process.poll() is not None:
            return None  # CLI ended without observing a held event barrier; inspect outcome separately.
        rows=json.loads(service.psql(event_wait_sql(phase2)))
        if rows and any(isinstance(x,dict) and x.get('barrier_wait') is True for x in rows):
            row=only_event_waiter(rows,coord)
            if phase2.only_coordinator(json.loads(service.psql(phase2.activity_sql('codex_coord_'+service.nonce))))!=coord:
                raise RuntimeError('coordinator identity changed')
            prove_event_log(service.logs(),row)
            return row
        time.sleep(0.1)
    raise RuntimeError('event preflight deadline exceeded')


def run_preflight(service,phase2,base):
    """Requires already-pinned source/host context; all execution is synthetic."""
    if type(service) is not base.OwnedService:
        raise RuntimeError('preflight requires the fixed owned service type')
    candidates=base.candidate_pair()
    body=candidates['locked_single_do']
    if hashlib.sha256(body).hexdigest()!=CANDIDATE_BODY_SHA:
        raise RuntimeError('STOP-stripped candidate body mismatch')
    binary=base.safe_cli_binary()  # official archive integrity and format validation
    clients=phase2.OwnedClients(service,base);original=None;result=None
    try:
        service.create();service.wait_final_postmaster();service.initialize();service.configure_synthetic_loopback()
        before=json.loads(service.psql(base.SNAPSHOT));service.psql(gate_sql(service.token,phase2.KEY))
        service.stage(binary,body)
        coord=clients.start_coordinator();clients.start_cli()
        waiter=wait_for_event(service,clients,phase2,coord)
        if waiter is not None: clients.release()
        code,output=clients.finish_cli()
        logs=service.logs()
        local_pids=set(re.findall(r'\[(\d+)\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection received: host=127\.0\.0\.1 port=[0-9]+(?:\s|$)',logs))
        cli_pids=set(re.findall(r'\[(\d+)\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?connection authorized: user=postgres database=synthetic_execbatch application_name=codex_execbatch_cli(?:\s|$)',logs))
        if not cli_pids or not cli_pids<=local_pids or (waiter is not None and str(waiter['pid']) not in cli_pids):
            raise RuntimeError('CLI loopback identity unproven')
        if service.psql('SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE pid IN ('+','.join(sorted(cli_pids))+');').strip()!='0':
            raise RuntimeError('CLI backend remains after preflight')
        if waiter is None:
            clients.release()
            if 'SYNTHETIC_REVOKE_EVENT_START' in logs:
                raise RuntimeError('event logged but no verified wait; outcome inconclusive')
        if code!=0:raise RuntimeError('CLI failed before conclusive event preflight')
        after=json.loads(service.psql(base.SNAPSHOT))
        history=json.loads(service.psql("SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,'statement_count',coalesce(array_length(statements,1),0)) ORDER BY version),'[]') FROM supabase_migrations.schema_migrations;"))
        if (len(history)!=1 or history[0].get('version')!=base.VERSION or history[0].get('name')!='synthetic_acl'
            or type(history[0].get('statement_count')) is not int or history[0]['statement_count']<=0
            or after['anon'] or after['authenticated'] or not after['service']):
            raise RuntimeError('event preflight migration/history controls failed')
        stable=('owner','rls','force','rows','policy','other_acl','other_effective','columns','memberships','role_attributes','hierarchy','service')
        if any(before[k]!=after[k] for k in stable):raise RuntimeError('event preflight unrelated state changed')
        fatal=base.summarize_control_fatals(logs,service.verified_negative_fatals)
        if fatal['verified_negative_control_fatals']!=2 or fatal['unexpected_fatal_count']!=0:
            raise RuntimeError('unexpected FATAL or negative-control evidence missing')
        result={'outcome':'fired' if waiter else 'not_observed','ready_for_competition':waiter is not None,
          'coordinator_pid':coord,'cli_pid':waiter['pid'] if waiter else None,
          'target_oid':waiter['target_oid'] if waiter else None,'history_count':len(history),
          'scope':'synthetic PG17/official CLI; event trigger observation only'}
    except BaseException as exc:
        original=exc
    finally:
        client_failed=False;container_unconfirmed=False
        try:clients.close()
        except BaseException:client_failed=True
        if service.cid is not None:
            try:
                capture=BoundedCapture()
                with contextlib.redirect_stdout(capture):service.stop_owned()
                evidence=validate_teardown(capture.getvalue(),service)
                evidence['client_cleanup_confirmed']=not client_failed
                print('SYNTHETIC_EVENT_OWNED_TEARDOWN '+json.dumps(evidence,sort_keys=True),flush=True)
            except BaseException:container_unconfirmed=True
        else:
            container_unconfirmed=True
        if client_failed or container_unconfirmed:
            raise PreflightCleanupError(original,client_failed,container_unconfirmed) from None
    if original is not None:raise PreflightRunError(original) from None
    if result is None:raise RuntimeError('preflight produced no result')
    result['cleanup_confirmed']=True
    return result


if __name__=='__main__':
    raise SystemExit('REVIEW ONLY: direct execution disabled')
