import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await Supabase.initialize(
    url: 'http://127.0.0.1:9999',
    publishableKey: 'test-publishable-key',
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );
  SemanticsBinding.instance.ensureSemantics();
  runApp(const ActionProbe());
}

class ActionProbe extends StatefulWidget {
  const ActionProbe({super.key});
  @override
  State<ActionProbe> createState() => _ActionProbeState();
}

class _PopupCounter extends NavigatorObserver {
  final pushes = ValueNotifier<int>(0);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pushes.value++);
    }
  }
}

class _ActionProbeState extends State<ActionProbe> {
  final navigator = GlobalKey<NavigatorState>();
  final counter = _PopupCounter();
  bool banner = false;
  bool visible = true;
  Timer? timer;

  void delayedBanner() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => banner = true);
    });
  }

  void hideShow() {
    timer?.cancel();
    setState(() => visible = false);
    timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => visible = true);
    });
  }

  Future<void> openFixtureModal() => showDialog<void>(
        context: navigator.currentState!.overlay!.context,
        builder: (context) => AlertDialog(
          title: const Text('合成検査モーダル'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('合成モーダルを閉じる'),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    timer?.cancel();
    counter.pushes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [counter],
        builder: (_, child) => Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: counter.pushes,
              builder: (_, value, child) => Material(
                child: Semantics(
                  container: true,
                  label: 'fixture-popup-pushes:$value',
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 320,
                    height: 40,
                    child: Text(
                      'fixture-popup-pushes:$value',
                      style: const TextStyle(fontSize: 12, height: 1),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: child!),
          ],
        ),
        home: Scaffold(
          body: Column(
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: delayedBanner,
                    child: const Text('合成：遅延カード'),
                  ),
                  TextButton(
                    onPressed: hideShow,
                    child: const Text('合成：非表示と再表示'),
                  ),
                  TextButton(
                    onPressed: openFixtureModal,
                    child: const Text('合成：モーダル'),
                  ),
                ],
              ),
              if (banner)
                const SizedBox(
                  height: 120,
                  child: Center(child: Text('合成：追加カード表示済み')),
                ),
              Expanded(
                child: visible
                    ? AssetManagementPage(
                        key: const ValueKey('synthetic-asset-page'),
                        debugNow: DateTime(2026, 6, 20),
                        debugCalendarNow: DateTime(2026, 6, 20),
                        debugInitialAssetData: const {
                          '2026-06-20': {
                            'Synthetic bank': 1000,
                            'SyntheticLoan': -10000,
                          },
                        },
                      )
                    : const Center(child: Text('合成：一時非表示')),
              ),
            ],
          ),
        ),
      );
}
