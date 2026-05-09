import 'dart:js_interop';

import 'package:web/web.dart' as web;

class PwaInstallPromptController {
  final void Function(bool isAvailable) _onAvailabilityChanged;

  _BeforeInstallPromptEvent? _deferredPrompt;
  JSFunction? _beforeInstallPromptListener;

  PwaInstallPromptController({
    required void Function(bool isAvailable) onAvailabilityChanged,
  }) : _onAvailabilityChanged = onAvailabilityChanged;

  bool get isAvailable => _deferredPrompt != null;

  void attach() {
    if (_beforeInstallPromptListener != null) {
      return;
    }

    _beforeInstallPromptListener = ((web.Event event) {
      event.preventDefault();
      _deferredPrompt = _BeforeInstallPromptEvent(event);
      _onAvailabilityChanged(true);
    }).toJS;
    web.window.addEventListener(
      'beforeinstallprompt',
      _beforeInstallPromptListener,
    );
  }

  Future<bool> promptInstall() async {
    final promptEvent = _deferredPrompt;
    if (promptEvent == null) {
      return false;
    }

    await promptEvent.prompt().toDart;
    _deferredPrompt = null;
    _onAvailabilityChanged(false);
    return true;
  }

  void dispose() {
    final listener = _beforeInstallPromptListener;
    if (listener == null) {
      return;
    }
    web.window.removeEventListener('beforeinstallprompt', listener);
    _beforeInstallPromptListener = null;
  }
}

@JS()
extension type _BeforeInstallPromptEvent(web.Event _) implements web.Event {
  external JSPromise<JSAny?> prompt();
}
