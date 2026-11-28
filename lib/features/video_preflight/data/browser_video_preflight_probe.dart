import '../domain/video_preflight_models.dart';
import 'browser_video_preflight_probe_stub.dart'
    if (dart.library.js_interop) 'browser_video_preflight_probe_web.dart'
    as platform;

VideoPreflightProbe createBrowserVideoPreflightProbe() =>
    platform.createBrowserVideoPreflightProbe();
