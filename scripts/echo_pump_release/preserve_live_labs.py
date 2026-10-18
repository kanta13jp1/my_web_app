"""Preserve the six already-public Blender lab files during the approved Web release."""
import argparse,gzip,hashlib,json,os,re,urllib.request
from pathlib import Path
SITE='my-web-app-b67f4'
PREFIX='/labs/blender-valve/'
NAMES={'index.html','viewer.js','valve.glb','valve.blend','valve.png','THREE-LICENSE.txt'}
def validated_files(rows):
    result={}
    for f in rows:
        if not f['path'].startswith(PREFIX):continue
        name=f['path'][len(PREFIX):]
        if name not in NAMES or name in result or f.get('status')!='ACTIVE' or not re.fullmatch('[0-9a-f]{64}',f.get('hash','')):
            raise RuntimeError('Unexpected public lab file metadata')
        result[name]=f['hash']
    if set(result)!=NAMES:raise RuntimeError('Existing public lab file set changed')
    return result
def public(path):
    req=urllib.request.Request('https://'+SITE+'.web.app'+path+'?verify='+os.environ.get('GITHUB_RUN_ID','0'),headers={'Cache-Control':'no-cache'})
    with urllib.request.urlopen(req,timeout=30) as r:return r.read()
def run(mode):
    record=Path('.deploy-logs/preserved-lab.json');record.parent.mkdir(exist_ok=True)
    if mode=='public':
        d=json.loads(record.read_text())
        for n,h in d['raw_hashes'].items():
            if hashlib.sha256(public(PREFIX+n)).hexdigest()!=h:raise RuntimeError('Public lab bytes changed: '+n)
        print('Verified six preserved public lab files');return
    if json.loads(public('/version.json'))['commit']!=os.environ['EXPECTED_PUBLIC_BASE']:
        raise RuntimeError('Public application base changed; stop')
    from google.oauth2.service_account import Credentials
    from google.auth.transport.requests import AuthorizedSession
    account_json=os.environ.pop('FIREBASE_ACCOUNT_JSON',None)
    if account_json is None:account_json=Path(os.environ['GOOGLE_APPLICATION_CREDENTIALS']).read_text()
    account=json.loads(account_json)
    del account_json
    if account.get('project_id')!=SITE:raise RuntimeError('Wrong project')
    auth=AuthorizedSession(Credentials.from_service_account_info(account,scopes=['https://www.googleapis.com/auth/firebase.hosting']))
    def get(path,params=None):
        r=auth.get('https://firebasehosting.googleapis.com/v1beta1/'+path,params=params,timeout=30)
        if not r.ok:raise RuntimeError('Hosting read failed HTTP '+str(r.status_code))
        return r.json()
    live=get(f'sites/{SITE}/channels/live')['release'];version=live['version']['name']
    if mode=='guard':
        if json.loads(record.read_text())['before_version']!=version:raise RuntimeError('Live changed; rebuild selective release')
        print('Verified live version still matches preservation checkpoint');return
    rows=[];token=None
    while True:
        r=get(version+'/files',{'pageSize':1000,**({'pageToken':token} if token else {})});rows+=r.get('files',[]);token=r.get('nextPageToken')
        if not token:break
    selected=validated_files(rows);raw_hashes={}
    root=Path('build/web').resolve()
    missing=[]
    for f in rows:
        p=root/f['path'].lstrip('/')
        if not p.resolve().is_relative_to(root):raise RuntimeError('Unexpected live file path')
        if not f['path'].startswith(PREFIX) and not p.is_file():missing.append(f['path'])
    if missing:raise RuntimeError('Other current public files would be removed; stop: '+repr(missing))
    for name,digest in selected.items():
        data=public(PREFIX+name)
        if not data or len(data)>5_000_000 or hashlib.sha256(gzip.compress(data,mtime=0)).hexdigest()!=digest:
            raise RuntimeError('Public lab bytes do not match Hosting manifest: '+name)
        target=Path('build/web')/PREFIX.lstrip('/')/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        raw_hashes[name]=hashlib.sha256(data).hexdigest()
    if get(f'sites/{SITE}/channels/live')['release']['version']['name']!=version:raise RuntimeError('Live changed during preservation')
    record.write_text(json.dumps({'before_release':live['name'],'before_version':version,'hashes':selected,'raw_hashes':raw_hashes},indent=2)+'\n')
    print('Preserved six verified existing public lab files')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['capture','guard','public']);run(p.parse_args().mode)
