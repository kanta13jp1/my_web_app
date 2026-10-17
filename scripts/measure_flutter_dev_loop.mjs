import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { createInterface } from 'node:readline';
import { EventEmitter } from 'node:events';
import { promises as fs, createWriteStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';

export function decodeDaemonLine(line) {
  try { const value = JSON.parse(line); return Array.isArray(value) ? value : []; }
  catch { return []; }
}

export function reloadRequest(appId, id) {
  if (!appId) throw new Error('A started app is required');
  return { id, method: 'app.restart', params: { appId, fullRestart: false,
    pause: false, debounce: false, reason: 'manual' } };
}

export function changedSource(original, sample) {
  const token = 'BGM・SE / 音量 ';
  if (original.split(token).length !== 2) throw new Error('Expected one shared UI marker');
  return original.replace(token, `BGM・SE 計測${sample} / 音量 `);
}

export function launchArgs(entry, mockPort) {
  if (!['normal', 'isolated'].includes(entry)) throw new Error('Unknown entry');
  return ['run', '--machine', '--debug', '-d', 'chrome', '--web-port=7359',
    '--web-browser-debug-port=9222', '--web-run-headless',
    '--web-browser-flag=--headless=new', '--web-browser-flag=--no-sandbox',
    '--web-browser-flag=--disable-dev-shm-usage',
    '--web-browser-flag=--host-resolver-rules=MAP * 127.0.0.1',
    '--no-web-resources-cdn', '--web-experimental-hot-reload',
    `--web-launch-url=http://localhost:7359/${entry === 'normal' ? 'echo-pump' : ''}`,
    '--target=' + (entry === 'normal' ? 'lib/main.dart' : 'test/fixtures/echo_pump_app.dart'),
    '--dart-define=ENVIRONMENT=development',
    `--dart-define=SUPABASE_URL=http://127.0.0.1:${mockPort}`,
    '--dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_local_benchmark_only'];
}

function waitForMessage(emitter, history, predicate, milliseconds, label) {
  const existing = history.find(predicate);
  if (existing) return Promise.resolve(existing);
  return new Promise((resolve, reject) => {
    const finish = (error, value) => { clearTimeout(timer); emitter.off('message', onMessage);
      emitter.off('exit', onExit); error ? reject(error) : resolve(value); };
    const onMessage = value => { if (predicate(value)) finish(null, value); };
    const onExit = () => finish(new Error(`Flutter exited while waiting for ${label}`));
    const timer = setTimeout(() => finish(new Error(`Timeout: ${label}`)), milliseconds);
    emitter.on('message', onMessage); emitter.on('exit', onExit);
  });
}

const digest = value => createHash('sha256').update(value).digest('hex');
const stopped = runner => !runner || !runner.pid || runner.exitCode !== null || runner.signalCode !== null;

export async function measure(entry) {
  if (process.platform !== 'linux' || process.env.GITHUB_ACTIONS !== 'true') {
    throw new Error('This benchmark runs only on an isolated Linux GitHub runner');
  }
  launchArgs(entry, 0); // Reject an invalid entry before opening any resources.
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const output = path.join(root, '.ci-logs/flutter-dev-loop');
  await fs.mkdir(output, { recursive: true });
  const sourcePath = path.join(root, 'lib/widgets/echo_pump_audio_controls.dart');
  const original = await fs.readFile(sourcePath, 'utf8');
  const report = { schema: 1, entry, head_sha: process.env.GITHUB_SHA, started_at: new Date().toISOString(),
    source_before: digest(original), result: 'failure', hot_reload: [], mock_requests: [],
    conditions: { cold_start_samples: 1, reload_samples: 3, mode: 'debug', browser: 'headless Chrome',
      viewport: '1280x900', backend: 'loopback synthetic only', external_dns: 'mapped to loopback',
      setup_and_queue_excluded: true } };
  const server = createServer((req, res) => {
    report.mock_requests.push({ method: req.method, path: req.url });
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' });
    res.end(JSON.stringify(req.url?.startsWith('/rest/v1/') ? [] : {}));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const args = launchArgs(entry, server.address().port);
  const emitter = new EventEmitter(); const history = []; let runner; let browser; let appId; let page;
  let phase = 'startup'; let nextId = 1;
  const log = createWriteStream(path.join(output, 'flutter.log'));
  const start = performance.now();
  async function request(message, timeout = 90000) {
    const response = waitForMessage(emitter, history, value => value.id === message.id,
      timeout, message.method);
    runner.stdin.write(JSON.stringify([message]) + '\n');
    const result = await response;
    if (result.error) throw new Error(JSON.stringify(result.error));
    return result.result;
  }
  try {
    report.command = ['flutter', ...args];
    runner = spawn('flutter', args, { cwd: root, detached: true, stdio: ['pipe', 'pipe', 'pipe'] });
    runner.on('error', error => { report.process_error = error.message; emitter.emit('exit'); });
    runner.on('exit', () => emitter.emit('exit'));
    runner.stdin.on('error', error => { report.stdin_error = error.message; emitter.emit('exit'); });
    const lines = createInterface({ input: runner.stdout });
    lines.on('line', line => {
      log.write(line + '\n');
      for (const value of decodeDaemonLine(line)) {
        history.push(value);
        if (value.event === 'app.start') appId = value.params?.appId;
        emitter.emit('message', value);
      }
    });
    runner.stderr.on('data', data => log.write(data));
    await waitForMessage(emitter, history, value => value.event === 'app.started', 240000, 'app.started');
    report.machine_ready_seconds = (performance.now() - start) / 1000;
    const { chromium, expect } = await import('@playwright/test');
    browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
    report.chrome_version = browser.version();
    const context = browser.contexts()[0];
    page = context.pages().find(p => p.url().includes('7359')) || context.pages()[0];
    if (!page) throw new Error('Flutter browser page missing');
    await page.setViewportSize({ width: 1280, height: 900 });
    report.page_errors = []; page.on('pageerror', error => report.page_errors.push(error.message));
    await page.getByRole('button', { name: '音をON', exact: true }).waitFor({ state: 'visible', timeout: 120000 });
    report.page_url = page.url();
    const slider = page.getByRole('slider').first();
    const initialVolume = await slider.getAttribute('aria-valuenow');
    if (initialVolume === null) throw new Error('Slider has no semantic value');
    await slider.press('ArrowLeft');
    await expect.poll(() => slider.getAttribute('aria-valuenow')).not.toBe(initialVolume);
    const retainedVolume = await slider.getAttribute('aria-valuenow');
    report.initial_volume = initialVolume; report.adjusted_volume = retainedVolume;
    report.interactive_ready_seconds = (performance.now() - start) / 1000;
    await page.screenshot({ path: path.join(output, 'startup.png') });
    let navigations = 0; page.on('framenavigated', frame => { if (frame === page.mainFrame()) navigations++; });
    for (let sample = 1; sample <= 3; sample++) {
      phase = `reload-${sample}`;
      const sampleStart = performance.now();
      await fs.writeFile(sourcePath, changedSource(original, sample));
      const message = reloadRequest(appId, nextId++);
      const reply = await request(message);
      const rpcSeconds = (performance.now() - sampleStart) / 1000;
      if (reply?.code !== 0) throw new Error('Hot Reload failed: ' + JSON.stringify(reply));
      await page.getByText(`BGM・SE 計測${sample} / 音量`, { exact: false }).first()
        .waitFor({ state: 'visible', timeout: 30000 });
      const seconds = (performance.now() - sampleStart) / 1000;
      const volume = await slider.getAttribute('aria-valuenow');
      if (volume !== retainedVolume || navigations !== 0) throw new Error('Reload did not preserve app state');
      report.hot_reload.push({ sample, seconds, rpc_seconds: rpcSeconds, reply,
        full_restart: message.params.fullRestart, state_preserved: true, navigations });
      await page.screenshot({ path: path.join(output, `reload-${sample}.png`) });
    }
    report.result = 'success';
  } catch (error) {
    report.failure = { phase, message: error.stack || String(error) };
    console.error(report.failure.message);
    if (page) {
      await page.screenshot({ path: path.join(output, 'failure.png') }).catch(() => {});
      await fs.writeFile(path.join(output, 'failure.html'), await page.content().catch(() => '')).catch(() => {});
    }
    process.exitCode = 1;
  } finally {
    try {
      if (!stopped(runner) && appId) {
        await request({ id: nextId++, method: 'app.stop', params: { appId } }, 5000).catch(() => {});
      }
      if (browser) await browser.close().catch(() => {});
      if (!stopped(runner)) {
        process.kill(-runner.pid, 'SIGTERM');
        await new Promise(resolve => { const timer = setTimeout(resolve, 3000);
          runner.once('exit', () => { clearTimeout(timer); resolve(); }); });
        if (!stopped(runner)) {
          process.kill(-runner.pid, 'SIGKILL');
          await new Promise(resolve => { const timer = setTimeout(resolve, 3000);
            runner.once('exit', () => { clearTimeout(timer); resolve(); }); });
        }
      }
    } catch (error) { report.cleanup_error = String(error); }
    finally {
      await fs.writeFile(sourcePath, original);
      report.source_restored = digest(await fs.readFile(sourcePath)) === report.source_before;
      report.runner_stopped = stopped(runner);
      if (!report.source_restored || !report.runner_stopped) { report.result = 'failure'; process.exitCode = 1; }
      await new Promise(resolve => server.close(resolve));
      log.end();
      await fs.writeFile(path.join(output, 'RESULT.json'), JSON.stringify(report, null, 2));
      console.log(JSON.stringify({ entry, result: report.result, ready: report.interactive_ready_seconds,
        reload_seconds: report.hot_reload.map(r => r.seconds), source_restored: report.source_restored }));
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const index = process.argv.indexOf('--entry');
  await measure(index < 0 ? '' : process.argv[index + 1]);
}
