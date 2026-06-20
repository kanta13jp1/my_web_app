import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_subscription_audit_catalog.dart';
import 'package:my_web_app/widgets/subscription_audit_card.dart';

void main() {
  final now = DateTime.utc(2026, 6, 20);

  const appleSource = SubscriptionAuditSource(
    id: 'apple_id',
    name: 'Apple (iOS) サブスク',
    kind: SubscriptionAuditSourceKind.manualCheck,
    checkSteps: <String>['設定アプリを開く', 'サブスクリプションをタップ'],
  );
  const cardSource = SubscriptionAuditSource(
    id: 'card_aupay_card',
    name: 'auPayカード',
    kind: SubscriptionAuditSourceKind.autoAssisted,
  );

  group('SubscriptionAuditCard.statusFor', () {
    test('null is unchecked', () {
      expect(
        SubscriptionAuditCard.statusFor(null, now),
        SubscriptionAuditStatus.unchecked,
      );
    });

    test('29 and 30 days are recentlyChecked, 31 needs recheck', () {
      expect(
        SubscriptionAuditCard.statusFor(
          now.subtract(const Duration(days: 29)),
          now,
        ),
        SubscriptionAuditStatus.recentlyChecked,
      );
      expect(
        SubscriptionAuditCard.statusFor(
          now.subtract(const Duration(days: 30)),
          now,
        ),
        SubscriptionAuditStatus.recentlyChecked,
      );
      expect(
        SubscriptionAuditCard.statusFor(
          now.subtract(const Duration(days: 31)),
          now,
        ),
        SubscriptionAuditStatus.needsRecheck,
      );
    });
  });

  Widget host({
    Map<String, DateTime> lastCheckedAt = const <String, DateTime>{},
    Map<String, int> counts = const <String, int>{},
    Map<String, ({int count, double total})> registered =
        const <String, ({int count, double total})>{},
    required void Function(SubscriptionAuditSource) onMarkChecked,
    required void Function(SubscriptionAuditSource) onRegister,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SubscriptionAuditCard(
            sources: const <SubscriptionAuditSource>[appleSource, cardSource],
            lastCheckedAt: lastCheckedAt,
            unregisteredCountBySourceId: counts,
            registeredByGatewaySourceId: registered,
            now: now,
            onMarkChecked: onMarkChecked,
            onRegisterSubscription: onRegister,
          ),
        ),
      ),
    );
  }

  testWidgets('manual row shows steps; card row shows unregistered count',
      (tester) async {
    await tester.pumpWidget(
      host(
        counts: const <String, int>{'card_aupay_card': 2},
        onMarkChecked: (_) {},
        onRegister: (_) {},
      ),
    );

    expect(find.text('サブスク棚卸し'), findsOneWidget);
    expect(find.text('Apple (iOS) サブスク'), findsOneWidget);
    // 手動ソースは確認手順、カードソースは未登録件数。
    expect(find.text('確認手順'), findsOneWidget);
    expect(find.textContaining('未登録の定期支出 2件'), findsOneWidget);
    // 全ソース未確認なので「要確認 2」バッジ。
    expect(find.textContaining('要確認 2'), findsOneWidget);
  });

  testWidgets('確認した and 登録 fire with the right source', (tester) async {
    SubscriptionAuditSource? checked;
    SubscriptionAuditSource? registered;
    await tester.pumpWidget(
      host(
        onMarkChecked: (s) => checked = s,
        onRegister: (s) => registered = s,
      ),
    );

    final appleRow = find.byKey(const Key('asset_subscription_audit_apple_id'));
    await tester.tap(
      find.descendant(of: appleRow, matching: find.text('確認した')),
    );
    expect(checked?.id, 'apple_id');
    await tester.tap(
      find.descendant(of: appleRow, matching: find.text('サブスクを登録')),
    );
    expect(registered?.id, 'apple_id');
  });

  testWidgets('checked source shows 確認済み and clears the recheck badge',
      (tester) async {
    await tester.pumpWidget(
      host(
        lastCheckedAt: <String, DateTime>{
          'apple_id': now.subtract(const Duration(days: 3)),
          'card_aupay_card': now.subtract(const Duration(days: 1)),
        },
        onMarkChecked: (_) {},
        onRegister: (_) {},
      ),
    );

    expect(find.textContaining('確認済み (3日前)'), findsOneWidget);
    // 全ソース確認済み (staleDays 以内) → 要確認バッジ無し。
    expect(find.textContaining('要確認'), findsNothing);
  });

  testWidgets('manual row shows the gateway reconciliation total', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        registered: const <String, ({int count, double total})>{
          'apple_id': (count: 3, total: 32480),
        },
        onMarkChecked: (_) {},
        onRegister: (_) {},
      ),
    );

    // Apple 行に「登録済み 3件 / 月 ¥32,480 ... 一致するか確認」が出る。
    expect(find.textContaining('登録済み 3件'), findsOneWidget);
    expect(find.textContaining('¥32,480'), findsOneWidget);
    expect(find.textContaining('APPLE.COM/BILL'), findsOneWidget);
  });
}
