import 'package:flutter/material.dart';
import '../main.dart';
import '../models/category.dart';
import '../services/gamification_service.dart'; // ゲーミフィケーション追加
import '../widgets/achievement_notification.dart'; // 実績通知追加

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Category> _categories = [];
  bool _isLoading = true;

  // ゲーミフィケーション用
  late final GamificationService _gamificationService;

  final List<String> _colorOptions = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#CDDC39', // Lime
    '#FFEB3B', // Yellow
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#9E9E9E', // Grey
  ];

  final List<String> _iconOptions = [
    '📁',
    '📂',
    '📄',
    '📝',
    '📋',
    '📌',
    '📍',
    '🏷️',
    '💼',
    '🎯',
    '⭐',
    '❤️',
    '💡',
    '🎨',
    '🎭',
    '🎪',
    '🏠',
    '🏢',
    '🏫',
    '🏥',
    '🚗',
    '✈️',
    '🍔',
    '☕',
    '🎵',
    '🎮',
    '📚',
    '💻',
    '📱',
    '⚡',
    '🔥',
    '🌟',
  ];

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $error')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await supabase.from('categories').delete().eq('id', categoryId);
      _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('カテゴリを削除しました')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $error')));
      }
    }
  }

  void _showCategoryDialog({Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.color ?? _colorOptions[5];
    String selectedIcon = category?.icon ?? '📁';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(category == null ? 'カテゴリを作成' : 'カテゴリを編集'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カテゴリ名
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ名',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 24),

                  // アイコン選択（ドロップダウン）
                  const Text(
                    'アイコン',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedIcon,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _iconOptions.map((icon) {
                        return DropdownMenuItem(
                          value: icon,
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedIcon = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // カラー選択（ドロップダウン）
                  const Text(
                    'カラー',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedColor,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: _colorOptions.map((color) {
                        final colorValue = Color(
                          int.parse(color.substring(1), radix: 16) + 0xFF000000,
                        );
                        return DropdownMenuItem(
                          value: color,
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: colorValue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey[400]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                {
                                      '#F44336': '赤',
                                      '#E91E63': 'ピンク',
                                      '#9C27B0': '紫',
                                      '#673AB7': '深紫',
                                      '#3F51B5': 'インディゴ',
                                      '#2196F3': '青',
                                      '#03A9F4': '水色',
                                      '#00BCD4': 'シアン',
                                      '#009688': 'ティール',
                                      '#4CAF50': '緑',
                                      '#8BC34A': '黄緑',
                                      '#CDDC39': 'ライム',
                                      '#FFEB3B': '黄',
                                      '#FFC107': 'アンバー',
                                      '#FF9800': 'オレンジ',
                                      '#FF5722': '深オレンジ',
                                      '#795548': '茶',
                                      '#9E9E9E': 'グレー',
                                    }[color] ??
                                    color,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedColor = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // プレビュー
                  const Text(
                    'プレビュー',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(selectedColor.substring(1), radix: 16) +
                                  0xFF000000,
                            ).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(
                                int.parse(
                                      selectedColor.substring(1),
                                      radix: 16,
                                    ) +
                                    0xFF000000,
                              ),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              selectedIcon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            nameController.text.isEmpty
                                ? 'カテゴリ名を入力してください'
                                : nameController.text,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: nameController.text.isEmpty
                                  ? Colors.grey
                                  : Color(
                                      int.parse(
                                            selectedColor.substring(1),
                                            radix: 16,
                                          ) +
                                          0xFF000000,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('カテゴリ名を入力してください')),
                    );
                    return;
                  }

                  try {
                    final userId = supabase.auth.currentUser!.id;
                    if (category == null) {
                      await supabase.from('categories').insert({
                        'user_id': userId,
                        'name': nameController.text.trim(),
                        'color': selectedColor,
                        'icon': selectedIcon,
                      });

                      // ゲーミフィケーション: カテゴリ作成イベント
                      final achievements = await _gamificationService
                          .onCategoryCreated(userId);
                      if (context.mounted) {
                        for (final achievement in achievements) {
                          AchievementNotification.show(
                            context: context,
                            achievement: achievement,
                          );
                        }
                      }
                    } else {
                      await supabase
                          .from('categories')
                          .update({
                            'name': nameController.text.trim(),
                            'color': selectedColor,
                            'icon': selectedIcon,
                          })
                          .eq('id', category.id);
                    }

                    if (!context.mounted) return; // ← mounted チェックを先に

                    Navigator.pop(context);
                    _loadCategories();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          category == null ? 'カテゴリを作成しました' : 'カテゴリを更新しました',
                        ),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return; // ← mounted チェックを先に

                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('エラー: $error')));
                  }
                },
                child: Text(category == null ? '作成' : '更新'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ管理')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'カテゴリがありません',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '右下の + ボタンから作成',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final color = Color(
                  int.parse(category.color.substring(1), radix: 16) +
                      0xFF000000,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          category.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _showCategoryDialog(category: category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('カテゴリを削除'),
                                content: const Text(
                                  'このカテゴリを削除しますか？\n'
                                  '※ メモのカテゴリは「未分類」になります',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteCategory(category.id);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('削除'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
