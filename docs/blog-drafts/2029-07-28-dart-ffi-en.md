---
title: "Dart FFI Guide — Calling C/C++ Libraries from Flutter"
tags: flutter,dart,webdev,indiedev
published: true
---

# Dart FFI Guide — Calling C/C++ Libraries from Flutter

Dart FFI lets you call C/C++ libraries directly from Flutter. Useful for crypto, image processing, ML inference, or any CPU-heavy task where pure Dart is too slow.

## Basic Setup

```yaml
dependencies:
  ffi: ^2.1.0
```

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Define C function signature
typedef AddNative = Int32 Function(Int32 a, Int32 b);
typedef AddDart = int Function(int a, int b);

// Load library
final dylib = Platform.isAndroid
    ? DynamicLibrary.open('libmylib.so')
    : Platform.isIOS
        ? DynamicLibrary.process()
        : DynamicLibrary.open('mylib.dll');

// Bind function
final add = dylib.lookupFunction<AddNative, AddDart>('add');

// Call it
final result = add(3, 4);  // 7
```

## C Library

```c
#ifdef _WIN32
  #define EXPORT __declspec(dllexport)
#else
  #define EXPORT __attribute__((visibility("default")))
#endif

EXPORT int32_t add(int32_t a, int32_t b) { return a + b; }

EXPORT char* to_upper(const char* str) {
  size_t len = strlen(str);
  char* result = (char*)malloc(len + 1);
  for (size_t i = 0; i < len; i++) result[i] = toupper(str[i]);
  result[len] = '\0';
  return result;
}

EXPORT void free_string(char* str) { free(str); }
```

## String Passing

```dart
typedef ToUpperNative = Pointer<Utf8> Function(Pointer<Utf8>);
final toUpper = dylib.lookupFunction<ToUpperNative, ToUpperNative>('to_upper');
final freeStr = dylib.lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>('free_string');

String callToUpper(String s) {
  final ptr = s.toNativeUtf8();
  final result = toUpper(ptr);
  final dart = result.toDartString();
  calloc.free(ptr);
  freeStr(result);
  return dart;
}
```

## Structs

```dart
final class Vector3 extends Struct {
  @Double() external double x;
  @Double() external double y;
  @Double() external double z;
}

typedef MagnitudeFn = Double Function(Pointer<Vector3>);
final magnitude = dylib.lookupFunction<MagnitudeFn, double Function(Pointer<Vector3>)>('magnitude');

double calcMagnitude(double x, double y, double z) {
  final vec = calloc<Vector3>()
    ..ref.x = x ..ref.y = y ..ref.z = z;
  final r = magnitude(vec);
  calloc.free(vec);
  return r;
}
```

## Real Use Case: Image Processing

```c
EXPORT void apply_grayscale(uint8_t* pixels, int32_t width, int32_t height) {
  int total = width * height * 4;
  for (int i = 0; i < total; i += 4) {
    uint8_t g = (uint8_t)(0.299*pixels[i] + 0.587*pixels[i+1] + 0.114*pixels[i+2]);
    pixels[i] = pixels[i+1] = pixels[i+2] = g;
  }
}
```

```dart
Future<Uint8List> applyGrayscale(Uint8List pixels, int w, int h) async {
  final ptr = calloc<Uint8>(pixels.length);
  ptr.asTypedList(pixels.length).setAll(0, pixels);
  grayscale(ptr, w, h);
  final result = Uint8List.fromList(ptr.asTypedList(pixels.length));
  calloc.free(ptr);
  return result;
}
```

## Android Build Config

```cmake
# android/CMakeLists.txt
cmake_minimum_required(VERSION 3.10)
add_library(mylib SHARED ../native/mylib.c ../native/image_utils.c)
target_include_directories(mylib PUBLIC ../native)
```

## When to Use FFI

| Scenario | Use FFI? |
|---|---|
| CPU-heavy processing (image/audio) | ✅ Yes |
| Existing C library you don't want to rewrite | ✅ Yes |
| ML model inference (via ONNX/TFLite C API) | ✅ Yes |
| Normal business logic | ❌ No (Dart is fast enough) |
| IO-bound operations | ❌ No (use async/await) |

FFI can yield 10-100x speedups for the right workloads.

---

Have you used Dart FFI in production? What C library did you wrap and why? Drop a comment.
