import hashlib,json,subprocess
from pathlib import Path
r=json.loads(Path('scripts/echo_pump_release/SOURCE_SELECTION.json').read_text())
actual=set(subprocess.check_output(['git','diff','--name-only',r['base'],'HEAD'],text=True).splitlines())
assert actual==set(r['expected_changed_paths']),(actual,set(r['expected_changed_paths']))
for path,blob in r['selected_blobs'].items():
    assert subprocess.check_output(['git','rev-parse','HEAD:'+path],text=True).strip()==blob,path
for path,digest in r['runtime_sha256'].items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,path
print('Exact restart-only paths and blobs verified; all other public source is preserved')
