class LocalCleanupResult {
  const LocalCleanupResult({
    required this.action,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  factory LocalCleanupResult.unsupported(String action, String message) {
    return LocalCleanupResult(
      action: action,
      exitCode: 1,
      stdout: '',
      stderr: message,
    );
  }

  final String action;
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get success => exitCode == 0;

  String get displayMessage {
    final output = stdout.trim().isNotEmpty ? stdout.trim() : stderr.trim();
    if (output.isEmpty) {
      return success ? '$action completed.' : '$action failed.';
    }
    return output.split(RegExp(r'\r?\n')).take(4).join('\n');
  }
}
