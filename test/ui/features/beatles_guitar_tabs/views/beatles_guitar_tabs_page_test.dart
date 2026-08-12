import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';

void main() {
  const repository = LocalGuitarTabRepository(
    catalogService: GuitarTabCatalogService(),
  );

  testWidgets(
    'compact layout filters songs and updates the selected practice',
    (tester) async {
      await _setSurfaceSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('beatles_tabs_compact_layout')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('beatles_song_blackbird-fingerstyle')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('beatles_tabs_search')),
        'sun',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('beatles_song_blackbird-fingerstyle')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('beatles_song_here-comes-the-sun-arpeggio')),
        findsOneWidget,
      );
      final selectedTitle = tester.widget<Text>(
        find.byKey(const Key('beatles_selected_song_title')),
      );
      expect(selectedTitle.data, 'Here Comes the Sun');
    },
  );

  testWidgets('wide layout uses a vertical library and changes song on tap', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 900));
    await tester.pumpWidget(
      const MaterialApp(home: BeatlesGuitarTabsFeature(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('beatles_song_list')), findsOneWidget);
    expect(find.byKey(const Key('beatles_tabs_compact_layout')), findsNothing);

    await tester.tap(find.byKey(const Key('beatles_song_day-tripper-riff')));
    await tester.pump();

    final selectedTitle = tester.widget<Text>(
      find.byKey(const Key('beatles_selected_song_title')),
    );
    expect(selectedTitle.data, 'Day Tripper');
    expect(find.byKey(const Key('beatles_tab_notation')), findsOneWidget);
  });
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
