import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_flow_description_service.dart';
import 'package:my_web_app/services/waste_tracking_service.dart';

FlowDescriptionParts _parts({
  String source = '',
  String destination = '',
  String memo = '',
  bool isTransfer = false,
}) {
  return (
    source: source,
    destination: destination,
    memo: memo,
    wasteCategory: null,
    isTransfer: isTransfer,
  );
}

void main() {
  group('AssetFlowDescriptionService', () {
    test('sourceLabel strips bracket markers', () {
      expect(AssetFlowDescriptionService.sourceLabel('[楽天カード]'), '楽天カード');
      expect(AssetFlowDescriptionService.sourceLabel(''), '');
    });

    test('displayTitle joins a transfer route and memo', () {
      expect(
        AssetFlowDescriptionService.displayTitle(
          _parts(
            source: '[A]',
            destination: '[B]',
            memo: 'メモ',
            isTransfer: true,
          ),
        ),
        'A → B ・ メモ',
      );
    });

    test('displayTitle for a transfer without memo shows the route only', () {
      expect(
        AssetFlowDescriptionService.displayTitle(
          _parts(source: '[A]', destination: '[B]', isTransfer: true),
        ),
        'A → B',
      );
    });

    test('displayTitle joins source and memo for a non-transfer', () {
      expect(
        AssetFlowDescriptionService.displayTitle(
          _parts(source: '[財布]', memo: 'ランチ'),
        ),
        '財布 ・ ランチ',
      );
    });

    test('displayTitle falls back to memo when there is no source', () {
      expect(
        AssetFlowDescriptionService.displayTitle(_parts(memo: 'コンビニ')),
        'コンビニ',
      );
    });
  });

  group('AssetFlowDescriptionService.parse', () {
    test('parses an expense with source and memo', () {
      final parts = AssetFlowDescriptionService.parse(
        '[財布] ランチ',
        actionType: 'expense',
      );
      expect(parts.source, '[財布]');
      expect(parts.memo, 'ランチ');
      expect(parts.isTransfer, isFalse);
    });

    test('parses a transfer route with memo', () {
      final parts = AssetFlowDescriptionService.parse(
        '[A] -> [B] 引越し資金',
        actionType: 'transfer',
      );
      expect(parts.source, '[A]');
      expect(parts.destination, '[B]');
      expect(parts.memo, '引越し資金');
      expect(parts.isTransfer, isTrue);
    });

    test('falls back to memo-only when there is no bracket', () {
      final parts = AssetFlowDescriptionService.parse(
        '給料',
        actionType: 'income',
      );
      expect(parts.source, '');
      expect(parts.memo, '給料');
      expect(parts.isTransfer, isFalse);
    });

    test('extracts and strips the waste marker only for expenses', () {
      final category = WasteTrackingService.categoryLabels.first;
      final described = WasteTrackingService.attachWasteCategory(
        '[セブン] コーヒー',
        category,
      );

      final expense = AssetFlowDescriptionService.parse(
        described,
        actionType: 'expense',
      );
      expect(expense.source, '[セブン]');
      expect(expense.memo, 'コーヒー'); // 浪費マーカーは除去
      expect(expense.wasteCategory, category);

      final income = AssetFlowDescriptionService.parse(
        described,
        actionType: 'income',
      );
      expect(income.wasteCategory, isNull);
      expect(income.memo, contains('[浪費:')); // 非支出はマーカー保持
    });
  });
}
