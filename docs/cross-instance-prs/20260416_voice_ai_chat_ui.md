# cross-instance-pr: 音声AIチャット UI実装

作成: Windows版#64 (2026-04-16)
宛先: VSCode版
状態: ✅ 完了 (VSCode版#80, 2026-04-17)

## 背景

Voice AI GMAT Tutor with Long-Term Memory (dev.to記事) のパターンを自分株式会社に適用。
Windows版#64 で以下を実装済み:
- `supabase/migrations/20260416140000_create_conversation_messages.sql`
  - `user_conversations` テーブル (セッション管理)
  - `conversation_messages` テーブル (user/assistantメッセージ、voice_used フラグ)
- `supabase/functions/ai-assistant/index.ts`: `chat` action 追加
  - 直近10件の会話履歴をコンテキスト注入 (長期記憶)
  - `conversationId` で会話セッション管理
  - `voiceUsed` フラグ対応

## VSCode版タスク

### 1. `lib/pages/ai_assistant_chat_page.dart` 新規作成

```dart
// 音声AIアシスタント チャット画面
// - Web Speech API (SpeechRecognition) でマイク入力
// - SpeechSynthesis API で音声出力
// - ai-assistant EF の chat action を呼ぶ
// - DesignTokens (Orange+Indigo) 適用

// EF呼び出し例:
// POST /ai-assistant
// { "action": "chat", "message": userText, "conversationId": _convId,
//   "voiceUsed": _voiceMode, "conversationContext": "general_chat" }
// → { "reply": "...", "conversationId": "uuid", "messageId": "uuid" }
```

主要ウィジェット:
- `ChatBubble` (user: 右寄せ orange, assistant: 左寄せ indigo)
- `VoiceInputButton` (マイク → `window.SpeechRecognition` → テキスト認識)
- `SpeakerButton` (メッセージごと → `window.speechSynthesis.speak()`)
- `VoiceModeToggle` (オン時: 応答を自動読み上げ)

Web Speech API アクセス方法 (dart:js or package:web):
```dart
import 'package:web/web.dart' as web;
// or
import 'dart:js' as js;

// STT
final recognition = js.JsObject(js.context['webkitSpeechRecognition']);
recognition['lang'] = 'ja-JP';
recognition['onresult'] = (e) { ... };
recognition.callMethod('start');

// TTS
final utterance = js.JsObject(js.context['SpeechSynthesisUtterance'], [text]);
js.context['speechSynthesis'].callMethod('speak', [utterance]);
```

### 2. `lib/main.dart` にルート追加

```dart
'/ai-assistant-chat': (context) => const AiAssistantChatPage(),
```

### 3. `lib/pages/landing_page.dart` に機能追加

LP の「コア機能」リストに追記:
```
音声AIアシスタント（会話・長期記憶）
```

## EF chat action の仕様

```
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-assistant
Authorization: Bearer <user_jwt>
{
  "action": "chat",
  "message": "今日のタスクを整理して",
  "conversationId": "uuid-or-empty-for-new",
  "conversationContext": "general_chat",
  "voiceUsed": false,
  "model": "claude-sonnet-4-6"  // optional
}

Response:
{
  "success": true,
  "reply": "了解です。以下のタスクを整理しました...",
  "conversationId": "abc-123-def",
  "messageId": "msg-456"
}
```

## 参考

- 元記事: "I Built a Voice AI GMAT Tutor with Long-Term Memory in 6 Weeks"
- NotebookLM: c7e786bb-b4fb-466e-9382-efdb739b992f
- DB migration: `20260416140000_create_conversation_messages.sql`
- EF: `supabase/functions/ai-assistant/index.ts` (chat action, lines ~749)
