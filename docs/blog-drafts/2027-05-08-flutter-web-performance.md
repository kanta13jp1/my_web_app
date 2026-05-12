---
title: "Flutter Web パフォーマンス最適化 — 実測で学ぶ速度改善テクニック"
tags: flutter,AI,個人開発,buildinpublic
published: true
---

# Flutter Web パフォーマンス最適化 — 実測で学ぶ速度改善テクニック

Flutter Web の初回ロードは遅い。対処法を知らないと離脱率が高くなる。実際の本番アプリで計測した改善手法をまとめる。

## 計測から始める

```bash
# Chrome DevTools Lighthouse でベースライン計測
# 本番 URL で実行 (ローカルは計測値が不正確)
LCP: 4.2s → 改善前
FID: 180ms
CLS: 0.12
```

改善前に計測しないと「何が効いたか」が分からない。

## 1. canvaskit → html レンダラー切り替え

Flutter Web は 2 種のレンダラーがある:

```yaml
# flutter build web のデフォルト
--web-renderer canvaskit  # 高忠実度・初回 DL 大 (~2.5MB)
--web-renderer html       # 軽量・初回 DL 小 (~300KB)
--web-renderer auto       # モバイル=html / デスクトップ=canvaskit
```

**改善後**: `--web-renderer html` に切り替えで初回ロード -1.5s。

```bash
flutter build web --web-renderer html --release
```

ただし `html` は CanvasKit 依存の描画 API (BlendMode 等) が制限される。使用 Widget を確認してから切り替える。

## 2. Lazy Loading — 遅延ルーティング

GoRouter で全ページを初回読み込みしない:

```dart
// NG: 全ページをトップレベルに import
import 'pages/heavy_page.dart';

// OK: builder 内で遅延ロード
GoRoute(
  path: '/heavy',
  builder: (context, state) {
    // このページは /heavy に遷移したときのみ実行される
    return const HeavyPage();
  },
),
```

大きな Widget (地図・グラフ・動画) は初回表示に必要なルートから外す。

## 3. compute() で重い処理を Isolate に逃がす

```dart
// UI スレッドでやると jank
List<HorseData> heavyParsing(String jsonString) {
  return (jsonDecode(jsonString) as List)
      .map((e) => HorseData.fromJson(e))
      .toList();
}

// compute() で Isolate に委譲
final result = await compute(heavyParsing, jsonString);
```

JSON parse が 50ms を超えるなら `compute()` を使う。UI が詰まらなくなる。

## 4. 画像最適化

```dart
// NG: ネットワーク画像をそのまま表示
Image.network('https://example.com/large.png')

// OK: キャッシュ + サイズ指定
CachedNetworkImage(
  imageUrl: 'https://example.com/large.webp',
  width: 300,
  height: 200,
  memCacheWidth: 300,  // メモリキャッシュサイズ制限
)
```

WebP 変換で PNG 比 -60%。`CachedNetworkImage` でリクエスト削減。

## 5. ListView.builder で仮想スクロール

```dart
// NG: 全アイテムを一度にビルド
ListView(children: items.map((e) => ItemWidget(e)).toList())

// OK: 表示領域のみビルド
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)
```

1000件リストは `ListView.builder` 必須。`ListView` は全件ビルドしてフリーズする。

## 6. const コンストラクタで再ビルド抑制

```dart
// 再ビルド対象になる
Widget build(BuildContext context) {
  return Column(children: [
    Text('Static Label'),  // 毎回再ビルド
    DynamicWidget(),
  ]);
}

// const で再ビルドをスキップ
Widget build(BuildContext context) {
  return Column(children: [
    const Text('Static Label'),  // 再ビルドなし
    DynamicWidget(),
  ]);
}
```

`flutter analyze` が `prefer_const_constructors` を警告してくれる。従う。

## 実測結果

| 施策 | LCP 改善 |
| --- | --- |
| html レンダラー切替 | -1.5s |
| 画像 WebP 化 | -0.8s |
| Lazy Loading | -0.4s |
| ListView.builder | FID -80ms |
| compute() | jank 解消 |

**Before**: LCP 4.2s → **After**: LCP 1.5s

Lighthouse スコア: 41 → 78

## まとめ

Flutter Web の速度改善は「レンダラー選択 → 画像 → 遅延読み込み → 計算コスト」の順で取り組む。計測ファーストで、改善前後の数値を必ず記録する。
