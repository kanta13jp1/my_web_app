---
title: "Flutter WebでMoneyForwardを超える家計AIアドバイザーを実装した話"
emoji: "💰"
type: "tech"
topics: ["flutter", "supabase", "ai", "dart", "moneyforward"]
published: true
---

# Flutter WebでMoneyForwardを超える家計AIアドバイザーを実装した話

## はじめに

自分株式会社 では、Notion・Evernote・MoneyForward・Slack など21競合SaaSを1つに統合するAIライフマネジメントアプリを開発しています。

今日は、**Amazon Rufus「Buy for Me」機能**がリリースされたことを受けて、対抗施策として**家計AIアドバイザー**を実装しました。128行のスタブページを、AIによる節約提案と将来シミュレーション付きの本格的な財務管理ページに全面刷新した記録です。

## 実装した機能

### 4タブ構成

1. **概要タブ** — 収入・支出・収支・貯蓄率のKPIカード + 支出トップ5
2. **予算タブ** — 15カテゴリ別の予算設定と使用率プログレスバー
3. **AI節約アドバイスタブ** — 支出データをAIが分析して節約提案3点生成
4. **将来シミュレーションタブ** — 複利計算で資産形成を試算

## AI節約アドバイスの実装

既存の `ai-assistant` Edge Function を活用してAI節約提案を実装しました。新しいEdge Functionを作らずに済んだのがポイントです。

```dart
Future<void> _fetchAiAdvice() async {
  final prompt = '''
以下の$_selectedMonth の家計データを分析して、節約アドバイスを3点提案してください。

収入合計: ¥${_fmt.format(totalIncome)}
支出合計: ¥${_fmt.format(totalExpense)}
カテゴリ別支出:
$breakdown

具体的で実践的な節約提案を3点だけ日本語で。
''';

  final response = await _supabase.functions.invoke(
    'ai-assistant',
    body: {'action': 'chat', 'message': prompt},
  );
  // ...
}
```

プロンプトエンジニアリングのポイント：
- 月次データを構造化してAIに渡す
- 「3点だけ」と制約を設けてコンパクトな回答を得る
- 実践的な提案を要求する

## 将来シミュレーションの数式

複利計算（月次積立あり）を純粋なDartで実装しました：

```dart
void _runSimulation() {
  final principal = double.tryParse(_initialAmountCtrl.text) ?? 0;
  final monthly = double.tryParse(_monthlyAddCtrl.text) ?? 0;
  final rate = (double.tryParse(_returnRateCtrl.text) ?? 0) / 100 / 12;
  final months = (int.tryParse(_yearsCtrl.text) ?? 0) * 12;

  double result = principal;
  for (int i = 0; i < months; i++) {
    result = result * (1 + rate) + monthly;
  }
  setState(() => _simResult = result);
}
```

年利5%・月積立3万円・初期100万円・20年で試算すると約1,544万円になります。元本合計約820万円に対して利息分が約724万円と複利の力が実感できます。

## Edge Function との連携パターン

`budget-financial-planner` Edge Function は `app_analytics` テーブルを汎用的に利用しています。専用テーブルを作らずに `source` カラムで用途を区別するパターンです：

```typescript
// 予算計画を保存
await adminClient.from("app_analytics").insert({
  user_id: user.id,
  source: "budget_plan",
  metadata: { month, category, amount }
});

// 支出を保存  
await adminClient.from("app_analytics").insert({
  user_id: user.id,
  source: "budget_expense",
  metadata: { month, category, amount, description }
});
```

このパターンのメリット：
- 新しいテーブルなしで多種類のデータを管理
- Supabase Edge Function の quota (94/94) を節約
- スキーマ変更なしで新フィールドを追加可能

## flutter analyze 0件を維持するTips

今回特に注意したのが `require_trailing_commas` ルールです。Flutterのアナライザーは末尾カンマを要求するため、複数行にまたがる引数には必ずカンマが必要です：

```dart
// NG
_kpiCard('収入', income, cs.primaryContainer, cs.onPrimaryContainer, Icons.arrow_upward),

// OK
_kpiCard(
  '収入',
  income,
  cs.primaryContainer,
  cs.onPrimaryContainer,
  Icons.arrow_upward,  // ← 末尾カンマ必須
),
```

また `DropdownButtonFormField` の `value` は Flutter 3.33以降 deprecated になっており、`initialValue` を使う必要があります。

## MoneyForwardとの差別化

| 機能 | MoneyForward | 自分株式会社 |
|------|-------------|------------|
| 月次予算管理 | ✅ | ✅ |
| カテゴリ別支出 | ✅ | ✅ |
| AI節約提案 | 一部 | ✅ (Claude API) |
| 将来シミュレーション | ✅ | ✅ |
| 価格 | 月480円〜 | 完全無料 |
| ノート・タスク連携 | ❌ | ✅ |

**完全無料かつ21競合機能を統合**している点が最大の差別化ポイントです。

## まとめ

- 128行スタブ → 750行本実装への全面刷新
- ai-assistant Edge Function の再利用でAI機能をゼロコスト追加
- dart:math不要の純粋Dart複利計算
- flutter analyze 0件・deno lint 0件を維持

サービスURL: https://my-web-app-b67f4.web.app/
GitHub: https://github.com/kanta13jp1/my_web_app

#FlutterWeb #Supabase #MoneyForward #buildinpublic
