"""Approved PR5861: clone live Hosting and change only the duplicate font preload."""
import gzip,hashlib,json,os,re,sys,time,urllib.request
from pathlib import Path
from google.oauth2.service_account import Credentials
from google.auth.transport.requests import AuthorizedSession
SITE='my-web-app-b67f4';API='https://firebasehosting.googleapis.com/v1beta1/'
OUT=Path('production-transfer');OUT.mkdir(exist_ok=True)
session=None

def call(method,path,body=None):
 response=session.request(method,API+path,json=body,timeout=40)
 if not response.ok:raise RuntimeError('Hosting '+method+' failed HTTP '+str(response.status_code))
 return response.json() if response.content else {}
def live():return call('GET',f'sites/{SITE}/channels/live')['release']['version']['name']
def files(version):
 rows={};token=''
 while True:
  result=call('GET',version+'/files?pageSize=1000'+('&pageToken='+token if token else ''))
  for row in result.get('files',[]):
   assert row['path'] not in rows;rows[row['path']]=row['hash']
  token=result.get('nextPageToken','')
  if not token:return rows

def preflight():
 version=live();meta=call('GET',version);listing=files(version)
 assert '/index.html' in listing and '/main.dart.js' in listing and len(listing)>100
 request=urllib.request.Request(f'https://{SITE}.web.app/index.html?pr5861='+os.environ['GITHUB_RUN_ID'],headers={'Cache-Control':'no-cache','Accept-Encoding':'identity'})
 with urllib.request.urlopen(request,timeout=30) as response:original=response.read()
 html=original.decode();pattern=r'<link\b[^>]*rel="preload"[^>]*href="assets/web/assets/fonts/NotoSansJP-Regular\.ttf"[^>]*>\s*'
 assert len(re.findall(pattern,html))==1,'Expected exactly one approved font preload'
 updated=re.sub(pattern,'',html).encode();assert b'flutter_bootstrap.js' in updated
 with urllib.request.urlopen(f'https://{SITE}.web.app/version.json?pr5861='+os.environ['GITHUB_RUN_ID'],timeout=30) as response:app=json.load(response)
 assert live()==version,'Live changed during preflight'
 (OUT/'index.html').write_bytes(updated)
 (OUT/'checkpoint.json').write_text(json.dumps({'before_app_version':{k:app.get(k) for k in ['version','buildNumber','commit']},'before_version':version,'files':listing,'config':meta.get('config',{}),'before_index_sha256':hashlib.sha256(original).hexdigest(),'after_index_sha256':hashlib.sha256(updated).hexdigest()},indent=2))
 print('Preflight: '+str(len(listing))+' live files; exactly one approved HTML tag will be removed')

def deploy():
 d=json.loads((OUT/'checkpoint.json').read_text());before=d['before_version'];assert live()==before,'Concurrent live release detected; stop'
 operation=call('POST',f'sites/{SITE}/versions:clone',{'sourceVersion':before,'finalize':False})
 for _ in range(60):
  if operation.get('done'):break
  time.sleep(2);operation=call('GET',operation['name'])
 assert operation.get('done') and not operation.get('error'),'Clone did not complete cleanly'
 version=operation['response']['name'];assert version.startswith(f'sites/{SITE}/versions/')
 (OUT/'staged-version.json').write_text(json.dumps({'before_version':before,'staged_version':version}))
 assert files(version)==d['files'],'Clone file map differs from live'
 config=call('GET',version).get('config',{})
 assert config==d['config'],'Clone serving config differs; stop before upload'
 content=(OUT/'index.html').read_bytes();compressed=gzip.compress(content,compresslevel=9,mtime=0);digest=hashlib.sha256(compressed).hexdigest()
 result=call('POST',version+':populateFiles',{'files':{'/index.html':digest}})
 required=result.get('uploadRequiredHashes',[]);assert set(required)<= {digest}
 for value in required:
  url=result['uploadUrl']+'/'+value;assert url.startswith('https://upload-firebasehosting.googleapis.com/upload/sites/'+SITE+'/')
  response=session.post(url,data=compressed,headers={'Content-Type':'application/octet-stream'},timeout=40)
  assert response.ok,'File upload failed HTTP '+str(response.status_code)
 expected={**d['files'],'/index.html':digest};assert files(version)==expected,'Unexpected file delta before finalize'
 call('PATCH',version+'?updateMask=status',{'status':'FINALIZED'})
 assert files(version)==expected and call('GET',version).get('config',{})==d['config']
 assert live()==before,'Another live release happened; staged version will not be released'
 # Exactly one publish request: on an uncertain response, inspect live state before any retry.
 result=call('POST',f'sites/{SITE}/releases?versionName='+version,{'message':'Approved PR5861: remove duplicate Japanese-font preload only'})
 report={'before_version':before,'version':version,'release':result['name'],'file_count':len(expected),'changed_files':['/index.html'],'other_files_hash_identical':True,'serving_config_identical':True,'index_sha256':d['after_index_sha256'],'merge_commit':os.environ['APPROVED_MERGE_SHA'],'preserved_app_version':d.get('before_app_version',{})}
 (OUT/'release.json').write_text(json.dumps(report,indent=2))
 assert live()==version,'Published version not live'
 for _ in range(12):
  request=urllib.request.Request(f'https://{SITE}.web.app/index.html?verify5861='+os.environ['GITHUB_RUN_ID'],headers={'Cache-Control':'no-cache','Accept-Encoding':'identity'})
  with urllib.request.urlopen(request,timeout=30) as response:public=response.read()
  if hashlib.sha256(public).hexdigest()==d['after_index_sha256']:break
  time.sleep(5)
 assert public==content,'Public HTML has not converged to expected content'
 assert files(version)==expected,'Final file map changed'
 print('Published and verified index-only release; every other file and serving config preserved')

if __name__=='__main__':
 account=json.loads(os.environ.pop('FIREBASE_ACCOUNT_JSON'));assert account['project_id']==SITE
 session=AuthorizedSession(Credentials.from_service_account_info(account,scopes=['https://www.googleapis.com/auth/firebase.hosting']));del account
 {'preflight':preflight,'deploy':deploy}[sys.argv[1]]()
