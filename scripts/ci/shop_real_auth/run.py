"""Real Supabase Auth/PostgREST contract tests, only in a disposable CI stack.

No hosted project linkage, deployment, payment, actual email, or customer data.
Never fabricate auth.uid(), roles, JWTs, Auth responses, or review API responses.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import unquote
from urllib.request import Request, build_opener, HTTPRedirectHandler

from guard import API, APP, local_url, runtime

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
EVIDENCE = ROOT / 'shop-real-auth-evidence'
CLI_VERSION = '2.84.2'
MIGRATIONS = [
    '20260728010000_create_shop_product_downloads.sql',
    '20260821015546_generalize_digital_product_store.sql',
    '20260912041437_shop_product_releases_reviews.sql',
    '20260912091100_shop_post_funnel_attribution.sql',
]
PRODUCT = 'hexciv-win64'
checks = []


def command(args, *, cwd=None, env=None, timeout=120, text_input=None):
    result = subprocess.run(args, cwd=cwd, env=env, input=text_input, capture_output=True,
                            text=True, encoding='utf-8', timeout=timeout, check=False)
    if result.returncode:
        # Emit only scrubbed diagnostics. Never persist raw CLI/auth output.
        safe = re.sub(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '[JWT REDACTED]', result.stderr)
        safe = re.sub(r'(postgres(?:ql)?://)[^\s]+', r'\1[REDACTED]', safe)
        safe = '\n'.join(line for line in safe.splitlines()
                         if not re.search(r'key|secret|password|token|authorization', line, re.I))
        print(safe[-4000:], flush=True)
        raise RuntimeError(f'Command failed: {Path(args[0]).name}; exit={result.returncode}')
    return result.stdout


def record(name, condition):
    checks.append({'name': name, 'passed': bool(condition)})
    if not condition:
        raise AssertionError('Contract failed: ' + name)
    print('PASS: ' + name, flush=True)


def save_json(path, data, *, private=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if private:
        # New files are private from the moment they are opened, not chmod later.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
    else:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def state():
    project, work = runtime()
    data = json.loads((work/'state.json').read_text(encoding='utf-8'))
    assert data['project'] == project
    local_url(data['url'], port=54321)
    local_url(data['db'], port=54322, database=True)
    return work, data


def sql(data, statement):
    conn = local_url(data['db'], port=54322, database=True)
    env = {**os.environ, 'PGPASSWORD': unquote(conn.password or ''), 'PGSSLMODE': 'disable'}
    return command(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                    '-p', '54322', '-U', 'postgres', '-d', 'postgres', '-c', statement], env=env).strip()


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError('Redirects are forbidden in the isolated API suite')


def request(data, path, method='GET', body=None, token=None, headers=None, admin=False):
    local_url(data['url'], port=54321)
    if not path.startswith(('/auth/v1/', '/rest/v1/')) or '\\' in path or '\n' in path:
        raise ValueError('Only local Auth and REST paths are allowed')
    key = data['service'] if admin else data['anon']
    req_headers = {'apikey': key, 'Authorization': 'Bearer ' + (token or key),
                   'Content-Type': 'application/json', **(headers or {})}
    req = Request(API + path, data=None if body is None else json.dumps(body).encode(),
                  headers=req_headers, method=method)
    try:
        response = build_opener(NoRedirect).open(req, timeout=20)
    except HTTPError as error:
        response = error
    raw = response.read()
    return response.status, json.loads(raw) if raw else None


def ok(data, path, method='GET', body=None, **kwargs):
    status, payload = request(data, path, method, body, **kwargs)
    if not 200 <= status < 300:
        code = payload.get('error_code', payload.get('code', '')) if isinstance(payload, dict) else ''
        raise AssertionError(f'API {method} {path.split("?")[0]} failed: {status}/{code}')
    return payload


def rpc(data, name, params, token=None):
    return ok(data, '/rest/v1/rpc/' + name, 'POST', params, token=token)


def snapshot(data):
    return [ok(data, '/rest/v1/' + table + '?select=*&order=id', admin=True)
            for table in ['shop_product_reviews', 'shop_product_releases', 'shop_purchases']] + [
                ok(data, '/rest/v1/shop_post_funnel_events?select=*&order=visitor_id,product_id,source,campaign,content_id,stage', admin=True)]


def deny(data, name, path, method, body=None, token=None, headers=None, allow_noop=False):
    before = snapshot(data)
    status, payload = request(data, path, method, body, token, headers)
    rejected = 400 <= status < 500 or (allow_noop and status in (200, 204) and payload in ([], None))
    record(name, rejected and snapshot(data) == before)


def prepare():
    project, work = runtime()
    assert not work.exists(), 'Do not reuse a previous runtime'
    assert command(['supabase', '--version']).strip() == CLI_VERSION
    (work/'supabase').mkdir(parents=True)
    config = (HERE/'config.toml').read_text(encoding='utf-8').replace('hexciv-auth-template', project)
    (work/'supabase'/'config.toml').write_text(config, encoding='utf-8')
    EVIDENCE.mkdir(exist_ok=True)
    command(['docker', 'network', 'create', '--driver', 'bridge', '--opt',
             'com.docker.network.bridge.host_binding_ipv4=127.0.0.1', project])
    command(['supabase', 'start', '--workdir', str(work), '--network-id', project, '--exclude',
             'realtime,imgproxy,studio,postgres-meta,edge-runtime,logflare,vector,supavisor,mailpit'],
            timeout=720)
    status = json.loads(command(['supabase', 'status', '--workdir', str(work), '--output', 'json']))
    data = dict(project=project, url=status['API_URL'], db=status['DB_URL'],
                anon=status['ANON_KEY'], service=status['SERVICE_ROLE_KEY'])
    local_url(data['url'], port=54321)
    local_url(data['db'], port=54322, database=True)
    services = command(['docker', 'ps', '--filter', 'network=' + project,
                        '--format', '{{.Names}} {{.Image}} {{.Ports}}']).splitlines()
    record('All published container ports are loopback-only',
           bool(services) and all('0.0.0.0:' not in s and '[::]:' not in s for s in services))
    # GitHub masks are an additional defense, not an artifact redaction strategy.
    for value in (data['service'], data['anon']):
        print('::add-mask::' + value, flush=True)
    record('PG17 and empty application DB',
           sql(data, "select current_setting('server_version_num')::int / 10000=17 "
               "and to_regclass('public.shop_products') is null and (select count(*)=0 from auth.users)") == 't')
    # These existing catalog relations predate this PR. Explicit grants model
    # their deployed access contract, not blanket default privileges for new tables.
    for name in MIGRATIONS[:2]:
        sql(data, (ROOT/'supabase'/'migrations'/name).read_text(encoding='utf-8'))
    sql(data, "revoke all on public.shop_products, public.shop_purchases, public.shop_download_events "
        "from anon, authenticated; grant select on public.shop_products to anon, authenticated; "
        "grant select on public.shop_purchases, public.shop_download_events to authenticated; "
        "grant all on public.shop_products, public.shop_purchases, public.shop_download_events to service_role;")
    # Deliberately mismatch the verified package hash when applying the feature.
    sql(data, "update public.shop_products set is_active=true, version='auth-test-v1', "
        "name_ja='HexCiv (Windows版)', stripe_price_id='price_isolated_never_checkout', "
        "sha256=repeat('0',64) where id='hexciv-win64';")
    for name in MIGRATIONS[2:]:
        sql(data, (ROOT/'supabase'/'migrations'/name).read_text(encoding='utf-8'))
    record('Package SHA mismatch never seeds a public release',
           sql(data, 'select count(*) from public.shop_product_releases') == '0')
    sql(data, "insert into public.shop_products(id,name_ja,price_jpy,storage_path,version,is_active) "
        "values('other','Other synthetic product',500,'not-distributed.zip','other-v2',true); "
        "insert into public.shop_product_releases(product_id,release_key,version,title_ja,notes_ja,is_published,published_at) "
        "values('hexciv-win64','auth-test','auth-test-v1','隔離検証用の更新情報','実販売ではない検証用データ',true,null),"
        "('hexciv-win64','draft','draft','Draft','Not public',false,null),"
        "('hexciv-win64','future','future','Future','Not yet public',true,now()+interval '1 year'); "
        "notify pgrst, 'reload schema';")
    ready = False
    for _ in range(30):
        status_code, _ = request(data, '/rest/v1/shop_product_releases?select=id')
        if status_code == 200:
            ready = True
            break
        time.sleep(1)
    record('PostgREST schema cache is ready', ready)
    users = {}
    for name in ('a', 'b', 'c', 'd'):
        email, password = f'hexciv-{name}@example.test', 'T7!' + secrets.token_hex(18)
        print('::add-mask::' + password, flush=True)
        user = ok(data, '/auth/v1/admin/users', 'POST',
                  {'email': email, 'password': password, 'email_confirm': True}, admin=True)
        users[name] = {'email': email, 'password': password, 'id': user['id']}
        if name != 'b':
            ok(data, '/rest/v1/shop_purchases', 'POST',
               {'user_id': user['id'], 'product_id': PRODUCT, 'amount_jpy': 500, 'status': 'paid'}, admin=True)
    data['users'] = users
    save_json(work/'state.json', data, private=True)
    # The build receives ONLY a public/anon key; no service key or user tokens.
    save_json(work/'web-defines.json', {'ENVIRONMENT': 'isolated-auth-test', 'SUPABASE_URL': API,
                                      'SUPABASE_PUBLISHABLE_KEY': data['anon']}, private=True)
    metadata = {'cli': CLI_VERSION, 'project': project, 'api_origin': API, 'app_origin': APP,
                'source_sha': command(['git', 'rev-parse', 'HEAD']).strip(),
                'migration_sha256': {n: hashlib.sha256((ROOT/'supabase'/'migrations'/n).read_bytes()).hexdigest()
                                     for n in MIGRATIONS},
                'services': services,
                'postgres_version': sql(data, 'show server_version'),
                'synthetic_only': True, 'hosted_projects_accessed': False}
    metadata['image_digests'] = command(['docker', 'images', '--digests', '--format',
                                        '{{.Repository}}:{{.Tag}} {{.Digest}}']).splitlines()
    save_json(EVIDENCE/'environment.json', metadata)
    print('ISOLATED AUTH READY', flush=True)


def api_tests():
    _, data = state()
    before_users = len(ok(data, '/auth/v1/admin/users', admin=True)['users'])
    signup_status, _ = request(data, '/auth/v1/signup', 'POST',
                               {'email': 'no-signup@example.test', 'password': 'NotARealUser123!'})
    record('Public signup remains disabled', 400 <= signup_status < 500 and before_users == 4 and
           len(ok(data, '/auth/v1/admin/users', admin=True)['users']) == before_users)
    tokens = {}
    for name, user in data['users'].items():
        session = ok(data, '/auth/v1/token?grant_type=password', 'POST',
                     {'email': user['email'], 'password': user['password']})
        token = session['access_token']
        for value in (token, session['refresh_token']):
            print('::add-mask::' + value, flush=True)
        claims = json.loads(base64.urlsafe_b64decode(token.split('.')[1] + '==='))
        record('Real Auth session ' + name,
               claims['sub'] == user['id'] and claims['role'] == 'authenticated'
               and bool(claims.get('session_id')) and session['user']['id'] == user['id'])
        record('Auth validates user ' + name,
               ok(data, '/auth/v1/user', token=token)['id'] == user['id'])
        tokens[name] = token
    a, b, c, d = [tokens[n] for n in 'abcd']
    record('Only public, nonfuture releases',
           [r['release_key'] for r in ok(data, '/rest/v1/shop_product_releases?select=release_key')] == ['auth-test'])
    def own(token, product=PRODUCT):
        return rpc(data, 'get_my_shop_product_review', {'p_product_id': product}, token)
    def reviews():
        return rpc(data, 'get_shop_product_reviews', {'p_product_id': PRODUCT})
    def save(token, rating=5, body='隔離API検証', product=PRODUCT):
        return rpc(data, 'save_shop_product_review',
                   {'p_product_id': product, 'p_rating': rating, 'p_body': body}, token)
    save_path = '/rest/v1/rpc/save_shop_product_review'
    params = {'p_product_id': PRODUCT, 'p_rating': 5, 'p_body': 'rejected'}
    deny(data, 'Guest cannot post', save_path, 'POST', params)
    deny(data, 'Nonbuyer cannot post', save_path, 'POST', params, b)
    for token in (None, a, b):
        deny(data, 'Private ownership schema not exposed ' + ('guest' if token is None else str(token == a)),
             '/rest/v1/owners?select=*', 'GET', token=token, headers={'Accept-Profile': 'shop_review_private'})
    for rating, body in ((0, ''), (6, ''), (5, '字' * 2001)):
        deny(data, 'Invalid review rejected ' + str(rating) + '/' + str(len(body)), save_path,
             'POST', {**params, 'p_rating': rating, 'p_body': body}, a)
    save(a, 5, ' 最初の口コミ ')
    ar = own(a)['review']
    record('Other purchaser cannot read author ownership through own-review RPC', own(c)['review'] is None)
    record('Review lists do not mix products',
           rpc(data, 'get_shop_product_reviews', {'p_product_id': 'other'})['count'] == 0)
    record('Server trims body and stamps catalog version',
           ar['body'] == '最初の口コミ' and ar['posted_version'] == 'auth-test-v1')
    save(a, 3, '編集済み')
    record('RPC upsert is one review with updated aggregate',
           reviews()['count'] == 1 and reviews()['average'] == 3)
    path = '/rest/v1/shop_product_reviews?id=eq.' + ar['id']
    returning = {'Prefer': 'return=representation'}
    for method, body in [('PATCH', {'rating': 1}), ('DELETE', None)]:
        deny(data, 'Other buyer cannot ' + method, path, method, body, c, returning, allow_noop=True)
    for column, value in [('posted_version', 'forged'), ('is_visible', False), ('product_id', 'other'),
                          ('created_at', '2000-01-01T00:00:00Z'), ('updated_at', '2000-01-01T00:00:00Z')]:
        deny(data, 'Protected column ' + column, path, 'PATCH', {column: value}, a, returning)
    for payload in ({'rating': 6}, {'body': '字' * 2001}):
        deny(data, 'Direct REST validates ' + next(iter(payload)), path, 'PATCH', payload, a, returning)
    ok(data, path, 'PATCH', {'rating': 4, 'body': 'REST edit'}, token=a, headers=returning)
    record('Own direct REST edit succeeds', own(a)['review']['rating'] == 4)
    ok(data, path, 'DELETE', token=a, headers=returning)
    inserted = ok(data, '/rest/v1/shop_product_reviews', 'POST',
                  {'id': ar['id'], 'product_id': PRODUCT, 'rating': 4, 'body': 'REST repost'}, token=a, headers=returning)
    record('Own direct REST insert after delete succeeds', len(inserted) == 1)
    deny(data, 'Direct duplicate rejected', '/rest/v1/shop_product_reviews', 'POST',
         {'id': ar['id'], 'product_id': PRODUCT, 'rating': 4}, a)
    ok(data, path, 'DELETE', token=a, headers=returning)
    deny(data, 'Forged product/owner mapping rejected', '/rest/v1/shop_product_reviews', 'POST',
         {'id': ar['id'], 'product_id': 'other', 'rating': 4}, a)
    save(a, 4, 'RPC repost')
    before_moderation = own(a)['review']
    ok(data, path, 'PATCH', {'is_visible': False}, admin=True)
    record('Hidden review excluded from public counts', reviews()['count'] == 0 and reviews()['items'] == [])
    record('Moderation does not forge version/date',
           own(a)['review']['updated_at'] == before_moderation['updated_at'])
    save(a, 2, 'Hidden edit')
    record('Author edit does not republish', not own(a)['review']['is_visible'] and reviews()['count'] == 0)
    ok(data, path, 'DELETE', token=a, headers=returning)
    save(d, 5, 'Refunded review')
    dr = own(d)['review']
    ok(data, '/rest/v1/shop_purchases?user_id=eq.' + data['users']['d']['id'],
       'PATCH', {'status': 'refunded'}, admin=True)
    record('Refund revokes edit entitlement', not own(d)['can_review'] and own(d)['review']['id'] == dr['id'])
    deny(data, 'Refunded RPC edit rejected', save_path, 'POST', params, d)
    dp = '/rest/v1/shop_product_reviews?id=eq.' + dr['id']
    deny(data, 'Refunded REST edit rejected', dp, 'PATCH', {'rating': 1}, d, returning, allow_noop=True)
    removed = ok(data, dp, 'DELETE', token=d, headers=returning)
    record('Refunded buyer can delete own content', len(removed) == 1 and reviews()['count'] == 0)
    deny(data, 'Refunded new post rejected', save_path, 'POST', params, d)
    for token, label in ((None, 'guest'), (a, 'buyer')):
        deny(data, label + ' cannot invent purchase', '/rest/v1/shop_purchases', 'POST',
             {'user_id': data['users']['b']['id'], 'product_id': PRODUCT, 'amount_jpy': 500, 'status': 'paid'}, token)
        deny(data, label + ' cannot publish release', '/rest/v1/shop_product_releases', 'POST',
             {'product_id': PRODUCT, 'release_key': 'forged', 'version': 'bad', 'title_ja': 'bad', 'notes_ja': 'bad'}, token)
        deny(data, label + ' cannot read attribution', '/rest/v1/shop_post_funnel_events', 'GET', token=token)
    event = dict(visitor_id=data['users']['a']['id'], product_id=PRODUCT, source='isolated',
                 campaign='real-auth-test', content_id='test-only', stage='product_view')
    for token in (None, a):
        deny(data, 'Client cannot insert attribution ' + str(token is None),
             '/rest/v1/shop_post_funnel_events', 'POST', event, token)
    for stage in ('product_view', 'purchase_click', 'checkout_redirect', 'purchase_complete'):
        for _ in range(2):
            ok(data, '/rest/v1/shop_post_funnel_events', 'POST', {**event, 'stage': stage}, admin=True,
               headers={'Prefer': 'resolution=ignore-duplicates'})
    record('Server-only attribution four stages deduplicate',
           len(ok(data, '/rest/v1/shop_post_funnel_events', admin=True)) == 4)
    # These synthetic server writes are not a real payment/webhook test.
    # Confirm JWT forgery is rejected by the gateway, not just by the UI.
    bad = a[:-8] + 'invalid0'
    deny(data, 'Forged JWT rejected', save_path, 'POST', params, bad)
    # Leave the four test users and an empty review list for real browser work.
    record('Browser starts with zero reviews', reviews()['count'] == 0)
    print('REAL AUTH API CONTRACT OK', flush=True)


def stop():
    project, work = runtime()
    if (work/'supabase'/'config.toml').exists():
        command(['supabase', 'stop', '--workdir', str(work), '--project-id', project], timeout=180)
        command(['docker', 'network', 'rm', project])
    print('Owned isolated stack stopped; no hosted environment changed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['prepare', 'api', 'stop'])
    args = parser.parse_args()
    completed = False
    try:
        {'prepare': prepare, 'api': api_tests, 'stop': stop}[args.mode]()
        completed = True
    finally:
        if args.mode in ('prepare', 'api'):
            save_json(EVIDENCE / (args.mode + '-checks.json'),
                      {'checks': checks, 'completed': completed,
                       'all_passed': completed and all(c['passed'] for c in checks),
                       'completed_at': datetime.now(timezone.utc).isoformat()})
