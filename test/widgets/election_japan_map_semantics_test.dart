import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/widgets/election_japan_map.dart';

void main() {
  testWidgets(
    'ElectionJapanMap keeps tile stack order top-to-bottom and avoids overlapping tile rects',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      addTearDown(semanticsHandle.dispose);

      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefectures = _samplePrefecturePlans();
      await _pumpMap(tester, prefectures);

      final tileStack = tester.widget<Stack>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Stack &&
              widget.children.length == 47 &&
              widget.children.every((child) => child is Positioned),
        ),
      );
      final positionedTiles = tileStack.children.cast<Positioned>().toList();
      final tileLabelsInStackOrder = <String>[
        for (final positioned in positionedTiles)
          (positioned.child as Semantics).properties.label ?? '',
      ];
      expect(tileLabelsInStackOrder.length, 47);

      int stackIndexFor(String prefectureName) {
        final index = tileLabelsInStackOrder.indexWhere(
          (label) => label.startsWith('$prefectureName '),
        );
        expect(
          index,
          greaterThanOrEqualTo(0),
          reason: '$prefectureName tile must exist in map Stack',
        );
        return index;
      }

      expect(stackIndexFor('新潟県'), lessThan(stackIndexFor('群馬県')));
      expect(stackIndexFor('長野県'), lessThan(stackIndexFor('山梨県')));
      expect(stackIndexFor('大分県'), lessThan(stackIndexFor('熊本県')));

      for (var i = 1; i < positionedTiles.length; i++) {
        final prev = positionedTiles[i - 1];
        final curr = positionedTiles[i];
        final prevTop = prev.top!;
        final currTop = curr.top!;
        final prevLeft = prev.left!;
        final currLeft = curr.left!;
        expect(
          prevTop < currTop || (prevTop == currTop && prevLeft <= currLeft),
          isTrue,
          reason: 'Map Stack tiles must be ordered by (row asc, col asc)',
        );
      }

      final tileNodes = find.semantics
          .byPredicate(
            (node) => RegExp(
              r'^(北海道|.+[都道府県]) KGI\d+ KPI\d+$',
            ).hasMatch(node.label),
          )
          .evaluate()
          .toList();
      expect(tileNodes.length, 47);

      final globalTileRects = <Rect>[
        for (final node in tileNodes) _globalSemanticsRect(node),
      ];
      for (var i = 0; i < tileNodes.length; i++) {
        expect(tileNodes[i].rect.isEmpty, isFalse);
        expect(globalTileRects[i].isEmpty, isFalse);
        for (var j = i + 1; j < tileNodes.length; j++) {
          expect(
            globalTileRects[i].overlaps(globalTileRects[j]),
            isFalse,
            reason: '${tileNodes[i].label} (${globalTileRects[i]}) overlaps '
                '${tileNodes[j].label} (${globalTileRects[j]})',
          );
        }
      }
    },
  );

  testWidgets(
    'ElectionJapanMap exposes concise tile semantics and updates selection via semantics and tap',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      addTearDown(semanticsHandle.dispose);

      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final prefectures = _samplePrefecturePlans();
      await _pumpMap(tester, prefectures);

      final gunmaLabel = _expectedTileLabel('群馬県', prefectures[9]);
      final yamanashiLabel = _expectedTileLabel('山梨県', prefectures[18]);
      final kumamotoLabel = _expectedTileLabel('熊本県', prefectures[42]);
      final tokyoLabel = _expectedTileLabel('東京都', prefectures[12]);

      for (final expectedLabel in <String>[
        gunmaLabel,
        yamanashiLabel,
        kumamotoLabel,
      ]) {
        final node = _findTileSemanticsNode(expectedLabel);
        expect(node.hasChildren, isFalse);
        expect(node.label, isNot(contains('期限')));
        expect(node.label, isNot(contains('\n')));
        expect(
          node,
          _tileSemanticsMatcher(label: expectedLabel, isSelected: false),
        );
      }

      expect(find.text('東京 選択中'), findsOneWidget);
      expect(
        _findTileSemanticsNode(tokyoLabel),
        _tileSemanticsMatcher(label: tokyoLabel, isSelected: true),
      );

      tester.semantics.tap(find.semantics.byLabel(yamanashiLabel));
      await tester.pumpAndSettle();
      expect(find.text('山梨 選択中'), findsOneWidget);
      expect(
        _findTileSemanticsNode(yamanashiLabel),
        _tileSemanticsMatcher(label: yamanashiLabel, isSelected: true),
      );
      expect(
        _findTileSemanticsNode(tokyoLabel),
        _tileSemanticsMatcher(label: tokyoLabel, isSelected: false),
      );

      tester.semantics.tap(find.semantics.byLabel(kumamotoLabel));
      await tester.pumpAndSettle();
      expect(find.text('熊本 選択中'), findsOneWidget);
      expect(
        _findTileSemanticsNode(kumamotoLabel),
        _tileSemanticsMatcher(label: kumamotoLabel, isSelected: true),
      );

      await tester.ensureVisible(find.text('群馬'));
      await tester.tap(find.text('群馬'));
      await tester.pumpAndSettle();
      expect(find.text('群馬 選択中'), findsOneWidget);
      expect(
        _findTileSemanticsNode(gunmaLabel),
        _tileSemanticsMatcher(label: gunmaLabel, isSelected: true),
      );
      expect(
        _findTileSemanticsNode(kumamotoLabel),
        _tileSemanticsMatcher(label: kumamotoLabel, isSelected: false),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  List<LocalElectionPrefecturePlan> prefectures,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ElectionJapanMap(prefectures: prefectures),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Matcher _tileSemanticsMatcher({
  required String label,
  required bool isSelected,
}) {
  return matchesSemantics(
    label: label,
    tooltip: '',
    isButton: true,
    hasEnabledState: true,
    isEnabled: true,
    hasSelectedState: true,
    isSelected: isSelected,
    hasTapAction: true,
  );
}

String _expectedTileLabel(
  String fullName,
  LocalElectionPrefecturePlan plan,
) {
  return '$fullName KGI${plan.kgiTargetLocalMembers} KPI${plan.kpiActualLocalMembers}';
}

SemanticsNode _findTileSemanticsNode(String label) {
  final finder = find.semantics.byLabel(label);
  expect(finder, findsOneWidget);
  return finder.evaluate().single;
}

Rect _globalSemanticsRect(SemanticsNode node) {
  var rect = node.rect;
  SemanticsNode? current = node;
  while (current != null) {
    final transform = current.transform;
    if (transform != null) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
    current = current.parent;
  }
  return rect;
}

List<LocalElectionPrefecturePlan> _samplePrefecturePlans() {
  return List<LocalElectionPrefecturePlan>.generate(47, (index) {
    final isTokyo = index == 12;
    return LocalElectionPrefecturePlan(
      prefecture: isTokyo ? '東京' : 'prefecture-$index',
      region: 'region',
      additionalSeatTarget: isTokyo ? 24 : (index % 5) + 1,
      incumbentRetentionTarget: isTokyo ? 12 : (index % 3) + 1,
      focusMunicipalityCount: isTokyo ? 20 : (index % 6) + 2,
      newCandidateTarget: isTokyo ? 26 : (index % 4) + 1,
      endorsementDeadlineMonth: isTokyo ? '2026-09' : '2026-11',
      closeRaceSupportRounds: isTokyo ? 18 : (index % 5) + 2,
      currentMembers: isTokyo ? 14 : (index % 7),
      scheduledElectionCount: isTokyo ? 3 : (index % 4),
      postConventionBattleCount: isTokyo ? 1 : 0,
      postConventionWinCount: 0,
      postConventionLossCount: isTokyo ? 1 : 0,
      cdpLocalMembers: isTokyo ? 82 : 0,
      cdpSourceUrl:
          isTokyo ? 'https://cdp-japan.jp/members/prefecture/tokyo' : '',
      endorsementConfirmed: index == 0,
      notes: isTokyo ? '重点自治体から先に月次レビューする' : '',
    );
  });
}
