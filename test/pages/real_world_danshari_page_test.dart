import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/domain/models/photo_action_advice.dart';
import 'package:my_web_app/pages/real_world_danshari_page.dart';
import 'package:my_web_app/services/photo_action_advisor_service.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/view_models/photo_action_advisor_view_model.dart';
import 'package:provider/provider.dart';

import 'real_world_danshari_page_test.mocks.dart';

final _transparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final _image = PhotoActionImage(
  bytes: _transparentImage,
  fileName: 'refrigerator.png',
  mimeType: 'image/png',
);

const _advice = PhotoActionAdvice(
  sceneSummary: '冷蔵庫内に食品、調味料、棚の汚れが見えます。',
  observations: ['棚にこぼれ跡が見えます', '複数の容器が置かれています'],
  actions: [
    PhotoRecommendedAction(
      priority: PhotoActionPriority.urgent,
      title: '食品の表示を1点ずつ確認する',
      reason: '写真だけでは期限や開封日を判断できないためです。',
      estimatedMinutes: 5,
      caution: '見た目やにおいだけで安全を断定しないでください。',
    ),
    PhotoRecommendedAction(
      priority: PhotoActionPriority.high,
      title: '棚のこぼれ跡を拭く',
      reason: '食品を戻す前に拭くと二度手間を防げます。',
      estimatedMinutes: 10,
    ),
  ],
  confidenceNote: '写真に写っている範囲だけを確認しました。',
  safetyNote: '異臭や液漏れがある場合は無理に触らないでください。',
);

void main() {
  late MockThemeService themeService;

  setUp(() {
    themeService = MockThemeService();
    when(themeService.isDarkMode).thenReturn(false);
  });

  Widget buildPage(PhotoActionAdvisorViewModel viewModel) {
    addTearDown(viewModel.dispose);
    return ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: MaterialApp(
        home: RealWorldDanshariPage(viewModel: viewModel),
        routes: {
          '/user-manual': (_) => const Scaffold(
                body: Text('リアル断捨離マニュアル'),
              ),
        },
      ),
    );
  }

  testWidgets('shows the general photo action advisor entry state',
      (tester) async {
    await tester.pumpWidget(
      buildPage(
        PhotoActionAdvisorViewModel(
          imagePicker: _FakePicker(),
          analyzer: _QueueAnalyzer([_advice]),
        ),
      ),
    );

    expect(find.text('AIフォト行動アドバイザー'), findsOneWidget);
    expect(find.textContaining('次に何をすべきか迷う場面'), findsOneWidget);
    expect(find.text('カメラで撮影'), findsOneWidget);
    expect(find.text('写真をアップロード'), findsOneWidget);
    expect(find.text('ここに写真が表示されます'), findsOneWidget);
  });

  testWidgets('uploads a photo and renders ordered concrete actions',
      (tester) async {
    final picker = _FakePicker(image: _image);
    await tester.pumpWidget(
      buildPage(
        PhotoActionAdvisorViewModel(
          imagePicker: picker,
          analyzer: _QueueAnalyzer([_advice]),
        ),
      ),
    );

    await tester.ensureVisible(find.text('写真をアップロード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写真をアップロード'));
    await tester.pumpAndSettle();

    expect(picker.lastSource, PhotoActionImageSource.gallery);
    expect(find.text('写真から確認できる状況'), findsOneWidget);
    expect(find.text(_advice.sceneSummary), findsOneWidget);
    expect(find.text('食品の表示を1点ずつ確認する'), findsOneWidget);
    expect(find.text('棚のこぼれ跡を拭く'), findsOneWidget);
    expect(find.text('約5分'), findsOneWidget);
    expect(find.byKey(const Key('photo-action-0')), findsOneWidget);
  });

  testWidgets('opens the related real-world decluttering help',
      (tester) async {
    await tester.pumpWidget(
      buildPage(
        PhotoActionAdvisorViewModel(
          imagePicker: _FakePicker(image: _image),
          analyzer: _QueueAnalyzer([_advice]),
        ),
      ),
    );

    await tester.ensureVisible(find.text('写真をアップロード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写真をアップロード'));
    await tester.pumpAndSettle();

    final helpLink = find.byKey(const Key('photo-action-help-link'));
    await tester.ensureVisible(helpLink);
    await tester.pumpAndSettle();
    await tester.tap(helpLink);
    await tester.pumpAndSettle();

    expect(find.text('リアル断捨離マニュアル'), findsOneWidget);
  });

  testWidgets('keeps the image and retries after an analysis failure',
      (tester) async {
    final analyzer = _QueueAnalyzer([
      const PhotoActionAdvisorException('一時的に解析できませんでした。'),
      _advice,
    ]);
    await tester.pumpWidget(
      buildPage(
        PhotoActionAdvisorViewModel(
          imagePicker: _FakePicker(image: _image),
          analyzer: analyzer,
        ),
      ),
    );

    await tester.ensureVisible(find.text('写真をアップロード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('写真をアップロード'));
    await tester.pumpAndSettle();
    expect(find.text('一時的に解析できませんでした。'), findsOneWidget);
    expect(find.text('もう一度分析'), findsOneWidget);

    await tester.ensureVisible(find.text('もう一度分析'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('もう一度分析'));
    await tester.pumpAndSettle();
    expect(find.text('食品の表示を1点ずつ確認する'), findsOneWidget);
    expect(analyzer.calls, 2);
  });

  testWidgets('switches between narrow and wide layouts without overflow',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final viewModel = PhotoActionAdvisorViewModel(
      imagePicker: _FakePicker(),
      analyzer: _QueueAnalyzer([_advice]),
    );

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(buildPage(viewModel));
    expect(find.byKey(const Key('photo-action-narrow-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-action-wide-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakePicker implements PhotoActionImagePicker {
  _FakePicker({this.image});

  final PhotoActionImage? image;
  PhotoActionImageSource? lastSource;

  @override
  Future<PhotoActionImage?> pick(PhotoActionImageSource source) async {
    lastSource = source;
    return image;
  }
}

class _QueueAnalyzer implements PhotoActionAnalyzer {
  _QueueAnalyzer(this.results);

  final List<Object> results;
  int calls = 0;

  @override
  Future<PhotoActionAdvice> analyze(PhotoActionImage image) async {
    final result = results[calls++];
    if (result is PhotoActionAdvisorException) throw result;
    return result as PhotoActionAdvice;
  }
}
