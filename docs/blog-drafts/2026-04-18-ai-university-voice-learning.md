---
title: "Flutter Web で音声学習を実装した — ElevenLabs TTS + Web Speech API フォールバック"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# Flutter Web で音声学習を実装した — ElevenLabs TTS + Web Speech API フォールバック

## はじめに

自分株式会社 AI大学に**音声学習モード**を実装しました。クイズ問題を音声で読み上げ、回答も音声入力できます。

**ポイント**: ElevenLabs の高品質 TTS を第一候補にしつつ、APIキー未設定や free-tier 制限時はブラウザ内蔵の **Web Speech API に自動フォールバック**するため、常に動作します。

## アーキテクチャ

```
Flutter _playTts(text)
  → ai-hub EF (voice.tts)
    → ElevenLabs eleven_multilingual_v2
    → 失敗時: { fallback: "webspeech" } を返す
  → フォールバック: window.speechSynthesis (ブラウザ内蔵・無料)
```

## Edge Function: ElevenLabs TTS

```typescript
// supabase/functions/ai-hub — voice.tts
case "voice.tts": {
  const elevenKey = Deno.env.get("ELEVENLABS_API_KEY") ?? "";
  if (!elevenKey) {
    // APIキー未設定 → クライアントに Web Speech 利用を指示
    return json({ success: false, fallback: "webspeech", text });
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
    // Free-tier 制限 → フォールバック通知
    if (errText.includes("paid_plan_required")) {
      return json({ success: false, fallback: "webspeech", text });
    }
    return json({ error: errText, fallback: "webspeech", text }, 502);
  }

  // バイナリ → base64 変換して返す
  const bytes = new Uint8Array(await ttsResp.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
  return json({ success: true, audio_base64: btoa(binary) });
}
```

`audio_base64` で返すのは Flutter Web の `HTMLAudioElement` が `data:` URL を受け付けるため。

## Flutter: TTS 再生 + フォールバック

```dart
// lib/pages/ai_university_voice_page.dart
Future<void> _playTts(String text) async {
  setState(() => _ttsStatus = 'loading');
  try {
    final resp = await _supabase.functions.invoke(
      'ai-hub',
      body: {'action': 'voice.tts', 'text': text},
    );
    final data = resp.data as Map<String, dynamic>?;
    final base64Audio = data?['audio_base64'] as String? ?? '';
    final fallback    = data?['fallback']     as String? ?? '';

    if (base64Audio.isEmpty) {
      if (fallback == 'webspeech') {
        _speakViaWebSpeech(text);  // ブラウザ内蔵で再生
        return;
      }
      setState(() => _ttsStatus = 'error');
      return;
    }

    // ElevenLabs 音声を HTMLAudioElement で再生
    _audio = web_api.HTMLAudioElement();
    _audio!.src = 'data:audio/mpeg;base64,$base64Audio';
    _audio!.play();
    setState(() => _ttsStatus = 'playing');
  } catch (_) {
    setState(() => _ttsStatus = 'error');
  }
}
```

## Web Speech API フォールバック

```dart
void _speakViaWebSpeech(String text) {
  final utter = web_api.SpeechSynthesisUtterance(text);
  utter.lang = 'ja-JP';
  utter.rate = 1.0;
  web_api.window.speechSynthesis.cancel();  // 前の発話をキャンセル
  web_api.window.speechSynthesis.speak(utter);
  setState(() => _ttsStatus = 'playing');
}
```

`package:web/web.dart` の `window.speechSynthesis` はブラウザネイティブのため追加コストゼロ。Chrome/Edge/Safari 対応。

## フォールバック戦略まとめ

| 状況 | 動作 | 品質 |
|------|------|------|
| ELEVENLABS_API_KEY 設定済み | ElevenLabs TTS | 高品質多言語音声 |
| APIキー未設定 | Web Speech API | ブラウザ内蔵 (無料) |
| Free-tier 制限 | Web Speech API | ブラウザ内蔵 (無料) |
| EF エラー | Web Speech API | ブラウザ内蔵 (無料) |

どの状態でも音声再生が止まりません。

## まとめ

1. **base64 経由でバイナリ音声を EF から返す** — Flutter Web は `data:audio/mpeg;base64,...` を直接 `HTMLAudioElement.src` に設定できる
2. **EF が `{ fallback: "webspeech" }` を返すだけ** — クライアント側で Web Speech に切り替えるシンプルな設計
3. **`package:web/web.dart` で統一** — `HTMLAudioElement` も `SpeechSynthesisUtterance` も同じパッケージ

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #音声AI
