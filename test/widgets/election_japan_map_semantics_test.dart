import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/widgets/election_japan_map.dart';

void main() {
  testWidgets(
    'ElectionJapanMap keeps tile stack order top-to-bottom and avoids overlapping tile rects',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
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
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'ElectionJapanMap exposes concise tile semantics and updates selection via semantics and tap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
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
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'ElectionJapanMap exposes non-color status symbols across tiles, legend, and detail badge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
        final fixedNow = DateTime(2026, 11, 15);
        final plans = _namedStatusPlans();
        await _pumpMap(tester, plans, now: fixedNow);

        for (final label in <String>[
          '低負荷',
          '高負荷',
          '公認確認済み',
          '期限接近',
          '期限超過',
        ]) {
          expect(find.text(label), findsOneWidget);
        }

        expect(find.text('!'), findsNWidgets(2));
        expect(find.text('△'), findsNWidgets(2));
        expect(find.text('✓'), findsNWidgets(2));
        expect(find.text('▲'), findsNWidgets(2));
        expect(find.text('○'), findsWidgets);

        expect(
          _findTileSemanticsNode(_expectedTileLabel('青森県', plans[1])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('青森県', plans[1]),
            isSelected: false,
            value: '期限超過',
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('岩手県', plans[2])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('岩手県', plans[2]),
            isSelected: false,
            value: '期限接近',
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('宮城県', plans[3])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('宮城県', plans[3]),
            isSelected: false,
            value: '公認確認済み',
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('秋田県', plans[4])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('秋田県', plans[4]),
            isSelected: false,
            value: '低負荷',
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('東京都', plans[12])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('東京都', plans[12]),
            isSelected: true,
            value: '高負荷',
          ),
        );

        tester.semantics.tap(
          find.semantics.byLabel(_expectedTileLabel('青森県', plans[1])),
        );
        await tester.pumpAndSettle();
        expect(find.text('青森 選択中'), findsOneWidget);
        expect(find.text('青森県 KGI/KPI'), findsOneWidget);
        expect(find.text('!'), findsNWidgets(3));

        tester.semantics.tap(
          find.semantics.byLabel(_expectedTileLabel('宮城県', plans[3])),
        );
        await tester.pumpAndSettle();
        expect(find.text('宮城 選択中'), findsOneWidget);
        expect(find.text('✓'), findsNWidgets(3));

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'ElectionJapanMap binds prefectures by name regardless of list ordering or subset length',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
        final fixedNow = DateTime(2026, 11, 15);
        final subset = <LocalElectionPrefecturePlan>[
          _makeNamedPlan(
            prefecture: '沖縄県',
            additionalSeatTarget: 6,
            incumbentRetentionTarget: 5,
            currentMembers: 3,
            deadlineMonth: '2026-10',
          ),
          _makeNamedPlan(
            prefecture: '東京都',
            additionalSeatTarget: 20,
            incumbentRetentionTarget: 15,
            currentMembers: 12,
            deadlineMonth: '2027-06',
            closeRaceSupportRounds: 10,
          ),
          _makeNamedPlan(
            prefecture: '北海道',
            additionalSeatTarget: 12,
            incumbentRetentionTarget: 9,
            currentMembers: 7,
            deadlineMonth: '2027-06',
            endorsementConfirmed: true,
          ),
          _makeNamedPlan(
            prefecture: '群馬県',
            additionalSeatTarget: 8,
            incumbentRetentionTarget: 7,
            currentMembers: 5,
            deadlineMonth: '2026-12',
          ),
        ];

        await _pumpMap(tester, subset, now: fixedNow);

        expect(find.text('東京 選択中'), findsOneWidget);
        expect(
          _findTileSemanticsNode(_expectedTileLabel('沖縄県', subset[0])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('沖縄県', subset[0]),
            isSelected: false,
            value: '期限超過',
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('北海道', subset[2])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('北海道', subset[2]),
            isSelected: false,
            value: '公認確認済み',
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('群馬県', subset[3])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('群馬県', subset[3]),
            isSelected: false,
            value: '期限接近',
          ),
        );
        expect(
          _findTileSemanticsNode('青森県'),
          _tileSemanticsMatcher(
            label: '青森県',
            isSelected: false,
            isEnabled: false,
          ),
        );

        tester.semantics.tap(
          find.semantics.byLabel(_expectedTileLabel('沖縄県', subset[0])),
        );
        await tester.pumpAndSettle();
        expect(find.text('沖縄 選択中'), findsOneWidget);
        expect(find.text('沖縄県 KGI/KPI'), findsOneWidget);

        tester.semantics.tap(
          find.semantics.byLabel(_expectedTileLabel('北海道', subset[2])),
        );
        await tester.pumpAndSettle();
        expect(find.text('北海道 選択中'), findsOneWidget);
        expect(find.text('北海道 KGI/KPI'), findsOneWidget);

        await tester.ensureVisible(find.text('青森'));
        await tester.tap(find.text('青森'));
        await tester.pumpAndSettle();
        expect(find.text('北海道 選択中'), findsOneWidget);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'ElectionJapanMap refuses positional fallback when a 47-item list has duplicate canonical names',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
        final plans = _samplePrefecturePlans();
        plans[46] = _makeNamedPlan(
          prefecture: '東京都',
          additionalSeatTarget: 60,
          incumbentRetentionTarget: 39,
          currentMembers: 88,
          deadlineMonth: '2027-06',
        );

        await _pumpMap(tester, plans, now: DateTime(2026, 11, 15));

        expect(
          _findTileSemanticsNode('沖縄県'),
          _tileSemanticsMatcher(
            label: '沖縄県',
            isSelected: false,
            isEnabled: false,
          ),
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('東京都', plans[12])),
          _tileSemanticsMatcher(
            label: _expectedTileLabel('東京都', plans[12]),
            isSelected: true,
          ),
        );
        expect(find.semantics.byLabel('沖縄県 KGI99 KPI88'), findsNothing);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  List<LocalElectionPrefecturePlan> prefectures, {
  DateTime? now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ElectionJapanMap(
            prefectures: prefectures,
            now: now,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Matcher _tileSemanticsMatcher({
  required String label,
  required bool isSelected,
  String? value,
  bool isEnabled = true,
}) {
  return matchesSemantics(
    label: label,
    value: value,
    tooltip: '',
    isButton: true,
    hasEnabledState: true,
    isEnabled: isEnabled,
    hasSelectedState: true,
    isSelected: isSelected,
    hasTapAction: isEnabled,
  );
}

LocalElectionPrefecturePlan _makeNamedPlan({
  required String prefecture,
  required int additionalSeatTarget,
  required int incumbentRetentionTarget,
  required int currentMembers,
  required String deadlineMonth,
  bool endorsementConfirmed = false,
  int closeRaceSupportRounds = 1,
}) {
  return LocalElectionPrefecturePlan(
    prefecture: prefecture,
    region: 'region',
    additionalSeatTarget: additionalSeatTarget,
    incumbentRetentionTarget: incumbentRetentionTarget,
    focusMunicipalityCount: 2,
    newCandidateTarget: additionalSeatTarget,
    endorsementDeadlineMonth: deadlineMonth,
    closeRaceSupportRounds: closeRaceSupportRounds,
    currentMembers: currentMembers,
    scheduledElectionCount: 1,
    endorsementConfirmed: endorsementConfirmed,
  );
}

List<LocalElectionPrefecturePlan> _namedStatusPlans() {
  return List<LocalElectionPrefecturePlan>.generate(47, (index) {
    return switch (index) {
      1 => _makeNamedPlan(
          prefecture: '青森県',
          additionalSeatTarget: 2,
          incumbentRetentionTarget: 2,
          currentMembers: 1,
          deadlineMonth: '2026-10',
        ),
      2 => _makeNamedPlan(
          prefecture: '岩手県',
          additionalSeatTarget: 3,
          incumbentRetentionTarget: 2,
          currentMembers: 2,
          deadlineMonth: '2026-12',
        ),
      3 => _makeNamedPlan(
          prefecture: '宮城県',
          additionalSeatTarget: 4,
          incumbentRetentionTarget: 2,
          currentMembers: 3,
          deadlineMonth: '2027-06',
          endorsementConfirmed: true,
        ),
      4 => _makeNamedPlan(
          prefecture: '秋田県',
          additionalSeatTarget: 2,
          incumbentRetentionTarget: 2,
          currentMembers: 1,
          deadlineMonth: '2027-06',
        ),
      12 => _makeNamedPlan(
          prefecture: '東京都',
          additionalSeatTarget: 24,
          incumbentRetentionTarget: 16,
          currentMembers: 14,
          deadlineMonth: '2027-06',
          closeRaceSupportRounds: 18,
        ),
      _ => _makeNamedPlan(
          prefecture: 'prefecture-$index',
          additionalSeatTarget: 1,
          incumbentRetentionTarget: 1,
          currentMembers: 0,
          deadlineMonth: '2027-06',
        ),
    };
  });
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
