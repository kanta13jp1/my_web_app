import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/social_feed_page.dart';
import 'package:my_web_app/services/musubi_feature_dependencies.dart';
import 'package:my_web_app/services/musubi_social_controller.dart';
import 'package:my_web_app/services/musubi_social_repository.dart';

void main() {
  testWidgets('search opens a direct message workspace', (tester) async {
    _setViewport(tester, const Size(1280, 900));
    final socialRepository = PreviewMusubiSocialRepository();
    final controller = MusubiSocialController(repository: socialRepository);
    await tester.pumpWidget(
      _app(
        controller,
        MusubiFeatureDependencies.preview(
          socialRepository: socialRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('見つける'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('musubi_discovery_view')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('musubi_search_field')),
      '佐伯',
    );
    await tester.tap(find.byKey(const Key('musubi_search_button')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('musubi_message_preview-person-hikari')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('musubi_messages_view')), findsOneWidget);
    expect(find.byKey(const Key('musubi_message_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('post reporting appears in Safety Center', (tester) async {
    _setViewport(tester, const Size(1280, 1000));
    final socialRepository = PreviewMusubiSocialRepository();
    final controller = MusubiSocialController(repository: socialRepository);
    await tester.pumpWidget(
      _app(
        controller,
        MusubiFeatureDependencies.preview(
          socialRepository: socialRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('投稿メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('スパム'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('セーフティセンター'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('musubi_safety_view')), findsOneWidget);
    expect(find.text('スパム'), findsOneWidget);
    expect(find.byKey(const Key('musubi_research_panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  MusubiSocialController controller,
  MusubiFeatureDependencies dependencies,
) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: MusubiSocialPage(
      controller: controller,
      dependencies: dependencies,
    ),
  );
}
