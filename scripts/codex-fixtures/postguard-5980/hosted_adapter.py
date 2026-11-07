"""Unreviewed hosted-only Docker adapter for protocol.py.

Never use with a real project. All connections are docker-exec processes
inside a newly created network-none container, using its Unix socket only.
Environment metadata is forgeable and is not a security attestation.
"""
import hashlib, json, os, queue, re, secrets, socket, stat, subprocess, sys, tempfile, threading, time
from pathlib import Path
import protocol

IMAGE = 'postgres@sha256:0b81cec82228160abfa753aeaad0609b709eb26eeb950f2e404ad2326e1cc370'
BOOT_SHA = '8ecedb30425f354fd5b9d5fada49481be7f57cad1147f186690b2babe4a88e6f'
STOP = "\\set ON_ERROR_STOP on\n-- SAFETY: This file is design evidence, not an executable setup script.\nDO $$ BEGIN RAISE EXCEPTION 'STOP: review-only fixture'; END $$;\n\n"
SOCKET = '/var/run/postgresql'

class HostedError(RuntimeError):
    pass


def _need(condition, label):
    if condition is not True: raise HostedError(label)


def _exact_pid(value):
    return type(value) is int and 1 <= value <= 2147483647


class Session:
    """One owned docker-exec/psql process; marker and SQL are internal only."""
    def __init__(self, driver, role):
        driver.inspect_owned()
        self.driver=driver; self.role=role; self.q=queue.Queue(); self.serial=0
        args=driver.docker+['exec','-i','-u','postgres',driver.cid,
            '/usr/bin/env','-i','PATH=/usr/local/bin:/usr/bin:/bin',
            '/usr/local/bin/psql','-X','-qAt','--no-password','-v','ON_ERROR_STOP=1',
            '-h',SOCKET,'-U','postgres','-d',driver.dbname]
        self.proc=subprocess.Popen(args,env=driver.child_env,stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE,stderr=subprocess.STDOUT,bufsize=0)
        def read():
            try:
                for line in iter(self.proc.stdout.readline,b''):
                    self.q.put(line.decode('utf8',errors='replace').rstrip('\r\n'))
            finally:
                self.q.put(None)
        self.reader=threading.Thread(target=read,daemon=True); self.reader.start()
    def submit(self, sql):
        _need(type(sql) is str and self.proc.poll() is None, 'session_not_running')
        self.proc.stdin.write(sql.encode('utf8')); self.proc.stdin.flush()
    def ask(self, sql, timeout=25):
        self.serial += 1
        tag='END_'+self.driver.nonce+'_'+self.role+'_'+str(self.serial)
        self.submit(sql+'\n\\echo '+tag+'\n')
        return self.until(tag,timeout)
    def until(self, tag, timeout=25):
        until=time.monotonic()+timeout; lines=[]
        while True:
            remaining=until-time.monotonic()
            if remaining<=0: raise HostedError('session_deadline')
            try: item=self.q.get(timeout=remaining)
            except queue.Empty as error: raise HostedError('session_deadline') from error
            if item is None: raise HostedError('session_exited')
            if item==tag: return lines
            if len(lines)>=20 or len(item)>4096: raise HostedError('unexpected_session_output')
            lines.append(item)
    def close(self):
        try:
            if self.proc.poll() is None:
                self.proc.terminate()
                try: self.proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.proc.kill(); self.proc.wait(timeout=5)
            return self.proc.poll() is not None
        except (OSError, subprocess.SubprocessError): return False


