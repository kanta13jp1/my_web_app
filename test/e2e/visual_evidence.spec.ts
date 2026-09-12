import { expect, Page, test, TestInfo } from '@playwright/test';

type RouteTarget = {
  name: string;
  route: string;
  surface: string;
};

type BrowserIssue = {
  kind: 'console' | 'pageerror' | 'requestfailed' | 'server';
  message: string;
  url?: string;
  status?: number;
};

const routeTargets: RouteTarget[] = [
  { name: 'landing', route: '/', surface: 'landing' },
  { name: 'home', route: '/home', surface: 'home' },
  { name: 'auth', route: '/two-factor-auth', surface: 'auth route' },
  { name: 'notion-wbs', route: '/project-gantt', surface: 'Notion/WBS equivalent' },
  { name: 'agent-org', route: '/agents', surface: 'agent org equivalent' },
  { name: 'tiger-reviewers', route: '/tiger-reviewers', surface: 'Tiger profiles' },
];

const ignoredConsoleFragments = [
  'ResizeObserver loop',
  'service worker',
  'ServiceWorker',
  'flutter_service_worker',
  'Cache.addAll',
  'ERR_INSUFFICIENT_RESOURCES',
];

test.describe('visual evidence smoke', () => {
  for (const target of routeTargets) {
    test(`${target.name} captures stable visual evidence`, async ({
      page,
    }, testInfo) => {
      const issues = collectBrowserIssues(page);

      const response = await page.goto(target.route, {
        waitUntil: 'domcontentloaded',
      });

      expect(response?.ok(), `${target.route} should return HTTP 2xx/3xx`).toBe(
        true,
      );

      await page.waitForLoadState('networkidle', { timeout: 3_000 }).catch(
        () => undefined,
      );

      const animationState = await waitForAnimations(page);
      const health = await collectVisualHealth(page);
      const blockingIssues = issues.filter(isBlockingIssue);

      await attachEvidence(testInfo, `${target.name}-snapshot`, {
        route: target.route,
        surface: target.surface,
        url: page.url(),
        animationState,
        health,
        issues,
        blockingIssues,
      });

      await attachScreenshot(testInfo, page, `${target.name}-stable`);
      await captureLowFpsSequence(testInfo, page, target.name);

      expect(
        health.hasVisibleContent,
        `${target.route} should not render as a blank screen`,
      ).toBe(true);
      expect(blockingIssues, formatIssueSummary(blockingIssues)).toEqual([]);
    });
  }
});

function collectBrowserIssues(page: Page): BrowserIssue[] {
  const issues: BrowserIssue[] = [];

  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    const text = message.text();
    if (ignoredConsoleFragments.some((fragment) => text.includes(fragment))) {
      return;
    }
    issues.push({
      kind: 'console',
      message: text,
      url: message.location().url,
    });
  });

  page.on('pageerror', (error) => {
    const text = error.message || String(error);
    if (ignoredConsoleFragments.some((fragment) => text.includes(fragment))) {
      return;
    }
    issues.push({ kind: 'pageerror', message: text });
  });

  page.on('requestfailed', (request) => {
    issues.push({
      kind: 'requestfailed',
      message: request.failure()?.errorText ?? 'request failed',
      url: request.url(),
    });
  });

  page.on('response', (response) => {
    const status = response.status();
    if (status < 500) return;
    issues.push({
      kind: 'server',
      message: response.statusText(),
      status,
      url: response.url(),
    });
  });

  return issues;
}

async function waitForAnimations(page: Page) {
  return page.evaluate(async () => {
    if (!('getAnimations' in document)) {
      return {
        supported: false,
        total: 0,
        running: 0,
        timedOut: false,
      };
    }

    const animations = document.getAnimations({ subtree: true });
    const running = animations.filter(
      (animation) =>
        animation.playState !== 'finished' && animation.playState !== 'idle',
    );
    const settled = Promise.allSettled(
      running.map((animation) => animation.finished),
    ).then(() => 'settled' as const);
    const timeout = new Promise<'timeout'>((resolve) => {
      window.setTimeout(() => resolve('timeout'), 1_500);
    });

    const result = await Promise.race([settled, timeout]);

    return {
      supported: true,
      total: animations.length,
      running: running.length,
      timedOut: result === 'timeout',
    };
  });
}

async function collectVisualHealth(page: Page) {
  return page.evaluate(() => {
    const textLength = (document.body.innerText || '').trim().length;
    const viewportArea = Math.max(window.innerWidth * window.innerHeight, 1);
    const visibleElements = Array.from(document.body.querySelectorAll('*'))
      .map((element) => {
        const rect = element.getBoundingClientRect();
        const style = window.getComputedStyle(element);
        const area = Math.max(rect.width, 0) * Math.max(rect.height, 0);
        return {
          tag: element.tagName.toLowerCase(),
          area,
          visible:
            area > 24 &&
            style.visibility !== 'hidden' &&
            style.display !== 'none' &&
            Number(style.opacity || '1') > 0.01,
        };
      })
      .filter((entry) => entry.visible);
    const largestVisibleRatio =
      visibleElements.reduce((max, entry) => Math.max(max, entry.area), 0) /
      viewportArea;
    const hasFlutterHost = visibleElements.some((entry) =>
      entry.tag.startsWith('flt-'),
    );
    const hasSeoShell =
      document.querySelector('#seo-shell') != null && textLength > 80;

    return {
      textLength,
      visibleElementCount: visibleElements.length,
      largestVisibleRatio,
      hasFlutterHost,
      hasSeoShell,
      hasVisibleContent:
        textLength > 80 ||
        largestVisibleRatio > 0.4 ||
        hasFlutterHost ||
        hasSeoShell,
    };
  });
}

async function attachScreenshot(
  testInfo: TestInfo,
  page: Page,
  name: string,
) {
  await testInfo.attach(name, {
    body: await page.screenshot({ fullPage: true }),
    contentType: 'image/png',
  });
}

async function captureLowFpsSequence(
  testInfo: TestInfo,
  page: Page,
  name: string,
) {
  for (const frame of [1, 2, 3]) {
    await page.waitForTimeout(350);
    await testInfo.attach(`${name}-low-fps-frame-${frame}`, {
      body: await page.screenshot(),
      contentType: 'image/png',
    });
  }
}

async function attachEvidence(
  testInfo: TestInfo,
  name: string,
  body: unknown,
) {
  await testInfo.attach(name, {
    body: JSON.stringify(body, null, 2),
    contentType: 'application/json',
  });
}

function formatIssueSummary(issues: BrowserIssue[]) {
  if (issues.length === 0) return 'No major browser issues captured.';

  return [
    'Major browser issues captured:',
    ...issues.map((issue) => {
      const location = issue.url ? ` (${issue.url})` : '';
      const status = issue.status ? ` ${issue.status}` : '';
      return `- ${issue.kind}${status}: ${issue.message}${location}`;
    }),
  ].join('\n');
}

function isBlockingIssue(issue: BrowserIssue) {
  if (issue.kind === 'pageerror' && issue.message.trim() === 'Error') {
    return false;
  }

  return true;
}
