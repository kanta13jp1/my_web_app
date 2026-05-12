---
title: "インディーデベロッパーのプロダクトマーケットフィット — ユーザーインタビューとフィードバックループの実践"
tags: 個人開発,flutter,AI,webdev
published: true
---

# インディーデベロッパーのプロダクトマーケットフィット — ユーザーインタビューとフィードバックループの実践

「作ったのに誰も使わない」は個人開発者の最大の落とし穴です。Product-Market Fit (PMF) を達成するには、コードを書く前にユーザーを理解し、リリース後も継続的にフィードバックを収集する仕組みが必要です。

## PMF とは何か

Sean Ellis の定義によると、PMF は「40% 以上のユーザーが『このプロダクトが使えなくなったら非常に残念』と回答する状態」です。

個人開発では「毎日使ってくれる 10 人を探す」がより現実的な目標です。

```
PMF の前兆:
✅ ユーザーが勝手に他人に紹介する
✅ 機能追加より安定性を求める声が増える
✅ 離脱ユーザーから「戻ってきた」連絡が来る
✅ 「これがないと困る」という発言が複数出る
```

## ユーザーインタビューの設計

### 良い質問と悪い質問

```
❌ 悪い質問 (誘導・仮定が入る):
「このダッシュボード機能、便利だと思いますか？」
「あと○○機能があれば使いますか？」

✅ 良い質問 (過去行動・具体的):
「最後にこのような問題が起きたのはいつですか？」
「その時、どうやって解決しましたか？」
「今使っているツールの何が不満ですか？」
```

### Jobs-to-be-Done フレームワーク

ユーザーはプロダクトを「雇う」ために使います。

```
状況 (When): 週次レポートを作成する時に
動機 (I want): 複数のツールからデータを集めずに
期待 (So that): 上司に報告するための数字を30分で出したい
```

このフレームに当てはめて質問を設計します。

```
インタビュースクリプト例:
1. 「今のワークフローを教えてください。具体的に何をどの順番でやりますか？」
2. 「そのプロセスで一番時間がかかる部分はどこですか？」
3. 「過去1ヶ月で、この問題が原因で困った具体的な出来事はありましたか？」
4. 「今はどのツールや方法で対処していますか？」
5. 「理想の解決策はどんなものですか？既存のツールでいいものがあれば教えてください。」
```

### インタビューの実施方法

```bash
# ユーザーを探す場所
- Twitterで問題ツイートを検索 → DMで参加依頼
- Redditの関連subredditでリクルート投稿
- 既存ユーザーへのメール (最初の100人は最重要)
- Product Hunt/Hacker Newsのコメント欄
- Discord/Slackのコミュニティ
```

インタビューは1回30〜45分、録音許可をもらいます。**5〜10人で共通パターンが浮かびます。**

## フィードバックループの自動化

### In-App フィードバック収集

```dart
// Flutter での NPS サーベイ実装
class NpsSurvey extends StatefulWidget {
  const NpsSurvey({super.key, required this.onSubmit});
  final void Function(int score, String? reason) onSubmit;

  @override
  State<NpsSurvey> createState() => _NpsSurveyState();
}

class _NpsSurveyState extends State<NpsSurvey> {
  int? _score;
  final _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'このアプリを友人・同僚に勧める可能性は？',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(11, (i) => _ScoreButton(
            score: i,
            isSelected: _score == i,
            onTap: () => setState(() => _score = i),
          )),
        ),
        if (_score != null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: InputDecoration(
              hintText: _score! >= 9
                  ? 'どの点が特に気に入っていますか？'
                  : '改善できる点を教えてください',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => widget.onSubmit(_score!, _reasonController.text),
            child: const Text('送信'),
          ),
        ],
      ],
    );
  }
}
```

### フィードバックの分類と集計

