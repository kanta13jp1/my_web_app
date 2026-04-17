---
title: "Guitar Recording → Auto-Post to X: OAuth 1.0a Server-Side + Twitter Intent Fallback"
tags: Flutter,Supabase,buildinpublic,X,OAuth
published: true
---

# Guitar Recording → Auto-Post to X: OAuth 1.0a Server-Side + Twitter Intent Fallback

## The Architecture

```
Flutter UI (guitar_recording_studio_page.dart)
  └─ _postToX(title, recordingId, isPublic: true)
       └─ supabase.functions.invoke('guitar-recording-studio', {action: 'share_to_x'})
            └─ guitar-recording-studio Edge Function
                 └─ postPublicRecordingToX(recording)
                      └─ POST /functions/v1/post-x-update  ← OAuth 1.0a signed
                           └─ X API v2 POST /tweets
```

Three hops. Flutter → EF → X. No OAuth keys in the client.

---

## Flutter: `isPublic` Flag + Fallback

```dart
Future<void> _postToX(
  String title,
  String recordingId, {
  bool isPublic = false,
}) async {
  setState(() => _isPostingToX = true);
  try {
    final user = _supabase.auth.currentUser;
    
    // Auto-post path: public recording + logged-in user
    if (isPublic && recordingId.isNotEmpty && recordingId != 'unknown' && user != null) {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'share_to_x', 'recordingId': recordingId},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data?['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Posted to X (@kanta13jp1)'),
            backgroundColor: Color(0xFF1DA1F2),
          ),
        );
        return;
      }
      // EF failed → fall through to Twitter intent
    }

    // Fallback: Twitter intent (manual post, no OAuth needed)
    final intentUrl = Uri.parse('https://twitter.com/intent/tweet')
        .replace(queryParameters: {'text': '#guitar $title https://my-web-app-b67f4.web.app/'});
    web.window.open(intentUrl.toString(), '_blank');
  } finally {
    if (mounted) setState(() => _isPostingToX = false);
  }
}
```

**Why the fallback**: EF failures (network timeout, X API rate limit, OAuth key expired) should never block the user from sharing. The fallback opens a pre-filled tweet compose window — slightly more friction, but always works.

---

## Edge Function: Ownership Check + Share

```typescript
async function shareRecordingToX(auth: AuthContext, body: Json) {
  const user = requireUser(auth);
  const recordingId = normalizeString(body.recordingId);
  if (!recordingId) throw new Error("recordingId is required");

  // Verify ownership — user can only share their own recordings
  const { data: row } = await auth.adminClient
    .from("guitar_recordings")
    .select("*")
    .eq("id", recordingId)
    .eq("user_id", user.id)  // ownership check
    .single();

  if (!row?.is_public) throw new Error("Recording must be public to share");

  await postPublicRecordingToX(row as GuitarRecordingRow);
  return { success: true };
}
```

The `user_id` check means a user can't share someone else's recording even if they know the ID.

---

## Tweet Text: 280-Character Guard

X counts Unicode code points, not bytes. Emojis count as 1. A URL always counts as 23 characters regardless of length.

```typescript
const lines = [
  `🎸 New recording published!`,
  `"${recording.title}"`,
  `${durationStr} / ${preset}`,
  shareUrl,
  `#buildinpublic #FlutterWeb #guitar`,
];
let text = lines.join("\n");

// Soft limit — X handles actual truncation, but warn in logs
if ([...text].length > 280) {
  text = `🎸 "${shortTitle}"\n${shareUrl}\n#buildinpublic #guitar`;
}
```

`[...text].length` spreads the string into Unicode code points — correct for emoji counting. `text.length` counts UTF-16 code units which double-counts emoji.

---

## Security Design

| Threat | Defense |
|--------|---------|
| Client has OAuth keys | Keys stored only in Supabase Secrets, never in client |
| User shares others' recordings | `user_id = auth.uid()` filter in EF query |
| User shares private recordings | `is_public = true` check before sharing |
| EF leaks SERVICE_ROLE_KEY | EF receives user JWT, uses admin client internally only |

The Flutter client sends only a user JWT + `recordingId`. It never sees the X API credentials or the `SERVICE_ROLE_KEY`.

---

## Two Call Sites for `_postToX`

The function is called from two places:

1. **After saving a new recording**: passes `_isPublic` (the current toggle state)
2. **From the recording list**: passes `isPublicRec` (the per-item public flag)

```dart
// Call site 1: after save
_postToX(title, newRecordingId, isPublic: _isPublic);

// Call site 2: from list
_postToX(rec['title'], rec['id'], isPublic: rec['is_public'] == true);
```

Named parameter `isPublic:` makes the intent clear at both call sites.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #X #OAuth
