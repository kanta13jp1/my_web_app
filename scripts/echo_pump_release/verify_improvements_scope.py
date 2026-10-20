import hashlib,json,subprocess
from pathlib import Path
r=json.loads(Path('scripts/echo_pump_release/SOURCE_SELECTION.json').read_text())
expected=set(['assets/echo_pump/AUDIO_PROVENANCE.json', 'assets/echo_pump/doorClose.wav', 'assets/echo_pump/doorOpen.wav', 'lib/pages/echo_pump_game_page.dart', 'lib/services/echo_pump_audio.dart', 'lib/widgets/echo_pump_door_transition.dart', 'lib/widgets/echo_pump_guidance.dart', 'lib/widgets/echo_pump_room_stage.dart', 'lib/widgets/echo_pump_visuals.dart', 'scripts/generate_echo_pump_audio.py', 'test/e2e/echo_pump.spec.ts', 'test/e2e/echo_pump_audio.spec.ts', 'test/e2e/echo_pump_room_stage.spec.ts', 'test/services/echo_pump_audio_test.dart', 'test/widgets/echo_pump_room_stage_test.dart', 'test/widgets/echo_pump_visuals_test.dart', '.github/workflows/cloud-development.yml', 'scripts/echo_pump_release/SOURCE_SELECTION.json', 'scripts/echo_pump_release/public_improvements.mjs', 'scripts/echo_pump_release/verify_improvements_scope.py'])
actual=set(subprocess.check_output(['git','diff','--name-only',r['base'],'HEAD'],text=True).splitlines())
assert actual<=expected,sorted(actual-expected)
for p,h in r['runtime_sha256'].items():
 assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
print('Approved PR5874 runtime matches reviewed merged source; unrelated public source unchanged')
