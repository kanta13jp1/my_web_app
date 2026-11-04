import json,os,sys,urllib.request
from pathlib import Path
from datetime import datetime,timezone
request=urllib.request.Request('https://my-web-app-b67f4.web.app/version.json?restart='+str(__import__('time').time_ns()),headers={'Cache-Control':'no-cache'})
with urllib.request.urlopen(request,timeout=25) as response:value=json.load(response)
assert value['commit']==os.environ['EXPECTED_PRODUCTION_SHA'],value
out=Path('echo-pump-public');out.mkdir(exist_ok=True)
(out/('restart-'+sys.argv[1]+'.json')).write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'version':value},indent=2))
