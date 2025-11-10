# 性格診断機能設計ドキュメント 🧠

**作成日**: 2025年11月10日
**最終更新**: 2025年11月10日
**目的**: 16personalities.comのような性格診断機能でユーザー獲得を加速

---

## 📋 要件定義

### ユーザーからの要望
> 16personalities.comのような性格診断機能を追加したい

### 機能の目的
1. **ユーザー獲得**: 性格診断をフックに新規ユーザーを獲得
2. **エンゲージメント向上**: 診断結果のシェアでバイラル性を高める
3. **パーソナライゼーション**: 性格タイプに基づいたメモ推奨
4. **差別化**: 競合メモアプリにはない独自機能

### ビジネスインパクト
- **予想獲得ユーザー**: 月間1,000-5,000人
- **シェア率**: 診断完了者の30%がSNSシェア
- **バイラル係数**: 1.5（1人が1.5人を招待）
- **収益化**: プレミアム診断（詳細レポート）月額500円

---

## 🎨 UI/UX設計

### 診断フロー

```
1. ランディングページ
   ↓
2. 診断開始
   ↓
3. 質問（60問、5-10分）
   ↓
4. 結果表示（16タイプのいずれか）
   ↓
5. 詳細レポート
   ↓
6. SNSシェア
```

### ランディングページ

```
┌─────────────────────────────────────┐
│                                     │
│   🧠 あなたの性格タイプを診断      │
│                                     │
│   メモの書き方で性格がわかる！     │
│                                     │
│   [診断を開始する（無料）]         │
│                                     │
│   ✅ たった5分で完了                │
│   ✅ 16種類の性格タイプ             │
│   ✅ 詳細な分析レポート             │
│                                     │
└─────────────────────────────────────┘
```

### 質問ページ

```
┌─────────────────────────────────────┐
│ 質問 15 / 60                        │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│ 25%完了                             │
│─────────────────────────────────────│
│                                     │
│ メモを書くとき、どちらが近いですか？│
│                                     │
│ [ ] 詳細に計画を立ててから書く     │
│                                     │
│ [ ] 思いついたことをすぐに書く     │
│                                     │
│         [戻る]         [次へ]       │
└─────────────────────────────────────┘
```

### 結果表示ページ

```
┌─────────────────────────────────────┐
│ 🎉 あなたの性格タイプは...          │
│                                     │
│        INTJ（建築家）               │
│     「戦略的な思考家」               │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                     │
│ 📊 性格の特徴                       │
│                                     │
│ 内向的 ████████░░ 80%               │
│ 直感的 ███████░░░ 70%               │
│ 思考型 █████████░ 90%               │
│ 計画的 ████████░░ 80%               │
│                                     │
│ 💡 強み                             │
│ ・戦略的思考                         │
│ ・論理的分析                         │
│ ・長期計画                           │
│                                     │
│ 📝 メモの書き方のアドバイス         │
│ ・体系的な構造を作りましょう         │
│ ・カテゴリ分けを活用しましょう       │
│ ・目標設定メモを書きましょう         │
│                                     │
│ [詳細レポートを見る]                │
│ [Twitterでシェア]                   │
│ [友達を招待する]                    │
│                                     │
└─────────────────────────────────────┘
```

---

## 🧬 性格タイプ（16タイプ）

### MBTI準拠の16タイプ

| コード | 日本語名 | 英語名 | 特徴 |
|:-----|:--------|:-------|:----|
| **INTJ** | 建築家 | Architect | 戦略的、論理的、完璧主義 |
| **INTP** | 論理学者 | Logician | 分析的、好奇心旺盛、柔軟 |
| **ENTJ** | 指揮官 | Commander | リーダーシップ、効率的、決断力 |
| **ENTP** | 討論者 | Debater | 革新的、議論好き、挑戦的 |
| **INFJ** | 提唱者 | Advocate | 理想主義、共感力、洞察力 |
| **INFP** | 仲介者 | Mediator | 創造的、理想主義、柔軟 |
| **ENFJ** | 主人公 | Protagonist | カリスマ、共感力、リーダーシップ |
| **ENFP** | 広報運動家 | Campaigner | 熱心、創造的、社交的 |
| **ISTJ** | 管理者 | Logistician | 実直、責任感、秩序 |
| **ISFJ** | 擁護者 | Defender | 献身的、思いやり、実用的 |
| **ESTJ** | 幹部 | Executive | 組織的、実用的、伝統的 |
| **ESFJ** | 領事 | Consul | 社交的、協力的、責任感 |
| **ISTP** | 巨匠 | Virtuoso | 実践的、柔軟、分析的 |
| **ISFP** | 冒険家 | Adventurer | 芸術的、柔軟、思いやり |
| **ESTP** | 起業家 | Entrepreneur | 行動的、現実的、社交的 |
| **ESFP** | エンターテイナー | Entertainer | 陽気、社交的、柔軟 |

