import 'package:flutter/material.dart';
import 'package:my_web_app/services/route_visibility_observer.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  runApp(
    MaterialApp(
      navigatorObservers: <NavigatorObserver>[deepLinkVisibilityRouteObserver],
      home: const BeatlesGuitarTabsFeature(),
    ),
  );
}
