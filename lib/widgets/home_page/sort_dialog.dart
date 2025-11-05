import 'package:flutter/material.dart';
import '../../models/sort_type.dart';

/// 並び替えダイアログ
class SortDialog extends StatelessWidget {
  final SortType currentSortType;
  final ValueChanged<SortType> onSortTypeChanged;

  const SortDialog({
    super.key,
    required this.currentSortType,
    required this.onSortTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.sort, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '並び替え',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完了'),
                ),
              ],
            ),
          ),
          const Divider(),
          ...SortType.values.map((sortType) {
            final isSelected = currentSortType == sortType;
            return ListTile(
              leading: Icon(
                _getSortIcon(sortType),
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              title: Text(
                sortType.label,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                onSortTypeChanged(sortType);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  IconData _getSortIcon(SortType sortType) {
    switch (sortType) {
      case SortType.updatedDesc:
      case SortType.createdDesc:
        return Icons.arrow_downward;
      case SortType.updatedAsc:
      case SortType.createdAsc:
        return Icons.arrow_upward;
      case SortType.titleAsc:
      case SortType.titleDesc:
        return Icons.sort_by_alpha;
    }
  }
}
