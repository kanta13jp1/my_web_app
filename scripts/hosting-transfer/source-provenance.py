import gzip,hashlib,importlib.util,json,os,time,urllib.request
from pathlib import Path
from google.oauth2.service_account import Credentials
from google.auth.transport.requests import AuthorizedSession
spec=importlib.util.spec_from_file_location('release',Path(__file__).with_name('index-release.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
account=json.loads(os.environ.pop('FIREBASE_ACCOUNT_JSON'));assert account['project_id']==m.SITE;m.session=AuthorizedSession(Credentials.from_service_account_info(account,scopes=['https://www.googleapis.com/auth/firebase.hosting']));del account
expected_live='sites/my-web-app-b67f4/versions/abfb507d7bf00155';old='a2107116e76cc1d9086502a2db1393d7671e78a8';new='0b002a465106a8c25bbf782877721ac59b81324a';index_hash='a5a1335723a9f2dac7592e7b5f5266703ed6bed546a90f574dd9115b6a4fe44d'
def public(path):
 req=urllib.request.Request('https://'+m.SITE+'.web.app'+path+'?source5861='+os.environ['GITHUB_RUN_ID'],headers={'Cache-Control':'no-cache','Accept-Encoding':'identity'})
 with urllib.request.urlopen(req,timeout=30) as r:return r.read()
assert m.live()==expected_live,'Live changed since verified release; stop'
listing=m.files(expected_live);config=m.call('GET',expected_live).get('config',{});assert hashlib.sha256(public('/index.html')).hexdigest()==index_hash
original=public('/version.json');before=json.loads(original);assert before['commit']==old and original.count(old.encode())==1
updated=original.replace(old.encode(),new.encode());after=json.loads(updated);assert {**before,'commit':new}==after
compressed=gzip.compress(updated,compresslevel=9,mtime=0);digest=hashlib.sha256(compressed).hexdigest()
op=m.call('POST',f'sites/{m.SITE}/versions:clone',{'sourceVersion':expected_live,'finalize':False})
for _ in range(60):
 if op.get('done'):break
 time.sleep(2);op=m.call('GET',op['name'])
assert op.get('done') and not op.get('error');version=op['response']['name'];assert m.files(version)==listing and m.call('GET',version).get('config',{})==config
result=m.call('POST',version+':populateFiles',{'files':{'/version.json':digest}})
assert set(result.get('uploadRequiredHashes',[]))<={digest}
for value in result.get('uploadRequiredHashes',[]):
 url=result['uploadUrl']+'/'+value;assert url.startswith('https://upload-firebasehosting.googleapis.com/upload/sites/'+m.SITE+'/')
 response=m.session.post(url,data=compressed,headers={'Content-Type':'application/octet-stream'},timeout=40);assert response.ok
expected={**listing,'/version.json':digest};assert m.files(version)==expected
m.call('PATCH',version+'?updateMask=status',{'status':'FINALIZED'});assert m.files(version)==expected and m.call('GET',version).get('config',{})==config and m.live()==expected_live
release=m.call('POST',f'sites/{m.SITE}/releases?versionName='+version,{'message':'PR5861: preserve index-only source provenance for future selective releases'})
report={'before_version':expected_live,'version':version,'release':release['name'],'changed_files':['/version.json'],'file_count':len(expected),'other_files_hash_identical':True,'serving_config_identical':True,'runtime_source_commit':old,'source_overlay_commit':new,'source_overlay_changed_paths':['web/index.html'],'approved_merge_commit':'5ccd574471baf7aafd8f380b48396b376b426419','app_version':before['version'],'app_build':before['buildNumber'],'index_sha256':index_hash}
Path('production-transfer/metadata-release.json').write_text(json.dumps(report,indent=2))
assert m.live()==version
for _ in range(12):
 observed=json.loads(public('/version.json'))
 if observed==after:break
 time.sleep(5)
assert observed==after and hashlib.sha256(public('/index.html')).hexdigest()==index_hash and m.files(version)==expected
print('Verified source-provenance update only; all HTML, JS, font and other asset hashes unchanged')
