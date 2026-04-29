---
title: "Indie Dev Customer Support Automation — FAQ Bot, Ticket Management, and Escalation"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# Indie Dev Customer Support Automation — FAQ Bot, Ticket Management, and Escalation

Running support solo requires automation. Here's a minimal-cost setup.

## Architecture

```
User → contact form → Supabase (support_tickets table)
Supabase → GHA cs-check (hourly) → Claude API (FAQ auto-reply)
Claude can't resolve → Slack DM (escalation) → manual response
```

## FAQ Auto-Reply Implementation

```typescript
// cs-check GHA asks Claude based on tickets from get-support-tickets EF
const prompt = `
The following is a user inquiry.
If you can answer from the FAQ, generate a reply.
If you cannot resolve it, respond with "ESCALATE".

Inquiry: ${ticket.message}

FAQ:
- Can't log in → reset password here: [URL]
- Pricing questions → see monthly plans at [URL]
- Export data → Settings > Data Management > Export
`;

const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 500,
  messages: [{ role: 'user', content: prompt }],
});
```

## Ticket Management Schema

```sql
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  message TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'auto_replied', 'escalated', 'resolved')),
  auto_reply TEXT,
  replied_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: users can only see their own tickets
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own tickets" ON support_tickets
  FOR ALL USING (auth.uid() = user_id);
```

## Escalation Notification (Slack)

```typescript
async function escalate(ticket: SupportTicket): Promise<void> {
  await fetch(Deno.env.get('SLACK_WEBHOOK')!, {
    method: 'POST',
    body: JSON.stringify({
      text: `🚨 Escalation: ${ticket.id.slice(0, 8)}\n${ticket.message.slice(0, 200)}`,
    }),
  });
  await supabase.from('support_tickets')
    .update({ status: 'escalated' })
    .eq('id', ticket.id);
}
```

## Summary

```
Auto-reply target   → 70% (handle 30% manually)
Response time       → GHA runs hourly → auto-reply within 1h max
Claude model        → Haiku (lowest cost / sufficient for FAQ replies)
Escalation path     → Slack DM (urgent) or email (next-day OK)
```

If the FAQ bot handles 70%, manual support drops to a handful of tickets per week.
