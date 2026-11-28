import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/agri_policy_timeline/agri_policy_timeline_container.dart';
import 'package:my_web_app/features/agri_policy_timeline/application/agri_policy_controller.dart';
import 'package:my_web_app/features/agri_policy_timeline/domain/agri_policy_models.dart';

class _FakeAgriPolicyRepository implements AgriPolicyRepository {
  _FakeAgriPolicyRepository({
    final List<AgriPolicyEvent>? initialEvents,
  }) : _events = List<AgriPolicyEvent>.from(
          initialEvents ?? _seedEvents(),
        );

  final List<AgriPolicyEvent> _events;
  bool throwOnFetch = false;
  Completer<AgriPolicyTimelineSnapshot>? pendingFetch;
  int _seq = 10;

  static List<AgriPolicyEvent> _seedEvents() => const <AgriPolicyEvent>[
        AgriPolicyEvent(
          id: 'ev-2018-a',
          slug: 'fy2018-production-target-abolition',
          eventDate: '2018-04-01',
          fiscalYear: 2018,
          phase: AgriPolicyPhase.past,
          title: '行政による生産数量目標の配分廃止（いわゆる減反廃止）',
          summary: '都道府県別生産数量目標の配分を2018年産から廃止。',
          tags: <String>['減反廃止', '生産調整', '主食用米'],
          relatedNodes: <String>['農林水産省', '需要に応じた生産'],
          factCheckStatus: FactCheckStatus.verified,
          sourceCitation: '農林水産省 平成30年産からの米政策の見直し',
          policyImpactNotes: '産地判断での作付選択へ移行。',
          verifiedAt: '2026-05-18T00:00:00Z',
        ),
        AgriPolicyEvent(
          id: 'ev-2018-b',
          slug: 'fy2018-direct-payment-restructure',
          eventDate: '2018-04-02',
          fiscalYear: 2018,
          phase: AgriPolicyPhase.past,
          title: '米の直接支払交付金廃止と経営所得安定対策の再編',
          summary: '一律面積払いを終了し、水田活用の直接支払交付金等へ移行。',
          tags: <String>['直接支払い', 'ナラシ対策'],
          relatedNodes: <String>['水田活用の直接支払交付金'],
          factCheckStatus: FactCheckStatus.verified,
          sourceCitation: '農林水産省 経営所得安定対策等の概要',
          policyImpactNotes: '非主食用米への転換支援を継続。',
          verifiedAt: '2026-05-18T00:00:00Z',
        ),
        AgriPolicyEvent(
          id: 'ev-2019-marukin',
          slug: 'fy2019-marukin-safety-net',
          eventDate: '2019-04-01',
          fiscalYear: 2019,
          phase: AgriPolicyPhase.past,
          title: 'マルキン制度（牛・豚経営安定交付金）の法制化・セーフティネット比較',
          summary: '標準的販売価格と生産費の差額を補填する枠組みを法制化。',
          tags: <String>['マルキン制度', '経営安定対策'],
          relatedNodes: <String>['肉用牛肥育経営安定交付金'],
          factCheckStatus: FactCheckStatus.verified,
          sourceCitation: '農林水産省 畜産経営の安定に関する法律',
          policyImpactNotes: '米分野の経営安定対策との制度比較軸。',
          verifiedAt: '2026-05-18T00:00:00Z',
        ),
        AgriPolicyEvent(
          id: 'ev-2027-reform',
          slug: 'fy2027-rice-paddy-policy-reform',
          eventDate: '2027-04-01',
          fiscalYear: 2027,
          phase: AgriPolicyPhase.planned,
          title: '2027年（令和9年）度 新たな米・水田政策の本格導入',
          summary: '生産性向上・需要に応じた供給体制への抜本見直しを予定。',
          tags: <String>['減反廃止', '直接支払い', '2027年改革'],
          relatedNodes: <String>['農林水産省', '需要に応じた生産'],
          factCheckStatus: FactCheckStatus.needsReview,
          sourceCitation: '農林水産省 令和9年度に向けた水田政策見直し方針',
          policyImpactNotes: '具体制度要件は公表資料を随時更新。',
        ),
      ];

  List<AgriKnowledgeEdge> _computeEdges(final List<AgriPolicyEvent> list) {
    final edges = <AgriKnowledgeEdge>[];
    for (var i = 0; i < list.length; i += 1) {
      for (var j = i + 1; j < list.length; j += 1) {
        final a = list[i];
        final b = list[j];
        final termsA = <String>{...a.tags, ...a.relatedNodes};
        final shared = <String>{
          ...b.tags.where(termsA.contains),
          ...b.relatedNodes.where(termsA.contains),
        }.toList(growable: false);
        if (shared.isNotEmpty) {
          edges.add(
            AgriKnowledgeEdge(
              fromEventId: a.id,
              toEventId: b.id,
              sharedTerms: shared,
            ),
          );
        }
      }
    }
    return edges;
  }

