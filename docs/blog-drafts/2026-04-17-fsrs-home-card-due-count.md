---
title: "FSRS 復習カウンターをホームカードに統合 — Flutter × Supabase リテンション設計"
tags: Flutter,Supabase,buildinpublic,個人開発,Dart
published: true
---

# FSRS 復習カウンターをホームカードに統合 — Flutter × Supabase リテンション設計

## 問題: 復習カードがあっても気づかない

FSRS スペース反復学習を実装した。今日が復習日のカードがある。でもユーザーは学習ページを開かない限りそれを知らない。

解決策: ホームカードに「復習X問」バッジを表示して、ユーザーが見逃せないようにする。

---

## スキーマ: ai_university_fsrs_cards

```sql
CREATE TABLE ai_university_fsrs_cards (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider    text        NOT NULL,
  quiz_key    text        NOT NULL,
  due_date    date        NOT NULL DEFAULT current_date,
  stability   real        NOT NULL DEFAULT 1.0,
  difficulty  real        NOT NULL DEFAULT 5.0,
  review_count int        NOT NULL DEFAULT 0,
  last_grade  int,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider, quiz_key)
);
```

`due_date` は `timestamptz` ではなく `date` — スペース反復は日単位で動作するため。今日のカードは `due_date <= current_date`。

---

## Flutter: ホームカードに due_count を読み込む

```dart
class _AiUniversityHomeCardState extends State<AiUniversityHomeCard> {
  int _dueCardCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDueCount();
  }

  Future<void> _loadDueCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('ai_university_fsrs_cards')
          .select('id')           // IDのみ取得 (最小ペイロード)
          .eq('user_id', userId)
          .lte('due_date', today); // 期限切れも含む

      setState(() {
        _dueCardCount = (response as List).length;
        _loading = false;
      });
    } catch (_) {
      // 新規ユーザーはテーブル行なし → クラッシュさせない
      setState(() => _loading = false);
    }
  }
}
```

ポイント:
- `.lte('due_date', today)` — 今日以前の期限切れカードも含む
- `.select('id')` — カード全データは不要。IDだけ取ってリスト長でカウント
- `catch (_)` — 新規ユーザー (FSRSカードなし) でもクラッシュしない

---

## Flutter: 条件付きバッジ

カードがある場合のみバッジを表示:

```dart
Row(
  children: [
    const Text('🎓', style: TextStyle(fontSize: 24)),
    const SizedBox(width: 8),
    Text('AI大学', style: Theme.of(context).textTheme.titleMedium),
    const Spacer(),
    if (!_loading && _dueCardCount > 0)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '復習 $_dueCardCount問',
          style: TextStyle(
            color: colorScheme.onErrorContainer,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
  ],
),
```

`colorScheme.errorContainer` / `colorScheme.onErrorContainer` — Material 3 の「注意が必要」セマンティックカラーペア。HEXコードなしで「赤系のバッジ」が実現できる。

---

## モバイル: 復習ボタン

モバイルではカードがある場合に CTA ボタンも表示:

```dart
if (!_loading && _dueCardCount > 0) ...[
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GeminiUniversityV2Page())),
      icon: const Icon(Icons.school),
      label: Text('復習する ($_dueCardCount問)'),
    ),
  ),
],
```

`FilledButton` (Material 3 プライマリアクション) を `width: double.infinity` でフルカード幅表示。

---

## .select('id') vs CountOption.exact

```dart
// 方法A: ID取得してクライアント側カウント (シンプル)
final response = await supabase
    .from('ai_university_fsrs_cards')
    .select('id')
    .eq('user_id', userId)
    .lte('due_date', today);
final count = (response as List).length;

// 方法B: PostgREST の exact count
final response = await supabase
    .from('ai_university_fsrs_cards')
    .select('*', const FetchOptions(count: CountOption.exact))
    .eq('user_id', userId)
    .lte('due_date', today);
final count = response.count;
```

FSRSカードはユーザーごとに数十〜百枚程度。方法Aで十分。大規模テーブルなら方法Bで DB側カウント。

---

## まとめ

| パターン | 効果 |
|---------|---------|
| `due_date` を `date` 型に | 日単位SRS・シンプルな `.lte()` フィルター |
| `.select('id')` | カウントだけに最小ペイロード |
| `if (_dueCardCount > 0)` 条件バッジ | 復習なし時はUI汚染なし |
| `colorScheme.errorContainer` | HEXなしで注意色 |
| `catch (_)` | 新規ユーザーでもホームカードが安全 |

ホームカードがリテンションフックになる: アプリを開く → バッジを見る → 復習する。

自分株式会社: [https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

#buildinpublic #FlutterWeb #Supabase #個人開発 #UX
