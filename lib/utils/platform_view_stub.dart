// Stub for non-web platforms — keeps tests compilable on Dart VM.
// Real implementation is in platform_view_web.dart selected via conditional import.

void registerIframeViewFactory(String viewId, String src) {
  // no-op on non-web platforms
}
