import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/election_intelligence.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/pages/election_victory_page.dart';

void main() {
  const hokkaidoEndorsement = OfficialEndorsementPrefecture(
    prefecture: '北海道',
    totalCount: 11,
    incumbentCount: 2,
    newcomerCount: 8,
    formerCount: 1,
    prefecturalCount: 1,
    municipalCount: 10,
  );

  const hokkaidoPlan = LocalElectionPrefecturePlan(
    prefecture: '北海道',
    region: '北海道',
    additionalSeatTarget: 4,
    incumbentRetentionTarget: 6,
    focusMunicipalityCount: 5,
    newCandidateTarget: 5,
    endorsementDeadlineMonth: '2026-10',
    closeRaceSupportRounds: 4,
    currentMembers: 6,
    cdpLocalMembers: 57,
  );

  testWidgets(
    'ElectionOfficialEndorsementBadge with source exposes single label, '
    'link/button semantics, tap action, and tap target guidelines',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      var tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElectionOfficialEndorsementBadge(
                endorsement: hokkaidoEndorsement,
                onOpenSource: () => tapCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgeFinder = find.byType(ElectionOfficialEndorsementBadge);
      final node = tester.getSemantics(badgeFinder);

      expect('公認掲載'.allMatches(node.label).length, 1);
      expect(node.label, contains('出典を開く'));
      expect(
        node,
        matchesSemantics(
          label: '公認掲載 11件 (現職2 / 新人8 / 元職1) 出典を開く',
          isLink: true,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      tester.semantics.tap(
        find.semantics.byLabel('公認掲載 11件 (現職2 / 新人8 / 元職1) 出典を開く'),
      );
      await tester.pump();
      expect(tapCount, 1);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'ElectionOfficialEndorsementBadge without source omits 出典を開く '
    'and has no tap action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElectionOfficialEndorsementBadge(
                endorsement: hokkaidoEndorsement,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgeFinder = find.byType(ElectionOfficialEndorsementBadge);
      final node = tester.getSemantics(badgeFinder);

      expect('公認掲載'.allMatches(node.label).length, 1);
      expect(node.label, isNot(contains('出典を開く')));
      expect(
        node,
        matchesSemantics(
          label: '公認掲載 11件 (現職2 / 新人8 / 元職1)',
          isLink: false,
          isButton: false,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );

  testWidgets(
    'ElectionBenchmarkExpansionCard separates toggle button semantics '
    'from expanded child pills and toggles cleanly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ElectionBenchmarkExpansionCard(
                initiallyExpanded: true,
                leading: const Icon(Icons.insights_outlined),
                title: const Text('立憲地方議員ベンチマーク'),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text('立憲合計 120人'),
                    ],
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Semantics(
                          container: true,
                          child: MergeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(hokkaidoPlan.prefecture),
                                Text(
                                  '国民 ${hokkaidoPlan.currentMembers} / '
                                  '立憲 ${hokkaidoPlan.cdpLocalMembers}',
                                ),
                                Text('立憲+${hokkaidoPlan.cdpMemberGap}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('北海道'), findsOneWidget);
      expect(find.text('国民 6 / 立憲 57'), findsOneWidget);

      final headerFinder = find.text('立憲地方議員ベンチマーク');
      final headerNode = tester.getSemantics(headerFinder);
      final headerData = headerNode.getSemanticsData();

      expect(headerData.label, contains('立憲地方議員ベンチマーク'));
      expect(headerData.label, contains('立憲合計 120人'));
      expect(headerData.label, isNot(contains('北海道')));
      expect(headerData.label, isNot(contains('国民 6 / 立憲 57')));
      expect(headerData.flagsCollection.isButton, isTrue);
      expect(headerData.flagsCollection.isEnabled, Tristate.isTrue);
      expect(headerData.flagsCollection.isExpanded, Tristate.isTrue);
      expect(headerData.hasAction(SemanticsAction.tap), isTrue);

      final pillNode = tester.getSemantics(find.text('北海道'));
      final pillData = pillNode.getSemanticsData();
      expect(pillNode.id, isNot(headerNode.id));
      expect(pillData.label, contains('北海道'));
      expect(pillData.label, contains('国民 6 / 立憲 57'));
      expect(pillData.label, contains('立憲+51'));
      expect(pillData.flagsCollection.isButton, isFalse);
      expect(pillData.hasAction(SemanticsAction.tap), isFalse);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      tester.semantics.tap(
        find.semantics.byLabel(RegExp('^立憲地方議員ベンチマーク')),
      );
      await tester.pumpAndSettle();

      expect(find.text('北海道'), findsNothing);
      expect(find.text('国民 6 / 立憲 57'), findsNothing);
      expect(
        tester
            .getSemantics(headerFinder)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isFalse,
      );

      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      expect(find.text('北海道'), findsOneWidget);
      expect(find.text('国民 6 / 立憲 57'), findsOneWidget);
      expect(
        tester
            .getSemantics(headerFinder)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isTrue,
      );
    },
  );

  testWidgets(
    'ElectionBenchmarkExpansionCard starts collapsed when initiallyExpanded '
    'is false and expands on tap',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: ElectionBenchmarkExpansionCard(
                initiallyExpanded: false,
                leading: Icon(Icons.account_balance_outlined),
                title: Text('自民地方議員ベンチマーク'),
                children: [
                  Text('出典(総務省 所属党派別人員調)を開く'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerFinder = find.text('自民地方議員ベンチマーク');
      expect(find.text('出典(総務省 所属党派別人員調)を開く'), findsNothing);
      expect(
        tester
            .getSemantics(headerFinder)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        Tristate.isFalse,
      );

      await tester.tap(headerFinder);
      await tester.pumpAndSettle();

      expect(find.text('出典(総務省 所属党派別人員調)を開く'), findsOneWidget);
      final expandedHeaderData =
          tester.getSemantics(headerFinder).getSemanticsData();
      expect(expandedHeaderData.flagsCollection.isExpanded, Tristate.isTrue);
      expect(
        expandedHeaderData.label,
        isNot(contains('出典(総務省 所属党派別人員調)を開く')),
      );
    },
  );
}