  @override
  Future<AgriPolicyTimelineSnapshot> fetchTimeline({
    final String? query,
    final String? tag,
    final AgriPolicyPhase? phase,
    final FactCheckStatus? factCheckStatus,
    final bool seedIfEmpty = true,
  }) async {
    if (pendingFetch != null) {
      return pendingFetch!.future;
    }
    if (throwOnFetch) {
      throw StateError('agri_policy backend unreachable');
    }

    final sorted = List<AgriPolicyEvent>.from(_events)
      ..sort(
        (final AgriPolicyEvent a, final AgriPolicyEvent b) =>
            a.eventDate.compareTo(b.eventDate),
      );
    final q = (query ?? '').trim().toLowerCase();
    final t = (tag ?? '').trim();

    final filtered = sorted.where((final AgriPolicyEvent ev) {
      if (t.isNotEmpty && !ev.tags.contains(t)) return false;
      if (phase != null && ev.phase != phase) return false;
      if (factCheckStatus != null && ev.factCheckStatus != factCheckStatus) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = <String>[
        ev.title,
        ev.summary,
        ev.eventDate,
        ev.sourceCitation,
        ev.policyImpactNotes,
        ...ev.tags,
        ...ev.relatedNodes,
      ].join('\n').toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);

    final tags = <String>{
      for (final ev in sorted) ...ev.tags,
    }.toList(growable: false);

    return AgriPolicyTimelineSnapshot(
      events: filtered,
      totalCount: sorted.length,
      filteredCount: filtered.length,
      seededCount: 0,
      availableTags: tags,
      knowledgeEdges: _computeEdges(filtered),
    );
  }

  @override
  Future<AgriPolicyEvent> createEvent({
    required final String eventDate,
    required final String title,
    required final String summary,
    required final List<String> tags,
    required final List<String> relatedNodes,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  }) async {
    _seq += 1;
    final year = int.tryParse(eventDate.split('-').first) ?? 2026;
    final created = AgriPolicyEvent(
      id: 'ev-$_seq',
      slug: 'custom-$_seq',
      eventDate: eventDate,
      fiscalYear: year,
      phase: year >= 2027
          ? AgriPolicyPhase.planned
          : year >= 2025
              ? AgriPolicyPhase.current
              : AgriPolicyPhase.past,
      title: title,
      summary: summary,
      tags: tags,
      relatedNodes: relatedNodes,
      factCheckStatus: factCheckStatus,
      sourceCitation: sourceCitation,
      policyImpactNotes: policyImpactNotes,
      verifiedAt:
          factCheckStatus == FactCheckStatus.verified ? '2026-11-26Z' : null,
    );
    _events.add(created);
    return created;
  }

  @override
  Future<AgriPolicyEvent> updateFactCheck({
    required final String id,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  }) async {
    for (var i = 0; i < _events.length; i += 1) {
      final ev = _events[i];
      if (ev.id == id) {
        final updated = AgriPolicyEvent(
          id: ev.id,
          slug: ev.slug,
          eventDate: ev.eventDate,
          fiscalYear: ev.fiscalYear,
          phase: ev.phase,
          title: ev.title,
          summary: ev.summary,
          tags: ev.tags,
          relatedNodes: ev.relatedNodes,
          factCheckStatus: factCheckStatus,
          sourceCitation: sourceCitation,
          policyImpactNotes: policyImpactNotes,
          verifiedAt: factCheckStatus == FactCheckStatus.verified
              ? '2026-11-26Z'
              : ev.verifiedAt,
        );
        _events[i] = updated;
        return updated;
      }
    }
    throw StateError('Event not found');
  }
}

void main() {
  group('AgriPolicyController domain & lifecycle', () {
    test('validates input and ignores pending completion after dispose',
        () async {
      final repo = _FakeAgriPolicyRepository();
      final controller = AgriPolicyController(repository: repo);

      final badDate = await controller.createEvent(
        eventDate: '2026/05/01',
        title: '検証テスト',
        summary: '',
        rawTags: '減反廃止',
        rawRelatedNodes: '',
        factCheckStatus: FactCheckStatus.unverified,
        sourceCitation: '',
        policyImpactNotes: '',
      );
      expect(badDate, isFalse);
      expect(controller.state.errorMessage, isNotNull);

      final completer = Completer<AgriPolicyTimelineSnapshot>();
      repo.pendingFetch = completer;
      final pending = controller.loadTimeline();
      controller.dispose();
      completer.complete(
        const AgriPolicyTimelineSnapshot(
          events: <AgriPolicyEvent>[],
          totalCount: 0,
          filteredCount: 0,
          seededCount: 0,
          availableTags: kDefaultAgriKeywordTags,
          knowledgeEdges: <AgriKnowledgeEdge>[],
        ),
      );
      await pending;
      expect(controller.state.events, isEmpty);
    });
  });

  group('AgriPolicyTimelineContainer UI', () {
    testWidgets(
      'renders chronological timeline, filters by tag & search, and shows KG edges',
      (final WidgetTester tester) async {
        final repo = _FakeAgriPolicyRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgriPolicyTimelineContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final timelineFinder = find.byKey(
          const ValueKey<String>('agri_policy_timeline_list'),
        );
        expect(timelineFinder, findsOneWidget);
        expect(
          find.descendant(
            of: timelineFinder,
            matching: find.text('行政による生産数量目標の配分廃止（いわゆる減反廃止）'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: timelineFinder,
            matching: find.text('2027年（令和9年）度 新たな米・水田政策の本格導入'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('agri_policy_kg_card')),
          findsOneWidget,
        );

        final marukinBtn = find.byKey(
          const ValueKey<String>('agri_policy_tag_マルキン制度'),
        );
        await tester.ensureVisible(marukinBtn);
        await tester.tap(marukinBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: timelineFinder,
            matching: find.text('マルキン制度（牛・豚経営安定交付金）の法制化・セーフティネット比較'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: timelineFinder,
            matching: find.text('2027年（令和9年）度 新たな米・水田政策の本格導入'),
          ),
          findsNothing,
        );

        final allTagBtn = find.byKey(
          const ValueKey<String>('agri_policy_tag_all'),
        );
        await tester.ensureVisible(allTagBtn);
        await tester.tap(allTagBtn);
        await tester.pumpAndSettle();

        final searchInput = find.byKey(
          const ValueKey<String>('agri_policy_search_input'),
        );
        await tester.ensureVisible(searchInput);
        await tester.enterText(searchInput, '直接支払い');

        final searchBtn = find.byKey(
          const ValueKey<String>('agri_policy_search_button'),
        );
        await tester.ensureVisible(searchBtn);
        await tester.tap(searchBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: timelineFinder,
            matching: find.text('米の直接支払交付金廃止と経営所得安定対策の再編'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: timelineFinder,
            matching: find.text('マルキン制度（牛・豚経営安定交付金）の法制化・セーフティネット比較'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'creates new policy event and updates fact-check metadata via dialog',
      (final WidgetTester tester) async {
        final repo = _FakeAgriPolicyRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgriPolicyTimelineContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editBtn = find.byKey(
          const ValueKey<String>('agri_policy_edit_fact_ev-2027-reform'),
        );
        await tester.ensureVisible(editBtn);
        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('agri_policy_fact_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(
            const ValueKey<String>('agri_policy_dialog_status_verified'),
          ),
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('agri_policy_dialog_source_input')),
          '農林水産省 令和9年度公式閣議決定資料',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('agri_policy_dialog_save')),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('agri_policy_fact_badge_ev-2027-reform'),
            ),
            matching: find.text('事実確認: 一次情報確認済'),
          ),
          findsOneWidget,
        );

        final titleInput = find.byKey(
          const ValueKey<String>('agri_policy_create_title_input'),
        );
        await tester.ensureVisible(titleInput);
        await tester.enterText(titleInput, '備蓄米供給・価格安定緊急対策');
        await tester.enterText(
          find.byKey(const ValueKey<String>('agri_policy_create_tags_input')),
          '備蓄米, 減反廃止',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('agri_policy_create_source_input')),
          '農水省 備蓄米公表データ',
        );

        final createBtn = find.byKey(
          const ValueKey<String>('agri_policy_create_button'),
        );
        await tester.ensureVisible(createBtn);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('agri_policy_timeline_list'),
            ),
            matching: find.text('備蓄米供給・価格安定緊急対策'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows error banner, recovers on retry, and unmounts safely while pending',
      (final WidgetTester tester) async {
        final repo = _FakeAgriPolicyRepository()..throwOnFetch = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgriPolicyTimelineContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('agri_policy_error_banner')),
          findsOneWidget,
        );

        repo.throwOnFetch = false;
        final retryBtn = find.byKey(
          const ValueKey<String>('agri_policy_retry_button'),
        );
        await tester.ensureVisible(retryBtn);
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('agri_policy_error_banner')),
          findsNothing,
        );

        final completer = Completer<AgriPolicyTimelineSnapshot>();
        repo.pendingFetch = completer;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgriPolicyTimelineContainer(repository: repo),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        completer.complete(
          const AgriPolicyTimelineSnapshot(
            events: <AgriPolicyEvent>[],
            totalCount: 0,
            filteredCount: 0,
            seededCount: 0,
            availableTags: kDefaultAgriKeywordTags,
            knowledgeEdges: <AgriKnowledgeEdge>[],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final semanticsHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final repo = _FakeAgriPolicyRepository();
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    'agri_policy_${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                  home: Builder(
                    builder: (final BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: Scaffold(
                          body: AgriPolicyTimelineContainer(repository: repo),
                        ),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(textContrastGuideline),
              );
              expect(tester.takeException(), isNull);
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
