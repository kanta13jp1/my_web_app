---
title: "個人開発の価格戦略 2.0 — フリーミアム設計とアップセルの仕組み"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発の価格戦略 2.0 — フリーミアム設計とアップセルの仕組み

「いくらにすればいい？」は間違った質問。「どこで壁を作るか？」が正しい問い。

## フリーミアムの設計原則

```
フリープラン = 価値を感じさせる十分な機能
有料プラン  = 「もっと使いたい」ユーザーが自然に欲しくなる機能
```

**壁の種類**:

```
数量制限    → 無料: 3プロジェクト / 有料: 無制限
機能制限    → 無料: 基本機能 / 有料: AI分析・エクスポート
容量制限    → 無料: 1GB / 有料: 10GB
チーム制限  → 無料: 1人 / 有料: チーム機能
```

**設計の鉄則**:

- 壁は「今すぐ必要」なところに置く (将来機能の先出しは機能しない)
- フリープランで「ヤバい、これ便利」を体感させてから壁
- 壁を超えたユーザーの 90% 以上が無料に戻らない構造を作る

## アップセルのタイミング

```dart
// Supabase で使用量を追跡して適切なタイミングで案内
Future<void> checkUpgradePrompt(String userId) async {
  final { data } = await supabase
      .from('usage_stats')
      .select('project_count, task_count')
      .eq('user_id', userId)
      .single();

  final projectCount = data['project_count'] as int;

  // 壁の手前 (80%) でアップグレードを提案
  if (projectCount >= 2) {  // 無料上限3の80%
    _showUpgradeHint('あと1プロジェクトで上限です。Proプランで無制限に。');
  }
}
```

## 価格の決め方

```
年収 1,000 万円目標の場合:
  月額 1,000 円 × 833 人 = 月 83.3 万円 = 年 1,000 万円
  月額 2,000 円 × 417 人 = 同じ
  月額 5,000 円 × 167 人 = 同じ

個人開発で 417〜833 人の有料ユーザーは現実的な目標。
```

**価格テスト方法 (A/B テスト)**:

```dart
// Supabase で価格 A/B テスト
final userGroup = userId.hashCode % 2;  // 0 or 1
final price = userGroup == 0 ? 980 : 1480;  // 円

// どちらの CVR が高いかを計測
await supabase.from('price_experiments').insert({
  'user_id': userId,
  'group': userGroup,
  'price': price,
  'shown_at': DateTime.now().toIso8601String(),
});
```

## 解約防止 (チャーン対策)

```
解約の主な理由:
  1. 使わなくなった (エンゲージメント低下)
  2. 高すぎる (価値を感じなくなった)
  3. 競合に乗り換えた

対策:
  1. 30日間未ログインで自動メール (Resend API)
  2. 解約前に「一時停止」オプションを提示 (50%オフで3ヶ月)
  3. 解約理由を必ず聞く (1問だけ)
```

```typescript
// Edge Function: churning-user-email
// 30日間未アクティブなユーザーにメール
const inactiveUsers = await supabase
  .from('profiles')
  .select('email, name')
  .lt('last_active_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
  .eq('plan', 'pro');

for (const user of inactiveUsers) {
  await resend.emails.send({
    from: 'noreply@myapp.com',
    to: user.email,
    subject: `${user.name}さん、最近どうですか？`,
    html: winbackEmailTemplate(user),
  });
}
```

## まとめ

```
壁の設計    → 数量/機能/容量/チームの4種類 + タイミングは80%で案内
価格設定    → 目標収益から逆算 + 必ず A/B テスト
解約防止    → 30日離脱メール + 一時停止オプション + 解約理由収集
```

価格は最大の成長レバー。1% の価格最適化は 1% のユーザー増より簡単。
