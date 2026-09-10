---
title: "Is Your User Manual Executable Code? Auditing 'Supported Imports' Against the Actual Picker"
tags: flutter, documentation, webdev, programming
published: true
---

# Is Your User Manual Executable Code? Auditing "Supported Imports" Against the Actual Picker

Jibun Inc.'s user manual claimed the app could import data from Notion, Evernote, MoneyForward, X (Twitter), and GitHub. When I cross-checked those six documented steps against the actual import screen's code, four of them turned out to be **impossible to follow as written**. Here's what was wrong and how it got fixed without touching any business logic.

## Don't trust the sentence "we support this"

The manual read:

> Jibun Inc. supports importing from Notion / Evernote / MoneyForward / X (Twitter) / GitHub / Markdown files.

Sounds reasonable. But the file picker in `import_page.dart` hardcodes allowed extensions per `sourceType`:

```dart
List<String> _extensionsFor(String sourceType) {
  switch (sourceType) {
    case 'notion':
      return const <String>['csv'];
    case 'evernote':
      return const <String>['enex', 'xml'];
    case 'markdown':
      return const <String>['md', 'markdown', 'txt'];
    case 'xlsx':
      return const <String>['xlsx'];
    case 'docx':
      return const <String>['docx'];
    case 'business_csv':
      return const <String>['csv'];
    default:
      return const <String>[];
  }
}
```

Only six `sourceType` cards actually exist: `notion`, `evernote`, `markdown`, `xlsx`, `docx`, `business_csv`. There is no card at all for `moneyforward`, `twitter`, or `github`.

## Four gaps between claim and code

1. **Notion**: the manual said "download the ZIP and select it directly," but `notion`'s allowed extension is `csv` only — the ZIP never even shows up in the file dialog.
2. **MoneyForward**: there's no `moneyforward` sourceType at all. Even if a user smuggles the CSV in through the `notion` card, the column matcher only recognizes headers like `title/name` and `content/text`, none of which exist in MoneyForward's Japanese export (date/description/amount). The result: **a silent zero-row import**.
3. **X (Twitter)**: the official archive is a ZIP full of JavaScript files. No accepted extension covers it.
4. **GitHub**: the account data export is a `.tar.gz`. Same story — no matching sourceType.

Case 2 is the dangerous one. Cases 1, 3, and 4 fail loudly — the file simply can't be selected, so the user notices immediately. Case 2 *looks* like it worked and silently produces nothing.

## The fix: reverse-engineer a working path from the code that already exists

On a day with no budget for a new feature, the working shortcut is often already sitting in the codebase. Reading the generic table parser used by the `xlsx` importer, I found its column-match candidates already included Japanese labels:

```dart
final contentIndex = _findColumnIndex(
  header,
  const <String>['content', 'text', 'body', 'plain text', '本文', '内容', 'メモ'],
);
```

So converting the MoneyForward CSV to `.xlsx` first, then uploading it through the "Excel (XLSX)" card, actually works — MoneyForward's `内容` (description) column maps straight into note content. Zero lines of app code changed; only the manual's steps needed to point at the path that already worked.

X and GitHub archives were too structurally different for the same trick, so instead of inventing a fake procedure, the manual now says plainly that direct import isn't supported yet, with a fallback of manually copying the text into a `.md` file and using the Markdown importer — which is real and verified to work.

## Takeaways

- "We support this" in a doc is a wish, not a source of truth. Before editing a manual, read the picker's extension whitelist and the column-matching logic it actually runs.
- The riskiest broken instruction isn't the one that errors out — it's the one that looks successful while silently importing nothing. Diffs and reviews should treat a zero-row import as an anomaly worth flagging.
- In a large automated codebase (this one runs 100+ concurrent AI-agent worktrees), auditing the gap between what's *documented* and what's *implemented* is often higher ROI than shipping another new feature.
