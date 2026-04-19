---
title: "Adding a Mobile Claude Code Instance — Real Device Bug Triage With a 5th Instance"
tags: ClaudeCode,Flutter,buildinpublic,mobile,productivity
published: false
---

# Adding a Mobile Claude Code Instance

## From 3 Instances to 5

Previously I wrote about [running 3 parallel Claude Code instances for $20/month](https://dev.to/kanta13jp1/running-3-parallel-claude-code-instances-to-get-200-of-dev-work-for-20month-294a).

I've since added two more: a **Web instance** (for NotebookLM research) and a **mobile instance** (for real-device bug triage). Still $20/month.

### The 5-Instance Setup

| Instance | Dedicated Role |
|----------|---------------|
| **VSCode** | UI/design compliance (Rule12/19) |
| **PowerShell** | CI/CD health (Rule17) + blog publishing |
| **Windows App** | AI University providers + migrations |
| **Web** | Competitor research + blog drafts (NotebookLM) |
| **📱 Mobile** | Real-device UAT + mobile bug triage |

## What the Mobile Instance Solves

Desktop dev tools — even Chrome's mobile emulator — miss a class of bugs that only appear on real hardware:

**Recent examples:**
- **PR #497**: Note editor's bottom buttons get hidden behind the software keyboard
- **PR #504**: ActionChip labels unreadable on dark theme at certain brightness levels

Both were invisible in Chrome DevTools → mobile emulator. Both were immediately obvious when opening the app on an actual phone.

### The Mobile Instance's Role: `mobile-bug-triage` Skill

```markdown
# mobile-bug-triage

When a bug is found on device:
1. Screenshot + reproduction steps
2. Create GitHub Issue with #priority:high label
3. Create cross-instance-pr for VSCode instance
   → VSCode picks it up next session and fixes it

Scope: layout breaks / keyboard overlap / tap targets / scroll issues
```

**The mobile instance doesn't fix.** It discovers and reports. Fixes go to VSCode.

## Keyboard Overlap Fix Pattern

When the software keyboard opens, `Scaffold.body` compresses and fixed-position buttons get pushed behind the keyboard:

```dart
// ❌ Problem
Scaffold(
  body: Column(
    children: [
      Expanded(child: NoteEditor()),
      BottomActionBar(), // hidden by keyboard
    ],
  ),
)

// ✅ Fix 1: explicit resizeToAvoidBottomInset (usually already true)
Scaffold(
  resizeToAvoidBottomInset: true,
  body: Column(...),
)

// ✅ Fix 2: dynamic bottom padding with viewInsets
Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).viewInsets.bottom,
  ),
  child: BottomActionBar(),
)
```

## Dark Theme ActionChip Contrast Fix

Flutter's `ActionChip` uses `colorScheme.surface` as its background by default. On dark themes, if `surface` is dark and the label inherits a dark color too, text becomes invisible.

```dart
// ❌ Theme-dependent, fails on dark
ActionChip(label: Text(label))

// ✅ Explicit contrast
ActionChip(
  label: Text(
    label,
    style: const TextStyle(color: Color(0xFFE2E8F0)),
  ),
  backgroundColor: const Color(0xFF334155),
)
```

## Why Role Separation Works

Without the mobile instance, mobile UX issues would only get caught by users filing support tickets — or never. With it:

1. Mobile bugs surface within the same session they're encountered
2. The VSCode instance gets a prioritized, well-described GitHub Issue
3. Fix goes through the normal PR → CI → deploy pipeline

The key insight: **specialization creates better signal**. The mobile instance has one job and does it well precisely because it's not distracted by code changes, migrations, or blog posts.

---
Building in public: https://my-web-app-b67f4.web.app/
#ClaudeCode #Flutter #buildinpublic #mobile
