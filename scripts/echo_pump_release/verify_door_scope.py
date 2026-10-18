import hashlib,json,subprocess
from pathlib import Path
r=json.loads(Path('scripts/echo_pump_release/SOURCE_SELECTION.json').read_text())
expected=set(['.github/workflows/echo-pump-prototype.yml', 'lib/pages/echo_pump_game_page.dart', 'lib/services/echo_pump_motion_stub.dart', 'lib/services/echo_pump_motion_web.dart', 'lib/widgets/echo_pump_door_transition.dart', 'scripts/echo_pump_dev_commands.json', 'test/e2e/echo_pump.spec.ts', 'test/pages/echo_pump_game_page_test.dart', '.github/workflows/cloud-development.yml', 'scripts/echo_pump_release/SOURCE_SELECTION.json', 'scripts/echo_pump_release/public_door.mjs', 'scripts/echo_pump_release/verify_door_scope.py'])
actual=set(subprocess.check_output(['git','diff','--name-only',r['base'],'HEAD'],text=True).splitlines())
assert actual<=expected,sorted(actual-expected)
for p,h in r['runtime_sha256'].items():
 assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
print('Approved door runtime matches merged source; unrelated application source unchanged')
