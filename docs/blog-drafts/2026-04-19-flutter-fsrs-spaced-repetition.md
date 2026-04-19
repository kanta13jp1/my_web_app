---
title: "FlutterでFSRS間隔反復アルゴリズムを実装する — AI大学の学習エンジン"
tags: Flutter,Supabase,AI,個人開発,buildinpublic
published: false
---

# FlutterでFSRS間隔反復アルゴリズムを実装する

## FSRS とは

**FSRS (Free Spaced Repetition Scheduler)** は Anki の後継として開発された
最新の間隔反復アルゴリズム。

従来の SM-2 (SuperMemo) より精度が高く、**オープンソース**で実装が公開されている。

自分株式会社の AI大学機能にこのアルゴリズムを組み込み、
「次にいつ復習すべきか」を AI が計算する。

## コアアルゴリズム: 4つのパラメータ

```dart
// FSRS の記憶状態モデル
class FsrsCard {
  final double stability;    // 記憶の安定度 (日数)
  final double difficulty;   // 問題の難易度 (1-10)
  final double retrievability; // 現時点での記憶確率
  final DateTime dueDate;    // 次回復習日
}
```

4段階の自己評価に応じて stability が変化する:

```dart
enum Rating { again, hard, good, easy }

// 次回復習間隔の計算
double _calcInterval(FsrsCard card, Rating rating) {
  final R = 0.9; // 目標記憶確率 90%
  switch (rating) {
    case Rating.again:
      return 1.0;  // 翌日
    case Rating.hard:
      return card.stability * 0.8;
    case Rating.good:
      return card.stability * _stabilityGrowth(card.difficulty);
    case Rating.easy:
      return card.stability * _stabilityGrowth(card.difficulty) * 1.3;
  }
}

// 安定度成長率 (difficulty が高いほど成長が遅い)
double _stabilityGrowth(double difficulty) {
  return 2.5 * (11 - difficulty) / 10;
}
```

## Supabase スキーマ

```sql
-- AI大学 FSRS カード管理テーブル
CREATE TABLE ai_university_fsrs_cards (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  provider text NOT NULL,
  category text NOT NULL,           -- "overview" | "models" | "api"
  stability float DEFAULT 1.0,
  difficulty float DEFAULT 5.0,
  due_date timestamptz DEFAULT now(),
  last_review timestamptz,
  review_count int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- 学習プロフィール (個別最適化パラメータ)
CREATE TABLE ai_university_learner_profiles (
  user_id uuid REFERENCES auth.users PRIMARY KEY,
  target_retention float DEFAULT 0.9,  -- 目標記憶確率
  daily_new_cards int DEFAULT 5,       -- 1日の新規カード数
  daily_review_cards int DEFAULT 20,   -- 1日の復習カード数
  updated_at timestamptz DEFAULT now()
);
```

## Flutter 実装: 復習 UI

```dart
class FsrsReviewWidget extends StatefulWidget {
  final String provider;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 問題表示
        _buildQuestion(),
        // 自己評価ボタン (FSRS 4段階)
        if (_showAnswer) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: Rating.values.map((r) => _buildRatingButton(r)).toList(),
          ),
        ] else
          ElevatedButton(
            onPressed: () => setState(() => _showAnswer = true),
            child: const Text('答えを表示'),
          ),
      ],
    );
  }

  Widget _buildRatingButton(Rating rating) {
    final label = switch (rating) {
      Rating.again => 'もう一度\n<1日',
      Rating.hard  => '難しい\n~3日',
      Rating.good  => '普通\n~7日',
      Rating.easy  => '簡単\n~14日',
    };
    return ElevatedButton(
      onPressed: () => _submitReview(rating),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  Future<void> _submitReview(Rating rating) async {
    await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'fsrs.review',
        'provider': widget.provider,
        'rating': rating.name,
      },
    );
    widget.onComplete();
  }
}
```

## Edge Function: 次回日付の計算

```typescript
// ai-hub/index.ts (action: "fsrs.review")
case "fsrs.review": {
  const { provider, rating } = params;
  const userId = user.id;

  // 現在のカード状態を取得
  const { data: card } = await supabase
    .from('ai_university_fsrs_cards')
    .select('stability, difficulty')
    .eq('user_id', userId)
    .eq('provider', provider)
    .single();

  // 次回間隔を計算
  const interval = calcFsrsInterval(
    card?.stability ?? 1.0,
    card?.difficulty ?? 5.0,
    rating
  );

  const nextDue = new Date();
  nextDue.setDate(nextDue.getDate() + Math.round(interval));

  // UPSERT
  await supabase
    .from('ai_university_fsrs_cards')
    .upsert({
      user_id: userId,
      provider,
      stability: updateStability(card?.stability, rating),
      difficulty: updateDifficulty(card?.difficulty, rating),
      due_date: nextDue.toISOString(),
      last_review: new Date().toISOString(),
      review_count: (card?.review_count ?? 0) + 1,
    });

  return { next_due: nextDue, interval_days: Math.round(interval) };
}
```

## 今日の学習キュー取得

```dart
// 今日復習すべきカードを取得
final dueCards = await Supabase.instance.client
    .from('ai_university_fsrs_cards')
    .select('provider, category, stability')
    .eq('user_id', userId)
    .lte('due_date', DateTime.now().toIso8601String())
    .order('due_date')
    .limit(20);
```

`due_date <= now()` でフィルタリング。
FSRS が計算した間隔が来たカードだけが表示される。

## まとめ

| 要素 | 実装 |
|------|------|
| アルゴリズム | FSRS (stability/difficulty/retrievability) |
| 自己評価 | 4段階 (again/hard/good/easy) |
| 間隔計算 | EF (stability growth) × difficulty factor |
| DB | ai_university_fsrs_cards + learner_profiles |
| EF | ai-hub action: fsrs.review |

Duolingo や Anki と同じ仕組みを100行以下で実装できる。
個人開発でもスペースドリピティションで学習効果を最大化できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #AI #buildinpublic #個人開発
