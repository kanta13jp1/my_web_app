---
title: "Flutter × Supabase Edge Function でギター録音をXに自動投稿するバイラルパイプラインを実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,バイラル
published: true
---

# ブログ下書き 2026-04-08 — 2026-04-08-x-viral-pipeline-catalog-expansion

## タイトル案
1. FlutterとSupabase Edge FunctionでギターレコーディングをX自動投稿するバイラルパイプラインを作った話
2. 個人開発アプリにバイラル係数>1を仕込む：録音→X自動投稿の実装全解説
3. fire-and-forgetパターンで実現するギター録音のX自動投稿：ユーザー獲得の技術的アプローチ

## 投稿先候補
- [x] Zenn
- [x] Qiita
- [ ] note
- [x] dev.to
- [ ] はてなブログ

## 本文下書き (2000字)

### はじめに

21の競合SaaSを1アプリに統合する「自分株式会社」を個人開発しています。
登録者4人という現実と向き合いながら、バイラル係数>1を目指して機能を積み上げています。

今回は「ギター録音 → X(Twitter)自動投稿パイプライン」の実装を解説します。

---

### なぜバイラルパイプラインが必要か

個人開発アプリで最大の課題は「誰も知らない」ことです。
SEO・ブログ・広告…すべてに共通する解決策として**バイラル係数 k > 1**を目指す必要があります。

`k = (感染ユーザー数) × (紹介率) = ユーザーが1人のとき、平均何人新規を連れてくるか`

録音を公開する → X に自動投稿される → フォロワーがアプリを知る → 登録

このループを作れれば、ユーザーが増えるほど自動的に認知が広がります。

---

### 実装構成

```
Flutter (フロント) → guitar-recording-studio Edge Function → post-x-update Edge Function
```

#### 1. Edge Function の fire-and-forget パターン

```typescript
// guitar-recording-studio/index.ts
const savedRow = await saveRecording(body);

// Auto-post to X when recording is made public
if (savedRow.is_public) {
  postPublicRecordingToX(savedRow); // fire-and-forget
}

return {
  success: true,
  recordingId,
  xPosted: savedRow.is_public,
};
```

`await` しないことで、X投稿の成否に関わらずユーザーへのレスポンスが即座に返ります。
X APIの遅延（1〜3秒）をユーザーに待たせずに済む設計です。

#### 2. X投稿ヘルパー

```typescript
async function postPublicRecordingToX(recording: GuitarRecordingRow): Promise<void> {
  const shareUrl = buildShareUrl(recording.id);
  const text = [
    `🎸 新しいギター演奏を録音しました！`,
    `「${recording.title}」`,
    `${shareUrl}`,
    `#ギター録音 #FlutterWeb #buildinpublic`,
  ].join('\n');

  // 280字チェック
  if ([...text].length > 280) {
    console.warn('Tweet text exceeds 280 chars, truncating');
  }

  const xPostUrl = `${SUPABASE_URL}/functions/v1/post-x-update`;
  await fetch(xPostUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
    body: JSON.stringify({ text }),
  });
}
```

#### 3. Flutter フロント側でのフィードバック表示

```dart
// guitar_recording_studio_page.dart
final data = _parseResponse(res.data);
final xPosted = data?['xPosted'] == true;

// ...setState...

if (mounted && xPosted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('🎸 録音を保存し、Xに自動投稿しました！'),
      backgroundColor: Color(0xFF1DA1F2),
      duration: Duration(seconds: 4),
    ),
  );
}
```

`xPosted` フラグをレスポンスから取得し、ユーザーに投稿成功を通知します。

---

### 詰まったポイント

#### X OAuth 1.0a 署名

X API v2 (OAuth 1.0a) の署名計算は複雑です。
HMAC-SHA1 + Base64 エンコードを Deno の WebCrypto API で実装しました。

```typescript
const signature = await computeHmacSha1(
  `${consumerSecret}&${tokenSecret}`,
  signatureBase,
);
```

#### Supabase quota 制約

現在 93/94 functions deployed。新規Edge Functionを追加する代わりに、
`guitar-recording-studio` にアクションを追加する方式を採用しました。

```typescript
switch (action) {
  case 'save_recording': return await saveRecording(auth, body);
  case 'share_to_x':    return await shareToX(auth, body);
  case 'public_gallery': return await getPublicGallery(auth, body);
  // ...
}
```

1関数で複数の責務を持たせる「アクション拡張パターン」でquotaを節約。

---

### まとめ

- fire-and-forgetで非同期X投稿 → UXを損なわずバイラルループを構築
- `xPosted`フラグでフロントへの通知 → ユーザーがシェアされたことを即座に確認
- Supabase quotaを意識したアクション拡張パターン → 1関数で多機能実現

バイラル係数の実測は今後のデータ次第ですが、「録音して公開するだけでXに拡散される」
体験は新規ユーザーへの動機付けになると考えています。

---

URL: https://my-web-app-b67f4.web.app/guitar-recording-studio
#FlutterWeb #Supabase #buildinpublic #ギター録音 #X自動投稿
