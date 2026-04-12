---
title: FlutterとSupabase Edge Functionでギター録音をXに自動投稿するパイプラインを作った
emoji: 🎸
type: tech
topics: [Flutter, Supabase, X, Twitter, OAuth]
published: true
---

# FlutterとSupabase Edge Functionでギター録音をXに自動投稿するパイプラインを作った

## はじめに

「自分株式会社」は Notion・Evernote・Slack など 21 の競合 SaaS を超えることを目指す AI 統合ライフマネジメントアプリです。今回はギタースタジオ機能で録音した音声をワンクリックで X (@kanta13jp1) に自動投稿する仕組みを実装しました。

バイラル係数を上げるには「ユーザーの行動→SNS 拡散」の摩擦をゼロにすることが重要です。従来は Twitter intent URL を開いてユーザーが手動でツイートする仕組みでしたが、今回はサーバーサイドで OAuth 1.0a 署名して直接 X API v2 に投稿する完全自動パイプラインに進化させました。

## アーキテクチャ

```
Flutter UI (guitar_recording_studio_page.dart)
  └─ _postToX(title, recordingId, isPublic: true)
       └─ supabase.functions.invoke('guitar-recording-studio', body: {action: 'share_to_x', ...})
            └─ guitar-recording-studio Edge Function
                 └─ postPublicRecordingToX(recording)
                      └─ POST /functions/v1/post-x-update  ← OAuth 1.0a 署名
                           └─ X API v2 POST /tweets
```

## 実装の詳細

### Flutter 側: isPublic フラグで分岐

```dart
Future<void> _postToX(
  String title,
  String recordingId, {
  bool isPublic = false,
}) async {
  setState(() => _isPostingToX = true);
  try {
    final user = _supabase.auth.currentUser;
    // 公開録音 & ログイン済み → Edge Function で自動投稿
    if (isPublic && recordingId.isNotEmpty && recordingId != 'unknown' && user != null) {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'share_to_x', 'recordingId': recordingId},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data?['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ X に自動投稿しました (@kanta13jp1)'),
            backgroundColor: Color(0xFF1DA1F2),
          ),
        );
        return;
      }
      // Edge Function 失敗 → フォールバック
    }

    // フォールバック: Twitter intent (手動投稿)
    final intentUrl = 'https://twitter.com/intent/tweet?text=...';
    web.window.open(intentUrl, '_blank');
  } finally {
    if (mounted) setState(() => _isPostingToX = false);
  }
}
```

### Edge Function 側: OAuth 1.0a 署名

`guitar-recording-studio` Edge Function 内の `shareRecordingToX` アクションが `postPublicRecordingToX` を呼び出し、`post-x-update` Edge Function 経由で X API v2 に投稿します。

```typescript
async function shareRecordingToX(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const recordingId = normalizeString(body.recordingId);
  if (!recordingId) throw new Error("recordingId is required");

  const { data: row } = await auth.adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("id", recordingId)
    .eq("user_id", user.id)
    .single();

  if (!row?.is_public) throw new Error("Recording must be public to share");
  
  await postPublicRecordingToX(row as GuitarRecordingRow);
  return { success: true };
}
```

ツイートテキストは 280 字以内に自動トリミング:

```typescript
const lines = [
  `🎸 新しい録音を公開しました！`,
  `「${recording.title}」`,
  `${durationStr} / ${preset}`,
  shareUrl,
  `#buildinpublic #FlutterWeb #guitar`,
];
let text = lines.join("\n");
if (text.length > 280) {
  // タイトルを短縮してフォールバック
  text = `🎸 「${shortTitle}」を公開しました！\n${shareUrl}\n#buildinpublic #guitar`;
}
```

## セキュリティ設計

- Flutter クライアントは `SERVICE_ROLE_KEY` を持たない
- ユーザー JWT で Edge Function を呼び出し、Edge Function 内で `user_id` 一致を確認
- `is_public = true` のみシェア可能（RLS + アプリロジックの二重防衛）
- X API の OAuth 1.0a 署名はサーバーサイドのみで行われる

## 詰まったポイント

**Twitter intent vs 自動投稿の切り替え判断**

公開録音は Edge Function で自動投稿し、非公開録音や未ログインユーザーには従来の Twitter intent フォールバックを維持しました。こうすることで、どのケースでも「シェア」が機能します。

**isPublic パラメータの受け渡し**

`_postToX` の呼び出し箇所が 2 箇所（録音後の保存ダイアログ・録音一覧）あり、それぞれ `_isPublic`（State変数）と `isPublicRec`（リストアイテム変数）を `isPublic:` 名前付き引数で渡すようにしました。

## まとめ

ギター録音 → X 自動投稿パイプラインが完成しました。録音を公開設定で保存した後、「Xに投稿」ボタンを押すと OAuth 1.0a で署名されたリクエストが X API v2 に送られ、@kanta13jp1 アカウントから自動投稿されます。

この仕組みにより「録音 → 公開 → シェア」の流れが完全自動化され、バイラル係数向上が期待できます。

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #guitar
