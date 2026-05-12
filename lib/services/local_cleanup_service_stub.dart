import 'local_cleanup_result.dart';

class LocalCleanupService {
  const LocalCleanupService();

  bool get isSupported => false;

  String get supportLabel => 'Web版';

  Future<LocalCleanupResult> runReport() async {
    return LocalCleanupResult.unsupported(
      'Smart cleanup report',
      'Windowsアプリ版でのみローカルPC操作を実行できます。',
    );
  }

  Future<LocalCleanupResult> applyApprovedCleanup() async {
    return LocalCleanupResult.unsupported(
      'Approved cleanup',
      'Windowsアプリ版でのみ承認済みクリーンアップを実行できます。',
    );
  }

  Future<LocalCleanupResult> runGeneratedCommand(
    String command, {
    required String action,
  }) async {
    return LocalCleanupResult.unsupported(
      action,
      'Windowsアプリ版でのみスケジュールタスクを操作できます。',
    );
  }
}
