class BrowserReminderPlatform {
  bool get supported => false;
  String get permission => 'unsupported';
  Future<String> requestPermission() async => 'unsupported';
  Future<void> showReminder() async => throw UnsupportedError('Browser only');
}
