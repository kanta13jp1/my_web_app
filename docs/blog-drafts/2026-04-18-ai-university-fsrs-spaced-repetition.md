---
title: "Flutter × Supabase で間隔反復学習 (FSRS) を実装した — AI大学の記憶定着システム"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# Flutter × Supabase で間隔反復学習 (FSRS) を実装した — AI大学の記憶定着システム

## はじめに

自分株式会社 AI大学に **間隔反復学習 (Spaced Repetition)** を実装しました。Duolingo や Anki と同じ「覚えたカードは遠くに飛ばし、忘れかけたカードを手前に引き戻す」仕組みです。

4段階グレーディング: **また明日 / 難しい / 覚えた / 簡単** でタップするだけで次回出題日が自動計算されます。

## アーキテクチャ

```
Flutter UI (4ボタン)
  → AiFsrsService.gradeCard(grade: 1~4)
    → ai-hub EF (quiz.fsrs_grade)
      → ai_university_fsrs_cards (Supabase PostgreSQL)
```

## DBスキーマ

```sql
CREATE TABLE ai_university_fsrs_cards (
  user_id     uuid REFERENCES auth.users NOT NULL,
  provider    text NOT NULL,
  question_id text NOT NULL,
  due_date    timestamptz NOT NULL DEFAULT now(),
  stability   float8 NOT NULL DEFAULT 1.0,
  reps        int  NOT NULL DEFAULT 0,
  lapses      int  NOT NULL DEFAULT 0,
  last_review timestamptz,
  state       text NOT NULL DEFAULT 'new',  -- new/learning/review/relearning
  PRIMARY KEY (user_id, provider, question_id)
);
```

`stability` が記憶の安定度。値が大きいほど次回出題日が遠ざかります。

## グレーディングアルゴリズム (Edge Function)

```typescript
// supabase/functions/ai-hub/index.ts — quiz.fsrs_grade
const currentStability = existing?.stability ?? 1.0;
const reps   = (existing?.reps ?? 0) + 1;
const lapses = grade === 1 ? (existing?.lapses ?? 0) + 1 : (existing?.lapses ?? 0);

let newStability  = currentStability;
let daysUntilNext = 1;

if      (grade === 1) { newStability = Math.max(currentStability * 0.5, 0.5); daysUntilNext = 1;                          } // Again
else if (grade === 2) { newStability = currentStability * 0.8;                daysUntilNext = Math.max(newStability, 1);  } // Hard
else if (grade === 3) {                                                         daysUntilNext = Math.max(currentStability, 1); } // Good
else                  { newStability = currentStability * 1.3;                daysUntilNext = Math.max(newStability * 1.3, 1); } // Easy

const nextDue = new Date();
nextDue.setDate(nextDue.getDate() + Math.round(daysUntilNext));

const state = grade === 1 ? "relearning" : reps > 2 ? "review" : "learning";
```

| グレード | stability 変化 | 次回出題 |
|---------|--------------|---------|
| 1: また明日 | × 0.5 (最低0.5) | 翌日 |
| 2: 難しい | × 0.8 | stability日後 |
| 3: 覚えた | 変化なし | stability日後 |
| 4: 簡単 | × 1.3 | stability × 1.3日後 |

初回 stability=1.0 なら「覚えた」で翌日、「簡単」で翌日。2回目以降は 1.3倍ずつ間隔が広がります。

## 今日の出題カード取得

```typescript
// quiz.fsrs_next: due_date <= now のカードを返す
const { data: cards } = await admin
  .from("ai_university_fsrs_cards")
  .select("question_id, provider, due_date, stability, state")
  .eq("user_id", userId)
  .eq("provider", provider)
  .lte("due_date", new Date().toISOString())
  .order("due_date", { ascending: true })
  .limit(limit);
```

`due_date <= now` のフィルタだけで「今日復習すべきカード」が取れます。

## Flutter サービス層

```dart
// lib/services/ai_fsrs_service.dart

/// grade: 1=Again, 2=Hard, 3=Good, 4=Easy
Future<({DateTime nextDue, double stability})> gradeCard({
  required String provider,
  required String questionId,
  required int grade,
}) async {
  final response = await _supabase.functions.invoke(
    'ai-hub',
    body: {
      'action': 'quiz.fsrs_grade',
      'provider': provider,
      'question_id': questionId,
      'grade': grade,
    },
  );
  final data = response.data as Map<String, dynamic>?;
  final nextDue  = DateTime.parse(data?['next_due'] as String);
  final stability = (data?['stability'] as num).toDouble();
  return (nextDue: nextDue, stability: stability);
}

static String nextDueLabel(DateTime nextDue) {
  final diff = nextDue.difference(DateTime.now()).inDays;
  if (diff <= 0) return '今日';
  if (diff == 1) return '明日';
  return '$diff日後';
}
```

## UI: 4ボタングレーディング

```dart
// lib/pages/gemini_university_v2_page.dart
Row(
  children: [
    for (final grade in [1, 2, 3, 4])
      ElevatedButton(
        onPressed: () async {
          final result = await _fsrsService.gradeCard(
            provider: providerId,
            questionId: questionId,
            grade: grade,
          );
          setState(() => _fsrsNextDue[providerId] = result.nextDue);
        },
        child: Text(AiFsrsService.gradeLabel(grade)),
      ),
  ],
)

// 次回出題バッジ
if (_fsrsNextDue.containsKey(providerId))
  Text('次回: ${AiFsrsService.nextDueLabel(_fsrsNextDue[providerId]!)}')
```

## ポイントまとめ

1. **stability が唯一の状態変数** — 直前のstabilityに倍率をかけるだけ。SM-2のような複雑な数式が不要
2. **`due_date <= now` フィルタ** — 追加ロジックなしで「今日の復習リスト」が完成
3. **UPSERT で冪等性** — `onConflict: "user_id,provider,question_id"` で何度でも安全に呼べる
4. **EFに閉じる** — Flutterはgrade番号を渡すだけ。アルゴリズム変更はEF側だけでよい

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #SpacedRepetition
