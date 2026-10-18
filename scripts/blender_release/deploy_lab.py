"""Preserve the current Firebase live file map/config; add only the approved lab.

Default is read-only. No credentials are written to disk or returned as evidence.
"""
import argparse
import gzip
import hashlib
import json
import os
import re
import time
from pathlib import Path

SITE = 'my-web-app-b67f4'
PREFIX = '/labs/blender-valve/'
FILES = {'index.html', 'viewer.js', 'valve.glb', 'valve.blend', 'valve.png', 'THREE-LICENSE.txt'}
API = 'https://firebasehosting.googleapis.com/v1beta1/'

def additions(folder):
    paths = {p.name for p in folder.iterdir() if p.is_file()}
    if paths != FILES:
        raise RuntimeError('Lab file allowlist mismatch')
    files, compressed, details = {}, {}, {}
    for name in sorted(FILES):
        raw = (folder/name).read_bytes()
        if not raw or len(raw) > 5_000_000:
            raise RuntimeError('Unexpected asset size')
        gz = gzip.compress(raw, mtime=0)
        digest = hashlib.sha256(gz).hexdigest()
        files[PREFIX+name] = digest
        compressed[digest] = gz
        details[name] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
    return files, compressed, details

def preserved_map(before, extra):
    if not before or '/index.html' not in before:
        raise RuntimeError('Current live root missing')
    if any(not p.startswith(PREFIX) or p[len(PREFIX):] not in FILES for p in extra):
        raise RuntimeError('Out-of-scope overwrite')
    result = {**before, **extra}
    if any(result[p] != h for p, h in before.items() if not p.startswith(PREFIX)):
        raise RuntimeError('Existing content changed')
    return result

def release_matches(live, created_name, version):
    # Legacy releases.create and channels.get may spell the resource differently.
    return live[1] == version and live[0].rsplit('/',1)[-1] == created_name.rsplit('/',1)[-1]

def run(publish=False):
    import requests
    from google.oauth2.service_account import Credentials
    from google.auth.transport.requests import AuthorizedSession

    account = json.loads(os.environ.pop('FIREBASE_ACCOUNT_JSON'))
    if account.get('project_id') != SITE:
        raise RuntimeError('Service account project mismatch')
    auth = AuthorizedSession(Credentials.from_service_account_info(account,
        scopes=['https://www.googleapis.com/auth/firebase.hosting']))
    del account
    plain = requests.Session()
    evidence = {'source_sha': os.environ['GITHUB_SHA'], 'publish_requested': publish,
                'site': SITE, 'stage': 'reading_live'}
    output = Path('blender-release.json')
    def save():
        output.write_text(json.dumps(evidence, ensure_ascii=False, indent=2))
    def request(method, path, **kw):
        response = auth.request(method, API+path, timeout=60, **kw)
        if not response.ok:
            raise RuntimeError(f'Hosting API {method} failed: HTTP {response.status_code}')
        return response.json()
    def current():
        release = request('GET', f'sites/{SITE}/channels/live')['release']
        return release['name'], release['version']['name']
    def filemap(version):
        result, token = {}, None
        while True:
            params = {'pageSize':1000}
            if token:params['pageToken']=token
            response=request('GET', version+'/files', params=params)
            for f in response.get('files', []):
                if f['path'] in result or f.get('status') != 'ACTIVE' or not re.fullmatch('[0-9a-f]{64}', f['hash']):
                    raise RuntimeError('Invalid or incomplete live file metadata')
                result[f['path']]=f['hash']
            token=response.get('nextPageToken')
            if not token:return result
    try:
        release, version = current()
        before = filemap(version)
        config = request('GET', version).get('config', {})
        extra, blobs, details = additions(Path('web/labs/blender-valve'))
        expected = preserved_map(before, extra)
        root_before = plain.get(f'https://{SITE}.web.app/version.json', timeout=30)
        root_before.raise_for_status()
        evidence.update(before_release=release, before_version=version,
            before_count=len(before), after_count=len(expected), additions=details,
            existing_config_sha256=hashlib.sha256(json.dumps(config,sort_keys=True).encode()).hexdigest(),
            existing_app_version_sha256=hashlib.sha256(root_before.content).hexdigest())
        evidence['stage']='read_only_preflight_passed';save()
        if not publish:return
        if current() != (release,version):raise RuntimeError('Live changed during preparation; stop')
        new = request('POST',f'sites/{SITE}/versions',json={'config':config})['name']
        evidence.update(new_version=new,stage='uploading');save()
        entries = list(expected.items())
        for start in range(0,len(entries),1000):
            response = request('POST',new+':populateFiles',json={'files':dict(entries[start:start+1000])})
            for digest in response.get('uploadRequiredHashes',[]):
                if digest not in blobs:raise RuntimeError('An existing live blob is unavailable; stop')
                url=response['uploadUrl']+'/'+digest
                if not url.startswith('https://upload-firebasehosting.googleapis.com/upload/'):
                    raise RuntimeError('Unexpected upload destination')
                upload=auth.post(url,data=blobs[digest],headers={'Content-Type':'application/octet-stream'},timeout=60)
                if not upload.ok:raise RuntimeError(f'Asset upload failed: HTTP {upload.status_code}')
        finalized=request('PATCH',new,params={'update_mask':'status'},json={'status':'FINALIZED'})
        if finalized.get('status')!='FINALIZED' or finalized.get('config',{})!=config:
            raise RuntimeError('Finalized config mismatch')
        if filemap(new)!=expected:raise RuntimeError('Finalized file map mismatch')
        evidence['stage']='finalized_and_verified';save()
        if current() != (release,version):raise RuntimeError('Live changed before release; stop')
        evidence['stage']='release_submission_started';save()
        # No automatic retry of this non-idempotent operation. Inspect live on uncertainty.
        created=request('POST',f'sites/{SITE}/releases',params={'versionName':new},
                        json={'message':'Approved Blender valve lab static addition'})
        evidence.update(release=created['name'],stage='release_returned');save()
        if not release_matches(current(),created['name'],new):
            raise RuntimeError('Live does not match returned release')
        for name, metadata in details.items():
            response=plain.get(f'https://{SITE}.web.app{PREFIX}{name}?verify={os.environ["GITHUB_RUN_ID"]}',timeout=30)
            response.raise_for_status()
            if hashlib.sha256(response.content).hexdigest()!=metadata['sha256']:
                raise RuntimeError('Public asset content mismatch: '+name)
        root_after=plain.get(f'https://{SITE}.web.app/version.json?verify={os.environ["GITHUB_RUN_ID"]}',timeout=30)
        root_after.raise_for_status()
        if root_after.content!=root_before.content:raise RuntimeError('Existing application version changed')
        evidence.update(stage='released_and_public_bytes_verified',preserved_existing_files=True,
                        preserved_existing_config=True,preserved_app_version=True)
        save()
    except Exception as exc:
        evidence['error_type']=type(exc).__name__
        # Do not dump exception objects or authenticated requests.
        save()
        raise

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--publish',action='store_true')
    run(parser.parse_args().publish)
