---
title: "Flutter Web で音声認識 (STT) を実装した — Deepgram Nova-2 + MediaRecorder"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# Flutter Web で音声認識 (STT) を実装した — Deepgram Nova-2 + MediaRecorder

## はじめに

自分株式会社の AI 大学に**音声認識 (STT)** を実装しました。ブラウザの `MediaRecorder` API で録音 → base64 変換 → Supabase Edge Function 経由で Deepgram Nova-2 に送信 → テキストに変換する流れです。

TTS 記事 (ElevenLabs + Web Speech API フォールバック) の続編として、音声学習の入力側を解説します。

## アーキテクチャ

```
Flutter Web (MediaRecorder)
  → 録音停止時に audioChunks を Blob → base64
  → ai-hub EF (voice.stt)
    → Deepgram Nova-2 /v1/listen
    → transcript テキストを返す
  → Flutter UI に転写結果を表示
```

## Edge Function: Deepgram STT

```typescript
// supabase/functions/ai-hub — voice.stt
case "voice.stt": {
  const audioBase64 = String(body.audio_base64 ?? "");
  const language    = String(body.language ?? "ja");
  const deepgramKey = Deno.env.get("DEEPGRAM_API_KEY") ?? "";
  if (!deepgramKey) return json({ error: "DEEPGRAM_API_KEY not configured" }, 503);

  // base64 → Uint8Array
  const audioBytes = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));

  const dgResp = await fetch(
    `https://api.deepgram.com/v1/listen?language=${language}&model=nova-2&punctuate=true`,
    {
      method: "POST",
      headers: {
        "Authorization": `Token ${deepgramKey}`,
        "Content-Type": "audio/webm",
      },
      body: audioBytes,
    },
  );

  const dgData = await dgResp.json();
  const transcriptText =
    dgData.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? "";

  return json({ success: true, transcript: transcriptText });
}
```

`model=nova-2&punctuate=true` で句読点付きの日本語転写ができます。

## Flutter Web: MediaRecorder で録音

```dart
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:convert';

// 録音チャンクを蓄積
final List<JSObject> _audioChunks = [];
web.MediaRecorder? _mediaRecorder;

Future<void> _startRecording() async {
  final stream = await web.window.navigator.mediaDevices
      .getUserMedia(web.MediaStreamConstraints(audio: true.jsify()!))
      .toDart;

  // audio/webm;codecs=opus を優先 (Deepgram 対応形式)
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

## 録音停止 → base64 変換 → STT 送信

```dart
Future<void> _stopAndTranscribe() async {
  if (_mediaRecorder == null) return;

  // 録音停止イベントを待つ
  final completer = Completer<String>();
  _mediaRecorder!.addEventListener('stop', (web.Event _) async {
    // chunks を1つの Blob に結合
    final blob = web.Blob(
      [_audioChunks.toJS].toJS,
      web.BlobPropertyBag(type: 'audio/webm'),
    );

    // Blob → ArrayBuffer → Uint8List → base64
    final arrayBuffer = await blob.arrayBuffer().toDart;
    final bytes = Uint8List.view(arrayBuffer.toDart);
    final base64Audio = base64Encode(bytes);

    // Edge Function に送信
    final resp = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {'action': 'voice.stt', 'audio_base64': base64Audio, 'language': 'ja'},
    );
    final data = resp.data as Map<String, dynamic>?;
    completer.complete(data?['transcript'] as String? ?? '');
  }.toJS);

  _mediaRecorder!.stop();
  final transcript = await completer.future;
  setState(() => _transcribedText = transcript);
}
```

## Deepgram モデル選択

| モデル | 特徴 | 用途 |
|--------|------|------|
| `nova-2` | 最高精度・多言語対応 | 日本語クイズ回答 |
| `nova` | バランス型 | 一般用途 |
| `base` | 軽量・低コスト | 高速処理優先 |

日本語は `nova-2` + `language=ja` の組み合わせが最も精度が高いです。

## まとめ

1. **MediaRecorder → `audio/webm`** — Deepgram が対応する形式で録音
2. **Blob → ArrayBuffer → base64** — EF に JSON で送れるよう変換
3. **EF で base64 → Uint8Array** → Deepgram へバイナリ送信
4. **`punctuate=true`** — 日本語の句読点を自動付与

TTS (ElevenLabs) と STT (Deepgram) を組み合わせると「問題を聞く → 音声で答える」完全な音声学習ループが完成します。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #音声認識
