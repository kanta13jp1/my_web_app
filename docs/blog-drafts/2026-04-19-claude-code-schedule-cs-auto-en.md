---
title: "Automating Solo SaaS Customer Support with Claude Code Schedule — FAQ, Bug Fix, Escalation"
tags: Claude,AI,buildinpublic,SaaS,webdev
published: true
---

# Automating Solo SaaS Customer Support with Claude Code Schedule

## The Problem: CS Is a Dev-Time Bottleneck

Running a solo SaaS means every support ticket pulls you away from building. But most tickets follow predictable patterns:

- "I can't log in"
- "My data disappeared"
- "Does this feature exist?"

Answering each one manually is waste. The answer is often already in the FAQ.

## The Solution: Claude Code Schedule + cs-check

Claude Code CLI's Schedule feature runs a `cs-check` task every hour automatically:

```yaml
# .claude/schedule.yaml
tasks:
  - name: cs-check
    cron: "0 * * * *"
    prompt: |
      Task: cs-check
      Fetch unreplied support tickets. Route to FAQ reply, bug fix, or escalation.
```

## 3-Case Routing Logic

### Step 1: Fetch Open Tickets

```typescript
// get-support-tickets Edge Function
const tickets = await supabase
  .from('support_tickets')
  .select('id, title, body, status')
  .eq('status', 'open')
  .is('replied_at', null);
```

### Step 2: Classify and Act

```
Case A: FAQ match (similarity > 0.7) → auto-reply
Case B: Bug keywords detected → read source, fix if simple, commit
Case C: Billing / refund / complex → escalate, log for human
```

```typescript
async function routeTicket(ticket: Ticket, faq: FAQ[]) {
  // Case A
  const match = faq.find(f => similarity(ticket.title, f.question) > 0.7);
  if (match) return replyWithFaq(ticket.id, match.answer);

  // Case B
  const bugWords = ['error', 'broken', 'not working', "can't"];
  if (bugWords.some(k => ticket.body.toLowerCase().includes(k))) {
    return { action: 'investigate', ticket };
  }

  // Case C
  return { action: 'escalate', ticket };
}
```

### Step 3: Auto-Fix for Bug Cases

When Claude identifies a fixable bug, it patches the code and commits:

```bash
# After applying the fix:
flutter analyze lib/   # confirm 0 errors
git add -p
git commit -m "fix: null check in home dashboard loader"
git push origin main
# Reply: "Fixed — deploy takes a few minutes"
```

## Audit Trail in cs-notes

Every session produces a log at `docs/cs-notes/YYYY-MM-DD-HH.md`:

```markdown
# CS Check 2026-04-19 10:00

## Replied (FAQ)
- "Can't reset password" → emailed password reset flow

## Fixed (Bug)
- "Home screen stuck loading" → null check fix, commit: abc1234

## Escalated
- "I want a refund" → requires human response
```

## Infrastructure Health Check as a Side Effect

While checking tickets, also ping live endpoints:

```typescript
const urls = [
  'https://yourproject.supabase.co/functions/v1/get-home-dashboard',
  'https://your-app.web.app/',
];

for (const url of urls) {
  const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
  if (!res.ok || /* timeout */) {
    appendToNote(`## Infrastructure Alert\n- ${url}: ${res.status}`);
  }
}
```

Downtime detection with zero extra tooling.

## Results

| Metric | Manual | Automated |
|--------|--------|-----------|
| Response time | 24h avg | < 1h |
| Human intervention rate | 100% | ~20% |
| Bug → fix latency | days | minutes |
| Mental overhead | High | Low |

For solo builders, automating CS might return more dev-hours per week than any other investment.

---
Building in public: https://my-web-app-b67f4.web.app/
#Claude #AI #buildinpublic #SaaS #automation