### 性格軸（5つ）

1. **E（外向的） vs I（内向的）**
   - E: 人といると元気になる
   - I: 一人の時間で充電する

2. **N（直感的） vs S（感覚的）**
   - N: 可能性や未来を見る
   - S: 現実や詳細を見る

3. **T（思考型） vs F（感情型）**
   - T: 論理と客観性を重視
   - F: 価値観と人間関係を重視

4. **J（計画的） vs P（柔軟的）**
   - J: 計画を立てて実行
   - P: 状況に応じて柔軟に対応

5. **A（自己主張的） vs T（慎重）** ※16personalities独自
   - A: 自信を持って行動
   - T: 慎重に考えて行動

---

## 📝 質問設計

### 質問数と構成
- **総質問数**: 60問
- **各軸の質問数**: 12問
- **所要時間**: 5-10分

### 質問例

#### E（外向的） vs I（内向的）

1. **メモを書くとき、どちらが近いですか？**
   - A: 人と話しながら考えをまとめる
   - B: 一人でじっくり考えてから書く

2. **新しいアイデアを思いついたとき、どうしますか？**
   - A: すぐに誰かに話したくなる
   - B: まず自分の中で整理してから話す

3. **メモアプリを使うとき、どちらが多いですか？**
   - A: 共有メモで他の人と協力する
   - B: 個人メモで自分だけの記録をする

#### N（直感的） vs S（感覚的）

1. **メモを書くとき、どちらが多いですか？**
   - A: 全体像や将来のビジョンを書く
   - B: 具体的な事実や詳細を書く

2. **タスクを管理するとき、どちらが近いですか？**
   - A: 大きな目標から逆算して考える
   - B: 今やるべきことから順番に考える

3. **アイデアメモを書くとき、どちらが近いですか？**
   - A: 可能性や「もしも」を書く
   - B: 現実的な実行手順を書く

#### T（思考型） vs F（感情型）

1. **メモを読み返すとき、何を重視しますか？**
   - A: 論理的に筋が通っているか
   - B: 自分の気持ちに正直か

2. **日記を書くとき、どちらが多いですか？**
   - A: 出来事の分析や原因を書く
   - B: 感じたことや気持ちを書く

3. **振り返りメモを書くとき、どちらが近いですか？**
   - A: 改善点や効率を考える
   - B: 感謝や学びを振り返る

#### J（計画的） vs P（柔軟的）

1. **メモを書くとき、どちらが近いですか？**
   - A: カテゴリやタグをきちんと設定する
   - B: 自由に思いついたまま書く

2. **タスク管理メモを書くとき、どちらが近いですか？**
   - A: 期限や優先順位を明確にする
   - B: 柔軟に変更できるように書く

3. **メモの整理方法は、どちらが近いですか？**
   - A: 定期的に整理して秩序を保つ
   - B: 必要なときに探せればOK

#### A（自己主張的） vs T（慎重）

1. **メモを共有するとき、どちらが近いですか？**
   - A: 自信を持って共有する
   - B: 何度も見直してから共有する

2. **新しい機能を試すとき、どちらが近いですか？**
   - A: すぐに試してみる
   - B: 慎重に調べてから試す

3. **失敗したとき、メモにどう書きますか？**
   - A: 次はうまくいくと前向きに書く
   - B: 何がいけなかったか詳しく分析する

---

## 🏗️ 技術設計

### データモデル

#### 1. PersonalityTest（診断テスト）

