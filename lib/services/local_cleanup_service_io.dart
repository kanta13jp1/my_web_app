import 'dart:io';

import 'local_cleanup_result.dart';

class LocalCleanupService {
  const LocalCleanupService();

  bool get isSupported => Platform.isWindows;

  String get supportLabel =>
      Platform.isWindows ? 'Windows app' : '${Platform.operatingSystem} app';

  Future<LocalCleanupResult> runReport() async {
    return _runPowerShellScript(
      'Invoke-SmartCleanup.ps1',
      action: 'Smart cleanup report',
    );
  }

  Future<LocalCleanupResult> applyApprovedCleanup() async {
    return _runPowerShellScript(
      'Invoke-ApprovedCleanup.ps1',
      action: 'Approved cleanup',
      arguments: const <String>['-Apply'],
    );
  }

  Future<LocalCleanupResult> runGeneratedCommand(
    String command, {
    required String action,
  }) async {
    if (!Platform.isWindows) {
      return LocalCleanupResult.unsupported(
        action,
        'Scheduled task operations are only available in the Windows app.',
      );
    }
    return _runExecutable(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        command,
      ],
      action: action,
    );
  }

  Future<LocalCleanupResult> _runPowerShellScript(
    String scriptName, {
    required String action,
    List<String> arguments = const <String>[],
  }) async {
    if (!Platform.isWindows) {
      return LocalCleanupResult.unsupported(
        action,
        'Local PC cleanup actions are only available in the Windows app.',
      );
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null || userProfile.isEmpty) {
      return LocalCleanupResult.unsupported(
        action,
        'USERPROFILE was not found. The cleanup script path cannot be resolved.',
      );
    }

    final scriptPath = _resolveScriptPath(scriptName, userProfile);
    if (scriptPath == null) {
      final bundledPath =
          '${File(Platform.resolvedExecutable).parent.path}\\scripts\\SmartCleanup\\$scriptName';
      final profilePath = '$userProfile\\Scripts\\SmartCleanup\\$scriptName';
      return LocalCleanupResult.unsupported(
        action,
        'Cleanup script not found. Checked: $bundledPath / $profilePath',
      );
    }

    return _runExecutable(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        ...arguments,
      ],
      action: action,
    );
  }

  String? _resolveScriptPath(String scriptName, String userProfile) {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      '$executableDir\\scripts\\SmartCleanup\\$scriptName',
      '$userProfile\\Scripts\\SmartCleanup\\$scriptName',
    ];
    for (final scriptPath in candidates) {
      if (File(scriptPath).existsSync()) {
        return scriptPath;
      }
    }
    return null;
  }

  Future<LocalCleanupResult> _runExecutable(
    String executable,
    List<String> arguments, {
    required String action,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        runInShell: false,
      );
      return LocalCleanupResult(
        action: action,
        exitCode: result.exitCode,
        stdout: '${result.stdout}',
        stderr: '${result.stderr}',
      );
    } on ProcessException catch (error) {
      return LocalCleanupResult.unsupported(action, error.message);
    }
  }
}
