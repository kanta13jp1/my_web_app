import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../domain/video_preflight_models.dart';

@JS('navigator.deviceMemory')
external JSNumber? get _jsDeviceMemory;

@JS('navigator.hardwareConcurrency')
external JSNumber? get _jsHardwareConcurrency;

@JS('navigator.permissions')
external _JsPermissions? get _jsPermissions;

@JS('navigator.mediaDevices')
external web.MediaDevices? get _jsMediaDevices;

@JS('navigator.mediaDevices.getDisplayMedia')
external JSAny? get _jsGetDisplayMediaProp;

@JS()
extension type _JsPermissions(JSObject _) implements JSObject {
  external JSPromise<_JsPermissionStatus> query(JSAny descriptor);
}

@JS()
extension type _JsPermissionStatus(JSObject _) implements JSObject {
  external JSString get state;
}

@JS()
extension type _JsGlContext(JSObject _) implements JSObject {
  external JSAny? getExtension(JSString name);
  external JSAny? getParameter(JSNumber pname);
}

@JS()
extension type _JsCanvasElement(JSObject _) implements JSObject {
  external _JsGlContext? getContext(JSString contextId);
}

@JS()
extension type _JsDisplayMediaDevices(JSObject _) implements JSObject {
  external JSPromise<web.MediaStream> getDisplayMedia(JSAny constraints);
}

VideoPreflightProbe createBrowserVideoPreflightProbe() =>
    _WebVideoPreflightProbe();

class _WebVideoPreflightProbe implements VideoPreflightProbe {
  MediaPermissionState _microphoneState = MediaPermissionState.prompt;
  MediaPermissionState _cameraState = MediaPermissionState.prompt;
  MediaPermissionState _screenShareState = MediaPermissionState.prompt;

  Future<MediaPermissionState> _queryPermissionApi(
    final String name,
    final MediaPermissionState fallback,
  ) async {
    final permissions = _jsPermissions;
    if (permissions == null) {
      return fallback;
    }
    try {
      final status = await permissions
          .query(<String, String>{'name': name}.jsify()!)
          .toDart;
      switch (status.state.toDart.toLowerCase()) {
        case 'granted':
          return MediaPermissionState.granted;
        case 'denied':
          return MediaPermissionState.denied;
        case 'prompt':
          return MediaPermissionState.prompt;
        default:
          return fallback;
      }
    } catch (_) {
      return fallback;
    }
  }

  ({bool webGlAvailable, bool hardwareAccelerated, String gpuRenderer})
      _inspectWebGl() {
    try {
      final element = web.document.createElement('canvas');
      final canvas = _JsCanvasElement(element);
      final gl = canvas.getContext('webgl2'.toJS) ??
          canvas.getContext('webgl'.toJS) ??
          canvas.getContext('experimental-webgl'.toJS);
      if (gl == null) {
        return (
          webGlAvailable: false,
          hardwareAccelerated: false,
          gpuRenderer: '',
        );
      }
      var renderer = 'WebGL Active';
      final ext = gl.getExtension('WEBGL_debug_renderer_info'.toJS);
      if (ext != null) {
        // 0x9246 == UNMASKED_RENDERER_WEBGL
        final rawRenderer = gl.getParameter(0x9246.toJS);
        if (rawRenderer != null && rawRenderer.isA<JSString>()) {
          renderer = (rawRenderer as JSString).toDart;
        }
      }
      return (
        webGlAvailable: true,
        hardwareAccelerated: !isSoftwareGpuRenderer(renderer),
        gpuRenderer: renderer,
      );
    } catch (_) {
      return (
        webGlAvailable: false,
        hardwareAccelerated: false,
        gpuRenderer: '',
      );
    }
  }

  @override
  Future<VideoSystemSnapshot> collectSnapshot() async {
    final userAgent = web.window.navigator.userAgent;
    final glInfo = _inspectWebGl();
    final hasMediaDevices = _jsMediaDevices != null;
    final hasDisplayMedia = hasMediaDevices && _jsGetDisplayMediaProp != null;

    if (hasMediaDevices) {
      _microphoneState = await _queryPermissionApi(
        'microphone',
        _microphoneState,
      );
      _cameraState = await _queryPermissionApi('camera', _cameraState);
      _screenShareState = hasDisplayMedia
          ? await _queryPermissionApi('display-capture', _screenShareState)
          : MediaPermissionState.unsupported;
    } else {
      _microphoneState = MediaPermissionState.unsupported;
      _cameraState = MediaPermissionState.unsupported;
      _screenShareState = MediaPermissionState.unsupported;
    }

    return VideoSystemSnapshot(
      isWebRuntime: true,
      isSecureContext: web.window.isSecureContext,
      userAgent: userAgent,
      browserName: detectBrowserLabel(userAgent),
      engine: classifyBrowserEngine(userAgent),
      webGlAvailable: glInfo.webGlAvailable,
      hardwareAccelerated: glInfo.hardwareAccelerated,
      gpuRenderer: glInfo.gpuRenderer,
      deviceMemoryGb: _jsDeviceMemory?.toDartDouble,
      hardwareConcurrency: _jsHardwareConcurrency?.toDartInt,
      supportsMediaDevices: hasMediaDevices,
      supportsDisplayMedia: hasDisplayMedia,
      microphonePermission: _microphoneState,
      cameraPermission: _cameraState,
      screenSharePermission: _screenShareState,
    );
  }

  void _stopTracks(final web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  Future<MediaPermissionState> _probeStream({
    required final bool requestAudio,
    required final bool requestVideo,
    required final bool requestScreen,
  }) async {
    final mediaDevices = _jsMediaDevices;
    if (mediaDevices == null) {
      return MediaPermissionState.unsupported;
    }
    try {
      final web.MediaStream stream;
      if (requestScreen) {
        if (_jsGetDisplayMediaProp == null) {
          return MediaPermissionState.unsupported;
        }
        stream = await _JsDisplayMediaDevices(mediaDevices)
            .getDisplayMedia(
              <String, Object?>{'video': true, 'audio': false}.jsify()!,
            )
            .toDart;
      } else {
        stream = await mediaDevices
            .getUserMedia(
              web.MediaStreamConstraints(
                audio: requestAudio.toJS,
                video: requestVideo.toJS,
              ),
            )
            .toDart;
      }
      _stopTracks(stream);
      return MediaPermissionState.granted;
    } catch (err) {
      final detail = err.toString().toLowerCase();
      if (detail.contains('notallowederror') ||
          detail.contains('permission') ||
          detail.contains('denied')) {
        return MediaPermissionState.denied;
      }
      return MediaPermissionState.unsupported;
    }
  }

  @override
  Future<VideoSystemSnapshot> verifyPermission({
    required final String capability,
  }) async {
    if (capability == 'microphone' || capability == 'all') {
      _microphoneState = await _probeStream(
        requestAudio: true,
        requestVideo: false,
        requestScreen: false,
      );
    }
    if (capability == 'camera' || capability == 'all') {
      _cameraState = await _probeStream(
        requestAudio: false,
        requestVideo: true,
        requestScreen: false,
      );
    }
    if (capability == 'screen_share' || capability == 'all') {
      _screenShareState = await _probeStream(
        requestAudio: false,
        requestVideo: false,
        requestScreen: true,
      );
    }
    return collectSnapshot();
  }
}
