---
title: "One Edge Function, Three AI Writers: Meeting Minutes + X Threads + Blog Drafts"
tags: Flutter,Supabase,AI,buildinpublic,GeminiAPI
published: true
---

# One Edge Function, Three AI Writers: Meeting Minutes + X Threads + Blog Drafts

## The Problem

Three recurring pain points in my indie dev workflow:
1. Writing meeting notes → structured minutes is tedious
2. Building a `#buildinpublic` presence means turning dev sessions into X threads daily
3. Technical blog posts take time to structure even when the content is clear

I solved all three with **three new `action` cases in one existing Edge Function** — no new function, no extra Supabase quota used.

---

## The Pattern: Extend Existing Edge Functions, Don't Create New Ones

I'm running [自分株式会社](https://my-web-app-b67f4.web.app/) on Supabase's free plan. Edge Function quotas are finite. The solution: every new AI feature adds a `case` to an existing function's switch statement rather than deploying a new function.

```typescript
// supabase/functions/ai-writing-assistant/index.ts
switch (action) {
  case "improve":   // existing
  case "summarize": // existing
  case "translate": // existing

  case "minutes":   // NEW
    prompt = buildMinutesPrompt(text);
    break;

  case "thread":    // NEW
    prompt = buildThreadPrompt(text);
    break;

  case "blog":      // NEW
    prompt = buildBlogPrompt(text);
    break;
}
```

Three features added, zero new Edge Functions deployed.

---

## The Meeting Minutes Prompt

The key insight: **Gemini follows a Markdown template better than prose instructions**. Providing the exact output format in the prompt produces consistent results.

```typescript
case "minutes":
  prompt = `Convert the following notes/conversation into a structured meeting minutes document.

【Output format】
## Meeting Minutes

**Date**: [extract if present, else "Not specified"]
**Attendees**: [extract if present]

### Discussion Points
(bullet points, organized by topic)

### Decisions Made
(clearly stated decisions as bullet points)

### Action Items
| Owner | Task | Deadline |
|-------|------|----------|

### Next Meeting
[extract if present]

---
Input text:
${text}`;
  break;
```

**Why this works**: Instead of "make a structured meeting summary," you show Gemini the exact table structure you want. The model fills in the blanks rather than inventing its own format.

---

## The X Thread Prompt

```typescript
case "thread":
  prompt = `Convert the following content into an X (Twitter) thread.

【Rules】
- Each tweet must be under 140 characters
- Thread length: 5-8 tweets
- First tweet starts with a hook that grabs attention
- Number each tweet (1/ 2/ ...)
- Last tweet includes #buildinpublic hashtag

Input text:
${text}`;
  break;
```

Constrained output format = reliable results. "Under 140 characters" and "5-8 tweets" prevent the model from going off-format.

---

## The Flutter UI: Add an "X" Share Button

When the user selects the `thread` action and generates output, a share button appears:

```dart
if (_selectedAction == 'thread')
  IconButton(
    icon: const Icon(Icons.open_in_new, size: 18),
    tooltip: 'Post to X',
    color: const Color(0xFF1DA1F2),
    onPressed: () async {
      final text = _resultController.text;
      final encoded = Uri.encodeComponent(
        text.length > 280
            ? '${text.substring(0, 277)}...'
            : text,
      );
      final uri = Uri.parse(
        'https://twitter.com/intent/tweet?text=$encoded',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    },
  ),
```

Tapping the button opens the X compose screen pre-filled with the first tweet. The user reviews, edits if needed, and posts.

---

## Adding Actions to the Flutter Action Map

```dart
static const _actions = {
  'improve':   ('Improve text',     Icons.auto_fix_high,  Color(0xFF6366F1)),
  'summarize': ('Summarize',        Icons.compress,       Color(0xFF8B5CF6)),
  'translate': ('Translate',        Icons.translate,      Color(0xFF10B981)),
  // New:
  'minutes':   ('Meeting minutes',  Icons.assignment,     Color(0xFF0EA5E9)),
  'thread':    ('X thread',         Icons.dynamic_feed,   Color(0xFF1DA1F2)),
  'blog':      ('Blog draft',       Icons.article,        Color(0xFFF97316)),
};
```

The map drives both the UI buttons and the action sent to the Edge Function. Adding a new action = add one map entry + one switch case.

---

## What I Learned

**1. Prompt format matters more than prompt length**

"Generate meeting minutes from this text" → inconsistent. "Fill in this exact Markdown template" → consistent every time. Show the model what you want, don't just describe it.

**2. Quota-aware architecture forces good design**

The constraint of "don't create new Edge Functions" pushed me toward a more extensible action-based architecture. Now every new AI feature is one `case` away.

**3. `twitter.com/intent/tweet` is underrated**

No OAuth, no API key, no rate limits. For a Flutter Web app where the user is already logged into X in their browser, the intent URL is the simplest possible share flow.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #AI #GeminiAPI
