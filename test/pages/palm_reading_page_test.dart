import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/palm_reading_image.dart';
import 'package:my_web_app/data/repositories/palm_reading_repository.dart';
import 'package:my_web_app/data/services/palm_reading_image_picker.dart';
import 'package:my_web_app/domain/models/palm_reading.dart';
import 'package:my_web_app/ui/features/palm_reading/view_models/palm_reading_view_model.dart';
import 'package:my_web_app/ui/features/palm_reading/views/palm_reading_page.dart';

void main() {
  testWidgets('guided capture enables AI only after photo and consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = PalmReadingViewModel(
      repository: _FakeRepository(),
      imagePicker: _FakePicker(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PalmReadingPage(viewModel: viewModel, isSignedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('きれいに読み取る4つのコツ'), findsOneWidget);
    expect(find.textContaining('手首まで写す'), findsOneWidget);
    expect(find.text('写真を選ぶ'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('palm_analyze_button')))
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.byKey(const Key('palm_gallery_button')));
    await tester.tap(find.byKey(const Key('palm_gallery_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palm_photo_preview')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('palm_privacy_consent')));
    await tester.tap(find.byKey(const Key('palm_privacy_consent')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('palm_analyze_button')))
          .onPressed,
      isNotNull,
    );

    await tester.ensureVisible(find.byKey(const Key('palm_analyze_button')));
    await tester.tap(find.byKey(const Key('palm_analyze_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palm_reading_result')), findsOneWidget);
    expect(find.text('生命線'), findsOneWidget);
    expect(find.textContaining('科学的・医学的な診断ではありません'), findsOneWidget);
  });

  testWidgets('history tab renders prior comparison and filters', (
    tester,
  ) async {
    final viewModel = PalmReadingViewModel(
      repository: _FakeRepository(history: <PalmReading>[_reading]),
      imagePicker: _FakePicker(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PalmReadingPage(viewModel: viewModel, isSignedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴・変化'));
    await tester.pumpAndSettle();

    expect(find.text('手相の変化を振り返る'), findsOneWidget);
    expect(find.textContaining('前回より'), findsOneWidget);
    expect(find.text('左手'), findsWidgets);
    expect(find.text('右手'), findsOneWidget);
  });

  testWidgets('desktop history uses a grid without layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = PalmReadingViewModel(
      repository: _FakeRepository(history: <PalmReading>[_reading]),
      imagePicker: _FakePicker(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PalmReadingPage(viewModel: viewModel, isSignedIn: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴・変化'));
    await tester.pumpAndSettle();

    expect(find.byType(SliverGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out users see a login gate', (tester) async {
    final viewModel = PalmReadingViewModel(
      repository: _FakeRepository(),
      imagePicker: _FakePicker(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PalmReadingPage(viewModel: viewModel, isSignedIn: false),
      ),
    );

    expect(find.text('手相AI占いにはログインが必要です'), findsOneWidget);
    expect(find.text('ログインへ'), findsOneWidget);
  });
}

class _FakePicker implements PalmReadingImagePicker {
  @override
  Future<PalmReadingImage?> pick(PalmImageSource source) async {
    return PalmReadingImage(
      fileName: 'palm.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      ),
    );
  }
}

class _FakeRepository implements PalmReadingRepository {
  _FakeRepository({List<PalmReading> history = const <PalmReading>[]})
      : _history = history;

  List<PalmReading> _history;

  @override
  Future<PalmReading> analyze({
    required PalmReadingImage image,
    required PalmHandSide handSide,
  }) async {
    _history = <PalmReading>[_reading, ..._history];
    return _reading;
  }

  @override
  Future<void> deleteReading(String readingId) async {
    _history = _history.where((item) => item.id != readingId).toList();
  }

  @override
  Future<List<PalmReading>> loadHistory({int limit = 50}) async => _history;
}

final PalmReading _reading = PalmReading.fromJson(<String, dynamic>{
  'id': 'reading-1',
  'request_id': 'request-1',
  'hand_side': 'left',
  'image_path': 'user/reading-1.jpg',
  'image_mime_type': 'image/jpeg',
  'created_at': '2026-08-22T01:00:00Z',
  'provider': 'google',
  'model': 'gemini-2.5-flash',
  'schema_version': 1,
  'analysis': <String, dynamic>{
    'photo_quality': <String, dynamic>{
      'score': 91,
      'is_usable': true,
      'feedback': '鮮明です',
    },
    'overall': '自立心と柔軟さが見える手相です。',
    'traits': '考えてから動くタイプです。',
    'love': '信頼を大切にします。',
    'work': '企画力を生かせます。',
    'advice': <String>['小さく試す'],
    'lines': <Map<String, dynamic>>[
      for (final key in <String>['life', 'head', 'heart', 'fate'])
        <String, dynamic>{
          'key': key,
          'visibility': 80,
          'strength': 70,
          'continuity': 60,
          'shape': '穏やかな線',
          'interpretation': '経験を重ねて伸びる相です。',
        },
    ],
  },
  'comparison': <String, dynamic>{
    'has_previous': true,
    'confidence': 'medium',
    'summary': '前回より生命線が明瞭に見えます。',
    'caution': '光の差を考慮してください。',
    'changes': <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'life',
        'direction': 'stronger',
        'detail': '濃く見えます。',
      },
    ],
  },
});
