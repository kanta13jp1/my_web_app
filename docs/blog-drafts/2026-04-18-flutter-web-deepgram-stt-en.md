---
title: "Flutter Web Speech-to-Text with Deepgram Nova-2 and MediaRecorder"
tags: Flutter,Supabase,buildinpublic,webdev,FlutterTips
published: true
---

# Flutter Web Speech-to-Text with Deepgram Nova-2 and MediaRecorder

Follow-up to my TTS post. Here's the input side: recording audio in Flutter Web with `MediaRecorder`, converting to base64, sending to Deepgram Nova-2 via a Supabase Edge Function, and displaying the transcript.

## Architecture

```
Flutter Web
  → MediaRecorder records audio/webm
  → stop → Blob → ArrayBuffer → base64
  → ai-hub EF (voice.stt)
    → Deepgram Nova-2 /v1/listen
    → transcript string
  → setState → display
```

## Edge Function — Deepgram STT

```typescript
// supabase/functions/ai-hub — voice.stt
case "voice.stt": {
  const audioBase64 = String(body.audio_base64 ?? "");
  const language    = String(body.language ?? "ja");
  const deepgramKey = Deno.env.get("DEEPGRAM_API_KEY") ?? "";
  if (!deepgramKey) return json({ error: "DEEPGRAM_API_KEY not configured" }, 503);

  const audioBytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));

  const dgResp = await fetch(
    `https://api.deepgram.com/v1/listen?language=${language}&model=nova-2&punctuate=true`,
    {
      method: "POST",
      headers: { "Authorization": `Token ${deepgramKey}`, "Content-Type": "audio/webm" },
      body: audioBytes,
    },
  );

  const dgData   = await dgResp.json();
  const text     = dgData.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? "";
  return json({ success: true, transcript: text });
}
```

`nova-2` + `punctuate=true` — best accuracy for Japanese.

## Flutter — Start Recording

```dart
import 'package:web/web.dart' as web;
import 'dart:js_interop';

final List<JSObject> _audioChunks = [];
web.MediaRecorder? _mediaRecorder;

Future<void> _startRecording() async {
  final stream = await web.window.navigator.mediaDevices
      .getUserMedia(web.MediaStreamConstraints(audio: true.jsify()!))
      .toDart;

  final mimeType = web.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
      ? 'audio/webm;codecs=opus'
      : 'audio/webm';

  _mediaRecorder = web.MediaRecorder(
    stream,
    web.MediaRecorderOptions(mimeType: mimeType),
  );
  _mediaRecorder!.addEventListener('dataavailable', (web.Event e) {
    final blob = (e as web.BlobEvent).data;
    if (blob.size > 0) _audioChunks.add(blob as JSObject);
  }.toJS);

  _audioChunks.clear();
  _mediaRecorder!.start();
}
```

## Flutter — Stop, Convert, Transcribe

```dart
Future<void> _stopAndTranscribe() async {
  final completer = Completer<String>();

  _mediaRecorder!.addEventListener('stop', (web.Event _) async {
    // Merge chunks into one Blob
    final blob = web.Blob(
      [_audioChunks.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/webm'),
    );

    // Blob → ArrayBuffer → Uint8List → base64
    final ab    = await blob.arrayBuffer().toDart;
    final bytes = Uint8List.view(ab.toDart);
    final b64   = base64Encode(bytes);

    final resp = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {'action': 'voice.stt', 'audio_base64': b64, 'language': 'ja'},
    );
    final data = resp.data as Map<String, dynamic>?;
    completer.complete(data?['transcript'] as String? ?? '');
  }.toJS);

  _mediaRecorder!.stop();
  setState(() => _transcribedText = await completer.future);
}
```

## Deepgram Model Options

| Model | Notes | Use case |
|-------|-------|----------|
| `nova-2` | Highest accuracy, multilingual | Quiz answers (Japanese) |
| `nova` | Balanced | General |
| `base` | Lightweight, low cost | Speed-critical |

## Key Takeaways

1. **Record as `audio/webm`** — Deepgram accepts it directly; prefer `codecs=opus`
2. **Blob → ArrayBuffer → base64** — cleanest path to JSON-serializable audio
3. **EF decodes base64 → Uint8Array** — then sends raw bytes to Deepgram
4. **`punctuate=true`** — auto-inserts punctuation in Japanese transcripts

Combined with TTS (ElevenLabs), this completes the voice loop: hear the question → speak the answer → get scored.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #STT #FlutterTips
