import '../domain/video_preflight_models.dart';

VideoPreflightProbe createBrowserVideoPreflightProbe() =>
    _StubVideoPreflightProbe();

class _StubVideoPreflightProbe implements VideoPreflightProbe {
  @override
  Future<VideoSystemSnapshot> collectSnapshot() async {
    return const VideoSystemSnapshot(
      isWebRuntime: false,
      isSecureContext: true,
      userAgent: '',
      browserName: '非Web環境 (VM / Native)',
      engine: BrowserEngineKind.other,
      webGlAvailable: true,
      hardwareAccelerated: true,
      gpuRenderer: 'Native Host',
      deviceMemoryGb: 8.0,
      hardwareConcurrency: 4,
      supportsMediaDevices: false,
      supportsDisplayMedia: false,
      microphonePermission: MediaPermissionState.unsupported,
      cameraPermission: MediaPermissionState.unsupported,
      screenSharePermission: MediaPermissionState.unsupported,
    );
  }

  @override
  Future<VideoSystemSnapshot> verifyPermission({
    required final String capability,
  }) {
    return collectSnapshot();
  }
}
