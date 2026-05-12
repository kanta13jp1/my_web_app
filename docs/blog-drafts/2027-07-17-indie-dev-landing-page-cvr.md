---
title: "個人開発のランディングページ最適化 — CVR を上げた6つの施策"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発のランディングページ最適化 — CVR を上げた6つの施策

ランディングページの CVR が 1.2% → 3.8% になった。デザイナーなしで実装した施策を公開する。

## なぜ LP が重要か

```
広告費 0 のとき、LP の CVR が唯一のレバー

訪問者 1,000 人 × CVR 1% = 10 サインアップ
訪問者 1,000 人 × CVR 4% = 40 サインアップ

4 倍の差が広告費ゼロで達成できる
```

## 施策1: ヒーローセクションを「動詞」に変える

```
❌ Before: "AI ライフマネジメントアプリ"
✅ After:  "Notion・Evernote・家計簿・X を一画面で管理できる"
```

ユーザーは「何ができるか」を探している。機能名より動詞で書く。

```dart
// Flutter LP のヒーロー
Column(
  children: [
    Text(
      'Notion・家計簿・X を\n1画面で管理',
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 16),
    Text(
      '21の競合アプリを1つに統合。\n月額980円から。',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: 32),
    ElevatedButton(
      onPressed: () => context.go('/signup'),
      child: const Text('無料で始める → 14日間トライアル'),
    ),
  ],
)
```

## 施策2: 社会的証明を数字で示す

```
❌ "多くのユーザーに支持されています"
✅ "2,400 人が使用中 / 平均セッション時間 8 分 / 返金率 0.8%"
```

```dart
// 数字バッジ
Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    _StatBadge(number: '2,400+', label: '利用者'),
    _StatBadge(number: '8 分', label: '平均滞在'),
    _StatBadge(number: '4.7★', label: 'App Store'),
  ],
)
```

## 施策3: CTA ボタンの摩擦を下げる

```
❌ "今すぐ購入"      → 購入の圧迫感
✅ "無料で試す"      → 摩擦ゼロ
✅ "14日間無料トライアル → クレジットカード不要"  → 疑念を先に解消
```

FAB (Floating Action Button) をスクロールに追従させる:

```dart
Scaffold(
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => context.go('/signup'),
    label: const Text('無料で試す'),
    icon: const Icon(Icons.arrow_forward),
  ),
  body: SingleChildScrollView(
    child: Column(children: [...]),
  ),
)
```

## 施策4: 競合比較表を作る

ユーザーは比較して選ぶ。比較の場を自分で作る:

```dart
// 機能比較テーブル
Table(
  children: [
    TableRow(children: [
      TableCell(child: Text('機能')),
      TableCell(child: Text('自分株式会社')),
      TableCell(child: Text('Notion')),
      TableCell(child: Text('Evernote')),
    ]),
    TableRow(children: [
      TableCell(child: Text('AI 日記')),
      TableCell(child: const Icon(Icons.check, color: Colors.green)),
      TableCell(child: const Icon(Icons.close, color: Colors.red)),
      TableCell(child: const Icon(Icons.close, color: Colors.red)),
    ]),
    // ... 21社分
  ],
)
```

比較表から直接サインアップページに誘導 → 高い CVR。

## 施策5: ページ速度を改善する

```
LCP 4.2s → 1.5s で離脱率が 22% 改善

改善方法:
  1. 画像を WebP 化 (PNG の 70% 削減)
  2. Flutter Web の --wasm ビルド
  3. Firebase Hosting のキャッシュ設定
  4. Above-the-fold を遅延ロードしない
```

```yaml
# Firebase Hosting キャッシュ設定
hosting:
  headers:
    - source: "**/*.{js,css,wasm}"
      headers:
        - key: Cache-Control
          value: public,max-age=31536000,immutable
```

## 施策6: A/B テストで数字で検証する

```
Supabase で A/B フラグを持ち、Flutter で分岐:

variant A: "無料で試す" ボタン (青)
variant B: "今すぐ始める" ボタン (オレンジ)
```

```dart
// A/B テスト実装
final variant = Random().nextBool() ? 'A' : 'B';

// Supabase に記録
await supabase.from('ab_events').insert({
  'variant': variant,
  'event': 'lp_view',
  'session_id': sessionId,
});

// 分岐
final buttonText = variant == 'A' ? '無料で試す' : '今すぐ始める';
final buttonColor = variant == 'A' ? Colors.blue : Colors.orange;
```

## 結果

```
施策前: CVR 1.2%
施策後: CVR 3.8% (3.2倍)

最も効果があった施策:
  1位: CTA の文言変更 (+0.9%)
  2位: ページ速度改善 (+0.7%)
  3位: 競合比較表追加 (+0.6%)
```

## まとめ

LP 改善は広告費ゼロで CAC を下げられる唯一の施策。優先度は:

1. ヒーローの動詞化
2. CTA の摩擦削減
3. 社会的証明の数字化
4. ページ速度
5. 競合比較表
6. A/B テストで継続改善

「ユーザーが何を求めているか」を軸に設計すれば、大きな予算なしでも CVR は上がる。
