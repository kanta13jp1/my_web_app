---
title: "9 Principles for Building a 200-Page SaaS Solo — The Jibun Kaisha Framework"
tags: Flutter,buildinpublic,AI,productivity,philosophy
published: true
---

# 9 Principles for Building a 200-Page SaaS Solo — The Jibun Kaisha Framework

## Why Decision Principles Matter at Scale

[Jibun Kabushiki Kaisha](https://my-web-app-b67f4.web.app/) ("Your Own Corporation") is a Flutter Web SaaS that integrates features from 21 competitors — Notion, Evernote, MoneyForward, Slack, X, Amazon — into one app. With 200+ pages and one developer, I face the same decisions a CEO does, every day:

- "Should I add this feature?"
- "Is this automation doing too much for the user?"
- "Will this KPI pull us away from the real goal?"

The 9 Principles are the decision framework I distilled from my product vision to answer these questions consistently.

## The 9 Principles

### Principle 1: CEO Feel (User Holds Final Decision)

> The user makes the final call. AI-only automation is a violation.

```dart
// ❌ AI decides alone
await autoPublishBlogPost(content);

// ✅ User confirms
final approved = await showConfirmDialog(content);
if (approved) await publishBlogPost(content);
```

Automation assists. "AI does it all" is Principle 1 violation.

### Principle 2: Mission-Driven Features

> Every feature must tie back to the user's mission and core values.

Not "build it because competitors have it" — but "how does this serve this user's values?" Before designing any feature, ask: **"Whose values does this support, and how?"**

### Principle 3: Gentle Mentor (Not a Watchdog)

> Notifications and AI feedback should coach, not police.

```
❌ "You wasted 3h12m on social media yesterday. Reduce it."
✅ "Yesterday's social media: 3h12m. What's your goal for today?"
```

The framing shifts from surveillance to support.

### Principle 4: Six Department Balance (People First)

> R&D / Finance / Marketing / People / HQ. If the People department says no, everything stops.

"People department = wellbeing." A feature can pass every other check, but if it harms mental/physical health, it's rejected.

### Principle 5: Product = Value Creation

> Increase the user's value. Never consume it.

Social media addiction loops, dark-pattern charges, notification spam — all Principle 5 violations. Rate each feature: **does it increase or decrease the user's time, capability, or happiness?**

### Principle 6: Capital = Time

> Minimize operation time. Make time allocation visible.

UI design criterion: **"How many seconds does this save per use?"**

Often it's better to make existing flows 3 seconds faster than to add a new feature.

### Principle 7: Assets vs. Liabilities

> Grow assets (skills, health, relationships, knowledge). Shrink liabilities (dependencies, waste, bad habits).

Before each release: **"Does this grow an asset or grow a liability?"**

### Principle 8: KPI = Yesterday's You

> Personal progress over peer comparison.

When building any ranking or score feature, always add the personal-best axis alongside the leaderboard:

```dart
// ✅ Compare to personal best, not others
final personalBest = await fetchPersonalBest(userId);
final improvement = currentScore - personalBest;
```

### Principle 9: Goal = IPO / Wellbeing

> Long-term happiness over short-term KPI racing.

Monthly DAU and conversion rates matter, but the real question is: **"Will this service still add value to the user's life in 5 years?"**

## The Checklist

| Principle | Check |
|-----------|-------|
| User holds final call | ✅/❌ |
| Mission-driven | ✅/❌ |
| Gentle mentor | ✅/❌ |
| People dept. passes | ✅/❌ |
| Value creation | ✅/❌ |
| Time minimized | ✅/❌ |
| Assets ↑ Liabilities ↓ | ✅/❌ |
| Personal progress focus | ✅/❌ |
| Long-term wellbeing | ✅/❌ |

**7+ ✅** → build it  
**4–6 ✅** → redesign  
**3 or fewer** → skip or major rethink

## Real Decisions This Framework Made

| Feature | Score | Outcome |
|---------|-------|---------|
| Horse racing predictions | 5/9 | Reframed as "data science learning lab" under R&D |
| AI auto-posting | 4/9 | Allowed with mandatory confirmation dialog |
| Social ranking | 6/9 | Redesigned to include personal-progress axis |
| AI University (learning) | 9/9 | Built immediately |

## The Key Insight

What a solo developer can compete on against 21 well-funded companies isn't features, pricing, or even code quality — it's **philosophy**.

These 9 principles are "what to build." The [AI development 7 principles](https://dev.to/kanta13jp1/7-principles-for-using-ai-agents-safely-in-production-a-solo-devs-checklist-568n) I covered previously are "how to build it." 

**Only features that pass both frameworks get implemented.** The constraint prevents drift toward becoming a pale copy of the competitors.

---
Building in public: https://my-web-app-b67f4.web.app/
#buildinpublic #FlutterWeb #AI #solodev #productphilosophy
