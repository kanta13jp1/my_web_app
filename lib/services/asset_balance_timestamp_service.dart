/// cfo_assets の記録時刻を DB と画面の日付へ安全に変換する。
class AssetBalanceTimestampService {
  const AssetBalanceTimestampService._();

  /// PostgreSQL `timestamp with time zone` へ渡す値は、タイムゾーンを明示した
  /// UTC の RFC 3339 文字列に統一する。
  static String encodeForDatabase(DateTime instant) =>
      instant.toUtc().toIso8601String();

  /// DB の時刻をローカル日付へ変換する。
  ///
  /// 旧 Web クライアントはローカル時刻をオフセットなしで送信していたため、
  /// UTC と誤解釈された行がローカル変換後に翌日になることがある。cfo_assets は
  /// 未来日付入力を提供しないため、現在より未来かつ翌日以降になった行だけは
  /// 当日へ丸め、更新済み残高を失わないようにする。
  static DateTime localRecordDate(DateTime createdAt, {required DateTime now}) {
    final localCreatedAt = createdAt.toLocal();
    final localNow = now.toLocal();
    final createdDate = DateTime(
      localCreatedAt.year,
      localCreatedAt.month,
      localCreatedAt.day,
    );
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    if (localCreatedAt.isAfter(localNow) && createdDate.isAfter(today)) {
      return today;
    }
    return createdDate;
  }
}
