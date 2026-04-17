---
title: "Flutter × Supabase で FSRS スペース反復学習を実装した — AI大学に記憶科学を組み込む"
tags: Flutter,Supabase,個人開発,機械学習,buildinpublic
published: true
---

# Flutter × Supabase で FSRS スペース反復学習を実装した

## はじめに

自分株式会社の「AI大学」は 66 社以上の AI プロバイダーをクイズ+ニュースで横断学習できる機能です。問題は **「一度学んだことをどう定着させるか」**。

そこで **FSRS (Free Spaced Repetition Scheduler)** アルゴリズムを組み込みました。Anki の次世代アルゴリズムとして注目される FSRS を Flutter + Supabase 上で実装した話を共有します。

## FSRS とは

FSRS は、記憶の安定性 (stability) と困難度 (difficulty) をパラメータとして持ち、忘却曲線に基づいて次回出題日を計算するアルゴリズムです。

- `state`: new / learning / review / relearning
- `stability`: 記憶がどれだけ定着しているか (高いほど次回まで間隔が長くなる)
- `difficulty`: 問題の主観的難しさ (1=易〜10=難)
- `due_date`: 次回出題予定日

## DB スキーマ設計

```sql
CREATE TABLE ai_university_fsrs_cards (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES auth.users NOT NULL,
  provider     text NOT NULL,        -- 'google', 'openai' など
  question_id  text NOT NULL,
  due_date     timestamptz NOT NULL DEFAULT now(),
  stability    float NOT NULL DEFAULT 1.0,
  difficulty   float NOT NULL DEFAULT 0.3,
  state        text NOT NULL DEFAULT 'new',
  reps         int NOT NULL DEFAULT 0,
  lapses       int NOT NULL DEFAULT 0,
  last_review  timestamptz,
  UNIQUE(user_id, provider, question_id)
);
```

RLS で `user_id = auth.uid()` を設定し、ユーザーは自分のカードのみ参照・更新できます。

## Edge Function 実装

Supabase Edge Function (`ai-hub`) に 2 つのアクションを追加しました。

### quiz.fsrs_next — 今日復習すべきカードを取得

```typescript
case "quiz.fsrs_next": {
  const { provider, limit = 10 } = body;
  const { data: cards } = await supabase
    .from("ai_university_fsrs_cards")
    .select("*")
    .eq("user_id", user.id)
    .eq("provider", provider)
    .lte("due_date", new Date().toISOString())
    .order("due_date")
    .limit(limit);
  return new Response(JSON.stringify({ success: true, cards }));
}
```

### quiz.fsrs_grade — 回答後に次回出題日を計算

```typescript
case "quiz.fsrs_grade": {
  const { provider, question_id, grade } = body; // grade: 1-4
  // FSRS アルゴリズムで stability・difficulty・due_date を更新
  const newStability = calcStability(currentCard, grade);
  const interval = Math.round(newStability * retrievabilityTarget);
  const nextDue = new Date(Date.now() + interval * 86400000);
  await supabase.from("ai_university_fsrs_cards").upsert({
    user_id: user.id, provider, question_id,
    stability: newStability, due_date: nextDue.toISOString(),
    state: grade === 1 ? "relearning" : "review",
    reps: currentCard.reps + 1
  });
  return new Response(JSON.stringify({ success: true, next_due: nextDue }));
}
```

## Flutter サービス層

```dart
class AiFsrsService {
  final _supabase = Supabase.instance.client;

  Future<List<FsrsCard>> getNextCards(String provider, {int limit = 10}) async {
    final response = await _supabase.functions.invoke(
      'ai-hub',
      body: {'action': 'quiz.fsrs_next', 'provider': provider, 'limit': limit},
    );
    final cards = (response.data?['cards'] as List? ?? []);
    return cards.map((c) => FsrsCard.fromJson(c)).toList();
  }

  Future<({DateTime nextDue, double stability})> gradeCard({
    required String provider,
    required String questionId,
    required int grade, // 1=また明日, 2=難しい, 3=覚えた, 4=簡単
  }) async {
    final response = await _supabase.functions.invoke(
      'ai-hub',
      body: {'action': 'quiz.fsrs_grade', 'provider': provider,
             'question_id': questionId, 'grade': grade},
    );
    final nextDue = DateTime.parse(response.data?['next_due'] ?? '');
    return (nextDue: nextDue, stability: response.data?['stability'] ?? 1.0);
  }

  static String nextDueLabel(DateTime nextDue) {
    final diff = nextDue.difference(DateTime.now()).inDays;
    if (diff <= 0) return '今日';
    if (diff == 1) return '明日';
    return '$diff日後';
  }
}
```

## ホームカードに復習カウンターを追加

今日復習すべきカード数をホーム最上部のカードに表示するようにしました。

```dart
// ホームカードの _loadProgress() に追加
final dueCardRow = await _supabase
    .from('ai_university_fsrs_cards')
    .select('id')
    .eq('user_id', user.id)
    .lte('due_date', DateTime.now().toIso8601String())
    .count(CountOption.exact);
setState(() => _dueCardCount = dueCardRow.count);
```

復習カードが存在する場合は「復習 X問」のバッジとボタンを表示します。

## 詰まったポイント

### RLS の `user_profiles` カラム名ミス

`user_profiles` テーブルは `id` ではなく `user_id` が主キー相当のカラムです。管理者 RLS を書く際に間違えやすいパターン:

```sql
-- NG: id は user_profiles の PK ではない
EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid())

-- OK: user_id が auth.uid() に対応
EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid())
```

### FSRS の grade 4段階

Anki の「再び / 難しい / 普通 / 簡単」に対応する 1〜4 の整数。grade=1 で `relearning` 状態にリセットされます。

## まとめ

FSRS を組み込むことで「今日復習すべき AI は何社か」が定量化されます。単なるクイズアプリではなく、科学的な記憶定着システムになりました。

次のステップは「音声 × FSRS」の組み合わせ — 音声で回答しながら FSRS で管理する学習体験です。

---
自分株式会社 AI大学: https://my-web-app-b67f4.web.app/#/gemini-university
#FlutterWeb #Supabase #FSRS #スペース反復 #buildinpublic #個人開発
