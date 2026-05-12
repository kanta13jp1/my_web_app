---
title: "Flutter プラグイン開発入門 — ネイティブ機能を Dart から呼び出す"
tags: flutter,dart,AI,個人開発
published: true
---

# Flutter プラグイン開発入門 — ネイティブ機能を Dart から呼び出す

Flutter の豊富なパッケージエコシステムでもカバーできないネイティブ機能が必要になることがあります。Platform Channel を使った Flutter プラグイン開発の基本を解説します。

## プラグインが必要になるケース

- 既存の pub.dev パッケージが存在しない機能
- 既存パッケージのパフォーマンスが不十分
- 社内ライブラリ・独自 SDK との連携
- OS 固有の深い機能 (バックグラウンド処理、ハードウェアアクセス等)

## プラグインの構造

```
my_plugin/
  lib/
    my_plugin.dart          # Dart API
    my_plugin_platform_interface.dart
    my_plugin_method_channel.dart
  android/
    src/main/kotlin/
      com/example/my_plugin/
        MyPlugin.kt         # Android 実装
  ios/
    Classes/
      MyPlugin.swift        # iOS 実装
  example/
    lib/main.dart           # 動作確認用アプリ
  pubspec.yaml
```

## プラグインの雛形生成

```bash
flutter create --template=plugin --platforms=android,ios my_plugin
cd my_plugin
```

## Dart 側の実装

```dart
// lib/my_plugin.dart
import 'my_plugin_platform_interface.dart';

class MyPlugin {
  // デバイスのバッテリーレベルを取得
  static Future<int?> getBatteryLevel() {
    return MyPluginPlatform.instance.getBatteryLevel();
  }
}
```

```dart
// lib/my_plugin_method_channel.dart
import 'package:flutter/services.dart';
import 'my_plugin_platform_interface.dart';

class MethodChannelMyPlugin extends MyPluginPlatform {
  static const _channel = MethodChannel('my_plugin');

  @override
  Future<int?> getBatteryLevel() async {
    try {
      return await _channel.invokeMethod<int>('getBatteryLevel');
    } on PlatformException catch (e) {
      throw Exception('Failed to get battery level: ${e.message}');
    }
  }
}
```

## Android 実装 (Kotlin)

```kotlin
// android/src/main/kotlin/com/example/my_plugin/MyPlugin.kt
package com.example.my_plugin

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "my_plugin")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBatteryLevel" -> {
                val batteryLevel = getBatteryLevel()
                if (batteryLevel != -1) {
                    result.success(batteryLevel)
                } else {
                    result.error("UNAVAILABLE", "Battery level not available.", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getBatteryLevel(): Int {
        val batteryIntent = context.registerReceiver(
            null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )
        val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        return if (level != -1 && scale != -1) (level * 100 / scale) else -1
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
```

## iOS 実装 (Swift)

```swift
// ios/Classes/MyPlugin.swift
import Flutter
import UIKit

public class MyPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "my_plugin",
            binaryMessenger: registrar.messenger()
        )
        let instance = MyPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getBatteryLevel":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let batteryLevel = Int(UIDevice.current.batteryLevel * 100)
            if batteryLevel >= 0 {
                result(batteryLevel)
            } else {
                result(FlutterError(
                    code: "UNAVAILABLE",
                    message: "Battery level not available",
                    details: nil
                ))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

## テスト

```dart
// test/my_plugin_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_plugin/my_plugin_method_channel.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelMyPlugin();

  test('getBatteryLevel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('my_plugin'),
      (call) async {
        if (call.method == 'getBatteryLevel') return 42;
        return null;
      },
    );

    final result = await platform.getBatteryLevel();
    expect(result, 42);
  });
}
```

## pub.dev への公開

```bash
# 公開前チェック
flutter pub publish --dry-run

# 公開
flutter pub publish
```

## まとめ

Platform Channel を使えば、Flutter から任意のネイティブ機能にアクセスできます。Dart / Kotlin / Swift の 3 層を意識して実装することで、型安全で保守しやすいプラグインが作れます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
