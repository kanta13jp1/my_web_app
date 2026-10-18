import test from 'node:test';
import assert from 'node:assert/strict';
import { changedSource, decodeDaemonLine, launchArgs, reloadRequest, measure, semanticVolume, allowedFontTunnel } from './measure_flutter_dev_loop.mjs';

test('external tunnels permit only the exact font hosts and TLS port', () => {
  assert.ok(allowedFontTunnel('fonts.gstatic.com:443'));
  assert.ok(allowedFontTunnel('fonts.googleapis.com:443'));
  for (const value of ['fonts.gstatic.com:80', 'fonts.gstatic.com.evil:443', 'project.supabase.co:443', 'example.com:443', undefined]) {
    assert.equal(allowedFontTunnel(value), false);
  }
});

test('Flutter normalized slider position does not hide a changed application value', () => {
  const before = { now: '1', text: 'BGM・SEの音量 50パーセント' };
  const after = { now: '1', text: 'BGM・SEの音量 30パーセント' };
  assert.notEqual(semanticVolume(before), semanticVolume(after));
  assert.equal(semanticVolume(after), after.text);
  assert.throws(() => semanticVolume({ now: '1', text: null }));
});

test('daemon messages distinguish protocol replies from ordinary output', () => {
  assert.deepEqual(decodeDaemonLine('Compiling 123 modules...'), []);
  assert.deepEqual(decodeDaemonLine('{"id":1}'), []);
  assert.deepEqual(decodeDaemonLine('[{"id":1,"result":{"code":0}}]'), [{ id: 1, result: { code: 0 } }]);
});
test('reload requests explicitly preserve the running isolate', () => {
  assert.throws(() => reloadRequest('', 1));
  const value = reloadRequest('started-app', 4);
  assert.equal(value.method, 'app.restart'); assert.equal(value.params.fullRestart, false);
  assert.equal(value.params.pause, false); assert.equal(value.id, 4);
});
test('only the unique shared UI string is changed', () => {
  const original = "before 'BGM・SE / 音量 70%' after";
  assert.equal(changedSource(original, 2), "before 'BGM・SE 計測2 / 音量 70%' after");
  assert.throws(() => changedSource('missing', 1));
  assert.throws(() => changedSource(original + original, 1));
});
test('entry conditions match except for target and initial route', () => {
  const a = launchArgs('normal', 1234); const b = launchArgs('isolated', 1234);
  const shared = args => args.filter(a => !a.startsWith('--target=') && !a.startsWith('--web-launch-url='));
  assert.deepEqual(shared(a), shared(b));
  assert.ok(a.includes('--target=lib/main.dart'));
  assert.ok(b.includes('--target=test/fixtures/echo_pump_app.dart'));
  assert.ok(a.includes('--web-launch-url=http://localhost:7359/echo-pump'));
  assert.ok(a.includes('--dart-define=SUPABASE_URL=http://127.0.0.1:1234'));
  assert.ok(a.includes('--no-web-resources-cdn'));
  assert.ok(a.includes('--web-browser-flag=--proxy-server=http://127.0.0.1:1234'));
  assert.ok(!a.some(v => v.includes('host-resolver-rules')));
  // Flutter's multi-option parser splits commas into extra Chrome arguments.
  assert.ok(a.filter(v => v.startsWith('--web-browser-flag=')).every(v => !v.includes(',')));
  assert.throws(() => launchArgs('unknown', 1));
});
test('the benchmark refuses local execution', async () => {
  if (process.env.GITHUB_ACTIONS !== 'true') await assert.rejects(measure('normal'), /isolated Linux/);
});
