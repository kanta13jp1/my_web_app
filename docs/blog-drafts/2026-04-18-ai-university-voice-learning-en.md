---
title: "Flutter Web Voice Learning — ElevenLabs TTS with Web Speech API Fallback"
tags: Flutter,Supabase,buildinpublic,webdev,FlutterTips
published: true
---

# Flutter Web Voice Learning — ElevenLabs TTS with Web Speech API Fallback

I added a voice learning mode to AI University. Quiz questions are read aloud; users can answer by voice. The key design: ElevenLabs for quality TTS, with automatic fallback to the browser's built-in Web Speech API — so it always works even without an API key.

## Architecture

```
Flutter _playTts(text)
  → ai-hub EF (voice.tts)
    → ElevenLabs eleven_multilingual_v2 → base64 audio
    → on failure → { fallback: "webspeech" }
  → Flutter fallback: window.speechSynthesis (free, built-in)
```

## Edge Function — ElevenLabs TTS

```typescript
// supabase/functions/ai-hub — voice.tts
case "voice.tts": {
  const elevenKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
  if (!elevenKey) {
    return json({ success: false, fallback: "webspeech", text }); // tell client to use Web Speech
  }

  const ttsResp = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: "POST",
      headers: { "xi-api-key": elevenKey, "Content-Type": "application/json" },
      body: JSON.stringify({
        text,
        model_id: "eleven_multilingual_v2",
        voice_settings: { stability: 0.5, similarity_boost: 0.75 },
      }),
    }
  );

  if (!ttsResp.ok) {
    const errText = await ttsResp.text();
    if (errText.includes("paid_plan_required")) {
      return json({ success: false, fallback: "webspeech", text }); // free-tier limit
    }
    return json({ error: errText, fallback: "webspeech", text }, 502);
  }

  // Binary → base64 (Flutter Web HTMLAudioElement accepts data: URLs)
  const bytes = new Uint8Array(await ttsResp.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
  return json({ success: true, audio_base64: btoa(binary) });
}
```

## Flutter — Play Audio + Fallback

```dart
// lib/pages/ai_university_voice_page.dart
Future<void> _playTts(String text) async {
  setState(() => _ttsStatus = 'loading');

  final resp = await _supabase.functions.invoke(
    'ai-hub', body: {'action': 'voice.tts', 'text': text},
  );
  final data         = resp.data as Map<String, dynamic>?;
  final base64Audio  = data?['audio_base64'] as String? ?? '';
  final fallback     = data?['fallback']     as String? ?? '';

  if (base64Audio.isEmpty) {
    if (fallback == 'webspeech') {
      _speakViaWebSpeech(text);  // switch to browser TTS
      return;
    }
    setState(() => _ttsStatus = 'error');
    return;
  }

  // ElevenLabs audio via HTMLAudioElement
  _audio = web_api.HTMLAudioElement();
  _audio!.src = 'data:audio/mpeg;base64,$base64Audio';
  _audio!.play();
  setState(() => _ttsStatus = 'playing');
}
```

## Web Speech API Fallback

```dart
void _speakViaWebSpeech(String text) {
  final utter = web_api.SpeechSynthesisUtterance(text);
  utter.lang = 'ja-JP';
  utter.rate = 1.0;
  web_api.window.speechSynthesis.cancel(); // stop any ongoing speech
  web_api.window.speechSynthesis.speak(utter);
  setState(() => _ttsStatus = 'playing');
}
```

`package:web/web.dart` — same package for both `HTMLAudioElement` and `SpeechSynthesisUtterance`.

## Fallback Matrix

| Situation | Behavior | Quality |
|-----------|----------|---------|
| API key configured | ElevenLabs TTS | High-quality multilingual |
| No API key | Web Speech API | Browser built-in (free) |
| Free-tier limit | Web Speech API | Browser built-in (free) |
| EF error | Web Speech API | Browser built-in (free) |

Audio playback never stops.

## Key Takeaways

1. **Return base64 audio from EF** — `HTMLAudioElement.src = 'data:audio/mpeg;base64,...'` works natively in Flutter Web
2. **EF signals fallback with `{ fallback: "webspeech" }`** — client decides how to handle it; no logic in EF
3. **One package for everything** — `package:web/web.dart` covers `HTMLAudioElement`, `SpeechSynthesisUtterance`, and more

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #VoiceAI #FlutterTips
