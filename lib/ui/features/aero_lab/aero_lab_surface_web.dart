import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../services/route_visibility_observer.dart';

/// First-party, reviewed static code, not a sandbox for generated/untrusted HTML.
/// No message bridge or credentials are passed into the experiment.
class AeroLabSurface extends StatefulWidget {
  const AeroLabSurface({super.key});

  @override
  State<AeroLabSurface> createState() => _AeroLabSurfaceState();
}

class _AeroLabSurfaceState extends State<AeroLabSurface> with RouteAware {
  web.HTMLIFrameElement? _frame;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      deepLinkVisibilityRouteObserver.unsubscribe(this);
      deepLinkVisibilityRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _frame?.src = 'about:blank';
    _frame = null;
    setState(() => _visible = false);
  }

  @override
  void didPopNext() => setState(() => _visible = true);

  @override
  void dispose() {
    deepLinkVisibilityRouteObserver.unsubscribe(this);
    // Unload the child document (including its GPU and recording resources).
    _frame?.src = 'about:blank';
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_visible
      ? const SizedBox.expand()
      : HtmlElementView.fromTagName(
          tagName: 'iframe',
          onElementCreated: (element) {
            final frame = element as web.HTMLIFrameElement;
            _frame = frame;
            frame
              ..title = 'AERO LAB 教育用3Dエンジン実験室'
              ..src = '/labs/aero-lab/index.html'
              ..referrerPolicy = 'no-referrer'
              ..allow =
                  "display-capture 'self'; camera 'none'; microphone 'none'; "
                      "geolocation 'none'"
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';
          },
        );
}
