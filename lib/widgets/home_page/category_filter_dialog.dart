import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../models/note.dart';
import '../../pages/categories_page.dart';

/// カテゴリフィルターダイアログ
class CategoryFilterDialog extends StatelessWidget {
  final String? selectedCategoryId;
  final List<Category> categories;
  final List<Note> notes;
  final ValueChanged<String?> onCategoryChanged;

  const CategoryFilterDialog({
    super.key,
    required this.selectedCategoryId,
    required this.categories,
    required this.notes,
    required this.onCategoryChanged,
  });

  int _getNoteCountForCategory(String? categoryId) {
    return notes.where((note) => note.categoryId == categoryId).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ヘッダー部分
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.category, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'カテゴリで絞り込み',
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

          // スクロール可能なコンテンツ部分
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 全て表示
                  ListTile(
                    leading:
                        const Icon(Icons.all_inclusive, color: Colors.blue),
                    title: const Text('すべて表示'),
                    trailing: selectedCategoryId == null
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onCategoryChanged(null);
                      Navigator.pop(context);
                    },
                  ),
                  // 未分類
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inbox, color: Colors.grey),
                    ),
                    title: const Text('未分類'),
                    trailing: selectedCategoryId == 'uncategorized'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      onCategoryChanged('uncategorized');
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  // カテゴリリスト
                  if (categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'カテゴリがありません',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('カテゴリを作成'),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CategoriesPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    ...(categories.map((category) {
                      final color = Color(
                        int.parse(category.color.substring(1), radix: 16) +
                            0xFF000000,
                      );
                      final isSelected = selectedCategoryId == category.id;
                      final noteCount = _getNoteCountForCategory(category.id);

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(
                          category.name,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text('$noteCount件のメモ'),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                        onTap: () {
                          onCategoryChanged(category.id);
                          Navigator.pop(context);
                        },
                      );
                    }).toList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
