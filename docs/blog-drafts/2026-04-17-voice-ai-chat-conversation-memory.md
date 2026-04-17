---
title: "Flutter WebにVoice AI Chatと会話記憶を実装した話 — Web Speech API + Supabase"
tags: Flutter,Supabase,WebSpeechAPI,個人開発,buildinpublic
published: true
---

# Flutter WebにVoice AI Chatと会話記憶を実装した話

## はじめに

自分株式会社という個人開発アプリに、**音声でAIと対話できるチャット機能**と**会話履歴の永続化**を追加しました。

- Web Speech API（ブラウザ標準）でマイク入力 → テキスト変換
- Supabase の `conversation_messages` テーブルで会話履歴を保存
- Edge Function の `ai-assistant` に `chat` アクションを追加してLong-term Memory対応

実装してみて、思ったより少ないコードで動くことに驚きました。

## 技術構成

| レイヤー | 技術 |
|---|---|
| フロントエンド | Flutter Web + `package:web` |
| 音声認識 | Web Speech API (SpeechRecognition) |
| バックエンド | Supabase Edge Function (Deno) |
| 会話記憶 | Supabase PostgreSQL `conversation_messages` |
| AI | Claude Sonnet 4.6 |

## 実装の核心: Web Speech API

Flutter Web で音声認識する場合、`package:web` を使って直接ブラウザAPIを叩きます。

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

ポイントは `lang = 'ja-JP'` で日本語認識を有効にすること。`continuous: false` にしておくと1発話で自動停止するので扱いやすいです。

## 会話記憶: conversation_messages テーブル

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

`session_id` でセッションを区切りつつ、過去の会話を引き継げます。

## Edge Function: chat アクション

既存の `ai-assistant` Edge Function に `chat` アクションを追加しました。

```typescript
case 'chat': {
  const { message, sessionId, userId } = body;

  // 直近10件の会話履歴を取得
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

  // ユーザーメッセージと返答を保存
  await supabase.from('conversation_messages').insert([
    { user_id: userId, session_id: sessionId, role: 'user', content: message },
    { user_id: userId, session_id: sessionId, role: 'assistant', content: assistantMessage },
  ]);

  return new Response(JSON.stringify({ message: assistantMessage }));
}
```

会話履歴をそのままClaude APIの `messages` に渡すだけでLong-term Memoryが実現できます。

## 詰まったポイント

### Web Speech API の型定義

`SpeechRecognition` は `package:web` に含まれていますが、コールバックの型が JS interop 形式です。`onresult` に Dart 関数を渡す際は `.toJS` が必要です。

```dart
_recognition!.onresult = (event) { ... }.toJS; // .toJS 必須
```

### RLS (Row Level Security) の設定

`conversation_messages` テーブルにRLSを設定する際、`auth.users` テーブルの参照ではなく `user_profiles` テーブルを参照するポリシーを使うプロジェクトの場合は注意。`42P01` エラー（テーブル不存在）が出たら外部参照先を確認してください。

## まとめ

- Web Speech API は Flutter Web から `package:web` で素直に使える
- Supabase + Edge Function で会話履歴の永続化も数十行で実装可能
- Claude API はメッセージ配列をそのまま渡せばコンテキストを保持してくれる

個人開発でAIチャット機能を追加したい方の参考になれば嬉しいです。

---

自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
