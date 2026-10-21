/// Select at most five evenly spaced recorded dates, including both ends.
/// Bar charts can request every group title even when an interval is supplied.
Set<int> assetChartDateLabelIndices(int count) {
  if (count <= 0) return const <int>{};
  final slots = count < 5 ? count : 5;
  if (slots == 1) return <int>{0};
  return <int>{
    for (var slot = 0; slot < slots; slot++)
      ((count - 1) * slot / (slots - 1)).round(),
  };
}
