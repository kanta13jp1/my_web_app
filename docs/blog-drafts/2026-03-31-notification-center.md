---
title: "Flutter WebでSupabaseを使ったアプリ内通知センターを実装した話"
emoji: "🔔"
type: "tech"
topics: ["flutter", "supabase", "dart", "web"]
published: false
---

# Flutter WebでSupabaseを使ったアプリ内通知センターを実装した話

自分株式会社アプリに**アプリ内通知センター**を実装しました。Supabase Edge FunctionをバックエンドにFlutter Webで未読バッジ付き通知UIを作る手順を解説します。

---

## 作ったもの

- AppBarに未読カウントバッジ付きの🔔ベルアイコン
- 通知一覧ページ（未読/既読/すべてフィルター）
- 既読マーク・全既読ボタン
- 7種類の通知カテゴリ（新機能・実績・CS返信・システム・マーケティング・ブログ・エージェント）

---

## テーブル設計

```sql
CREATE TABLE app_notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE, -- null = 全員向け
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'system',
  link text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

`user_id IS NULL` の通知はすべてのユーザーに表示されます。これで「全体向けお知らせ」と「個人向けCSS返信」を同じテーブルで管理できます。

RLSポリシー:

```sql
-- ユーザーは自分宛 or 全体向けの通知を読める
CREATE POLICY "users_read_own_notifications" ON app_notifications
  FOR SELECT USING (
    auth.uid() = user_id OR user_id IS NULL
  );
```

---

## Edge Function: notification-center

3つのエンドポイントを1つのEdge Functionで提供:

- `GET ?mode=user&filter=unread` → 未読通知一覧 + 未読数
- `GET ?mode=admin` → 管理者向け全通知
- `POST {action: "mark_read", notification_id: "..."}` → 既読マーク
- `POST {action: "mark_read", mark_all: true}` → 全既読

未読数は別クエリで集計して返します:

```typescript
const { count: unreadCount } = await adminClient
  .from("app_notifications")
  .select("*", { count: "exact", head: true })
  .or(`user_id.eq.${user.id},user_id.is.null`)
  .eq("is_read", false);
```

---

## Flutter: 未読バッジ付きAppBar

`Stack` + `Positioned` で既存の `IconButton` の上にバッジを乗せます:

```dart
Stack(
  alignment: Alignment.center,
  children: [
    IconButton(
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () async {
        await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()));
        _fetchNotifUnreadCount(); // 戻ったら再取得
      },
    ),
    if (_notifUnreadCount > 0)
      Positioned(
        top: 8, right: 8,
        child: Container(
          width: 16, height: 16,
          decoration: const BoxDecoration(
            color: Colors.red, shape: BoxShape.circle),
          child: Center(
            child: Text(
              _notifUnreadCount > 9 ? '9+' : '$_notifUnreadCount',
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
      ),
  ],
),
```

---

## Flutter: 通知一覧ページ

`supabase.functions.invoke` でEdge Functionを呼び出します:

```dart
final response = await _supabase.functions.invoke(
  'notification-center',
  queryParameters: {'mode': 'user', 'filter': _filter},
);
final data = response.data;
_notifications = (data['notifications'] as List).cast<Map<String, dynamic>>();
_unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
```

通知タイプごとにアイコン・カラーを定義した `_NotifMeta` クラスでUIを差別化:

```dart
static const Map<String, _NotifMeta> _typeMeta = {
  'feature_update': _NotifMeta(Icons.new_releases, Color(0xFF6366F1), '新機能'),
  'achievement': _NotifMeta(Icons.emoji_events, Color(0xFFF59E0B), '実績'),
  'cs_reply': _NotifMeta(Icons.support_agent, Color(0xFF10B981), 'CS返信'),
  // ...
};
```

---

## dart:html 廃止対応

CSV ダウンロードで使っていた `dart:html` を `package:web` に移行:

```dart
// Before (deprecated)
import 'dart:html' as html;
final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
final url = html.Url.createObjectUrlFromBlob(blob);
final anchor = html.AnchorElement(href: url)..click();

// After (dart:js_interop + package:web)
import 'dart:js_interop';
import 'package:web/web.dart' as web;
final blob = web.Blob([csvBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'));
final url = web.URL.createObjectURL(blob);
web.HTMLAnchorElement()
  ..href = url
  ..download = 'file.csv'
  ..click();
web.URL.revokeObjectURL(url);
```

`List<int>` に `.toJS` は使えないので、事前に `Uint8List.fromList(bytes)` で変換します。

---

## まとめ

- Supabase `app_notifications` テーブルで全体向け/個人向け通知を一元管理
- Edge Functionで認証・フィルタリングをバックエンドに集約
- Flutter Webでバッジ付きベルアイコン + 通知一覧ページを実装
- `dart:html` → `package:web` の移行パターンも同時解決

flutter analyze 0件を維持しつつ、フロントエンドとバックエンドを綺麗に分離した実装になりました。

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #通知センター
