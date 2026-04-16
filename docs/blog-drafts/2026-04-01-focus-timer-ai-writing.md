---
title: "Forest × Grammarly を Flutter Web で自前実装した話 — 集中タイマー & AI文章アシスタント同時開発"
tags: Flutter,Supabase,個人開発,buildinpublic,AI
published: false
---

# ブログ下書き 2026-04-01 (daily-development)

## タイトル案

1. Forest × Grammarly を Flutter Web で自前実装した話 — 集中タイマー & AI文章アシスタントを215本目のEdge Functionとして追加
2. ポモドーロタイマーをSupabaseで管理する — focus_sessions テーブル & Flutter CircularProgressIndicator
3. 「浪費耐性トレーニング」をホーム画面に統合 — AbstinenceDisciplineSnapshot で我慢回数・連続日数をリアルタイム表示

## 投稿先候補

- [x] Zenn (技術実装詳細)
- [x] Qiita (Flutter/Supabase Tips)
- [ ] note (開発エッセイ)
- [ ] dev.to (英語版)

## 本文下書き (約2000字)

### はじめに

「自分株式会社」は Notion・Evernote・MoneyForward など21競合SaaSの機能を1つに統合する
Flutter Web + Supabase のライフマネジメントアプリです。
今回の daily-development では以下を実装しました。

- **集中タイマーページ** (`focus_timer_page.dart`) — Forest/Focusmate競合
- **AI文章アシスタントページ** (`ai_writing_assistant_page.dart`) — Grammarly/Notion AI競合
- **浪費耐性トレーニングカード** — ホーム画面の禁欲ガードパネルに統合
- **5本の新規Edge Functionを CI/CDに追加** (focus-timer/ai-writing-assistant/bookmark-sync/task-dependency/note-sharing-enhanced)

---

### 集中タイマーの実装

#### Edge Function: focus-timer

`focus_sessions` テーブルを使って GET (stats) / POST (start/complete/cancel) を提供します。

```typescript
// GET ?action=stats&days=7
const { data: sessions } = await userClient
  .from("focus_sessions")
  .select("*")
  .eq("user_id", user.id)
  .gte("started_at", since)
  .order("started_at", { ascending: false });

const streak = _calculateStreak(sessions ?? []);
```

ストリーク計算は「連続した日付」を Set で重複排除してカウントします。

#### Flutter フロントエンド

`CircularProgressIndicator` + `Timer.periodic` でリアルタイムカウントダウンを実現:

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
  if (!mounted) return;
  setState(() {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
    } else {
      _completeSession();
    }
  });
});
```

セッション開始時に Edge Function で DB レコードを作成し、完了/キャンセル時に UPDATE します。
セッション ID を `_activeSessionId` に保持することで、途中でページを離れても完了/キャンセルを確実に記録できます。

#### 詰まったポイント: `Colors.white08` は存在しない

Flutter では `Colors.white08` のような shorthand は存在せず、
`Colors.white.withValues(alpha: 0.08)` と書く必要があります。
`flutter analyze` で `undefined_getter` として検出されたため即修正しました。

---

### AI文章アシスタントの実装

#### Edge Function: ai-writing-assistant

Gemini 2.0 Flash API に action に応じたプロンプトを送ります:

```typescript
case "improve":
  prompt = `以下の文章を、読みやすく自然な日本語に改善してください。\n\n${text}`;
  break;
case "titles":
  prompt = `以下の文章のタイトル候補を5つ提案してください。各タイトルは20字以内で...\n\n${text}`;
  break;
```

GEMINI_API_KEY 未設定時はフォールバックメッセージを返すため、
ローカル開発環境でもエラーなく動作します。

#### Flutter フロントエンド

Dart 3 のレコード構文 `(String, IconData, Color)` でアクション定義を圧縮しています:

```dart
static const _actions = {
  'improve': ('文章改善', Icons.auto_fix_high, Color(0xFF6366F1)),
  'summarize': ('要約', Icons.compress, Color(0xFF10B981)),
  // ...
};
```

`e.value.$1` / `e.value.$2` / `e.value.$3` でタプル要素にアクセスできます。
これにより別途 enum や Model クラスを作らずにアクション定義をシンプルに保てます。

---

### 浪費耐性トレーニングのホーム画面統合

既存の `AbstinenceDisciplineSnapshot` から5つのプロパティ
(repCount / moneySaved / timeSavedMinutes / streakDays / stageLabel) を
`HomeSnapshot` に追加し、ホーム画面の禁欲ガードパネルに「浪費耐性トレーニング」カードを表示しました。

`_formatYen(int)` は `double` を受け取るため `.toDouble()` が必要です。
`flutter analyze` で `argument_type_not_assignable` として検出 → 即修正。

---

### まとめ

- flutter analyze 0件を維持しながら2つの新規ページ + 1カード統合 + 5本のEdge Function CI/CD追加を実施
- `prefer_const_declarations` / `require_trailing_commas` / 型不一致 など6件のLintエラーをすべて修正
- 集中タイマーと AI文章アシスタントは業務メニューカタログの `growth` セクションから検索可能

サービスURL: <https://my-web-app-b67f4.web.app/>

\#FlutterWeb \#Supabase \#buildinpublic \#Forest \#Grammarly
