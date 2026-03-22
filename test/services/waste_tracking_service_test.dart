import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/waste_tracking_service.dart';

void main() {
  group('WasteTrackingService', () {
    test('attaches and strips explicit waste markers', () {
      final description = WasteTrackingService.attachWasteCategory(
        '[現金] 二次会',
        '飲酒',
      );

      expect(description, '[現金] 二次会 [浪費:飲酒]');
      expect(
        WasteTrackingService.stripWasteMarker(description),
        '[現金] 二次会',
      );
      expect(
        WasteTrackingService.extractWasteCategory(description),
        '飲酒',
      );
    });

    test('infers category from legacy memo keywords', () {
      expect(
        WasteTrackingService.extractWasteCategory('[現金] ビールと焼酎'),
        '飲酒',
      );
      expect(
        WasteTrackingService.extractWasteCategory('[現金] パチンコ'),
        'ギャンブル',
      );
      expect(
        WasteTrackingService.extractWasteCategory('[現金] Switchソフト'),
        'ゲーム',
      );
    });

    test('normalizes only supported categories', () {
      expect(WasteTrackingService.normalizeCategory('喫煙'), '喫煙');
      expect(WasteTrackingService.normalizeCategory('  喫煙  '), '喫煙');
      expect(WasteTrackingService.normalizeCategory('投資'), isNull);
      expect(WasteTrackingService.normalizeCategory(''), isNull);
    });
  });
}
