import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/kokumin_member_directory_observation.dart';
import 'package:my_web_app/ui/features/election_victory/widgets/kokumin_member_directory_observation_card.dart';

void main() {
  testWidgets('shows verified directory count without relabeling stale rows',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KokuminMemberDirectoryObservationCard(onOpenSource: (_) {}),
        ),
      ),
    );
    expect(find.text('党公式名簿の掲載人数: 416人'), findsOneWidget);
    expect(find.text('確認日: 2026/11/14（原本の基準日は記載なし）'), findsOneWidget);
    expect(find.textContaining('県別内訳・計画KPIは更新していません'), findsOneWidget);
    expect(find.textContaining('全国現職420人（11/9党代表発表）'), findsOneWidget);
  });

  testWidgets('opens only the observed official source', (tester) async {
    String? openedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KokuminMemberDirectoryObservationCard(
            onOpenSource: (url) => openedUrl = url,
          ),
        ),
      ),
    );
    await tester.tap(find.text('党公式の地方議員名簿を開く'));
    expect(openedUrl, kokuminMemberDirectoryObservation20261114.sourceUrl);
    expect(openedUrl, 'https://new-kokumin.jp/member');
  });

  testWidgets('narrow viewport preserves date and caveat without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KokuminMemberDirectoryObservationCard(onOpenSource: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('予定候補者の公認・推薦件数'), findsOneWidget);
    expect(find.text('党公式の地方議員名簿を開く'), findsOneWidget);
  });
}
