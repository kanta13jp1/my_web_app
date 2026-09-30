import 'package:flutter/material.dart';
import 'package:my_web_app/services/route_visibility_observer.dart';
import 'package:my_web_app/ui/features/flow_city/flow_city_surface.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(
    MaterialApp(
      navigatorObservers: [deepLinkVisibilityRouteObserver],
      home: const _Home(),
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const _Lab()),
        ),
        child: const Text('実験室を開く'),
      ),
    ),
  );
}

class _Lab extends StatelessWidget {
  const _Lab();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('表示ライフサイクル検証'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _Cover()),
          ),
          child: const Text('覆う画面を開く'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('実験室を閉じる'),
        ),
      ],
    ),
    body: const FlowCitySurface(),
  );
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('実験室へ戻る'),
      ),
    ),
  );
}
