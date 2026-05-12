---
title: "Dart FFI Advanced — C Library Integration, Memory Management, and Flutter Plugin"
tags: dart,flutter,webdev,indiedev
published: true
---

## Introduction

Dart FFI (Foreign Function Interface) lets you call C libraries directly from Dart and Flutter. Writing performance-critical code — image processing, cryptography, audio decoding — in Pure Dart is often impractical. FFI lets you leverage the entire C ecosystem instead. This article covers everything from loading a shared library to packaging your FFI code as a reusable Flutter plugin.

---

## 1. Calling C Functions with dart:ffi

Start by examining the C library's function signatures:

```c
// native/image_processor.h
int grayscale(uint8_t* pixels, int width, int height);
void free_buffer(uint8_t* buf);
```

Load and call them from Dart:

```dart
import 'dart:ffi';
import 'dart:io';

// Define native and Dart type aliases
typedef GrayscaleNative = Int32 Function(Pointer<Uint8>, Int32, Int32);
typedef GrayscaleDart = int Function(Pointer<Uint8>, int, int);

typedef FreeBufferNative = Void Function(Pointer<Uint8>);
typedef FreeBufferDart = void Function(Pointer<Uint8>);

class ImageProcessorFFI {
  late final DynamicLibrary _lib;
  late final GrayscaleDart _grayscale;
  late final FreeBufferDart _freeBuffer;

  ImageProcessorFFI() {
    // Load the shared library per platform
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libimage_processor.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _lib = DynamicLibrary.process(); // iOS uses static linking
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

## 2. Memory Operations with Pointer<T> and Struct

To work with C structs from Dart, extend the `Struct` class:

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Dart mirror of a C struct
final class ImageInfo extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Int32()
  external int channels;

  external Pointer<Uint8> data;
}

void processImage(Pointer<ImageInfo> imgPtr) {
  final info = imgPtr.ref;
  print('Width: ${info.width}, Height: ${info.height}');

  // Convert native pixel buffer to a Dart TypedData view
  final pixelCount = info.width * info.height * info.channels;
  final pixels = info.data.asTypedList(pixelCount);

  // In-place brightness reduction
  for (int i = 0; i < pixels.length; i++) {
    pixels[i] = (pixels[i] * 0.8).clamp(0, 255).toInt();
  }
}
```

`asTypedList` gives you a zero-copy `Uint8List` view into native memory — mutations affect the C buffer directly.

---

## 3. Scoped Memory Management with Arena Allocator

Manual `malloc`/`free` is error-prone. The `Arena` allocator from `package:ffi` automatically frees everything when the scope exits.

```dart
import 'package:ffi/ffi.dart';

Future<void> runWithArena() async {
  using((Arena arena) {
    // Allocate a native UTF-8 string
    final nativeStr = 'Hello FFI'.toNativeUtf8(allocator: arena);

    // Allocate a struct
    final imageInfo = arena<ImageInfo>();
    imageInfo.ref.width = 640;
    imageInfo.ref.height = 480;
    imageInfo.ref.channels = 3;

    // Allocate a pixel buffer
    final pixelBuf = arena<Uint8>(640 * 480 * 3);
    imageInfo.ref.data = pixelBuf;

    // Call C function
    processNativeImage(imageInfo, nativeStr);

    // All allocations freed automatically when `using` block exits
  });
}
```

Use `calloc`/`malloc` directly only when you need allocations to outlive a scope. In that case, always pair with an explicit `calloc.free()` call in a `finally` block or a `Finalizer`.

---

## 4. NativeCallable — Passing Dart Callbacks to C

When a C library requires a progress callback, use `NativeCallable` to pass a Dart function as a C function pointer:

```dart
typedef ProgressCallbackNative = Void Function(Int32 current, Int32 total);
typedef EncodeWithProgressNative = Void Function(
    Pointer<Uint8> data,
    Int32 len,
    Pointer<NativeFunction<ProgressCallbackNative>>);

void encodeWithProgress(Uint8List data) {
  // Wrap a Dart closure as a C function pointer
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
        .asFunction<
            void Function(Pointer<Uint8>, int,
                Pointer<NativeFunction<ProgressCallbackNative>>)>();

    encodeWithProgressFn(nativeData, data.length, callback.nativeFunction);
  });

  // Always close to release the underlying port
  callback.close();
}
```

`NativeCallable.listener` dispatches the callback on the Dart isolate, making it thread-safe for use with multithreaded C libraries.

---

## 5. Packaging FFI Code as a Flutter Plugin

To share your FFI wrapper across projects, package it as a Flutter plugin with `ffiPlugin: true`:

```yaml
# pubspec.yaml (plugin side)
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

With `ffiPlugin: true`, Flutter's build system automatically handles `CMakeLists.txt` on Android/Windows/Linux and `Podspec` on iOS/macOS. Place your C source in `src/` and it gets compiled automatically.

```
image_processor_ffi/
  lib/
    image_processor_ffi.dart   # Public Dart API
  src/
    image_processor.c          # C implementation
    image_processor.h
  android/
    CMakeLists.txt
  ios/
    Classes/
  windows/
    CMakeLists.txt
```

---

## Practical Example: OpenSSL AES Encryption in Flutter

```dart
// AES-256-CBC encryption via OpenSSL FFI wrapper
Uint8List aesEncrypt(Uint8List plaintext, Uint8List key, Uint8List iv) {
  return using((arena) {
    final ptPtr = arena<Uint8>(plaintext.length);
    ptPtr.asTypedList(plaintext.length).setAll(0, plaintext);

    final keyPtr = arena<Uint8>(32); // 256-bit key
    keyPtr.asTypedList(32).setAll(0, key);

    final ivPtr = arena<Uint8>(16);
    ivPtr.asTypedList(16).setAll(0, iv);

    // Extra 16 bytes for PKCS7 padding
    final ctPtr = arena<Uint8>(plaintext.length + 16);
    final ctLen = arena<Int32>();

    _opensslAesEncrypt(ptPtr, plaintext.length, keyPtr, ivPtr, ctPtr, ctLen);

    return Uint8List.fromList(ctPtr.asTypedList(ctLen.value));
  });
}
```

---

## Summary

| Feature | Purpose |
|---------|---------|
| `DynamicLibrary.open` | Load a shared library at runtime |
| `Pointer<T>` / `Struct` | Manipulate C memory from Dart |
| `Arena` allocator | Scoped, exception-safe memory management |
| `NativeCallable` | Pass Dart closures as C function pointers |
| `ffiPlugin: true` | Package FFI code as a distributable Flutter plugin |

Dart FFI dramatically expands what you can do with Flutter. Performance-sensitive workloads that would be impractical in Pure Dart — image processing, audio codecs, cryptography — become straightforward by leveraging the proven C ecosystem. Start with `Arena` for memory safety and `NativeCallable` for callbacks, and you'll avoid most of the pitfalls that make FFI feel intimidating.
