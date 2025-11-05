import 'package:flutter/material.dart';
import '../../models/category.dart';

/// カテゴリ選択チップウィジェット
class CategoryChip extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = categories.cast<Category?>().firstWhere(
          (c) => c?.id == selectedCategoryId,
          orElse: () => null,
        );

    if (category == null) {
      return TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_circle_outline, size: 18),
        label: const Text('カテゴリを設定'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[700],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    final color = Color(
      int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
