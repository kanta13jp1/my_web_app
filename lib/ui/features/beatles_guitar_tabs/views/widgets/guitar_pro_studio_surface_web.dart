import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../../../../services/route_visibility_observer.dart';

const String kGuitarProStudioAssetPath = '/labs/guitar-pro-studio/index.html';

/// First-party, reviewed static code, not a sandbox for untrusted HTML.
/// Keeps alphaTab / AudioWorklet isolated inside the same-origin static lab.
class GuitarProStudioSurface extends StatefulWidget {
  const GuitarProStudioSurface({super.key});

  @override
  State<GuitarProStudioSurface> createState() => _GuitarProStudioSurfaceState();
}

class _GuitarProStudioSurfaceState extends State<GuitarProStudioSurface>
    with RouteAware {
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
    // Stop Web Audio / AudioWorklet playback cleanly when switching away.
    _frame?.src = 'about:blank';
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.expand();
    }
    return Semantics(
      container: true,
      label: 'プロ譜面ラボ (alphaTab)',
      child: HtmlElementView.fromTagName(
        key: const Key('guitar_pro_studio_iframe'),
        tagName: 'iframe',
        onElementCreated: (Object element) {
          final frame = element as web.HTMLIFrameElement;
          _frame = frame;
          frame
            ..title = 'プロ譜面ラボ (alphaTab)'
            ..src = kGuitarProStudioAssetPath
            ..referrerPolicy = 'no-referrer'
            ..allow = "display-capture 'none'; camera 'none'; "
                "microphone 'none'; geolocation 'none'"
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
        },
      ),
    );
  }
}
