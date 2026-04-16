---
title: "Implementing Voice AI Chat with Conversation Memory in Flutter Web — Web Speech API + Supabase"
tags: Flutter,Supabase,WebSpeechAPI,buildinpublic,webdev
published: false
---

# Implementing Voice AI Chat with Conversation Memory in Flutter Web

## Introduction

I added **voice-based AI chat** and **persistent conversation history** to my personal app "自分株式会社" (Jibun Kabushiki Kaisha).

- Web Speech API (browser-native) for mic input → text conversion
- Supabase `conversation_messages` table for storing conversation history
- Added a `chat` action to the existing `ai-assistant` Edge Function for long-term memory

It turned out to require surprisingly little code.

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web + `package:web` |
| Speech Recognition | Web Speech API (SpeechRecognition) |
| Backend | Supabase Edge Function (Deno) |
| Conversation Memory | Supabase PostgreSQL `conversation_messages` |
| AI | Claude Sonnet 4.6 |

## Core: Web Speech API in Flutter Web

To use speech recognition in Flutter Web, access the browser API directly via `package:web`:

```dart
import 'package:web/web.dart' as web;

class SpeechRecognitionService {
  web.SpeechRecognition? _recognition;

  void startListening(Function(String) onResult) {
    _recognition = web.SpeechRecognition();
    _recognition!.lang = 'ja-JP';
    _recognition!.continuous = false;
    _recognition!.interimResults = false;

    _recognition!.onresult = (web.SpeechRecognitionEvent event) {
      final transcript = event.results.item(0)!.item(0)!.transcript;
      onResult(transcript);
    }.toJS;

    _recognition!.start();
  }
}
```

Key points: set `lang` for your language, use `continuous: false` for single-utterance capture.

## Conversation Memory: conversation_messages Table

```sql
create table conversation_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  session_id text not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz default now()
);
```

The `session_id` separates sessions while enabling history carryover.

## Edge Function: chat Action

Added a `chat` action to the existing `ai-assistant` Edge Function:

```typescript
case 'chat': {
  const { message, sessionId, userId } = body;

  // Fetch last 10 messages for context
  const { data: history } = await supabase
    .from('conversation_messages')
    .select('role, content')
    .eq('session_id', sessionId)
    .order('created_at', { ascending: true })
    .limit(10);

  const messages = [
    ...(history || []),
    { role: 'user', content: message }
  ];

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    messages,
  });

  const assistantMessage = response.content[0].text;

  await supabase.from('conversation_messages').insert([
    { user_id: userId, session_id: sessionId, role: 'user', content: message },
    { user_id: userId, session_id: sessionId, role: 'assistant', content: assistantMessage },
  ]);

  return new Response(JSON.stringify({ message: assistantMessage }));
}
```

Passing the history array directly to Claude's `messages` parameter gives you long-term memory for free.

## Gotchas

### JS Interop for Callbacks

When assigning callbacks to `SpeechRecognition` events in Flutter Web, you must use `.toJS`:

```dart
_recognition!.onresult = (event) { ... }.toJS; // .toJS is required
```

### RLS Policy References

When setting up Row Level Security on `conversation_messages`, make sure your policy references the correct table. If your project uses a `user_profiles` table instead of referencing `auth.users` directly, you'll get a `42P01` error.

## Conclusion

- Web Speech API works cleanly in Flutter Web via `package:web`
- Supabase + Edge Functions makes persistent conversation memory achievable in ~50 lines
- The Claude API's messages array naturally handles conversation context

Hope this helps anyone adding AI chat features to their personal projects.

---

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
