import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../services/route_visibility_observer.dart';

/// First-party, reviewed static code, not a sandbox for generated/untrusted HTML.
/// No message bridge or credentials are passed into the experiment.
class LumenPathSurface extends StatefulWidget {
  const LumenPathSurface({super.key});

  @override
  State<LumenPathSurface> createState() => _LumenPathSurfaceState();
}

class _LumenPathSurfaceState extends State<LumenPathSurface> with RouteAware {
  web.HTMLIFrameElement? _frame;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _visible = route == null || route.isCurrent;
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
    // Unload the child document (including its animations and event listeners).
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
              ..title = 'LUMEN PATH 光の経路パズル'
              ..src = '/labs/lumen-path/index.html'
              ..referrerPolicy = 'no-referrer'
              ..allow =
                  "display-capture 'none'; camera 'none'; microphone 'none'; "
                      "geolocation 'none'"
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';
          },
        );
}
