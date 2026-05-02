import { expect, type Page, type TestInfo } from '@playwright/test';

type BrowserIssue = {
  kind: 'console' | 'pageerror';
  text: string;
  stack?: string;
};

const currentFocusTraversalSignatures = [
  '.gO',
  '.ge2',
  'Object.e93',
  'Object.dBT',
  '.aEM',
];

const focusTraversalAlternatives = [
  ['.gnc', '.gmc'],
  ['.akW', '.akk'],
  ['.aTV', '.a7V'],
  ['.asE', '.aSE'],
];

function hasAnySignature(text: string, signatures: string[]): boolean {
  return signatures.some((signature) => text.includes(signature));
}

export function isKnownFlutterFocusTraversalIssue(
  issue: BrowserIssue,
): boolean {
  const detail = `${issue.text}\n${issue.stack ?? ''}`;
  if (!detail.includes('main.dart.js')) return false;

  return (
    currentFocusTraversalSignatures.every((signature) =>
      detail.includes(signature),
    ) &&
    focusTraversalAlternatives.every((signatures) =>
      hasAnySignature(detail, signatures),
    )
  );
}

export function installConsoleGuard(
  page: Page,
  testInfo: TestInfo,
): () => Promise<void> {
  const unexpectedIssues: BrowserIssue[] = [];

  page.on('pageerror', (error) => {
    const issue: BrowserIssue = {
      kind: 'pageerror',
      text: error.message,
      stack: error.stack,
    };
    if (!isKnownFlutterFocusTraversalIssue(issue)) {
      unexpectedIssues.push(issue);
    }
  });

  page.on('console', (message) => {
    if (message.type() !== 'error') return;

    const issue: BrowserIssue = {
      kind: 'console',
      text: message.text(),
      stack: message.location().url,
    };
    if (!isKnownFlutterFocusTraversalIssue(issue)) {
      unexpectedIssues.push(issue);
    }
  });

  return async () => {
    if (unexpectedIssues.length > 0) {
      await testInfo.attach('unexpected-browser-issues', {
        body: JSON.stringify(unexpectedIssues, null, 2),
        contentType: 'application/json',
      });
    }

    expect(unexpectedIssues).toEqual([]);
  };
}
