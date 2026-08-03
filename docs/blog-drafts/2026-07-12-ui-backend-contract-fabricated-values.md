---
title: "『全行 +0』の正体 — Flutter × Supabase で UI がレスポンス契約とズレて捏造値を出すバグ"
tags: Flutter,Supabase,dart,webdev
published: false
---

一覧ページが「どの行も同じそれっぽい初期値」を出しているとき、それは表示崩れではなく **UI とバックエンドのレスポンス契約のズレ** であることが多い。実際に自作アプリのロイヤリティポイント画面で踏んだバグと、再発させないための直し方をまとめる。

## 症状

ポイント履歴の一覧が、どの行も「ポイント 1 / +0 pt」「ポイント 2 / +0 pt」…と表示される。日時だけは正しい。残高の合計はどこにも出ていない。

## 原因: nested な応答を flat なキーで読んでいた

Edge Function 側はこう返していた。

```json
{
  "success": true,
  "balance": 1250,
  "history": [
    {
      "id": "...",
      "metadata": { "amount": 500, "reason": "初回登録ボーナス" },
      "created_at": "2026-07-12T..."
    }
  ]
}
```

一方、UI 側はこう読んでいた。

```dart
final points = item['points']?.toString() ?? '0';      // 存在しない → '0'
final type = item['type']?.toString() ?? 'earn';        // 存在しない → 'earn'
final desc = item['description']?.toString() ?? 'ポイント ${index + 1}';
```

`amount` は `metadata.amount` に、`reason` は `metadata.reason` にあるのに、UI はトップレベルの `points` / `type` / `description` を読んでいた。結果、全部フォールバック値になり **「+0 pt」という数字を UI が捏造** していた。さらに `balance` は取得しているのに描画していなかった。

これは「測っていない値を、測ったように見せている」誠実性の問題でもある。ユーザーは 0 と表示されれば「本当に 0 なんだ」と受け取る。

## 直し方 1: 純データモデルに解析を閉じ込める

パースを UI から切り離し、Flutter 非依存の純関数/モデルにする。VM 単体テストが書けるようになり、契約ズレを回帰テストで固定できる。

```dart
class LoyaltyPointEntry {
  const LoyaltyPointEntry({
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  final num amount; // 正 = 付与 / 負 = 交換
  final String reason;
  final String createdAt;

  bool get isEarn => amount >= 0;

  factory LoyaltyPointEntry.fromMap(Map<String, dynamic> raw) {
    final meta = raw['metadata'] is Map
        ? (raw['metadata'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    // 正しいキーを読む。旧 flat キーはフォールバックとして残す。
    final rawAmount = meta['amount'] ?? raw['amount'] ?? raw['points'] ?? 0;
    final reason =
        (meta['reason'] ?? raw['reason'] ?? raw['description'] ?? '')
            .toString()
            .trim();
    return LoyaltyPointEntry(
      amount: rawAmount is num ? rawAmount : num.tryParse('$rawAmount') ?? 0,
      reason: reason.isEmpty ? 'ポイント履歴' : reason,
      createdAt: (raw['created_at'] ?? '').toString(),
    );
  }
}
```

## 直し方 2: 捏造ゼロを回帰テストで固定する

「0 を出してはならない」という意図をテストに書く。次に誰かがキーを間違えたら赤で気づける。

```dart
test('does NOT fabricate +0 pt rows', () {
  final entry = LoyaltyPointEntry.fromMap({
    'metadata': {'amount': 500, 'reason': 'キャンペーン付与'},
    'created_at': '2026-07-12T00:00:00Z',
  });
  expect(entry.amount, 500);
  expect(entry.amount, isNot(0)); // 捏造の 0 を許さない
  expect(entry.reason, 'キャンペーン付与');
});
```

## 教訓

- 「一覧の全行が同じ初期値」= まず **応答契約のキー不一致** を疑う。nested (`metadata.x`) と flat (`x`) の取り違えが定番。
- フォールバック値 (`?? '0'`) は、契約ズレを **静かに捏造値へ変換する装置** になりうる。0 が返ってきたのか、キーが無くて 0 になったのかを区別する。
- 取得しているのに描画していないフィールド (この例では `balance`) がないか棚卸しする。
- パースは純モデルへ抽出し、意図 (捏造ゼロ) を回帰テストで固定する。

小さなページの小さなバグだが、「アプリが出す数字は信じてよい」という信頼を守るための修正である。