```dart
// Edge Function でフィードバックを分類
// supabase/functions/classify-feedback/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CATEGORIES = {
  bug: ['バグ', 'エラー', '動かない', 'クラッシュ', 'bug', 'error', 'crash'],
  feature: ['機能', '追加', 'できれば', 'want', 'feature', 'wish'],
  ux: ['使いにくい', 'わかりにくい', 'confusing', 'complicated'],
  praise: ['便利', '助かる', 'great', 'love', 'perfect'],
};

function classify(text: string): string {
  const lower = text.toLowerCase();
  for (const [category, keywords] of Object.entries(CATEGORIES)) {
    if (keywords.some(kw => lower.includes(kw))) return category;
  }
  return 'other';
}

Deno.serve(async (req) => {
  const { feedbackId, text } = await req.json();
  const category = classify(text);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  await supabase
    .from('feedback')
    .update({ category })
    .eq('id', feedbackId);

  return Response.json({ category });
});
```

### Supabase でフィードバックダッシュボード

```sql
-- フィードバック週次集計ビュー
CREATE VIEW feedback_weekly_summary AS
SELECT
  date_trunc('week', created_at) AS week,
  category,
  count(*) AS count,
  avg(nps_score) FILTER (WHERE nps_score IS NOT NULL) AS avg_nps,
  count(*) FILTER (WHERE nps_score >= 9) AS promoters,
  count(*) FILTER (WHERE nps_score <= 6) AS detractors
FROM feedback
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;
```

## PMF シグナルの定量化

### Retention Curve 分析

真の PMF は Retention Curve が水平になる状態です。

```
% retained
100 |
 80 |  \
 60 |    \
 40 |      \_____________________  ← PMF あり (水平収束)
 20 |
  0 |        \___________________  ← PMF なし (ゼロ収束)
    +--+--+--+--+--+--+--+--+--→ weeks after signup
```

```sql
-- Supabase でコホート Retention 計算
WITH cohort AS (
  SELECT
    user_id,
    date_trunc('week', created_at) AS cohort_week
  FROM users
),
activity AS (
  SELECT
    user_id,
    date_trunc('week', created_at) AS activity_week
  FROM user_events
)
SELECT
  c.cohort_week,
  EXTRACT(EPOCH FROM (a.activity_week - c.cohort_week)) / 604800 AS weeks_since_signup,
  count(DISTINCT a.user_id)::float / count(DISTINCT c.user_id) AS retention_rate
FROM cohort c
LEFT JOIN activity a USING (user_id)
GROUP BY 1, 2
ORDER BY 1, 2;
```

### North Star Metric の設定

```
一般的な North Star Metric 例:
- ノートアプリ: 週次アクティブノート数
- ToDo アプリ: 週次タスク完了数
- SaaS: 月次アクティブユーザー数 × 主要機能使用率
```

North Star は「ユーザーが価値を得た証拠」を測定します。セッション数や PV は Vanity Metric です。

## PMF 前後の行動変容

### PMF 前: 探索フェーズ

```
やること:
✅ ユーザーインタビュー週2回以上
✅ 機能を増やさず削る
✅ 1 segment に絞る
✅ 手動でユーザーをサポート (Concierge MVP)

やらないこと:
❌ スケーリングの検討
❌ マーケティング予算投下
❌ 複数 persona 対応
```

### PMF 後: 最適化フェーズ

```
やること:
✅ 成長エンジンの特定 (Paid/Viral/Sticky)
✅ Onboarding の改善 (Activation rate 向上)
✅ 価格実験
✅ 自動化とスケーリング
```

## まとめ

PMF は「作ったら売れる」ではなく「誰かの問題を本当に解決しているか」の確認プロセスです。

1. **インタビューで Problem を検証** → 解決策前に問題を理解
2. **フィードバックループを自動化** → 継続的な信号収集
3. **Retention Curve を見る** → 真の PMF シグナル
4. **North Star Metric を設定** → ビジネス成果と連結

PMF 前にスケールしても意味はありません。まず10人に愛されるプロダクトを作りましょう。

---

*自分株式会社では Flutter + Supabase で日本の21競合SaaSを1つに統合するライフマネジメントアプリを開発しています。開発の舞台裏を発信中 → [@kanta13jp1](https://x.com/kanta13jp1)*
