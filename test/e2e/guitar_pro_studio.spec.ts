import { test, expect } from '@playwright/test';

const LAB_PATH = '/labs/guitar-pro-studio/index.html';

const LOCAL_UPLOAD_ALPHATEX = String.raw`\title "Local Private Etude"
\subtitle "Imported From Browser File Picker"
\tempo 108
.
\track "Nylon Study"
\instrument 24
\clef G2
\ts 4 4
0.1.4{ch "Em"} 2.2.4 0.3.4 2.4.4 |
3.5.4{ch "C"} 2.4.4 0.3.4 1.2.4 |
`;

test('renders SMuFL Bravura score + 6-string TAB, handles presets, dark theme, local file validation, and audio engine', async ({
  page,
}, info) => {
  const errors: string[] = [];
  const externalRequests: string[] = [];
  const httpFailures: string[] = [];
  let bravuraLoaded = false;

  page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(`console.error: ${msg.text()}`);
    }
  });
  page.on('request', (req) => {
    const url = req.url();
    if (
      !url.startsWith('http://127.0.0.1:7359/') &&
      !url.startsWith('blob:') &&
      !url.startsWith('data:')
    ) {
      externalRequests.push(url);
    }
  });
  page.on('response', (resp) => {
    const url = resp.url();
    if (url.includes('Bravura.woff2') && resp.status() === 200) {
      bravuraLoaded = true;
    }
    if (resp.status() >= 400) {
      httpFailures.push(`${resp.status()} ${url}`);
    }
  });

  await page.goto(LAB_PATH);
  const isMobile = (page.viewportSize()?.width ?? 1440) < 600;
  const viewport = page.locator('#score-viewport');
  await expect(viewport).toHaveAttribute('data-render-state', 'ready', {
    timeout: 25_000,
  });
  if (isMobile) {
    await viewport.scrollIntoViewIfNeeded();
  }
  await expect(page.locator('#alphaTab-surface svg').first()).toBeVisible();
  await expect(page.locator('#status-message')).toContainText(
    'Midnight Fingerpicking Study',
  );
  expect(bravuraLoaded).toBe(true);
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.waitForTimeout(300);
  await page.screenshot({ path: info.outputPath('01-default-stave-tab-light.png') });

  // Switch to multi-track preset and change track
  await page
    .getByRole('button', { name: 'Sunday Acoustic Duo', exact: true })
    .click();
  await expect(page.locator('#status-message')).toContainText(
    'Sunday Acoustic Duo',
  );
  await expect(viewport).toHaveAttribute('data-render-state', 'ready', {
    timeout: 15_000,
  });
  const trackSelect = page.locator('#track-select');
  await expect(trackSelect.locator('option')).toHaveCount(2);
  await trackSelect.selectOption('1');
  await expect(viewport).toHaveAttribute('data-render-state', 'ready', {
    timeout: 15_000,
  });
  if (isMobile) {
    await viewport.scrollIntoViewIfNeeded();
  }
  await page.waitForTimeout(250);
  await page.screenshot({ path: info.outputPath('02-preset2-multitrack.png') });

  // Switch to TAB-only + Dark paper theme
  await page.locator('#stave-profile').selectOption('tab');
  await expect(viewport).toHaveAttribute('data-render-state', 'ready', {
    timeout: 15_000,
  });
  await page.getByRole('button', { name: 'ダーク譜面', exact: true }).click();
  await expect(viewport).toHaveAttribute('data-render-state', 'ready', {
    timeout: 15_000,
  });
  await expect(viewport).toHaveClass(/sheet-dark/);
  if (isMobile) {
    await viewport.scrollIntoViewIfNeeded();
  }
  await page.waitForTimeout(250);
  await page.screenshot({ path: info.outputPath('03-dark-tab-only.png') });

  // Local upload validation: reject unsupported extension, then accept valid .tex
  const fileInput = page.locator('#score-file-input');
  await fileInput.setInputFiles({
    name: 'invalid.png',
    mimeType: 'image/png',
    buffer: Buffer.from('not-a-score'),
  });
  await expect(page.locator('#error-message')).toBeVisible();

  await fileInput.setInputFiles({
    name: 'local_study.tex',
    mimeType: 'text/plain',
    buffer: Buffer.from(LOCAL_UPLOAD_ALPHATEX, 'utf8'),
  });
  await expect(page.locator('#error-message')).toBeHidden();
  await expect(page.locator('#status-message')).toContainText(
    'Local Private Etude',
  );
  await expect(viewport).toHaveAttribute('data-render-state', 'ready', {
    timeout: 15_000,
  });
  if (isMobile) {
    await viewport.scrollIntoViewIfNeeded();
  }
  await page.waitForTimeout(250);
  await page.screenshot({ path: info.outputPath('04-local-upload-loaded.png') });

  // Audio player readiness & safe start/stop lifecycle
  await expect(viewport).toHaveAttribute('data-player-ready', 'true', {
    timeout: 25_000,
  });
  await page.getByRole('button', { name: '再生', exact: true }).click();
  await page.waitForTimeout(400);
  await page.getByRole('button', { name: '停止', exact: true }).click();

  expect(externalRequests, `External requests: ${externalRequests.join(', ')}`).toEqual([]);
  expect(httpFailures, `HTTP errors: ${httpFailures.join(', ')}`).toEqual([]);
  expect(errors, `Browser errors: ${errors.join('; ')}`).toEqual([]);
});
