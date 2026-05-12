---
title: "Dart FFI 上級編 — C ライブラリ統合・メモリ管理・Flutter プラグイン化"
tags: flutter,dart,個人開発,AI
published: true
---

## はじめに

Dart FFI (Foreign Function Interface) を使うと、C で書かれたライブラリを Dart/Flutter から直接呼び出せる。パフォーマンスクリティカルな画像処理・暗号化・音声デコードなどを Pure Dart で書くのは非効率だ。既存の C ライブラリ資産を最大限活用する方法を解説する。

---

## 1. dart:ffi で C 関数を呼ぶ基本

まず C ライブラリの関数シグネチャを確認する。

```c
// native/image_processor.h
int grayscale(uint8_t* pixels, int width, int height);
void free_buffer(uint8_t* buf);
```

Dart 側でシンボルをロードする:

```dart
import 'dart:ffi';
import 'dart:io';

// ネイティブ型の型エイリアス定義
typedef GrayscaleNative = Int32 Function(Pointer<Uint8>, Int32, Int32);
typedef GrayscaleDart = int Function(Pointer<Uint8>, int, int);

typedef FreeBufferNative = Void Function(Pointer<Uint8>);
typedef FreeBufferDart = void Function(Pointer<Uint8>);

class ImageProcessorFFI {
  late final DynamicLibrary _lib;
  late final GrayscaleDart _grayscale;
  late final FreeBufferDart _freeBuffer;

  ImageProcessorFFI() {
    // プラットフォーム別でライブラリをロード
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libimage_processor.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _lib = DynamicLibrary.process(); // iOS は静的リンク
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('image_processor.dll');
    } else {
      _lib = DynamicLibrary.open('libimage_processor.so');
    }

    _grayscale = _lib
        .lookup<NativeFunction<GrayscaleNative>>('grayscale')
        .asFunction();
    _freeBuffer = _lib
        .lookup<NativeFunction<FreeBufferNative>>('free_buffer')
        .asFunction();
  }
}
```

---

## 2. Pointer<T> と Struct でのメモリ操作

C の構造体を Dart から操作するには `Struct` を継承したクラスを定義する。

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// C の struct に対応する Dart クラス
final class ImageInfo extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Int32()
  external int channels;

  external Pointer<Uint8> data;
}

// 使用例
void processImage(Pointer<ImageInfo> imgPtr) {
  final info = imgPtr.ref;
  print('Width: ${info.width}, Height: ${info.height}');

  // ピクセルデータを Dart の List に変換
  final pixelCount = info.width * info.height * info.channels;
  final pixels = info.data.asTypedList(pixelCount);

  // 明度調整
  for (int i = 0; i < pixels.length; i++) {
    pixels[i] = (pixels[i] * 0.8).clamp(0, 255).toInt();
  }
}
```

---

## 3. Arena Allocator でスコープ付きメモリ管理

FFI でメモリを手動管理するのは事故の元だ。`Arena` を使うと `using` ブロックを抜けたときに自動解放される。

```dart
import 'package:ffi/ffi.dart';

Future<void> runWithArena() async {
  // Arena スコープ内でアロケート
  using((Arena arena) {
    // 文字列を C に渡す
    final nativeStr = 'Hello FFI'.toNativeUtf8(allocator: arena);

    // 構造体をアロケート
    final imageInfo = arena<ImageInfo>();
    imageInfo.ref.width = 640;
    imageInfo.ref.height = 480;
    imageInfo.ref.channels = 3;

    // ピクセルバッファをアロケート
    final pixelBuf = arena<Uint8>(640 * 480 * 3);
    imageInfo.ref.data = pixelBuf;

    // C 関数を呼ぶ
    processNativeImage(imageInfo, nativeStr);

    // スコープを抜けると arena が全メモリを自動解放
  });
}
```

`calloc` / `malloc` を直接使う場合は `free()` を忘れずに呼ぶ。Arena は特に複数のアロケーションが絡む処理で威力を発揮する。

---

## 4. NativeCallable で Dart コールバックを C に渡す

C ライブラリが進捗コールバックを要求する場合、`NativeCallable` を使って Dart 関数を C 関数ポインタとして渡せる。

```dart
typedef ProgressCallbackNative = Void Function(Int32 current, Int32 total);
typedef EncodeWithProgressNative = Void Function(
    Pointer<Uint8> data, Int32 len, Pointer<NativeFunction<ProgressCallbackNative>>);

