---
title: "Building a Viral Loop: Guitar Recording → Auto-Post to X (Fire-and-Forget Pattern)"
tags: Flutter,Supabase,buildinpublic,X,webdev
published: true
---

# Building a Viral Loop: Guitar Recording → Auto-Post to X (Fire-and-Forget Pattern)

## The Problem: Nobody Knows Your App Exists

[自分株式会社](https://my-web-app-b67f4.web.app/) had 4 registered users when I wrote this. The challenge every indie dev faces: you can build features all day, but if nobody discovers the app, it doesn't matter.

The solution: **viral coefficient k > 1**.

```
k = (users who share) × (new users per share)
```

If every user who records guitar and makes it public automatically posts to X, and even 5% of their followers sign up, k approaches 1. Stack a few features like this and you have organic growth without ads.

---

## The Pipeline

```
Flutter UI → guitar-recording-studio EF → post-x-update EF → X API
```

Three components:
1. User records guitar and taps "Make Public"
2. Edge Function saves the recording and fires an X post **without waiting**
3. User sees "Posted to X!" confirmation in the UI

---

## The Fire-and-Forget Pattern

The key technique: don't `await` the X post. Return the response to the user immediately and let the post happen in the background.

```typescript
// guitar-recording-studio/index.ts
const savedRow = await saveRecording(body);

// Kick off X post without blocking the response
if (savedRow.is_public) {
  postPublicRecordingToX(savedRow); // intentionally no await
}

return new Response(JSON.stringify({
  success: true,
  recordingId: savedRow.id,
  xPosted: savedRow.is_public,  // flag for the Flutter client
}));
```

**Why no `await`**: X's API can take 1-3 seconds. If you `await` it, the user waits for X's response before seeing their recording saved. With fire-and-forget, the save confirms instantly and the X post happens asynchronously.

**Trade-off**: If the X post fails silently, there's no retry. For a best-effort "share" feature (not a critical transaction), this is acceptable.

---

## The X Post Helper

```typescript
async function postPublicRecordingToX(
  recording: GuitarRecordingRow
): Promise<void> {
  const shareUrl = buildShareUrl(recording.id);
  const text = [
    `🎸 New guitar recording!`,
    `"${recording.title}"`,
    shareUrl,
    `#guitar #FlutterWeb #buildinpublic`,
  ].join('\n');

  // Soft limit check (X counts Unicode chars, not bytes)
  if ([...text].length > 280) {
    console.warn('Tweet too long, will be truncated by X');
  }

  await fetch(`${SUPABASE_URL}/functions/v1/post-x-update`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
    body: JSON.stringify({ text }),
  });
}
```

Note `[...text].length` (not `text.length`) for accurate Unicode character counting — emojis are multi-byte but count as 1 character on X.

---

## Flutter: Show the "Posted to X" Confirmation

The Edge Function returns `xPosted: true` when the recording was public. Flutter uses this flag to show a confirmation snackbar:

```dart
final data = res.data as Map<String, dynamic>?;
final xPosted = data?['xPosted'] == true;

if (mounted && xPosted) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('🎸 Recording saved and posted to X!'),
      backgroundColor: Color(0xFF1DA1F2),
      duration: Duration(seconds: 4),
    ),
  );
}
```

The `mounted` check is required after any `async` gap in Flutter 3.33+.

---

## X OAuth 1.0a in Deno (WebCrypto)

X API v2 requires OAuth 1.0a with HMAC-SHA1 signatures. Deno's WebCrypto API handles this:

```typescript
const signature = await computeHmacSha1(
  `${consumerSecret}&${tokenSecret}`,
  signatureBase,
);

async function computeHmacSha1(key: string, data: string): Promise<string> {
  const encoder = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(key),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    cryptoKey,
    encoder.encode(data),
  );
  return btoa(String.fromCharCode(...new Uint8Array(signature)));
}
```

No npm packages needed — Deno's built-in WebCrypto covers HMAC-SHA1.

---

## Edge Function Quota Constraint → Action Pattern

At the time I was at 93/94 deployed functions. Adding a new function would hit the limit. Solution: extend `guitar-recording-studio` with a new action instead:

```typescript
switch (action) {
  case 'save_recording':  return await saveRecording(auth, body);
  case 'share_to_x':      return await shareToX(auth, body);
  case 'public_gallery':  return await getPublicGallery(auth, body);
  case 'delete':          return await deleteRecording(auth, body);
}
```

The action-based switch pattern lets one Edge Function handle multiple responsibilities without hitting quota limits.

---

## Does the Viral Loop Work?

Viral coefficient measurement requires more users than I had when building this. But the mechanism is sound:

1. User creates content (recording)
2. Content is automatically shared with attribution
3. Their audience discovers the app
4. Some percentage signs up

Every feature that creates public content with an automatic X post is a potential viral loop. Guitar recordings are just the first.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #webdev