```dart
class PersonalityTest {
  final int id;
  final String userId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Map<String, int> scores; // E/I, N/S, T/F, J/P, A/T
  final String? personalityType; // INTJ, INFP, etc.
  final bool isCompleted;

  PersonalityTest({
    required this.id,
    required this.userId,
    required this.startedAt,
    this.completedAt,
    required this.scores,
    this.personalityType,
    required this.isCompleted,
  });
}
```

#### 2. PersonalityQuestion（質問）

```dart
class PersonalityQuestion {
  final int id;
  final String text;
  final String axis; // E/I, N/S, T/F, J/P, A/T
  final String direction; // A or B
  final String optionA;
  final String optionB;
  final int order;

  PersonalityQuestion({
    required this.id,
    required this.text,
    required this.axis,
    required this.direction,
    required this.optionA,
    required this.optionB,
    required this.order,
  });
}
```

#### 3. PersonalityAnswer（回答）

```dart
class PersonalityAnswer {
  final int id;
  final int testId;
  final int questionId;
  final String answer; // A or B
  final DateTime answeredAt;

  PersonalityAnswer({
    required this.id,
    required this.testId,
    required this.questionId,
    required this.answer,
    required this.answeredAt,
  });
}
```

#### 4. PersonalityType（性格タイプ）

```dart
class PersonalityType {
  final String code; // INTJ, INFP, etc.
  final String nameJa;
  final String nameEn;
  final String description;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> noteAdvice;
  final String iconUrl;

  PersonalityType({
    required this.code,
    required this.nameJa,
    required this.nameEn,
    required this.description,
    required this.strengths,
    required this.weaknesses,
    required this.noteAdvice,
    required this.iconUrl,
  });
}
```

---

### データベーススキーマ（Supabase）

```sql
-- 性格診断テストテーブル
CREATE TABLE personality_tests (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  personality_type TEXT, -- INTJ, INFP, etc.
  is_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- スコアテーブル（各軸のスコア）
CREATE TABLE personality_scores (
  id BIGSERIAL PRIMARY KEY,
  test_id BIGINT NOT NULL REFERENCES personality_tests(id) ON DELETE CASCADE,
  axis TEXT NOT NULL, -- E/I, N/S, T/F, J/P, A/T
  score INTEGER NOT NULL, -- -100 to 100
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(test_id, axis)
);

-- 質問テーブル
CREATE TABLE personality_questions (
  id BIGSERIAL PRIMARY KEY,
  text TEXT NOT NULL,
  axis TEXT NOT NULL, -- E/I, N/S, T/F, J/P, A/T
  direction TEXT NOT NULL, -- A or B
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  order_num INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(order_num)
);

-- 回答テーブル
CREATE TABLE personality_answers (
  id BIGSERIAL PRIMARY KEY,
  test_id BIGINT NOT NULL REFERENCES personality_tests(id) ON DELETE CASCADE,
  question_id BIGINT NOT NULL REFERENCES personality_questions(id) ON DELETE CASCADE,
  answer TEXT NOT NULL, -- A or B
  answered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(test_id, question_id)
);

-- インデックス
CREATE INDEX idx_personality_tests_user_id ON personality_tests(user_id);
CREATE INDEX idx_personality_tests_completed ON personality_tests(is_completed);
CREATE INDEX idx_personality_scores_test_id ON personality_scores(test_id);
CREATE INDEX idx_personality_answers_test_id ON personality_answers(test_id);

-- RLSポリシー
ALTER TABLE personality_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE personality_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE personality_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE personality_answers ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のテストのみアクセス可能
CREATE POLICY "Users can view their own tests"
  ON personality_tests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tests"
  ON personality_tests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tests"
  ON personality_tests FOR UPDATE
  USING (auth.uid() = user_id);

-- 質問は全ユーザーが閲覧可能
CREATE POLICY "Anyone can view questions"
  ON personality_questions FOR SELECT
  USING (true);

-- ユーザーは自分の回答のみアクセス可能
CREATE POLICY "Users can view their own answers"
  ON personality_answers FOR SELECT
  USING (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own answers"
  ON personality_answers FOR INSERT
  WITH CHECK (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

-- スコアも同様
CREATE POLICY "Users can view their own scores"
  ON personality_scores FOR SELECT
  USING (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));

CREATE POLICY "Users can insert their own scores"
  ON personality_scores FOR INSERT
  WITH CHECK (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));
```

---

### サービス設計

