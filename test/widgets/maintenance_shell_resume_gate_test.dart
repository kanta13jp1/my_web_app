import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/maintenance_service.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';
import 'package:my_web_app/widgets/maintenance_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {}

/// fetchActive の force 引数だけ記録するフェイク (ネットワークは張らない)。
class _CountingMaintenanceService extends MaintenanceService {
  _CountingMaintenanceService() : super(client: _FakeSupabaseClient());

  int forceTrueCalls = 0;
  int forceFalseCalls = 0;

  @override
  Future<MaintenanceSnapshot> fetchActive({bool force = false}) async {
    if (force) {
      forceTrueCalls += 1;
    } else {
      forceFalseCalls += 1;
    }
    return MaintenanceSnapshot(
      windows: const [],
      fetchedAt: DateTime.now(),
    );
  }
}

void main() {
  testWidgets(
    'MaintenanceShell: 初回ロードは force、resumed は非force '
    '(フォーカス往復での schedule-hub 連打を抑制)',
    (WidgetTester tester) async {
      final service = _CountingMaintenanceService();
      final routeListenable = ValueNotifier<UniversalSharePageContext>(
        UniversalSharePageContext.fromRouteName('/admin'),
      );
      addTearDown(routeListenable.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceShell(
            routeListenable: routeListenable,
            service: service,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      // 初回ロードは即時性が必要なので force:true が1回。
      expect(service.forceTrueCalls, 1);
      expect(service.forceFalseCalls, 0);

      // resumed をフォーカス往復ぶん連発しても force:true は増えず、
      // 非force(=TTL 尊重)で処理される。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(service.forceTrueCalls, 1, reason: 'resumed は force しない');
      expect(service.forceFalseCalls, 2, reason: 'resumed 2回は非force で処理');
    },
  );
}
