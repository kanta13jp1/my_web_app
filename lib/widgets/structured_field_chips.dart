import 'package:flutter/material.dart';

/// GitHub Issue Fields 相当の構造化フィールド (Priority / Effort / 期日) の
/// ラベル・色・表示チップを feature_requests / growth_plans 双方で共有する。
/// 値ドメインは DB の CHECK 制約と一致させること。

const List<String> kPriorityValues = <String>['p0', 'p1', 'p2', 'p3'];
const List<String> kEffortValues = <String>['xs', 's', 'm', 'l', 'xl'];

String priorityLabel(String? value) {
  switch (value) {
    case 'p0':
      return 'P0 最優先';
    case 'p1':
      return 'P1 高';
    case 'p2':
      return 'P2 中';
    case 'p3':
      return 'P3 低';
    default:
      return '未設定';
  }
}

Color priorityColor(String? value) {
  switch (value) {
    case 'p0':
      return const Color(0xFFE53935);
    case 'p1':
      return const Color(0xFFFF6B35);
    case 'p2':
      return const Color(0xFFFFC107);
    case 'p3':
      return const Color(0xFF9E9E9E);
    default:
      return const Color(0xFF9E9E9E);
  }
}

String effortLabel(String? value) {
  switch (value) {
    case 'xs':
      return 'XS';
    case 's':
      return 'S';
    case 'm':
      return 'M';
    case 'l':
      return 'L';
    case 'xl':
      return 'XL';
    default:
      return '—';
  }
}

/// ISO 日付文字列 (yyyy-MM-dd もしくは timestamptz) を yyyy-MM-dd に整形。
String? formatTargetDate(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return text.length >= 10 ? text.substring(0, 10) : text;
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

/// 優先度チップ。値が無ければ null。
Widget? priorityChip(String? value) {
  if (value == null || value.isEmpty) return null;
  final color = priorityColor(value);
  return _StructuredChip(
    label: priorityLabel(value),
    color: color,
    icon: Icons.flag,
  );
}

/// 工数チップ。値が無ければ null。
Widget? effortChip(String? value) {
  if (value == null || value.isEmpty) return null;
  return _StructuredChip(
    label: '工数 ${effortLabel(value)}',
    color: const Color(0xFF3D5AFE),
    icon: Icons.fitness_center,
  );
}

/// 期日チップ。値が無ければ null。
Widget? dueDateChip(dynamic raw) {
  final formatted = formatTargetDate(raw);
  if (formatted == null) return null;
  return _StructuredChip(
    label: formatted,
    color: const Color(0xFF4CAF50),
    icon: Icons.event,
  );
}

class _StructuredChip extends StatelessWidget {
  const _StructuredChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
