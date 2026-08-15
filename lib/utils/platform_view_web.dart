import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerIframeViewFactory(String viewId, String src) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewIdInt) {
    final iframe = web.HTMLIFrameElement()
      ..src = src
      ..allow = 'accelerometer; autoplay; clipboard-write; '
          'encrypted-media; gyroscope; picture-in-picture'
      ..setAttribute('allowfullscreen', 'true')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
}

void registerVideoViewFactory(String viewId, String src) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewIdInt) {
    final video = web.HTMLVideoElement()
      ..src = src
      ..controls = true
      ..preload = 'metadata'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('aria-label', 'AGI Fireworks video')
      ..style.backgroundColor = '#000000'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain';
    return video;
  });
}

void registerSandboxedSrcDocIframeViewFactory(
  String viewId,
  String srcDoc, {
  required String sandbox,
  required String csp,
}) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewIdInt) {
    final iframe = web.HTMLIFrameElement()
      ..setAttribute('srcdoc', srcDoc)
      ..setAttribute('sandbox', sandbox)
      ..setAttribute('csp', csp)
      ..setAttribute('credentialless', 'true')
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..setAttribute('allow', '')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    return iframe;
  });
}
