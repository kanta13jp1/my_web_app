---
title: FlutterとSupabase Edge Functionsで「絵文字リアクション」を匿名実装した話
emoji: 🎉
type: tech
topics: [flutter, supabase, deno, webdev, buildinpublic]
published: true
---

# はじめに — 2026-03-28-public-memo-reactions

公開メモへの「👍❤️🔥💡🎉」絵文字リアクションを、**ログイン不要**で実装しました。

X(Twitter) のリプライや Medium の Claps のように、読んだ人が一発でリアクションできる仕組みです。
今回は「IP ハッシュで重複防止」「Edge Function で toggle」「Flutter でアニメーション付き UI」の3つを解説します。

---

# 技術スタック

- **フロントエンド**: Flutter Web (Dart)
- **バックエンド**: Supabase Edge Function (Deno)
- **DB**: PostgreSQL (Supabase)
- **認証**: なし (anon アクセス)

---

# DB 設計

```sql
CREATE TABLE memo_reactions (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id    integer     NOT NULL REFERENCES public_memos(id) ON DELETE CASCADE,
  reaction   text        NOT NULL CHECK (reaction IN ('👍','❤️','🔥','💡','🎉')),
  ip_hash    text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 1 IPアドレス × 1 絵文字 × 1 メモで重複防止
CREATE UNIQUE INDEX memo_reactions_dedup
  ON memo_reactions (memo_id, ip_hash, reaction);
```

`ip_hash` は `SHA-256(prefix + IP)` の先頭16桁なので元のIPは復元不可能。RLS は SELECT/INSERT を全開放し、Edge Function 側で制御します。

---

# Edge Function: memo-reactions

### GET — リアクション一覧取得

```
GET /memo-reactions?memo_id=42
→ { reactions: {"👍":3,"❤️":1,...}, userReactions: ["👍"] }
```

### POST — トグル (押す/外す)

```
POST /memo-reactions
{ "memo_id": 42, "reaction": "👍" }
→ { ok: true, added: true, counts: {"👍":4,...} }
```

**ポイント**: INSERT が UNIQUE 違反 → DELETE でトグルオフを実現。

```typescript
const { error: insertErr } = await client.from("memo_reactions").insert({
  memo_id: memoId, reaction, ip_hash: ipHash,
});
if (insertErr) {
  // unique violation → toggle off
  await client.from("memo_reactions").delete()
    .eq("memo_id", memoId).eq("ip_hash", ipHash).eq("reaction", reaction);
  added = false;
}
```

---

# Flutter UI

`_MemoReactionsBar` ウィジェットはシンプルな `Wrap` + `AnimatedContainer` で実装。

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  decoration: BoxDecoration(
    color: active ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: active ? colorScheme.primary : Colors.transparent),
  ),
  child: Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    if (count > 0) Text('$count'),
  ]),
)
```

- 押すと即座にカウントが+1（楽観的更新なし、Edge Function レスポンスを待つシンプル設計）
- `_reactionsLoading` フラグで二重タップを防止

---

# 詰まったポイント

**問題**: Flutter Web から `http` パッケージで Edge Function を直接呼び出す際、CORS エラーが出ることがある。
**解決**: Edge Function に `Access-Control-Allow-Origin: *` ヘッダーを追加し、OPTIONS プリフライトを正しく返す。

**問題**: Emoji は `text CHECK (reaction IN (...))` の DB 制約と、Dart 側の `_kAllReactions` リストが一致しないとバグる。
**解決**: Edge Function の `ALLOWED_REACTIONS` と Dart の `_kAllReactions` を同一の5種に統一。

---

# まとめ

- DB の UNIQUE インデックスだけでトグル機能が実現できる
- IP ハッシュで匿名 + プライバシー保護を両立
- `AnimatedContainer` で押した感触を演出
- 全体で 200行未満のシンプルな実装

サービス URL: https://my-web-app-b67f4.web.app/

#FlutterWeb #Supabase #buildinpublic
