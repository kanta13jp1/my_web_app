import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerIframeViewFactory(String viewId, String src) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewIdInt) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..allow = 'accelerometer; autoplay; clipboard-write; '
            'encrypted-media; gyroscope; picture-in-picture'
        ..setAttribute('allowfullscreen', 'true')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    },
  );
}
