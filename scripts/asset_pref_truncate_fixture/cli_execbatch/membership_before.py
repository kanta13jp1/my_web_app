"""REVIEW ONLY: synthetic membership GRANT before candidate REVOKE.

No direct execution. A future reviewed entry must fix PR/head, sources, FIFO,
prior runs and one owned network-none synthetic cluster per case.
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
TABLE_SHA='d94a40d01de858131cca42f17119bcf3c36a6b3ccf4811cc495aa750080922a6'
BODY_SHA='75191bde9ec18b47cdb9b1b8170245fd150ed653834de585e91b24f256781d4f'
ROLE='synthetic_acl_parent'
GRANT_SQL='GRANT synthetic_acl_parent TO anon WITH INHERIT TRUE, SET FALSE, ADMIN FALSE;'
DONE='SYNTHETIC_MEMBERSHIP_DONE'
COMMITTED='SYNTHETIC_MEMBERSHIP_COMMIT'


def load_fixed():
    path=HERE/'table_grant.py'
    if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()!=TABLE_SHA:
        raise RuntimeError('fixed table-grant support mismatch')
    spec=importlib.util.spec_from_file_location('fixed_table_support_membership',path)
    table=importlib.util.module_from_spec(spec);spec.loader.exec_module(table)
    event,phase2,base=table.load_fixed()
    return table,event,phase2,base


def snapshot_sql():
    return ("SET statement_timeout='3s'; SELECT jsonb_build_object("
      "'target_oid','public.asset_pref_mirror'::regclass::oid::bigint,"
      "'parent_oid','synthetic_acl_parent'::regrole::oid::bigint,'anon_oid','anon'::regrole::oid::bigint,"
      "'parent_truncate',pg_catalog.has_table_privilege('synthetic_acl_parent','public.asset_pref_mirror','TRUNCATE'),"
      "'parent_other',EXISTS(SELECT 1 FROM (VALUES ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('REFERENCES'),('TRIGGER'),('MAINTAIN')) p(name) "
      "WHERE pg_catalog.has_table_privilege('synthetic_acl_parent','public.asset_pref_mirror',p.name)),"
      "'anon_truncate',pg_catalog.has_table_privilege('anon','public.asset_pref_mirror','TRUNCATE'),"
      "'authenticated_truncate',pg_catalog.has_table_privilege('authenticated','public.asset_pref_mirror','TRUNCATE'),"
      "'member',pg_catalog.pg_has_role('anon','synthetic_acl_parent','MEMBER'),"
      "'usage',pg_catalog.pg_has_role('anon','synthetic_acl_parent','USAGE'),"
      "'set',pg_catalog.pg_has_role('anon','synthetic_acl_parent','SET'),"
      "'direct_anon',EXISTS(SELECT 1 FROM pg_catalog.pg_class c CROSS JOIN LATERAL "
      "pg_catalog.aclexplode(coalesce(c.relacl,pg_catalog.acldefault('r',c.relowner))) x "
      "WHERE c.oid='public.asset_pref_mirror'::regclass AND x.grantee='anon'::regrole::oid AND x.privilege_type='TRUNCATE'),"
      "'direct_authenticated',EXISTS(SELECT 1 FROM pg_catalog.pg_class c CROSS JOIN LATERAL "
      "pg_catalog.aclexplode(coalesce(c.relacl,pg_catalog.acldefault('r',c.relowner))) x "
      "WHERE c.oid='public.asset_pref_mirror'::regclass AND x.grantee='authenticated'::regrole::oid AND x.privilege_type='TRUNCATE'),"
      "'membership',coalesce((SELECT jsonb_agg(jsonb_build_array(m.roleid::bigint,m.member::bigint,m.grantor::bigint,"
      "m.admin_option,m.inherit_option,m.set_option) ORDER BY m.roleid,m.member,m.grantor) FROM pg_catalog.pg_auth_members m "
      "WHERE m.roleid='synthetic_acl_parent'::regrole AND m.member='anon'::regrole),'[]'::jsonb),"
      "'other_memberships',coalesce((SELECT jsonb_agg(jsonb_build_array(m.roleid::bigint,m.member::bigint,m.grantor::bigint,"
      "m.admin_option,m.inherit_option,m.set_option) ORDER BY m.roleid,m.member,m.grantor) FROM pg_catalog.pg_auth_members m "
      "WHERE NOT (m.roleid='synthetic_acl_parent'::regrole AND m.member='anon'::regrole)),'[]'::jsonb),"
      "'role_attributes',coalesce((SELECT jsonb_agg(jsonb_build_array(r.oid::bigint,r.rolname,r.rolsuper,r.rolinherit,"
      "r.rolbypassrls,r.rolcanlogin,r.rolcreaterole,r.rolcreatedb,r.rolreplication) ORDER BY r.oid) "
      "FROM pg_catalog.pg_roles r WHERE r.rolname IN ('postgres','anon','authenticated','service_role','synthetic_acl_parent')),'[]'::jsonb));")


def membership_snapshot(service):
    value=json.loads(service.psql(snapshot_sql()))
    if not isinstance(value,dict):raise RuntimeError('invalid synthetic membership snapshot')
    for key in ('target_oid','parent_oid','anon_oid'):
        if type(value.get(key)) is not int or not 1<=value[key]<=4294967295:
            raise RuntimeError('invalid synthetic membership OID')
    for key in ('parent_truncate','parent_other','anon_truncate','authenticated_truncate','member','usage','set','direct_anon','direct_authenticated'):
        if type(value.get(key)) is not bool:raise RuntimeError('invalid synthetic privilege boolean')
    for key in ('membership','other_memberships','role_attributes'):
        if not isinstance(value.get(key),list):raise RuntimeError('invalid synthetic role catalog array')
    return value


def activity_sql(nonce):
    if not re.fullmatch(r'[0-9a-f]{32}',nonce):raise RuntimeError('invalid synthetic membership nonce')
    return ("SELECT coalesce(json_agg(json_build_object('pid',a.pid,'state',a.state,'wait_type',a.wait_event_type,"
      "'blockers',pg_catalog.pg_blocking_pids(a.pid),'local_socket',a.client_addr IS NULL,"
      "'target_oid','public.asset_pref_mirror'::regclass::oid::bigint,'parent_oid','synthetic_acl_parent'::regrole::oid::bigint,"
      "'done_query',pg_catalog.btrim(a.query)=$$SELECT '"+DONE+"';$$,"
      "'grant_query',pg_catalog.btrim(a.query)=$$"+GRANT_SQL+"$$)), '[]') FROM pg_catalog.pg_stat_activity a "
      "WHERE a.application_name='codex_member_"+nonce+"' AND a.datname='synthetic_execbatch' AND a.usename='postgres';")


def classify_activity(rows,target_oid,parent_oid,other_pids):
    if not isinstance(rows,list) or len(rows)!=1 or not isinstance(rows[0],dict):
        raise RuntimeError('membership backend not unique')
    x=rows[0];pid=x.get('pid');blockers=x.get('blockers')
    if (type(pid) is not int or pid<=0 or pid in other_pids or type(x.get('target_oid')) is not int
        or x['target_oid']!=target_oid or type(x.get('parent_oid')) is not int or x['parent_oid']!=parent_oid
        or x.get('local_socket') is not True or not isinstance(blockers,list)
        or any(type(v) is not int or v<=0 for v in blockers)):
        raise RuntimeError('membership PID, role, target or blocker mismatch')
    if x.get('state')=='idle in transaction' and x.get('done_query') is True:
        return {'state':'statement_done','pid':pid,'blockers':blockers}
    if x.get('state')=='active' and x.get('wait_type')=='Lock':
        if x.get('grant_query') is not True:raise RuntimeError('unexpected membership session lock wait')
        return {'state':'lock_wait','pid':pid,'blockers':blockers}
    return {'state':'pending','pid':pid,'blockers':blockers}


class MemberClient:
    def __init__(self,service,base):self.s=service;self.base=base;self.proc=None;self.files=[]
    def start(self):
        if self.proc is not None or not self.s.verified:raise RuntimeError('unverified membership client')
        self.s.inspect(running=True)
        if not re.fullmatch(r'[0-9a-f]{32}',self.s.nonce) or not re.fullmatch(r'[0-9a-f-]{36}',self.s.token):
            raise RuntimeError('invalid synthetic membership identity')
        out=tempfile.TemporaryFile();err=tempfile.TemporaryFile();self.files.extend((out,err))
        argv=self.s.docker+['exec','-i','-u','postgres',self.s.cid,'/usr/bin/env','-i',
          'PATH=/usr/local/bin:/usr/bin:/bin','PGAPPNAME=codex_member_'+self.s.nonce,
          '/usr/lib/postgresql/17/bin/psql','-X','-qAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose',
          '-h','/var/run/postgresql','-U','postgres','-d',self.base.DB]
        self.proc=subprocess.Popen(argv,env=self.s.env,stdin=subprocess.PIPE,stdout=out,stderr=err)
        sql=("SELECT 1/((current_database()='synthetic_execbatch' AND current_user='postgres' "
          "AND EXISTS(SELECT 1 FROM public.codex_execbatch_guard WHERE token='"+self.s.token+"'::uuid))::int);\n"
          "SELECT 'SYNTHETIC_MEMBER_READY:'||pg_catalog.pg_backend_pid()::text||':'||'public.asset_pref_mirror'::regclass::oid::bigint::text||':'||'synthetic_acl_parent'::regrole::oid::bigint::text;\n"
          "SET statement_timeout='10s';\nSET log_statement='all';\nBEGIN;\n"+GRANT_SQL+"\nSELECT '"+DONE+"';\n")
        self.proc.stdin.write(sql.encode());self.proc.stdin.flush()
    def bounded(self):
        for f in self.files:
            f.flush()
            if f.seek(0,2)>65536:raise RuntimeError('membership client output limit exceeded')
    def poll_until(self,deadline,target_oid,parent_oid,other_pids):
        while time.monotonic()<deadline:
            self.bounded()
            if self.proc.poll() is not None:return {'state':'client_exited'}
            rows=json.loads(self.s.psql(activity_sql(self.s.nonce)))
            if rows:
                x=classify_activity(rows,target_oid,parent_oid,other_pids)
                if x['state']!='pending':return x
            time.sleep(0.1)
        return {'state':'deadline'}
    def commit(self):
        if self.proc is None or self.proc.poll() is not None:raise RuntimeError('membership client unavailable for commit')
        self.proc.stdin.write(("COMMIT;\nSELECT '"+COMMITTED+"';\n\\q\n").encode());self.proc.stdin.close()
    def finish(self):
        self.proc.wait(timeout=15);self.bounded();out,err=self.files;out.seek(0);err.seek(0)
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
        if failed:raise RuntimeError('owned membership client cleanup failed')


def verify_auth(pid,logs,nonce):
    prefix=r'\['+str(pid)+r'\] LOG:\s+(?:[0-9A-Z]{5}:\s+)?'
    auth=prefix+'connection authorized: user=postgres database=synthetic_execbatch application_name=codex_member_'+nonce+r'(?:\s|$)'
    if not re.search(auth,logs):raise RuntimeError('membership backend authentication not proven')
    return prefix


def verify_success(pid,target_oid,parent_oid,out,err,logs,nonce):
    expected=['1','SYNTHETIC_MEMBER_READY:'+str(pid)+':'+str(target_oid)+':'+str(parent_oid),DONE,COMMITTED]
    prefix=verify_auth(pid,logs,nonce)
    statements=(GRANT_SQL,"SELECT '"+DONE+"';",'COMMIT;')
    if out.splitlines()!=expected or err.strip() or not all(re.search(prefix+r'statement:\s+'+re.escape(x),logs) for x in statements):
        raise RuntimeError('membership statement, role, PID or commit unproven')


def verify_statement(pid,logs,nonce):
    prefix=verify_auth(pid,logs,nonce)
    if not all(re.search(prefix+r'statement:\s+'+re.escape(s),logs) for s in (GRANT_SQL,"SELECT '"+DONE+"';")):
        raise RuntimeError('membership statement completion lacks same-PID evidence')


def verify_error(table,code,out,err,logs,nonce,target_oid,parent_oid,other_pids):
    lines=out.splitlines()
    match=re.fullmatch(r'SYNTHETIC_MEMBER_READY:([1-9][0-9]*):([1-9][0-9]*):([1-9][0-9]*)',lines[1]) if len(lines)>=2 else None
    if code==0 or not lines or lines[0]!='1' or match is None:raise RuntimeError('membership failure identity absent')
    pid,target,role=map(int,match.groups())
    if pid in other_pids or target!=target_oid or role!=parent_oid:raise RuntimeError('membership failure OID/PID mismatch')
    verify_auth(pid,logs,nonce)
    states=set(re.findall(r'\b([0-9A-Z]{5}):',err));found=[];server=logs.splitlines()
    pattern=re.compile(r'\['+str(pid)+r'\] ERROR:\s+([0-9A-Z]{5}):\s*(.*?)\s*$')
    same=re.compile(r'\['+str(pid)+r'\] ')
    detail=re.compile(r'\['+str(pid)+r'\] (?:DETAIL|HINT|CONTEXT|LOCATION):')
    statement=re.compile(r'\['+str(pid)+r'\] STATEMENT:\s+'+re.escape(GRANT_SQL)+r'(?:\s|$)')
    for i,line in enumerate(server):
        item=pattern.search(line)
        if not item:continue
        for following in server[i+1:i+9]:
            if statement.search(following):found.append((item.group(1),item.group(2)));break
            if same.search(following) and not detail.search(following):break
    if len(found)!=1 or found[0][0] not in states:raise RuntimeError('membership error statement or SQLSTATE unproven')
    state,message=found[0]
    return {'pid':pid,'sqlstate':state,'message_diagnostic':table.classify_server_message(message)}


# Exact candidate messages only; unknown messages remain hidden in this synthetic fixture.
CANDIDATE_ERROR_CLASSES={
 'read committed transaction isolation required':'isolation_required',
 'target table missing':'target_missing',
 'ordinary target table required':'ordinary_table_required',
 'target identity changed before lock':'identity_changed',
 'inheritance or partition relationship requires separate review':'inheritance_or_partition',
 'unexpected owner':'unexpected_owner',
 'incomplete privilege baseline':'incomplete_privilege_baseline',
 'incomplete service privilege baseline':'incomplete_service_baseline',
 'remaining effective truncate privilege':'remaining_effective_truncate',
 'truncate privilege reachable through role membership':'membership_reachable',
 'unrelated table privilege changed':'unrelated_privilege_changed',
 'incomplete privilege comparison':'incomplete_comparison',
 'service role changed':'service_role_changed',
}

def verify_cli_candidate_error(pid,output,logs,candidate):
    if type(pid) is not int or pid<=0 or not isinstance(candidate,bytes) or hashlib.sha256(candidate).hexdigest()!=BODY_SHA:
        raise RuntimeError('candidate or CLI PID invalid')
    # The sole SHA-pinned synthetic DO block has exactly one terminal delimiter.
    # CLI v2.84.2 SplitAndTrim removes that delimiter before ExecParams.
    # This is a fixed-fixture derivation, not a general PostgreSQL SQL parser.
    source=candidate.decode('utf8',errors='strict').replace('\r\n','\n').strip()
    if not source.isascii() or not source.endswith('$$;') or source.endswith('$$;;') or source.count('$$')!=2:
        raise RuntimeError('fixed candidate token shape invalid')
    fixed=source.removesuffix(';').strip()
    if not fixed or len(fixed)>65536 or '(SQLSTATE ' in fixed:raise RuntimeError('candidate statement size invalid')
    states=re.findall(r'\(SQLSTATE ([0-9A-Z]{5})\)',output)
    lines=logs.replace('\r\n','\n').splitlines();found=[]
    error=re.compile(r'\['+str(pid)+r'\] ERROR:\s+([0-9A-Z]{5}):\s*(.*?)\s*$')
    any_entry=re.compile(r'\['+str(pid)+r'\] (?:ERROR|FATAL|PANIC|LOG|STATEMENT):')
    statement=re.compile(r'\['+str(pid)+r'\] STATEMENT:[ \t]*')
    same_pid_errors=sum(bool(error.search(line)) for line in lines)
    for i,line in enumerate(lines):
        hit=error.search(line)
        if not hit:continue
        for j in range(i+1,min(i+40,len(lines))):
            match=statement.search(lines[j])
            if match:
                observed=lines[j][match.end():]+'\n'+'\n'.join(lines[j+1:])
                tail=observed[len(fixed):] if observed.startswith(fixed) else None
                if tail is not None and (not tail or re.match(r'\n+(?:(?:[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)? UTC )?\[[0-9]+\] (?:LOG|ERROR|FATAL|PANIC|STATEMENT|DETAIL|HINT|CONTEXT|LOCATION):|$)',tail)):
                    found.append((hit.group(1),hit.group(2)))
                break
            if any_entry.search(lines[j]):break
    if same_pid_errors!=1 or len(found)!=1 or len(states)!=1 or found[0][0]!=states[0]:
        diagnostic={'single_same_pid_error':same_pid_errors==1,
          'same_pid_statement_seen':any(statement.search(line) is not None for line in lines),
          'candidate_bytes_present':fixed in logs.replace('\r\n','\n'),
          'unique_candidate_error_pair':len(found)==1,
          'client_sqlstate_unique':len(states)==1,
          'client_sqlstate_matches':len(found)==1 and len(states)==1 and found[0][0]==states[0]}
        print('SYNTHETIC_MEMBERSHIP_CANDIDATE_ERROR_DIAGNOSTIC '+json.dumps(diagnostic,sort_keys=True),flush=True)
        raise RuntimeError('CLI candidate statement, PID or SQLSTATE unproven')
    state,message=found[0];raw=message.encode('utf8',errors='strict')
    if not raw or len(raw)>4096:raise RuntimeError('CLI candidate error message absent or exceeds bound')
    return {'status':'sql_error','sqlstate':state,'message_diagnostic':{
      'class':CANDIDATE_ERROR_CLASSES.get(message,'unknown'),'length':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}}

def verify_membership(snapshot,expected,target_oid,parent_oid,anon_oid):
    if (snapshot['target_oid']!=target_oid or snapshot['parent_oid']!=parent_oid or snapshot['anon_oid']!=anon_oid
        or snapshot['parent_truncate'] is not True or snapshot['parent_other'] is not False):
        raise RuntimeError('membership target or parent privilege mismatch')
    attrs=snapshot['role_attributes']
    parents=[r for r in attrs if isinstance(r,list) and len(r)==9 and r[1]==ROLE]
    postgres=[r for r in attrs if isinstance(r,list) and len(r)==9 and r[1]=='postgres']
    if (len(parents)!=1 or parents[0][0]!=parent_oid or parents[0][2:]!=[False,True,False,False,False,False,False]
        or len(postgres)!=1 or type(postgres[0][0]) is not int or postgres[0][0]<=0):
        raise RuntimeError('synthetic role attributes or grantor mismatch')
    rows=snapshot['membership']
    if expected:
        if (len(rows)!=1 or not isinstance(rows[0],list) or len(rows[0])!=6
            or rows[0][0]!=parent_oid or rows[0][1]!=anon_oid
            or rows[0][2]!=postgres[0][0]
            or rows[0][3:]!=[False,True,False] or snapshot['member'] is not True
            or snapshot['usage'] is not True or snapshot['set'] is not False or snapshot['anon_truncate'] is not True):
            raise RuntimeError('committed membership options or reachability mismatch')
    elif rows!=[] or snapshot['member'] or snapshot['usage'] or snapshot['set']:
        raise RuntimeError('unexpected preexisting membership')


def run_before(service,table,event,phase2,base):
    if type(service) is not base.OwnedService:raise RuntimeError('fixed owned service required')
    candidates=base.candidate_pair();body=candidates['locked_single_do']
    if hashlib.sha256(body).hexdigest()!=BODY_SHA:raise RuntimeError('candidate body mismatch')
    binary=base.safe_cli_binary();clients=phase2.OwnedClients(service,base);member=MemberClient(service,base)
    original=None;result=None;stage='initialization'
    try:
        service.create();service.wait_final_postmaster();service.initialize();service.configure_synthetic_loopback()
        stage='role_setup'
        service.psql('CREATE ROLE synthetic_acl_parent NOLOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB NOREPLICATION NOBYPASSRLS; '
          'GRANT TRUNCATE ON TABLE public.asset_pref_mirror TO synthetic_acl_parent;')
        stage='baseline'
        before_table=json.loads(service.psql(base.SNAPSHOT));before=membership_snapshot(service)
        oid,parent_oid,anon_oid=(before[k] for k in ('target_oid','parent_oid','anon_oid'))
        verify_membership(before,False,oid,parent_oid,anon_oid)
        if not all(before[k] for k in ('direct_anon','direct_authenticated','anon_truncate','authenticated_truncate')):
            raise RuntimeError('membership fixture baseline mismatch')
        stage='gate_and_staging'
        service.psql(event.gate_sql(service.token,phase2.KEY));service.stage(binary,body)
        stage='event_wait'
        coord=clients.start_coordinator();clients.start_cli();waiter=event.wait_for_event(service,clients,phase2,coord)
        if waiter is None:raise RuntimeError('required before-revoke event not observed')
        cli_pid=waiter['pid']
        if waiter['target_oid']!=oid:raise RuntimeError('event and role fixture target OID mismatch')
        table.verify_cli_auth(cli_pid,service.logs());event.prove_event_log(service.logs(),waiter)
        stage='membership_observation'
        member.start();first=member.poll_until(time.monotonic()+3,oid,parent_oid,{coord,cli_pid})
        released=False
        if first['state']=='lock_wait':
            verify_auth(first['pid'],service.logs(),service.nonce)
            print('SYNTHETIC_MEMBERSHIP_LOCK_WAIT '+json.dumps({'target_oid':oid,'parent_oid':parent_oid,
              'cli_pid':cli_pid,'member_pid':first['pid'],'blocker_pids':first['blockers']},sort_keys=True),flush=True)
        if first['state'] in ('lock_wait','deadline'):
            clients.release();released=True
            final=member.poll_until(time.monotonic()+12,oid,parent_oid,{coord,cli_pid})
        else:final=first
        stage='membership_finalize'
        if final['state']=='statement_done':
            pid=final['pid'];verify_statement(pid,service.logs(),service.nonce)
            member.commit();code,out,err=member.finish()
            if code!=0:raise RuntimeError('membership explicit commit failed')
            verify_success(pid,oid,parent_oid,out,err,service.logs(),service.nonce)
            b={'status':'committed','pid':pid,'sqlstate':None}
        elif final['state']=='client_exited':
            code,out,err=member.finish()
            b={'status':'sql_error',**verify_error(table,code,out,err,service.logs(),service.nonce,oid,parent_oid,{coord,cli_pid})}
        else:raise RuntimeError('membership completion deadline or state unresolved')
        stage='before_release_snapshot'
        before_release=None
        if b['status']=='committed' and not released:
            before_release=membership_snapshot(service);verify_membership(before_release,True,oid,parent_oid,anon_oid)
            if (before_release['other_memberships']!=before['other_memberships']
                or before_release['role_attributes']!=before['role_attributes']):
                raise RuntimeError('unrelated role state changed before CLI release')
        if not released:clients.release()
        stage='cli_finish'
        acode,aoutput=clients.finish_cli();logs=service.logs()
        if service.psql('SELECT count(*) FROM pg_catalog.pg_stat_activity WHERE pid IN ('+str(cli_pid)+','+str(b['pid'])+');').strip()!='0':
            raise RuntimeError('CLI or membership backend remains')
        stage='post_release_snapshot'
        after_table=json.loads(service.psql(base.SNAPSHOT));after=membership_snapshot(service)
        verify_membership(after,b['status']=='committed',oid,parent_oid,anon_oid)
        history=json.loads(service.psql("SELECT coalesce(jsonb_agg(jsonb_build_object('version',version,'name',name,'statement_count',coalesce(array_length(statements,1),0)) ORDER BY version),'[]') FROM supabase_migrations.schema_migrations;"))
        stage='cli_outcome_validation'
        if acode==0:
            if (len(history)!=1 or history[0].get('version')!=base.VERSION or history[0].get('name')!='synthetic_acl'
                or type(history[0].get('statement_count')) is not int or history[0]['statement_count']<=0
                or after['direct_anon'] is not False or after['direct_authenticated'] is not False
                or after['anon_truncate'] is not (b['status']=='committed')):
                raise RuntimeError('CLI membership-case success/history mismatch')
            a={'status':'committed','sqlstate':None}
        else:
            if history!=[] or after['direct_anon'] is not True or after['direct_authenticated'] is not True:
                raise RuntimeError('CLI membership-case rollback/history mismatch')
            stage='cli_failure_classification'
            a=verify_cli_candidate_error(cli_pid,aoutput,logs,body)
        stage='other_invariant_checks'
        stable=('owner','rls','force','rows','policy','other_acl','other_effective','columns','role_attributes','hierarchy','service')
        if any(before_table[k]!=after_table[k] for k in stable):raise RuntimeError('unrelated table state changed')
        if (before['other_memberships']!=after['other_memberships'] or before['role_attributes']!=after['role_attributes']):
            raise RuntimeError('unrelated membership or role attributes changed')
        if acode!=0 and before_table['acl']!=after_table['acl']:
            raise RuntimeError('failed CLI did not roll back its table ACL')
        stage='fatal_validation'
        summary=base.summarize_control_fatals(logs,service.verified_negative_fatals)
        if summary['verified_negative_control_fatals']!=2 or summary['unexpected_fatal_count']!=0:
            raise RuntimeError('unexpected FATAL or missing negative controls')
        result={'stage':'before_revoke','run_id':service.run_id,'nonce':service.nonce,'container_id':service.cid,'target_oid':oid,'parent_oid':parent_oid,'anon_oid':anon_oid,
          'cli_pid':cli_pid,'coordinator_pid':coord,'member_pid':b['pid'],'first_observation':first['state'],
          'blocker_pids':first.get('blockers',[]),'membership_grant':b,'cli':a,'history_count':len(history),
          'membership_commit_before_cli_release':b['status']=='committed' and not released,
          'before_release_membership_observed':before_release is not None,
          'final_member':after['member'],'final_usage':after['usage'],'final_set':after['set'],
          'final_direct_anon_truncate':after['direct_anon'],'final_effective_anon_truncate':after['anon_truncate'],
          'scope':'synthetic PG17, INHERIT TRUE/SET FALSE only; no after-revoke or production claim'}
    except BaseException as exc:
        original=exc
        try:
            print('SYNTHETIC_MEMBERSHIP_FAILURE_STAGE '+json.dumps(
              {'stage':stage,'runtime_error':isinstance(exc,RuntimeError)},sort_keys=True),flush=True)
        except BaseException:pass
    finally:
        member_failed=False;clients_failed=False;container_unconfirmed=False
        try:member.close()
        except BaseException:member_failed=True
        try:clients.close()
        except BaseException:clients_failed=True
        if service.cid is not None:
            try:
                capture=event.BoundedCapture()
                with contextlib.redirect_stdout(capture):service.stop_owned()
                evidence=event.validate_teardown(capture.getvalue(),service)
                evidence.update(member_client_cleanup_confirmed=not member_failed,cli_clients_cleanup_confirmed=not clients_failed)
                print('SYNTHETIC_MEMBERSHIP_OWNED_TEARDOWN '+json.dumps(evidence,sort_keys=True),flush=True)
            except BaseException:container_unconfirmed=True
        else:container_unconfirmed=True
        if member_failed or clients_failed or container_unconfirmed:
            raise event.PreflightCleanupError(original,member_failed or clients_failed,container_unconfirmed) from None
    if original is not None:raise event.PreflightRunError(original) from None
    if result is None:raise RuntimeError('membership observation produced no result')
    result['cleanup_confirmed']=True
    return result


if __name__=='__main__':raise SystemExit('REVIEW ONLY: direct execution disabled')
