import 'package:intl/intl.dart';

/// Do not present failed or unfinished reads as an empty task register.
String formatAssetMustTaskSummary({
  required List<Map<String, dynamic>> tasks,
  required DateTime month,
  required bool isLoading,
  required bool loadFailed,
}) {
  final output = StringBuffer()
    ..writeln('### ⑤ 必須タスク（${DateFormat('yyyy/MM').format(month)}）');
  if (isLoading) {
    output.writeln('- 未取得（読込中）');
    return output.toString();
  }
  if (loadFailed) {
    output.writeln('- 未取得（読込失敗。最新の登録状況は未確認）');
    return output.toString();
  }
  final current = tasks.where((task) {
    final deadline = DateTime.parse(task['deadline'] as String).toLocal();
    return deadline.year == month.year && deadline.month == month.month;
  }).toList()
    ..sort(
        (a, b) => (a['deadline'] as String).compareTo(b['deadline'] as String));
  if (current.isEmpty) {
    output.writeln('- （未登録）');
  } else {
    for (final task in current) {
      final deadline = DateTime.parse(task['deadline'] as String).toLocal();
      final completed = task['is_completed'] == true;
      output.writeln(
        '- ${completed ? "✅" : "⬜️"} ${task["title"]}（締切 ${DateFormat('MM/dd').format(deadline)}）',
      );
    }
  }
  return output.toString();
}
