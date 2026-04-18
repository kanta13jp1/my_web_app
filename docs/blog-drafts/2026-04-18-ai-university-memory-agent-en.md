---
title: "Claude + Groq Hybrid LLM — AI University Memory Agent"
tags: Flutter,Supabase,buildinpublic,webdev,FlutterTips
published: false
---

# Claude + Groq Hybrid LLM — AI University Memory Agent

After each learning session in AI University, a Memory Agent automatically builds a structured learner profile — weak providers, strong providers, preferred learning style. Next session, quizzes are personalized based on that profile.

**The trick**: two models, two jobs — Claude Sonnet for deep profile extraction, Groq Llama for real-time quiz scoring.

## Architecture

```
Session ends
  → learner.update_profile (Edge Function)
    → Claude Sonnet → structured JSON profile
      → UPSERT into ai_university_learner_profiles

Quiz answer submitted
  → quiz.evaluate (Edge Function)
    → Groq Llama 3.3 70B → JSON score {result, confidence}
    → fallback: string match
```

## Memory Agent — Claude Extracts the Profile

```typescript
// supabase/functions/ai-hub — learner.update_profile
const prompt = `Extract a structured learner profile from this session data.
Session summary: ${sessionSummary}
Score data: ${JSON.stringify(scores).slice(0, 2000)}
Return JSON: {"weak_providers":["..."],"strong_providers":["..."],"preferred_style":"visual|text|voice","insights":"..."}`;

const claudeResp = await fetch("https://api.anthropic.com/v1/messages", {
  body: JSON.stringify({
    model: "claude-sonnet-4-6",
    max_tokens: 512,
    messages: [{ role: "user", content: prompt }],
  }),
});

// Strip code fences before parsing
const rawText  = claudeData.content[0].text;
const profile  = JSON.parse(rawText.replace(/```json\n?|\n?```/g, "").trim());
```

Save to Supabase:

```typescript
await admin.from("ai_university_learner_profiles").upsert({
  user_id,
  weak_providers:  profile.weak_providers  ?? [],
  strong_providers: profile.strong_providers ?? [],
  preferred_style: profile.preferred_style  ?? "text",
  profile_json:    profile,
  total_sessions:  (existing?.total_sessions ?? 0) + 1,
}, { onConflict: "user_id" });
```

## Quiz Evaluator — Groq Scores Answers Fast

```typescript
// quiz.evaluate — Groq Llama 3.3 70B, JSON mode
const groqResp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
  body: JSON.stringify({
    model: "llama-3.3-70b-versatile",
    max_tokens: 100,
    temperature: 0,
    response_format: { type: "json_object" },  // guaranteed JSON
    messages: [{
      role: "user",
      content: `Question: ${question}\nExpected: ${correctAnswer}\nUser: ${userAnswer}
Score: {"result":"correct|incorrect|partial","confidence":0-100}`,
    }],
  }),
}).catch(() => null);

// Groq failure → fallback to exact string match
if (!groqResp || !groqResp.ok) {
  const match = userAnswer.trim().toLowerCase() === correctAnswer.trim().toLowerCase();
  return json({ result: match ? "correct" : "incorrect", confidence: 100, fallback: true });
}
```

## Why Two Models?

| Task | Model | Reason |
|------|-------|--------|
| Learner profile extraction | Claude Sonnet 4.6 | Complex reasoning, structured JSON quality |
| Quiz scoring | Groq Llama 3.3 70B | Low latency, high volume, free tier |

Claude runs once at session end. Groq runs on every quiz answer. Matching the model to the task cuts costs without sacrificing quality.

## DB Schema

```sql
CREATE TABLE ai_university_learner_profiles (
  user_id          uuid PRIMARY KEY REFERENCES auth.users,
  weak_providers   text[] DEFAULT '{}',
  strong_providers text[] DEFAULT '{}',
  preferred_style  text   DEFAULT 'text',
  profile_json     jsonb  DEFAULT '{}',
  total_sessions   int    DEFAULT 0,
  updated_at       timestamptz DEFAULT now()
);
```

## Key Takeaways

1. **Assign models by strength** — Claude for deep analysis, Groq for speed
2. **`response_format: json_object`** — eliminates JSON parse errors from Groq
3. **Strip code fences** — Claude wraps JSON in ` ```json ``` ` → strip before `JSON.parse`
4. **Always fallback** — Groq outage shouldn't break quiz scoring

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #LLM #FlutterTips
