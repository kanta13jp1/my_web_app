import 'package:flutter/material.dart';
import 'package:my_web_app/services/route_visibility_observer.dart';
import 'package:my_web_app/ui/features/sea_shelter/sea_shelter_surface.dart';

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
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const _Game())),
            child: const Text('ゲームを開く'),
          ),
        ),
      );
}

class _Game extends StatelessWidget {
  const _Game();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const _Cover())),
              child: const Text('別画面'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ゲームを閉じる'),
            ),
          ],
        ),
        body: const SeaShelterSurface(),
      );
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ゲームに戻る'),
          ),
        ),
      );
}
