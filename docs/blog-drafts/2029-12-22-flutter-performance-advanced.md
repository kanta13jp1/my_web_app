---
title: "Flutter パフォーマンス最適化上級編 — DevTools プロファイリング・Skia・Impeller の使いこなし"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter パフォーマンス最適化上級編 — DevTools プロファイリング・Skia・Impeller の使いこなし

Flutter アプリが「なんとなく重い」と感じたとき、勘に頼った最適化は時間の無駄です。本記事では Flutter DevTools を使った科学的なプロファイリング手法と、Impeller 移行まで含めた上級最適化テクニックを解説します。

## Flutter DevTools の Timeline タブを読む

`flutter run --profile` でプロファイルモードを起動し、DevTools の **Timeline** タブを開きます。注目すべき指標は以下の 3 つです。

- **UI スレッド**: Dart コードの実行時間。16ms を超えると Jank が発生します。
- **Raster スレッド**: GPU へのコマンド送信時間。重い ShaderMask や BackdropFilter はここに現れます。
- **Frame Budget**: 60fps であれば 1 フレームあたり 16.6ms、90fps なら 11.1ms が上限。

Timeline 上で赤くハイライトされたフレームをクリックすると、どのウィジェットの `build()` や `paint()` がボトルネックかを確認できます。**Rebuild count** を表示する `debugProfileBuildsEnabled = true` フラグも合わせて活用しましょう。

```dart
void main() {
  debugProfileBuildsEnabled = true; // Timeline に rebuild 数を表示
  runApp(const MyApp());
}
```

## Memory タブでリークを検出する

**Memory** タブの **Allocation Tracing** を有効にし、特定の操作を繰り返した後にスナップショットを比較します。`List<Uint8List>` や `StreamSubscription` が解放されずに積み上がっている場合はリークの疑いがあります。

`dispose()` で必ず購読をキャンセルしてください。

```dart
class _MyState extends State<MyWidget> {
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = stream.listen(_onData);
  }

  @override
  void dispose() {
    _sub.cancel(); // 忘れると Memory タブに積み上がる
    super.dispose();
  }
}
```

## Skia vs Impeller — 何が違うか

Flutter の描画バックエンドは従来 **Skia** でしたが、Flutter 3.10 以降 iOS では **Impeller** がデフォルトになり、Android でも段階的に移行中です。

| 項目 | Skia | Impeller |
|------|------|---------|
| シェーダーコンパイル | 実行時（= 初回 Jank） | 事前コンパイル（= Jank なし） |
| Metal/Vulkan 対応 | 間接レイヤー経由 | ネイティブ |
| カスタムシェーダー | 一部制限あり | GLSL サブセットをサポート |

**切替方法**（Android で Impeller を試す場合）:

```yaml
# AndroidManifest.xml の <application> タグ内に追記
<meta-data
  android:name="io.flutter.embedding.android.EnableImpeller"
  android:value="true" />
```

Impeller で描画崩れが起きた場合は `--no-enable-impeller` で一時的に無効化できます。

## const constructor の徹底活用

`const` を付けるだけでウィジェットツリーの再 build を防げます。コンパイル時定数にできるウィジェットはすべて `const` にする習慣を付けましょう。

```dart
// Bad
Column(children: [Text('Hello'), Icon(Icons.star)]);

// Good
const Column(children: [Text('Hello'), Icon(Icons.star)]);
```

`flutter analyze` に `prefer_const_constructors` lint を追加すると、`const` 化できる箇所を自動検出できます。

## RepaintBoundary と IndexedStack の使いどころ

アニメーションが走っているウィジェットを `RepaintBoundary` で囲むと、その領域だけが再 raster 化され、親ウィジェットの描画コストを節約できます。

```dart
RepaintBoundary(
  child: AnimatedWidget(...),
)
```

`IndexedStack` は非表示タブのウィジェットを破棄せず保持するため、タブ切替時の再 build を防ぎます。ただしメモリ使用量は増加するため、重い画面では注意が必要です。

## Dart Isolate でメインスレッドを解放する

JSON デコードや画像処理など CPU バウンドな処理は `compute()` を使って別 Isolate に逃がします。

```dart
Future<List<Item>> parseItems(String jsonStr) async {
  // メインスレッドをブロックしない
  return compute(_decodeItems, jsonStr);
}

List<Item> _decodeItems(String jsonStr) {
  final list = jsonDecode(jsonStr) as List;
  return list.map((e) => Item.fromJson(e)).toList();
}
```

より細かい制御が必要な場合は `Isolate.spawn()` と `SendPort`/`ReceivePort` を直接使います。大量データを送受信するときは `TransferableTypedData` でコピーゼロ転送にすると速度が大幅に向上します。

## まとめ

1. **Timeline** で Jank フレームを特定 → **Rebuild count** で無駄な build を発見
2. **Memory** タブで StreamSubscription / 画像キャッシュのリークを検出
3. iOS は Impeller デフォルト、Android も段階移行 → 事前コンパイルで初回 Jank を排除
4. `const` constructor + `RepaintBoundary` + `compute()` が上級最適化の三本柱

DevTools のデータを見ながら一か所ずつ改善することで、体感速度は確実に向上します。次回は Supabase Edge Functions の上級パターンを解説します。
