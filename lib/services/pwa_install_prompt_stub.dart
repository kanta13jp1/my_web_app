class PwaInstallPromptController {
  PwaInstallPromptController({
    required void Function(bool isAvailable) onAvailabilityChanged,
  });

  bool get isAvailable => false;

  void attach() {}

  Future<bool> promptInstall() async => false;

  void dispose() {}
}
