Future<void> withBusinessExecutionLock(
  String name,
  Future<void> Function() action,
) async {
  throw UnsupportedError('この環境では安全な端末保存を利用できません。');
}