class HostedAdapter:
    def __init__(self):
        self.nonce=secrets.token_hex(16); self.dbname='fx_'+self.nonce[:20]
        self.name='codex-acl-postguard-'+self.nonce; self.cid=None; self.created_attempted=False
        self.config=None; self.sessions={}; self.safety_seen=False
        self.child_env={'PATH':'/usr/bin:/bin','LANG':'C'}
        self.image=None; self.password=None; self.server_version_num=None
    def _run(self, args, timeout=30, check=True):
        try:
            result=subprocess.run(self.docker+args, env=self.child_env, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, timeout=timeout)
        except (OSError, subprocess.SubprocessError) as error:
            raise HostedError('docker_command_failed') from error
        if check and result.returncode!=0: raise HostedError('docker_nonzero')
        return result
    def _json(self, args):
        try:
            obj=json.loads(self._run(args).stdout)
            _need(type(obj) is list and len(obj)==1 and type(obj[0]) is dict,'inspect_shape')
            return obj[0]
        except (ValueError, TypeError) as error: raise HostedError('inspect_invalid') from error
    def preflight(self):
        _need(sys.platform=='linux','not_linux')
        required={'GITHUB_ACTIONS':'true','CI':'true','RUNNER_ENVIRONMENT':'github-hosted',
                  'RUNNER_OS':'Linux','GITHUB_REPOSITORY':'kanta13jp1/my_web_app',
                  'GITHUB_EVENT_NAME':'push','GITHUB_REF':'refs/heads/codex/asset-pref-postguard-5980'}
        _need(all(os.environ.get(k)==v for k,v in required.items()),'hosted_identity_missing')
        _need(re.fullmatch(r'[0-9]+',os.environ.get('GITHUB_RUN_ID','')) is not None and
              re.fullmatch(r'[0-9a-f]{40}',os.environ.get('GITHUB_SHA','')) is not None,'run_identity_missing')
        root=Path(os.environ.get('RUNNER_TEMP',''))
        _need(root.is_absolute() and root.is_dir() and not root.is_symlink(),'runner_temp_invalid')
        socket_path=Path('/var/run/docker.sock')
        _need(socket_path.exists() and not socket_path.is_symlink() and
              stat.S_ISSOCK(socket_path.stat().st_mode) and socket_path.stat().st_uid==0,'docker_socket_invalid')
        self.config=tempfile.TemporaryDirectory(prefix='fx-docker-',dir=str(root.resolve(strict=True)))
        self.docker=['/usr/bin/docker','--config',self.config.name,'--host','unix:///var/run/docker.sock']
        _need(Path('/usr/bin/docker').is_file() and not Path('/usr/bin/docker').is_symlink(),'docker_binary_invalid')
        self.image=self._json(['image','inspect',IMAGE])
        _need(IMAGE in (self.image.get('RepoDigests') or []) and
              re.fullmatch(r'sha256:[0-9a-f]{64}',str(self.image.get('Id',''))) is not None,'image_not_pinned')
    def inspect_owned(self):
        _need(self.cid is not None and re.fullmatch(r'[0-9a-f]{64}',self.cid) is not None,'container_id_invalid')
        obj=self._json(['inspect','--type=container',self.cid]); cfg=obj.get('Config') or {}; host=obj.get('HostConfig') or {}
        net=obj.get('NetworkSettings') or {}; state=obj.get('State') or {}; labels=cfg.get('Labels') or {}
        mounts=obj.get('Mounts'); ports=net.get('Ports') or {}; networks=net.get('Networks') or {}
        _need(obj.get('Id')==self.cid and obj.get('Image')==self.image.get('Id') and
              cfg.get('Image')==IMAGE and labels.get('codex.fixture.nonce')==self.nonce and
              labels.get('codex.fixture.scope')=='postguard-5980' and state.get('Running') is True,
              'container_identity')
        _need(host.get('NetworkMode')=='none' and set(networks)=={'none'} and
              host.get('Privileged') is False and host.get('PublishAllPorts') is False and
              not any(host.get(k) for k in ('Binds','PortBindings','Devices','DeviceRequests','CapAdd',
                                            'ExtraHosts','Links','VolumesFrom','SecurityOpt')) and
              all(not v for v in ports.values()) and type(mounts) is list and
              all(m.get('Type')=='tmpfs' and m.get('Destination')=='/var/lib/postgresql/data' for m in mounts),
              'container_isolation')
        image_cfg=self.image.get('Config') or {}
        def env_map(values):
            _need(type(values) is list,'env_shape')
            result={}
            for item in values:
                _need(type(item) is str and '=' in item,'env_item')
                key,value=item.split('=',1)
                _need(bool(key) and key not in result,'env_duplicate')
                result[key]=value
            return result
        expected=env_map(image_cfg.get('Env'))
        expected.update(POSTGRES_DB=self.dbname,POSTGRES_PASSWORD=self.password)
        _need(env_map(cfg.get('Env'))==expected and
              cfg.get('Entrypoint')==image_cfg.get('Entrypoint') and
              cfg.get('Cmd')==image_cfg.get('Cmd') and
              cfg.get('User')==image_cfg.get('User'),'container_environment')
        tmpfs=host.get('Tmpfs') or {}
        _need(set(tmpfs)=={'/var/lib/postgresql/data'} and
              {'rw','nosuid','nodev'}.issubset(set(tmpfs['/var/lib/postgresql/data'].split(','))) and
              bool({'size=256m','size=268435456'} & set(tmpfs['/var/lib/postgresql/data'].split(','))),'container_tmpfs')
        _need(host.get('PidMode') in ('','private') and host.get('IpcMode') in ('','private') and
              host.get('UsernsMode') in ('','private'),'container_namespace')
        return obj
    def provision(self):
        self.preflight(); self.password=secrets.token_hex(24)
        self.created_attempted=True
        result=self._run(['run','--detach','--pull=never','--network','none','--name',self.name,
            '--label','codex.fixture.scope=postguard-5980','--label','codex.fixture.nonce='+self.nonce,
            '--tmpfs','/var/lib/postgresql/data:rw,nosuid,nodev,size=256m',
            '--env','POSTGRES_DB='+self.dbname,'--env','POSTGRES_PASSWORD='+self.password,IMAGE],timeout=30)
        self.cid=result.stdout.decode('ascii',errors='strict').strip()
        self.inspect_owned(); self.safety_seen=True
        deadline=time.monotonic()+30
        while True:
            self.inspect_owned()
            ready=self._run(['exec','-u','postgres',self.cid,'/usr/bin/env','-i',
                'PATH=/usr/local/bin:/usr/bin:/bin','/usr/local/bin/pg_isready',
                '-h',SOCKET,'-U','postgres','-d',self.dbname],timeout=4,check=False)
            if ready.returncode==0: break
            if time.monotonic()>=deadline: raise HostedError('postgres_ready_deadline')
            time.sleep(0.25)
        return {'owned':True,'verified_image':True,'network_none':True,'no_host_mounts_or_ports':True,'fresh_nonce':True}
    def _session(self, name):
        _need(self.safety_seen is True and name not in self.sessions,'session_scope')
        self.inspect_owned(); session=Session(self,name); self.sessions[name]=session
        return session
    def _query_json(self, session, sql):
        lines=session.ask(sql)
        _need(len(lines)==1,'json_row_count')
        try: value=json.loads(lines[0])
        except ValueError as error: raise HostedError('json_invalid') from error
        _need(type(value) is dict,'json_shape')
        return value
    def _identity(self, session):
        x=self._query_json(session,"SELECT json_build_object('pid',pg_backend_pid(),'dbname',current_database(),'socket',inet_server_addr() IS NULL,'v',current_setting('server_version_num')::int)::text;")
        _need(_exact_pid(x.get('pid')) and x.get('dbname')==self.dbname and x.get('socket') is True and
              type(x.get('v')) is int and 170000<=x['v']<180000,'db_identity')
        if self.server_version_num is None:
            self.server_version_num=x['v']
        _need(x['v']==self.server_version_num,'server_version_changed')
        return {'pid':x['pid'],'unix_socket':True,'system_id':self.cid}
    def _bootstrap_content(self):
        path=Path(__file__).resolve().parent/'bootstrap.REVIEW-ONLY.sql.txt'; data=path.read_bytes()
        _need(hashlib.sha256(data).hexdigest()==BOOT_SHA,'bootstrap_hash')
        text=data.decode('utf-8-sig').replace('\r\n','\n')
        _need(text.startswith(STOP) and text.count("RAISE EXCEPTION 'STOP: review-only fixture'")==1,'bootstrap_guard')
        return text[len(STOP):]
    def bootstrap(self):
        setup=self._session('SETUP'); self._identity(setup)
        empty=self._query_json(setup,"SELECT json_build_object('empty', NOT EXISTS (SELECT FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','fixture_trunc_parent')) AND to_regclass('public.asset_pref_mirror') IS NULL AND NOT EXISTS (SELECT FROM pg_namespace WHERE nspname='fixture_history'))::text;")
        _need(empty.get('empty') is True,'fixture_not_empty')
        _need(setup.ask(self._bootstrap_content()) == [], 'unexpected_bootstrap_output'); snapshot=self._snapshot(setup)
        _need(setup.close(),'setup_client_cleanup')
        self.sessions.pop('SETUP')
        return {'fresh_synthetic_db':True,'pg17':True,'target_rls_postgres':snapshot['target_rls_postgres'],
                'fixture_parent_truncate':snapshot['fixture_parent_truncate'],'member':snapshot['member'],
                'anon_direct':snapshot['anon_direct'],'auth_direct':snapshot['auth_direct'],
                'anon_effective':snapshot['anon_effective'],'auth_effective':snapshot['auth_effective'],
                'history_count':snapshot['history_count'],'other_acl_fingerprint':snapshot['other_acl_fingerprint']}
    def open_session(self,name):
        _need(name in ('A','B','C'),'session_name')
        session=self._session(name); identity=self._identity(session); session.pid=identity['pid']; return identity
    def _get(self,name,pid):
        self.inspect_owned(); s=self.sessions.get(name)
        _need(s is not None and s.pid==pid and s.proc.poll() is None,'session_pid_mismatch')
        return s
    def c_hold_barrier(self,pid):
        s=self._get('C',pid); rows=s.ask('SELECT pg_advisory_lock(73580,1);'); return rows==[''] or rows==[]
    def a_begin_and_guard(self,pid,migration):
        _need(type(migration) is bytes and hashlib.sha256(migration).hexdigest()==protocol.MIGRATION_SHA256,'migration_hash')
        s=self._get('A',pid); rows=s.ask("BEGIN; SELECT pg_current_xact_id()::text;")
        _need(len(rows)==1 and rows[0].isdigit(),'candidate_xid')
        txid=rows[0]; output=s.ask(migration.decode('utf8'))
        _need(output==[],'unexpected_migration_output')
        return {'pid':pid,'txid':txid,'guard_ok':True}
    def a_send_history(self,pid,statement):
        _need(statement==protocol.HISTORY_SQL,'history_sql_mismatch')
        s=self._get('A',pid); self.a_tag='HISTORY_'+self.nonce
        s.submit(statement+'\n\\echo '+self.a_tag+'\n'); return True
    def _wait_observation(self,c_pid,a_pid):
        s=self._get('C',c_pid)
        sql="""SELECT json_build_object('a_pid',a.pid,'c_pid',pg_backend_pid(),'txid',a.backend_xid::text,'query',a.query,
          'a_waits_exact_lock',EXISTS(SELECT 1 FROM pg_locks l WHERE l.pid=a.pid AND l.locktype='advisory' AND l.classid=73580 AND l.objid=1 AND l.objsubid=2 AND NOT l.granted),
          'c_holds_exact_lock',EXISTS(SELECT 1 FROM pg_locks l WHERE l.pid=pg_backend_pid() AND l.locktype='advisory' AND l.classid=73580 AND l.objid=1 AND l.objsubid=2 AND l.granted))::text
          FROM pg_stat_activity a WHERE a.pid=%d AND a.wait_event_type='Lock' AND a.wait_event='advisory';""" % a_pid
        end=time.monotonic()+20
        while time.monotonic()<end:
            rows=s.ask(sql)
            if len(rows)==1:
                try: result=json.loads(rows[0])
                except ValueError as error: raise HostedError('wait_json') from error
                if result.get('a_waits_exact_lock') is True and result.get('c_holds_exact_lock') is True: return result
            elif rows: raise HostedError('wait_rows')
            time.sleep(0.2)
        raise HostedError('barrier_deadline')
    def c_observe_wait(self,c,a): return self._wait_observation(c,a)
    def b_commit_membership(self,pid):
        s=self._get('B',pid); rows=s.ask('BEGIN; GRANT fixture_trunc_parent TO anon WITH INHERIT TRUE; COMMIT;')
        _need(rows==[],'grant_output'); return {'pid':pid,'committed':True}
    def c_observe_after_b(self,c,a):
        wait=self._wait_observation(c,a)
        member=self._query_json(self._get('C',c),"SELECT json_build_object('member',pg_has_role('anon','fixture_trunc_parent','MEMBER'),'member_inherit',EXISTS(SELECT 1 FROM pg_auth_members WHERE roleid='fixture_trunc_parent'::regrole AND member='anon'::regrole AND inherit_option))::text;")
        return {'a_pid':wait['a_pid'],'txid':wait['txid'],'member':member.get('member'),'member_inherit':member.get('member_inherit'),
                'a_still_waits':wait['a_waits_exact_lock'],'c_still_holds':wait['c_holds_exact_lock']}
    def c_release_barrier(self,pid):
        x=self._query_json(self._get('C',pid),"SELECT json_build_object('released',pg_advisory_unlock(73580,1))::text;")
        return x.get('released') is True
    def a_finish(self,pid):
        s=self._get('A',pid); _need(s.until(self.a_tag)==[],'history_output')
        _need(s.ask('COMMIT;')==[],'commit_output'); return {'pid':pid,'commit_ok':True}
    def _snapshot(self, session):
        sql="""SELECT json_build_object(
          'target_rls_postgres',c.relrowsecurity AND pg_get_userbyid(c.relowner)='postgres' AND c.relkind='r',
          'fixture_parent_truncate',has_table_privilege('fixture_trunc_parent',c.oid,'TRUNCATE'),
          'member',pg_has_role('anon','fixture_trunc_parent','MEMBER'),
          'member_inherit',EXISTS(SELECT 1 FROM pg_auth_members m WHERE m.roleid='fixture_trunc_parent'::regrole AND m.member='anon'::regrole AND m.inherit_option),
          'anon_direct',EXISTS(SELECT 1 FROM aclexplode(c.relacl) e WHERE e.grantee='anon'::regrole AND e.privilege_type='TRUNCATE'),
          'auth_direct',EXISTS(SELECT 1 FROM aclexplode(c.relacl) e WHERE e.grantee='authenticated'::regrole AND e.privilege_type='TRUNCATE'),
          'anon_effective',has_table_privilege('anon',c.oid,'TRUNCATE'),
          'auth_effective',has_table_privilege('authenticated',c.oid,'TRUNCATE'),
          'history_count',(SELECT count(*) FROM fixture_history.migrations),
          'other',json_build_object(
            'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'forced',c.relforcerowsecurity,'kind',c.relkind,
            'service_truncate',has_table_privilege('service_role',c.oid,'TRUNCATE'),
            'acl',(SELECT coalesce(json_agg(json_build_array(e.grantor,e.grantee,e.privilege_type,e.is_grantable) ORDER BY e.grantor,e.grantee,e.privilege_type,e.is_grantable),'[]'::json)
              FROM aclexplode(c.relacl) e WHERE NOT (e.privilege_type='TRUNCATE' AND e.grantee IN ('anon'::regrole,'authenticated'::regrole))),
            'policies',(SELECT coalesce(json_agg(json_build_array(p.polname,p.polcmd,p.polpermissive,p.polroles::text,pg_get_expr(p.polqual,p.polrelid),pg_get_expr(p.polwithcheck,p.polrelid)) ORDER BY p.polname),'[]'::json)
              FROM pg_policy p WHERE p.polrelid=c.oid),
            'memberships',(SELECT coalesce(json_agg(json_build_array(m.roleid,m.member,m.grantor,m.admin_option,m.inherit_option,m.set_option) ORDER BY m.roleid,m.member,m.grantor),'[]'::json)
              FROM pg_auth_members m WHERE NOT (m.roleid='fixture_trunc_parent'::regrole AND m.member='anon'::regrole))
          ))::text FROM pg_class c WHERE c.oid='public.asset_pref_mirror'::regclass;"""
        obj=self._query_json(session,sql)
        other=obj.pop('other',None)
        _need(type(other) is dict,'other_acl_missing')
        obj['other_acl_fingerprint']=hashlib.sha256(json.dumps(other,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        return obj
    def c_final_observation(self,pid):
        obj=self._snapshot(self._get('C',pid))
        return {k:obj[k] for k in ('history_count','member','member_inherit','anon_direct','auth_direct','anon_effective','auth_effective','other_acl_fingerprint')}
    def cleanup(self):
        clients_ok=True
        for s in list(self.sessions.values()): clients_ok=s.close() and clients_ok
        self.sessions.clear()
        removed=False; inspected_absent=False; listed_absent=False
        if self.cid is not None:
            try:
                self.inspect_owned()
                removed=self._run(['rm','--force',self.cid],timeout=30).returncode==0
                missing=self._run(['inspect','--type=container',self.cid],check=False)
                inspected_absent=missing.returncode!=0 and b'No such object' in missing.stderr
                listed=self._run(['ps','--all','--quiet','--no-trunc','--filter','id='+self.cid])
                listed_absent=listed.stdout.strip()==b''
            except HostedError:
                pass
        elif not self.created_attempted:
            removed=inspected_absent=listed_absent=True
        # When docker run timed out after a possible create and no ID was
        # returned, ownership cannot be established: leave it and fail closed.
        if self.config is not None:
            try: self.config.cleanup()
            except OSError: clients_ok=False
        return {'owned_clients_stopped':clients_ok,'owned_container_removed':removed,
                'inspect_absent':inspected_absent,'list_absent':listed_absent}
