import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/artifact_kv_storage_service.dart';
import 'package:my_web_app/widgets/artifact_kv_storage_card.dart';

void main() {
  test('ArtifactKvStorageService enforces key format, size limit, and LWW',
      () async {
    final service = ArtifactKvStorageService(
      maxPayloadBytes: 32,
      clock: () => DateTime.utc(2026, 11, 27, 2, 0, 0),
    );

    await expectLater(
      () => service.put(
        scope: ArtifactStorageScope.private,
        key: 'invalid_key',
        payloadJson: '{}',
      ),
      throwsA(isA<ArtifactKvValidationException>()),
    );

    await expectLater(
      () => service.put(
        scope: ArtifactStorageScope.private,
        key: 'table:item_1',
        payloadJson: '{"data":"012345678901234567890123456789"}',
      ),
      throwsA(isA<ArtifactKvValidationException>()),
    );

    await service.put(
      scope: ArtifactStorageScope.shared,
      key: 'table:item_1',
      payloadJson: '{"v":2}',
      updatedAt: DateTime.utc(2026, 11, 27, 2, 0, 0),
    );
    await service.put(
      scope: ArtifactStorageScope.shared,
      key: 'table:item_1',
      payloadJson: '{"v":1}',
      updatedAt: DateTime.utc(2026, 11, 27, 1, 0, 0),
    );

    final resolved = await service.get(
      scope: ArtifactStorageScope.shared,
      key: 'table:item_1',
    );
    expect(resolved?.payloadJson, '{"v":2}');
  });

  testWidgets('ArtifactKvStorageCard renders at 360x800 with 2.0x textScale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = ArtifactKvStorageService(
      clock: () => DateTime.utc(2026, 11, 27, 2, 0, 0),
    );
    await service.put(
      scope: ArtifactStorageScope.private,
      key: 'canvas:doc-1',
      payloadJson: '{"ok":true}',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ArtifactKvStorageCard(storageService: service),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Artifact 永続ストレージ'), findsOneWidget);
    expect(find.text('canvas:doc-1 (11B)'), findsOneWidget);
    expect(find.text('再読込'), findsOneWidget);
    expect(find.text('状態保存'), findsOneWidget);
    expect(find.text('共有切替'), findsOneWidget);
  });
}
