/// 本日記録済み口座入力行のリアルタイム編集状態 (#4096)。
enum AssetInputRowEditState {
  unrecorded,
  savedToday,
  dirtyEdit,
}

/// 本日記録済みの口座に対して、入力欄の現在値が直前の本日記録額から
/// 変更されているかを判定する純粋関数 (#4096)。
AssetInputRowEditState resolveAssetInputRowEditState({
  required bool isUpdatedToday,
  required double? recordedAmount,
  required String rawInput,
}) {
  if (!isUpdatedToday) {
    return AssetInputRowEditState.unrecorded;
  }
  final normalized = rawInput.replaceAll(',', '').trim();
  if (normalized.isEmpty) {
    return AssetInputRowEditState.savedToday;
  }
  final parsed = double.tryParse(normalized);
  if (parsed == null || !parsed.isFinite) {
    return AssetInputRowEditState.savedToday;
  }
  if (recordedAmount == null) {
    return AssetInputRowEditState.dirtyEdit;
  }
  return (parsed - recordedAmount).abs() > 0.005
      ? AssetInputRowEditState.dirtyEdit
      : AssetInputRowEditState.savedToday;
}
