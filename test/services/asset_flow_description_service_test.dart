import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_flow_description_service.dart';

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
}
