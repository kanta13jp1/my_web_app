---
title: "Flutter Plugin Development — Calling Native Features from Dart"
tags: flutter,dart,ai,indiedev
published: true
---

# Flutter Plugin Development — Calling Native Features from Dart

Sometimes Flutter's rich package ecosystem doesn't cover the native feature you need. This guide covers the basics of Flutter plugin development using Platform Channels.

## When You Need a Plugin

- No existing pub.dev package covers the feature
- Existing packages have insufficient performance
- Integration with internal libraries or proprietary SDKs
- Deep OS-specific features (background processing, hardware access, etc.)

## Plugin Structure

```
my_plugin/
  lib/
    my_plugin.dart          # Dart API
    my_plugin_platform_interface.dart
    my_plugin_method_channel.dart
  android/
    src/main/kotlin/
      com/example/my_plugin/
        MyPlugin.kt         # Android implementation
  ios/
    Classes/
      MyPlugin.swift        # iOS implementation
  example/
    lib/main.dart           # Test app
  pubspec.yaml
```

## Generate the Plugin Scaffold

```bash
flutter create --template=plugin --platforms=android,ios my_plugin
cd my_plugin
```

## Dart Implementation

```dart
// lib/my_plugin.dart
import 'my_plugin_platform_interface.dart';

class MyPlugin {
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

## Android Implementation (Kotlin)

```kotlin
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
                if (batteryLevel != -1) result.success(batteryLevel)
                else result.error("UNAVAILABLE", "Battery level not available.", null)
            }
            else -> result.notImplemented()
        }
    }

    private fun getBatteryLevel(): Int {
        val intent = context.registerReceiver(
            null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        return if (level != -1 && scale != -1) (level * 100 / scale) else -1
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
```

## iOS Implementation (Swift)

```swift
import Flutter
import UIKit

public class MyPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "my_plugin",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(MyPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getBatteryLevel":
            UIDevice.current.isBatteryMonitoringEnabled = true
            let level = Int(UIDevice.current.batteryLevel * 100)
            if level >= 0 { result(level) }
            else { result(FlutterError(code: "UNAVAILABLE", message: "Not available", details: nil)) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

## Testing

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelMyPlugin();

  test('getBatteryLevel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('my_plugin'),
      (call) async => call.method == 'getBatteryLevel' ? 42 : null,
    );

    expect(await platform.getBatteryLevel(), 42);
  });
}
```

## Publishing to pub.dev

```bash
# Pre-publish check
flutter pub publish --dry-run

# Publish
flutter pub publish
```

## Summary

Platform Channels give Flutter access to any native feature. By structuring your plugin across Dart / Kotlin / Swift layers, you get type-safe, maintainable plugins ready to share with the community.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
