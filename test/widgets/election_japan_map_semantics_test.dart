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
    'ElectionJapanMap binds prefectures by name when list order is reversed',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
        final plans = _canonicalNamedPlans();
        await _pumpMap(tester, plans.reversed.toList());

        final hokkaidoLabel = _expectedTileLabel('北海道', plans[0]);
        final tokyoLabel = _expectedTileLabel('東京都', plans[12]);
        expect(_findTileSemanticsNode(hokkaidoLabel), isNotNull);
        expect(_findTileSemanticsNode(tokyoLabel), isNotNull);

        final osakaPlan = plans[26];
        await tester.ensureVisible(find.text('大阪'));
        await tester.tap(find.text('大阪'));
        await tester.pumpAndSettle();
        expect(find.text('大阪 選択中'), findsOneWidget);
        expect(find.text('大阪府 KGI/KPI'), findsOneWidget);
        expect(
          find.text(
            'KGI ${osakaPlan.kgiTargetLocalMembers} / KPI ${osakaPlan.kpiActualLocalMembers}',
          ),
          findsOneWidget,
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'ElectionJapanMap does not misbind shortened list onto unrelated positional tiles',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semanticsHandle = tester.ensureSemantics();
      try {
        final subset = <LocalElectionPrefecturePlan>[
          _buildNamedPlan(prefecture: '大阪府', seatTarget: 30, memberCount: 7),
          _buildNamedPlan(prefecture: '東京都', seatTarget: 42, memberCount: 14),
        ];
        await _pumpMap(tester, subset);

        expect(
          _findTileSemanticsNode(_expectedTileLabel('大阪府', subset[0])),
          isNotNull,
        );
        expect(
          _findTileSemanticsNode(_expectedTileLabel('東京都', subset[1])),
          isNotNull,
        );
        final hokkaidoNode = _findTileSemanticsNode('北海道');
        expect(hokkaidoNode.label, '北海道');
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'ElectionJapanMap renders non-color status symbols on tiles and legend',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final dueSoonDate = DateTime(now.year, now.month, now.day + 25);
      final dueSoonMonth =
          '${dueSoonDate.year}-${dueSoonDate.month.toString().padLeft(2, '0')}';

      final plans = <LocalElectionPrefecturePlan>[
        _buildNamedPlan(
          prefecture: '北海道',
          seatTarget: 15,
          memberCount: 3,
          deadlineMonth: '2020-01',
          endorsementConfirmed: false,
        ),
        _buildNamedPlan(
          prefecture: '東京都',
          seatTarget: 24,
          memberCount: 14,
          deadlineMonth: dueSoonMonth,
          endorsementConfirmed: false,
        ),
        _buildNamedPlan(
          prefecture: '大阪府',
          seatTarget: 20,
          memberCount: 8,
          deadlineMonth: '2030-12',
          endorsementConfirmed: true,
        ),
      ];
      await _pumpMap(tester, plans);

      expect(find.text('!'), findsAtLeastNWidgets(2));
      expect(find.text('△'), findsAtLeastNWidgets(2));
      expect(find.text('✓'), findsAtLeastNWidgets(2));
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

const List<String> _canonicalPrefectureNames = <String>[
  '北海道',
  '青森県',
  '岩手県',
  '宮城県',
  '秋田県',
  '山形県',
  '福島県',
  '茨城県',
  '栃木県',
  '群馬県',
  '埼玉県',
  '千葉県',
  '東京都',
  '神奈川県',
  '新潟県',
  '富山県',
  '石川県',
  '福井県',
  '山梨県',
  '長野県',
  '岐阜県',
  '静岡県',
  '愛知県',
  '三重県',
  '滋賀県',
  '京都府',
  '大阪府',
  '兵庫県',
  '奈良県',
  '和歌山県',
  '鳥取県',
  '島根県',
  '岡山県',
  '広島県',
  '山口県',
  '徳島県',
  '香川県',
  '愛媛県',
  '高知県',
  '福岡県',
  '佐賀県',
  '長崎県',
  '熊本県',
  '大分県',
  '宮崎県',
  '鹿児島県',
  '沖縄県',
];

LocalElectionPrefecturePlan _buildNamedPlan({
  required String prefecture,
  required int seatTarget,
  required int memberCount,
  String deadlineMonth = '2030-12',
  bool endorsementConfirmed = false,
}) {
  return LocalElectionPrefecturePlan(
    prefecture: prefecture,
    region: 'region',
    additionalSeatTarget: seatTarget,
    incumbentRetentionTarget: 0,
    focusMunicipalityCount: 2,
    newCandidateTarget: 1,
    endorsementDeadlineMonth: deadlineMonth,
    closeRaceSupportRounds: 1,
    currentMembers: memberCount,
    scheduledElectionCount: 1,
    postConventionBattleCount: 0,
    postConventionWinCount: 0,
    postConventionLossCount: 0,
    cdpLocalMembers: 0,
    cdpSourceUrl: '',
    endorsementConfirmed: endorsementConfirmed,
    notes: '',
  );
}

List<LocalElectionPrefecturePlan> _canonicalNamedPlans() {
  return List<LocalElectionPrefecturePlan>.generate(
    _canonicalPrefectureNames.length,
    (index) => _buildNamedPlan(
      prefecture: _canonicalPrefectureNames[index],
      seatTarget: index + 10,
      memberCount: index + 1,
    ),
  );
}
