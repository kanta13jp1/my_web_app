---
title: "Flutter Platform Channels 上級編 — 型安全なDart-Native通信の実践"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter Platform Channels 上級編 — 型安全なDart-Native通信の実践

Flutter アプリでネイティブ機能を呼び出す際、`MethodChannel` の生の `dynamic` 型は実行時エラーの温床です。本記事では、型安全なチャネル設計・Pigeon による自動コード生成・エラーハンドリングのベストプラクティスを解説します。

## Platform Channel の基本アーキテクチャ

Flutter の Platform Channel は3種類あります。

```
Dart (Flutter) ←→ Platform Channel ←→ Native (iOS/Android)
  MethodChannel    メソッド呼び出し (1回)
  EventChannel     ストリーム送信 (連続)
  BasicMessageChannel  文字列/バイナリ送信
```

最も一般的な `MethodChannel` の問題は型安全性の欠如です。

```dart
// ❌ 型安全でない従来の書き方
static const _channel = MethodChannel('com.example.app/sensor');

Future<double> getBatteryLevel() async {
  final result = await _channel.invokeMethod('getBatteryLevel');
  return result as double; // ランタイムキャストエラーの可能性
}
```

## Pigeon で型安全なチャネルを自動生成

[Pigeon](https://pub.dev/packages/pigeon) は Dart のインターフェース定義からネイティブコードを自動生成します。

```dart
// pigeons/sensor_api.dart (定義ファイル)
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/platform/sensor_api.g.dart',
  swiftOut: 'ios/Runner/SensorApi.g.swift',
  kotlinOut: 'android/app/src/main/kotlin/SensorApi.g.kt',
))
class BatteryInfo {
  BatteryInfo({required this.level, required this.isCharging});
  final double level;
  final bool isCharging;
}

@HostApi()
abstract class SensorHostApi {
  BatteryInfo getBatteryInfo();
  @async
  BatteryInfo refreshBatteryInfo();
}

@FlutterApi()
abstract class SensorFlutterApi {
  void onBatteryLevelChanged(double level);
}
```

生成コマンドを実行すると完全に型付けされたクライアントコードが生成されます。

```bash
dart run pigeon --input pigeons/sensor_api.dart
```

## 生成コードの使い方

```dart
// lib/platform/sensor_service.dart
import 'sensor_api.g.dart';

class SensorService {
  final SensorHostApi _api = SensorHostApi();

  Future<BatteryInfo> getBatteryInfo() async {
    try {
      return await _api.refreshBatteryInfo();
    } on PlatformException catch (e) {
      throw SensorException(e.code, e.message);
    }
  }
}
```

Pigeon が生成したコードは `dynamic` キャストを含まず、コンパイル時に型エラーを検出できます。

## EventChannel でリアルタイムセンサーデータを受信

連続的なネイティブイベントには `EventChannel` を使います。

```dart
// Flutter側: センサーストリームを受信
class AccelerometerService {
  static const _channel = EventChannel('com.example.app/accelerometer');

  Stream<AccelerometerData> get stream => _channel
      .receiveBroadcastStream()
      .map((event) => AccelerometerData.fromMap(Map<String, dynamic>.from(event)));
}

// データクラス
class AccelerometerData {
  const AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  factory AccelerometerData.fromMap(Map<String, dynamic> map) {
    return AccelerometerData(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
```

## iOS 側の実装 (Swift)

```swift
// AppDelegate.swift
import Flutter
import UIKit
import CoreMotion

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private let motionManager = CMMotionManager()
  private var eventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterEventChannel(
      name: "com.example.app/accelerometer",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setStreamHandler(self)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    self.eventSink = events
    motionManager.accelerometerUpdateInterval = 0.1
    motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
      guard let data = data else { return }
      self?.eventSink?([
        "x": data.acceleration.x,
        "y": data.acceleration.y,
        "z": data.acceleration.z,
        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopAccelerometerUpdates()
    eventSink = nil
    return nil
  }
}
```

## Android 側の実装 (Kotlin)

```kotlin
// MainActivity.kt
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

class MainActivity: FlutterActivity() {
    private val sensorManager by lazy {
        getSystemService(SENSOR_SERVICE) as SensorManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.app/accelerometer"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            private var listener: SensorEventListener? = null

            override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                listener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        sink.success(mapOf(
                            "x" to event.values[0].toDouble(),
                            "y" to event.values[1].toDouble(),
                            "z" to event.values[2].toDouble(),
                            "timestamp" to System.currentTimeMillis()
                        ))
                    }
                    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
                }
                sensorManager.registerListener(
                    listener, sensor, SensorManager.SENSOR_DELAY_NORMAL
                )
            }

            override fun onCancel(args: Any?) {
                sensorManager.unregisterListener(listener)
                listener = null
            }
        })
    }
}
```

## エラーハンドリングのベストプラクティス

```dart
// カスタム例外クラス
sealed class PlatformChannelException implements Exception {
  const PlatformChannelException(this.message);
  final String message;
}

class PermissionDeniedException extends PlatformChannelException {
  const PermissionDeniedException() : super('センサーへのアクセス許可がありません');
}

class HardwareUnavailableException extends PlatformChannelException {
  const HardwareUnavailableException(String sensor)
      : super('$sensor センサーが利用できません');
}

// エラーコードマッピング
extension PlatformExceptionMapper on PlatformException {
  PlatformChannelException toTyped() => switch (code) {
    'PERMISSION_DENIED' => const PermissionDeniedException(),
    'HARDWARE_UNAVAILABLE' => HardwareUnavailableException(message ?? 'Unknown'),
    _ => PlatformChannelException('Unexpected error: $message'),
  };
}
```

## テスト戦略

```dart
// test/platform/sensor_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SensorService', () {
    setUp(() {
      // MethodChannel をモック化
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.app/sensor'),
        (MethodCall call) async {
          if (call.method == 'getBatteryInfo') {
            return {'level': 85.0, 'isCharging': true};
          }
          throw PlatformException(code: 'NOT_IMPLEMENTED');
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('com.example.app/sensor'), null);
    });

    test('getBatteryInfo returns typed data', () async {
      final service = SensorService();
      final info = await service.getBatteryInfo();
      expect(info.level, 85.0);
      expect(info.isCharging, true);
    });
  });
}
```

## パフォーマンス最適化

Platform Channel の呼び出しはメインスレッドをブロックしません。ただし高頻度のメッセージパッシングはパフォーマンスに影響します。

```dart
// ✅ バッファリングで呼び出し頻度を削減
class ThrottledSensorService {
  Stream<AccelerometerData> get stream => AccelerometerService()
      .stream
      .throttleTime(const Duration(milliseconds: 100)); // 10Hz に制限
}
```

## まとめ

Platform Channels を型安全に使うポイントです。

1. **Pigeon** で自動生成 → `dynamic` を排除
2. **Sealed class** + `switch` でエラー網羅
3. **EventChannel** でストリームを活用
4. **Mock MethodCall** でユニットテストを書く
5. **Throttle** で高頻度イベントを制御

型安全なネイティブ連携は、プラグイン開発・センサー取得・ファイルシステム操作など多岐にわたります。Pigeon を導入するだけでランタイムエラーの大部分を防止できます。

---

*自分株式会社では Flutter + Supabase で日本の21競合SaaSを1つに統合するライフマネジメントアプリを開発しています。開発の舞台裏を発信中 → [@kanta13jp1](https://x.com/kanta13jp1)*
