import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../services/route_visibility_observer.dart';

/// First-party, reviewed static showcase portal for Gemini 4 interactive labs,
/// Blender 3D breakdowns, concept roadmap, and X benchmark references.
/// No message bridge or credentials are passed into the embedded document.
class NeonShowcaseSurface extends StatefulWidget {
  const NeonShowcaseSurface({super.key});

  @override
  State<NeonShowcaseSurface> createState() => _NeonShowcaseSurfaceState();
}

class _NeonShowcaseSurfaceState extends State<NeonShowcaseSurface>
    with RouteAware {
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
              ..title = 'Gemini 4 作品館 · NEON SHOWCASE'
              ..src = '/labs/neon-showcase/index.html?v=20261120-32'
              ..referrerPolicy = 'no-referrer'
              ..allowFullscreen = true
              ..allow =
                  "fullscreen; camera 'none'; microphone 'none'; geolocation 'none'"
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';
          },
        );
}
