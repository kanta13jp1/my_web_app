import hashlib,json,subprocess
from pathlib import Path
r=json.loads(Path('scripts/echo_pump_release/SOURCE_SELECTION.json').read_text())
expected=set(r['selected_files'])|{'.github/workflows/cloud-development.yml','scripts/echo_pump_release/SOURCE_SELECTION.json','scripts/echo_pump_release/verify_pump_scope.py','scripts/echo_pump_release/public_pump.mjs','scripts/echo_pump_release/preserve_live_labs.py','scripts/echo_pump_release/test_preserve_live_labs.py'}
actual=set(subprocess.check_output(['git','diff','--name-only',r['base'],'HEAD'],text=True).splitlines())
assert actual<=expected,sorted(actual-expected)
for path,digest in r['runtime_sha256'].items():
 assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest,path
print('Approved pump runtime hashes match; no unrelated source changes')
