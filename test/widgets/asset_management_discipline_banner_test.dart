import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RejectingMarkerStore extends InMemorySharedPreferencesStore {
  _RejectingMarkerStore()
      : super.withData({'flutter.asset_management_display_mode_v1': 'full'});

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key.startsWith('flutter.asset_suspended_debt_accounts_v1_')) {
      return Future<bool>.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

class _ConfirmedPaymentRepository
    extends SharedPreferencesAssetLiabilityRepository {
  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return const AssetLiabilityMonthlyState(
      confirmedPaymentDays: <String, double>{'aupay_card': 13},
    );
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

const _firstOwner = '00000000-0000-4000-8000-000000000001';
const _secondOwner = '00000000-0000-4000-8000-000000000002';

Future<void> _setSyntheticOwner(String id) {
  return Supabase.instance.client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'synthetic-local-test-only',
      'token_type': 'bearer',
      'user': {
        'id': id,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-07-10T00:00:00Z',
      },
    }),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      httpClient: MockClient((request) async {
        final read =
            request.method == 'GET' && request.url.path.startsWith('/rest/v1/');
        return http.Response(
          read ? '[]' : '{}',
          read ? 200 : 403,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('借金しない宣言違反がある月は上部赤バナーが表示され、使用停止の目印を付けられる (#4217)', (
    tester,
  ) async {
    await _setSyntheticOwner(_firstOwner);
    final now = DateTime(2026, 7, 10);
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
      <String, AssetLiabilityRevolvingCreditConfig>{
        'aupay_card': const AssetLiabilityRevolvingCreditConfig(
          monthlyAmount: 0,
          newUsageAmount: 15000,
          creditLimit: 100000,
        ),
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    final workingStore = SharedPreferencesStorePlatform.instance;
    SharedPreferencesStorePlatform.instance = _RejectingMarkerStore();
    addTearDown(() => SharedPreferencesStorePlatform.instance = workingStore);
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 1. 違反あり: バナーが表示され、対象口座に使用停止の目印を付けられる
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: now,
          debugCalendarNow: now,
          debugRevolvingConfigsMirror: mirrorValue,
          assetLiabilityRepository: _ConfirmedPaymentRepository(),
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{
              '三井住友銀行大塚支店': 50000,
              'auPayカード': -100000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('asset_liability_workbook_board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('asset_discipline_violation_banner')),
      findsOneWidget,
    );
    final suspendButton = find.byKey(
      const Key('discipline_banner_suspend_todo_aupay_card'),
    );
    expect(suspendButton, findsOneWidget);

    final savedTag = find.byKey(const Key('debt_suspended_tag_aupay_card'));
    await tester.ensureVisible(suspendButton);
    await tester.tap(suspendButton);
    await tester.pump();
    expect(find.text('端末内に記録できませんでした。再試行してください。'), findsOneWidget);
    expect(savedTag, findsNothing);

    await _setSyntheticOwner(_secondOwner);
    await tester.pumpAndSettle();
    await _setSyntheticOwner(_firstOwner);
    await tester.pumpAndSettle();
    expect(savedTag, findsNothing);

    SharedPreferencesStorePlatform.instance = workingStore;
    await tester.ensureVisible(suspendButton);
    await tester.tap(suspendButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('debt_suspended_tag_aupay_card')),
      findsOneWidget,
    );

    await _setSyntheticOwner(_secondOwner);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('debt_suspended_tag_aupay_card')),
      findsNothing,
    );

    await _setSyntheticOwner(_firstOwner);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('debt_suspended_tag_aupay_card')),
      findsOneWidget,
    );

    await _unmount(tester);

    // 2. 違反なし: バナーは表示されない
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_display_mode_v1': 'full',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugNow: now,
          debugCalendarNow: now,
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{
              '三井住友銀行大塚支店': 200000,
              'auPayカード': 0,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const Key('asset_liability_workbook_board')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('asset_discipline_violation_banner')),
      findsNothing,
    );

    await _unmount(tester);
  });
}
