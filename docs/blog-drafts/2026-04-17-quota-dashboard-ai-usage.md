---
title: "AI利用クォータ監視ダッシュボード — Flutter × Supabase でリアルタイム使用量可視化"
tags: Flutter,Supabase,buildinpublic,個人開発,Dart
published: true
---

# AI利用クォータ監視ダッシュボード — Flutter × Supabase でリアルタイム使用量可視化

## 問題: AIコストが見えない

複数のAIプロバイダー（Claude / Gemini / OpenAI）を使うアプリで、月のトークン消費が見えない。いつ制限に達するか分からず、突然APIが止まる。

解決策: Supabase `ai_quota_usage` テーブルにトークン消費を記録し、Flutter ダッシュボードでリアルタイム可視化する。

---

## スキーマ: ai_quota_usage

```sql
CREATE TABLE ai_quota_usage (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  model        text        NOT NULL,
  -- 例: 'claude-sonnet-4-6', 'gemini-2.0-flash', 'gpt-4o'
  input_tokens  int        NOT NULL DEFAULT 0,
  output_tokens int        NOT NULL DEFAULT 0,
  total_tokens  int        GENERATED ALWAYS AS (input_tokens + output_tokens) STORED,
  feature       text,
  -- 例: 'ai-university', 'daily-judgment', 'horse-racing'
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON ai_quota_usage (user_id, created_at DESC);
CREATE INDEX ON ai_quota_usage (model, created_at DESC);
```

`total_tokens` は GENERATED ALWAYS AS 列 — アプリ側で計算不要。インデックスを `(user_id, created_at DESC)` にして時系列クエリを高速化。

---

## Edge Function: クォータ記録

`admin-hub` EF の `quota.record` アクションで記録:

```typescript
case 'quota.record': {
  const { model, inputTokens, outputTokens, feature } = body;
  const userId = req.headers.get('x-user-id') ?? null;

  await supabase.from('ai_quota_usage').insert({
    user_id: userId,
    model,
    input_tokens: inputTokens,
    output_tokens: outputTokens,
    feature,
  });

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
}
```

各 AI 呼び出し後に fire-and-forget でこのアクションを呼ぶ:

```typescript
// 他の処理と並行して記録 (await しない)
supabase.from('ai_quota_usage').insert({
  model: 'claude-sonnet-4-6',
  input_tokens: usage.input_tokens,
  output_tokens: usage.output_tokens,
  feature: 'ai-university',
}).then(() => {}).catch(() => {}); // 失敗しても本処理に影響しない
```

---

## Flutter: QuotaDashboardPage

```dart
class QuotaDashboardPage extends StatefulWidget {
  const QuotaDashboardPage({super.key});

  @override
  State<QuotaDashboardPage> createState() => _QuotaDashboardPageState();
}

class _QuotaDashboardPageState extends State<QuotaDashboardPage> {
  List<Map<String, dynamic>> _modelStats = [];
  int _totalTokensToday = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // モデル別集計
    final response = await Supabase.instance.client
        .from('ai_quota_usage')
        .select('model, input_tokens, output_tokens')
        .gte('created_at', today);

    final stats = <String, Map<String, int>>{};
    for (final row in (response as List)) {
      final model = row['model'] as String;
      stats[model] ??= {'input': 0, 'output': 0};
      stats[model]!['input'] = stats[model]!['input']! + (row['input_tokens'] as int);
      stats[model]!['output'] = stats[model]!['output']! + (row['output_tokens'] as int);
    }

    setState(() {
      _modelStats = stats.entries
          .map((e) => {
                'model': e.key,
                'input': e.value['input'],
                'output': e.value['output'],
                'total': e.value['input']! + e.value['output']!,
              })
          .toList()
        ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
      _totalTokensToday = _modelStats.fold(0, (sum, s) => sum + (s['total'] as int));
      _loading = false;
    });
  }
}
```

---

## Flutter: 使用量バー表示

```dart
Widget _buildModelRow(Map<String, dynamic> stat) {
  final colorScheme = Theme.of(context).colorScheme;
  final total = stat['total'] as int;
  final fraction = _totalTokensToday > 0 ? total / _totalTokensToday : 0.0;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                stat['model'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              '${_formatTokens(total)} tokens',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}

String _formatTokens(int tokens) {
  if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
  if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
  return '$tokens';
}
```

---

## コスト見積もり

モデル別の単価をフロントエンドで適用してコスト表示:

```dart
const Map<String, double> _costPer1kTokens = {
  'claude-sonnet-4-6': 0.003,   // $3/1M tokens (input)
  'claude-haiku-4-5':  0.00025, // $0.25/1M tokens
  'gemini-2.0-flash':  0.00015, // $0.15/1M tokens
  'gpt-4o':            0.005,   // $5/1M tokens
};

double _estimateCost(String model, int tokens) {
  final rate = _costPer1kTokens[model] ?? 0.001;
  return tokens / 1000 * rate;
}
```

---

## まとめ

| パターン | 効果 |
|---------|---------|
| `GENERATED ALWAYS AS` total_tokens | アプリ側計算なし・DB側で一貫 |
| fire-and-forget記録 | 本処理のレイテンシに影響しない |
| `(user_id, created_at DESC)` インデックス | 日次クエリが高速 |
| モデル別バー表示 | コストの内訳が直感的に分かる |
| フロントエンド単価マップ | APIキーなしでコスト見積もり |

AIコストを「見えないもの」から「管理できるもの」に変える。月 $20 プランを最大活用するために不可欠な可視化レイヤー。

自分株式会社: [https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

#buildinpublic #FlutterWeb #Supabase #個人開発 #AI