#### PersonalityTestService

```dart
// lib/services/personality_test_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalityTestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 診断を開始
  Future<PersonalityTest> startTest() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase.from('personality_tests').insert({
      'user_id': userId,
      'started_at': DateTime.now().toIso8601String(),
      'is_completed': false,
    }).select().single();

    return PersonalityTest.fromJson(response);
  }

  // 質問を取得
  Future<List<PersonalityQuestion>> getQuestions() async {
    final response = await _supabase
        .from('personality_questions')
        .select()
        .order('order_num', ascending: true);

    return (response as List)
        .map((e) => PersonalityQuestion.fromJson(e))
        .toList();
  }

  // 回答を保存
  Future<void> saveAnswer({
    required int testId,
    required int questionId,
    required String answer,
  }) async {
    await _supabase.from('personality_answers').upsert({
      'test_id': testId,
      'question_id': questionId,
      'answer': answer,
      'answered_at': DateTime.now().toIso8601String(),
    });
  }

  // スコアを計算
  Future<Map<String, int>> calculateScores(int testId) async {
    // 回答を取得
    final answersResponse = await _supabase
        .from('personality_answers')
        .select('*, personality_questions!inner(*)')
        .eq('test_id', testId);

    final answers = answersResponse as List;

    // 各軸のスコアを計算
    final scores = <String, int>{
      'E/I': 0,
      'N/S': 0,
      'T/F': 0,
      'J/P': 0,
      'A/T': 0,
    };

    for (var answer in answers) {
      final question = answer['personality_questions'];
      final axis = question['axis'];
      final direction = question['direction'];
      final userAnswer = answer['answer'];

      // スコア加算（Aなら+1、Bなら-1）
      final score = (userAnswer == 'A') ? 1 : -1;
      scores[axis] = (scores[axis] ?? 0) + score;
    }

    // スコアを保存
    for (var entry in scores.entries) {
      await _supabase.from('personality_scores').upsert({
        'test_id': testId,
        'axis': entry.key,
        'score': entry.value,
      });
    }

    return scores;
  }

  // 性格タイプを判定
  String determinePersonalityType(Map<String, int> scores) {
    String type = '';

    // E vs I
    type += (scores['E/I']! > 0) ? 'E' : 'I';

    // N vs S
    type += (scores['N/S']! > 0) ? 'N' : 'S';

    // T vs F
    type += (scores['T/F']! > 0) ? 'T' : 'F';

    // J vs P
    type += (scores['J/P']! > 0) ? 'J' : 'P';

    return type;
  }

  // 診断を完了
  Future<void> completeTest(int testId, String personalityType) async {
    await _supabase.from('personality_tests').update({
      'personality_type': personalityType,
      'completed_at': DateTime.now().toIso8601String(),
      'is_completed': true,
    }).eq('id', testId);
  }

  // 診断結果を取得
  Future<PersonalityTest> getTestResult(int testId) async {
    final response = await _supabase
        .from('personality_tests')
        .select()
        .eq('id', testId)
        .single();

    return PersonalityTest.fromJson(response);
  }

  // ユーザーの最新診断結果を取得
  Future<PersonalityTest?> getLatestTestResult() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('personality_tests')
        .select()
        .eq('user_id', userId)
        .eq('is_completed', true)
        .order('completed_at', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;

    return PersonalityTest.fromJson(response.first);
  }
}
```

---

## 🎯 実装計画

### フェーズ1: 基本機能（2週間）

**Week 1: バックエンド**
- [ ] データベーススキーマ作成
- [ ] PersonalityTestServiceクラス作成
- [ ] 60問の質問データを作成（JSON）
- [ ] 質問データをSupabaseに投入
- [ ] 16タイプの詳細データを作成

**Week 2: フロントエンド**
- [ ] PersonalityTestモデル作成
- [ ] PersonalityQuestionモデル作成
- [ ] 診断開始ページ作成
- [ ] 質問ページ作成（1問ずつ表示）
- [ ] プログレスバー実装
- [ ] 結果表示ページ作成（基本版）

### フェーズ2: 詳細レポート（1週間）

- [ ] 詳細レポートページ作成
- [ ] 強み・弱みの表示
- [ ] メモの書き方アドバイス
- [ ] 性格軸のレーダーチャート
- [ ] アイコン・ビジュアルデザイン

