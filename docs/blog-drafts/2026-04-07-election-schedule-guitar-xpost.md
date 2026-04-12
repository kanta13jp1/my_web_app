---
title: 地方選挙±1年スケジュール表示とギタースタジオX自動投稿の完成 — Flutter×Supabase Build in Public
emoji: 🎸
type: tech
topics: [Flutter, Supabase, FlutterWeb, BuildInPublic]
published: true
---

# 地方選挙±1年スケジュール表示とギタースタジオX自動投稿の完成

## はじめに

自分株式会社 (https://my-web-app-b67f4.web.app/) の開発日記です。
今日は2つの機能改善を行いました。

1. **地方選挙スケジュールの±1年表示** — 過去1年〜未来1年の選挙情報を一覧できるように
2. **ギタースタジオX自動投稿の完成** — 録音保存後に自動投稿されたことをUIで確認できるように

## 1. 地方選挙スケジュール±1年表示

### 背景

これまで選挙スケジュールは「今日以降の選挙」しか表示していませんでした。
しかし、過去の選挙結果を参照したいニーズがあり、±1年の表示に対応しました。

### Edge Function の拡張

```typescript
// supabase/functions/local-election-intelligence/index.ts
const SCHEDULE_PAST_DAYS = 365;
const SCHEDULE_WINDOW_DAYS = 365; // 120 → 365 に拡大
const SCHEDULE_MAX_ENTRIES = 300; // 60 → 300 に拡大

// フィルタ条件を「today - 1年 ≤ voteDate ≤ today + 1年」に変更
// isPast フィールドを追加
```

### Dart モデルの拡張

```dart
// lib/models/local_election_reality.dart
class LocalElectionScheduleEntry {
  // 新フィールド追加
  final bool isPast;

  // isWithinDays で過去エントリを除外
  bool isWithinDays(int days) {
    if (isPast) return false;
    // ...
  }
}
```

### UIの改善

- **統一地方選挙2027カウントダウン** — 第一次・第二次公示日・投開票日の残日数を表示
- **過去/未来の分割表示** — 過去エントリは「過去1年の結果」として折りたたみ表示
- 過去エントリには「結果」バッジをつけてグレー表示

```dart
// lib/pages/election_victory_page.dart

Widget _buildUnifiedElectionCountdown() {
  // 2027年統一地方選の残日数カードを4セル表示
  // 第一次公示日 / 第一次投開票 / 第二次公示日 / 第二次投開票
}

Widget _buildScheduleSection(LocalElectionRealitySnapshot snapshot) {
  final pastSchedules = allSchedules.where((s) => s.isPast).toList();
  final futureSchedules = allSchedules.where((s) => !s.isPast).toList();

  // カウントダウンを先頭に挿入
  // 未来エントリを表示
  // 過去エントリは ExpansionTile で折りたたみ
}
```

## 2. ギタースタジオX自動投稿の完成

### 問題点

ギタースタジオの「公開録音」機能では、録音保存時にEdge Functionが自動でX (@kanta13jp1) に投稿していました。
しかし、UIにはその確認が表示されず、ユーザーは投稿されたかどうかわかりませんでした。

### 改善内容

録音保存成功後、`isPublic = true` のときにX自動投稿の確認バナーを表示しました。

```dart
if (_isPublic) ...[
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1DA1F2).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFF1DA1F2).withValues(alpha: 0.3),
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, color: Color(0xFF1DA1F2), size: 16),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('@kanta13jp1 に自動投稿しました 🐦'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed('/public-guitar-gallery'),
          child: const Text('ギャラリー →'),
        ),
      ],
    ),
  ),
  // 続いて共有リンクコピー・手動X投稿ボタン
]
```

### バックエンドの仕組み

Edge Function側ではすでに実装済み:

```typescript
// 録音保存時にfire-and-forgetでX投稿
case "save_recording":
  const result = await saveRecording(auth, body);
  // isPublic の場合、非同期でX投稿
  postPublicRecordingToX(savedRow); // fire-and-forget
  return jsonResponse(result);

async function postPublicRecordingToX(recording) {
  // post-x-update Edge Function を呼び出す
  // OAuth 1.0a で署名されたツイートを投稿
}
```

## まとめ

- **deno lint**: 0件 ✅
- **flutter analyze**: 0件 ✅
- 地方選挙スケジュール±1年表示で政治情報の充実度が向上
- ギタースタジオのX自動投稿UXが完成し、バイラル機能が完全稼働

自分株式会社は毎日コツコツ21競合を追いかけています 💪

URL: https://my-web-app-b67f4.web.app/
#buildinpublic #FlutterWeb #Supabase
