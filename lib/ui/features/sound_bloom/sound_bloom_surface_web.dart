import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../services/route_visibility_observer.dart';

/// First-party, reviewed static code, not a sandbox for generated/untrusted HTML.
/// No message bridge or credentials are passed into the experiment.
class SoundBloomSurface extends StatefulWidget {
  const SoundBloomSurface({super.key});

  @override
  State<SoundBloomSurface> createState() => _SoundBloomSurfaceState();
}

class _SoundBloomSurfaceState extends State<SoundBloomSurface> with RouteAware {
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
              ..title = 'SOUND BLOOM インタラクティブ音楽体験'
              ..src = '/labs/sound-bloom/index.html'
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
