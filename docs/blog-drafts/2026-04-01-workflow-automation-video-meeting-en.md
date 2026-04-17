---
title: "3 SaaS Competitors in One Day: AI Workflow, SNS Scheduler & Video Meeting (Flutter + Supabase)"
tags: Flutter,Supabase,buildinpublic,Dart,productivity
published: true
---

# 3 SaaS Competitors in One Day: AI Workflow, SNS Scheduler & Video Meeting

## What We Shipped

Three features in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **AI Workflow Automation** — competing with Zapier, Power Automate
2. **SNS Post Scheduler** — competing with Hootsuite, Buffer
3. **Video Meeting Manager** — competing with Zoom, Google Meet

Plus 5 new Edge Functions added to CI/CD.

All use the same Edge Function First architecture.

---

## AI Workflow Automation

### Fetch Everything in One Call

```dart
class _WorkflowAutomationPageState extends State<WorkflowAutomationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await _supabase.functions.invoke(
      'ai-workflow-automation',
      body: {'action': 'list'},
    );
    // workflows, templates, and stats returned in one response
  }
}
```

One Edge Function call returns workflows, templates, and statistics together. Flutter handles only rendering.

### Focus-Timer Streak Calculation (TypeScript)

The `focus-timer` Edge Function calculates streaks entirely in Deno — no client-side logic:

```typescript
function _calculateStreak(sessions: Array<{started_at?: string; status?: string}>): number {
  const dates = sessions
    .filter((s) => s.status === "completed")
    .map((s) => new Date(s.started_at!).toDateString());
  const unique = [...new Set(dates)];
  let streak = 0;
  const today = new Date();
  for (let i = 0; i < 30; i++) {
    const d = new Date(today);
    d.setDate(today.getDate() - i);
    if (unique.includes(d.toDateString())) streak++;
    else if (i > 0) break;
  }
  return streak;
}
```

`new Set(dates)` deduplicates multiple sessions on the same day. Loop backward from today — first missing day breaks the streak.

---

## SNS Post Scheduler

### Platform Color Map

```dart
Color _platformColor(String? platform) {
  switch (platform) {
    case 'x':         return Colors.black;
    case 'linkedin':  return const Color(0xFF0077B5);
    case 'instagram': return const Color(0xFFE1306C);
    case 'facebook':  return const Color(0xFF1877F2);
    default:          return Colors.grey;
  }
}
```

Four platforms (X, LinkedIn, Instagram, Facebook) with brand colors. The user picks a platform from a dialog, writes content, and taps "Save Draft" — the Edge Function handles scheduling.

---

## Video Meeting Manager

### AI Meeting Minutes

The `video-meeting-manager` Edge Function calls Gemini after each meeting to extract:
- Summary
- Action items (who, what, deadline)
- Sentiment

```dart
IconData _meetingTypeIcon(String? type) {
  switch (type) {
    case 'video':        return Icons.videocam;
    case 'audio':        return Icons.mic;
    case 'webinar':      return Icons.cast;
    case 'screen_share': return Icons.screen_share;
    default:             return Icons.meeting_room;
  }
}
```

Meeting type drives the icon — no external package needed for a 4-variant icon set.

---

## 5 New Edge Functions

| Function | Competing With | Responsibility |
|----------|---------------|---------------|
| `bookmark-sync` | Pocket, Instapaper | Tagged bookmark sync |
| `note-sharing-enhanced` | Notion Share | Password-protected, expiry links |
| `focus-timer` | Forest, Focusmate | Pomodoro + streak tracking |
| `task-dependency` | Asana | Task dependency graph |
| `ai-writing-assistant` | Grammarly, Notion AI | Improve / summarize / translate |

---

## 4-Instance Merge Conflict Pattern

Running 4 parallel dev instances (VSCode / Web / Windows / PowerShell) means `edge_function_summary_card.dart` conflicts on almost every session:

```bash
git checkout --theirs supabase/functions/edge_function_summary_card.dart
# Then append the new functions to the accepted version
```

`--theirs` takes the remote version, then we append our new additions. This is faster than manual conflict resolution on a file that changes every session.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #productivity