void encodeWithProgress(Uint8List data) {
  // Dart のコールバックを C 関数ポインタに変換
  final callback = NativeCallable<ProgressCallbackNative>.listener(
    (int current, int total) {
      final percent = (current / total * 100).toStringAsFixed(1);
      print('Encoding: $percent%');
    },
  );

  using((arena) {
    final nativeData = arena<Uint8>(data.length);
    nativeData.asTypedList(data.length).setAll(0, data);

    final encodeWithProgressFn = _lib
        .lookup<NativeFunction<EncodeWithProgressNative>>('encode_with_progress')
        .asFunction<void Function(Pointer<Uint8>, int, Pointer<NativeFunction<ProgressCallbackNative>>)>();

    encodeWithProgressFn(nativeData, data.length, callback.nativeFunction);
  });

  // 使い終わったら必ず close する
  callback.close();
}
```

`NativeCallable.listener` は Dart の isolate 上でコールバックを受け取る（スレッドセーフ）。

---

## 5. Flutter プラグインとして FFI コードをパッケージ化

再利用可能にするには Flutter Plugin 構造でパッケージ化する。

```yaml
# pubspec.yaml（プラグイン側）
name: image_processor_ffi
description: Flutter plugin wrapping libimage_processor via dart:ffi

flutter:
  plugin:
    platforms:
      android:
        ffiPlugin: true
      ios:
        ffiPlugin: true
      macos:
        ffiPlugin: true
      windows:
        ffiPlugin: true
      linux:
        ffiPlugin: true
```

`ffiPlugin: true` を指定すると Flutter のビルドシステムが `CMakeLists.txt` や `Podfile` を自動的に処理する。C ソースは `src/` に置けば自動コンパイルされる。

```
image_processor_ffi/
  lib/
    image_processor_ffi.dart   # Dart API
  src/
    image_processor.c          # C 実装
    image_processor.h
  android/
    CMakeLists.txt
  ios/
    Classes/
  windows/
    CMakeLists.txt
```

---

## 実用例：OpenSSL AES 暗号化を Flutter で使う

```dart
// AES-256-CBC 暗号化の例（OpenSSL FFI ラッパー）
Uint8List aesEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
  return using((arena) {
    final ptPtr = arena<Uint8>(plaintext.length);
    ptPtr.asTypedList(plaintext.length).setAll(0, plaintext);

    final keyPtr = arena<Uint8>(32);
    keyPtr.asTypedList(32).setAll(0, key);

    final ivPtr = arena<Uint8>(16);
    ivPtr.asTypedList(16).setAll(0, iv);

    final ctPtr = arena<Uint8>(plaintext.length + 16); // パディング分
    final ctLen = arena<Int32>();

    _opensslAesEncrypt(ptPtr, plaintext.length, keyPtr, ivPtr, ctPtr, ctLen);

    return Uint8List.fromList(ctPtr.asTypedList(ctLen.value));
  });
}
```

---

## まとめ

| 機能 | 用途 |
|------|------|
| `DynamicLibrary.open` | 共有ライブラリのロード |
| `Pointer<T>` / `Struct` | C のポインタ・構造体を Dart で操作 |
| `Arena` allocator | スコープ付き安全なメモリ管理 |
| `NativeCallable` | C へのコールバック渡し |
| `ffiPlugin: true` | Flutter プラグインとして配布 |

dart:ffi は Dart の守備範囲を大幅に広げる機能だ。Pure Dart では難しいパフォーマンスが要求される処理を、既存の C エコシステムを活用して Flutter アプリに組み込める。