### フェーズ3: シェア機能（3-5日）

- [ ] TwitterシェアボタN
- [ ] OGP画像自動生成（診断結果付き）
- [ ] 友達招待機能
- [ ] 紹介キャンペーン（ポイント付与）

### フェーズ4: ゲーミフィケーション統合（3-5日）

- [ ] 診断完了でアチーブメント獲得
- [ ] 診断完了でポイント獲得
- [ ] 性格タイプ別バッジ
- [ ] 性格タイプ別リーダーボード

### フェーズ5: パーソナライゼーション（1週間）

- [ ] 性格タイプに基づいたメモテンプレート推奨
- [ ] 性格タイプに基づいたカテゴリ推奨
- [ ] 性格タイプに基づいたタスク推奨
- [ ] AI秘書機能との連携

---

## 📊 効果測定

### KPI

| 指標 | 目標 | 測定方法 |
|:----|:----|:---------|
| 診断開始率 | 50% | (診断開始数 / 訪問者数) |
| 診断完了率 | 70% | (診断完了数 / 診断開始数) |
| シェア率 | 30% | (SNSシェア数 / 診断完了数) |
| バイラル係数 | 1.5 | (招待登録数 / 診断完了数) |
| 診断後7日継続率 | 60% | (7日後アクティブ / 診断完了数) |

### A/Bテスト

1. **質問数**: 30問 vs 60問
2. **ビジュアル**: シンプル vs リッチ
3. **結果表示**: 即座 vs アニメーション付き
4. **シェアインセンティブ**: なし vs ポイント付与

---

## 💰 収益化戦略

### 無料プラン
- 基本診断（60問）
- 基本結果レポート
- 1回の診断

### プレミアムプラン（月額500円）
- 詳細診断（120問）
- 詳細レポート（10ページ以上）
- キャリア適性診断
- 人間関係アドバイス
- 何度でも再診断可能

### 予想収益
- 診断完了者: 月間1,000人
- プレミアム転換率: 5%
- 月間収益: 1,000人 × 5% × 500円 = **25,000円/月**

---

## 🔍 競合分析

### 16personalities.com

**強み**:
- ブランド認知度が高い
- 詳細なレポート
- 多言語対応

**弱み**:
- メモアプリとは無関係
- パーソナライゼーションなし
- 診断後のエンゲージメント低い

### マイメモの差別化

✅ **メモアプリと統合**: 診断後もずっと使える
✅ **パーソナライゼーション**: 性格に合ったメモ推奨
✅ **ゲーミフィケーション**: 診断でポイント・バッジ獲得
✅ **コミュニティ**: 性格タイプ別のリーダーボード

---

## 🚀 マーケティング戦略

### 施策1: SEO対策
- キーワード: 「性格診断 無料」「MBTI 診断」「16personalities 日本語」
- ブログ記事: 「性格タイプ別のメモの書き方」

### 施策2: SNS広告
- Twitter広告: 「あなたの性格タイプは？無料診断」
- Facebook広告: 30-50代ターゲット

### 施策3: インフルエンサーマーケティング
- YouTuber: 診断結果をシェア
- TikToker: 診断の面白さをアピール

### 施策4: バイラルキャンペーン
- 「友達を招待すると1,000ポイント」
- 「診断結果をシェアするとプレミアム1ヶ月無料」

---

## 📚 参考資料

### 参考サイト
- [16Personalities](https://www.16personalities.com/)
- [MBTI公式](https://www.myersbriggs.org/)

### 技術参考
- [MBTI理論](https://ja.wikipedia.org/wiki/MBTI)
- [Big Five性格特性](https://ja.wikipedia.org/wiki/ビッグファイブ_(心理学))

---

## 🎯 次のアクション

### 今週
1. 質問60問を作成（各軸12問）
2. データベーススキーマを実装
3. PersonalityTestServiceを実装

### 来週
1. 診断UIを実装
2. 質問ページを実装
3. 結果表示ページを実装

### 1ヶ月後
1. βテスト開始（50人）
2. フィードバック収集
3. 改善・調整
4. 正式リリース

---

**最終更新**: 2025年11月10日
**次回レビュー**: 実装完了後
**作成者**: Claude Code
