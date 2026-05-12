---
title: "Flutter パフォーマンス最適化 — const / 遅延ロード / 画像キャッシュ"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter パフォーマンス最適化 — const / 遅延ロード / 画像キャッシュ

体感速度を上げる3つの鉄則。DevTools で計測してから実施する。

## 1. const: リビルドを最小化

`const` コンストラクタを使うと、ウィジェットツリーの再構築時にそのウィジェットが
スキップされる。最も効果的なパフォーマンス改善の一つ。

```dart
// Bad: 毎回再構築される
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('タイトル'),           // const なし
        Icon(Icons.star),           // const なし
        TaskList(),                 // const なし
      ],
    );
  }
}

// Good: 変わらないウィジェットは const
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('タイトル'),           // const: リビルドスキップ
        Icon(Icons.star),           // const
        TaskList(),                 // データ依存がなければ const
      ],
    );
  }
}
```

**`flutter analyze` で警告検出**:

```bash
# prefer_const_constructors が有効なら警告が出る
flutter analyze lib/ | grep "const"
```

## 2. 遅延ロード: 初期表示を速くする

大きなリストやタブは最初から全部ロードしない。

```dart
// ListView.builder: アイテムを遅延生成
ListView.builder(
  itemCount: tasks.length,
  itemBuilder: (context, index) {
    return TaskCard(task: tasks[index]);  // 画面内だけ生成
  },
)

// AutomaticKeepAliveClientMixin: タブ切替でリビルドしない
class TaskTabPage extends StatefulWidget { /* ... */ }

class _TaskTabPageState extends State<TaskTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;  // タブ離脱後も状態を保持

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TaskList();
  }
}

// 画像の遅延ロード
Image.network(
  imageUrl,
  loadingBuilder: (context, child, progress) {
    if (progress == null) return child;
    return const CircularProgressIndicator();
  },
)
```

## 3. 画像キャッシュ: cached_network_image

```dart
// pubspec.yaml
// dependencies:
//   cached_network_image: ^3.3.0

import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: 'https://example.com/avatar.jpg',
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  // メモリキャッシュ: アプリ内
  memCacheWidth: 200,   // 実際の表示サイズに合わせてリサイズ
  memCacheHeight: 200,
  // ディスクキャッシュ: 次回起動時も有効
)
```

**Supabase Storage の画像変換** (リサイズをサーバー側で実施):

```dart
// ?width=200&height=200 でサーバー側リサイズ
final optimizedUrl = supabase.storage
    .from('avatars')
    .getPublicUrl('user123.jpg',
        transform: const TransformOptions(width: 200, height: 200));
```

## Flutter DevTools で計測

```bash
# DevTools を起動
flutter run --profile
# ブラウザで http://127.0.0.1:9100 を開く
```

確認ポイント:
- **Frame chart**: 16ms (60fps) を超えるフレームを特定
- **Widget rebuild**: 赤くハイライトされる過剰リビルドを検出
- **Memory**: メモリリーク (右肩上がりのグラフ)

## まとめ

```
const            → 変わらないウィジェットに付けるだけでリビルドスキップ
遅延ロード       → ListView.builder + AutomaticKeepAlive でスクロール高速化
画像キャッシュ   → cached_network_image + Supabase 変換でサイズ最適化
計測先行         → DevTools の Frame chart でボトルネック特定 → 最適化
```

計測なしのパフォーマンス改善は時間の無駄。まず DevTools で遅い箇所を見つける。
