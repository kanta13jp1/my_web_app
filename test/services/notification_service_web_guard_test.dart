import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/notification_service.dart';

void main() {
  // R35: flutter_local_notifications の zonedSchedule は web 未対応で
  // UnsupportedError を投げる。main.dart は起動時に既定 true で
  // scheduleSaturdayReminder() を呼ぶため、ガードが無いと web の毎起動で
  // 例外→FlutterError.reportError→auto_error_report が発生する。
  test('スケジュール可否は web かどうかで決まる', () {
    expect(notificationSchedulingSupported, equals(!kIsWeb));
  });

  test('VM (非web) ではスケジュールが許可される', () {
    // このテストは VM で走るため web ではない = スケジュール可。
    expect(kIsWeb, isFalse);
    expect(notificationSchedulingSupported, isTrue);
  });
}
