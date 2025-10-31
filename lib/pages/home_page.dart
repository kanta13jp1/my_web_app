import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import 'auth_page.dart';
import 'note_editor_page.dart';
import 'categories_page.dart';
import 'share_note_dialog.dart';
import '../widgets/advanced_search_dialog.dart';
import '../services/search_history_service.dart';
import 'package:intl/intl.dart'; // 追加

// 並び替えの種類
enum SortType {
  updatedDesc('更新日時（新しい順）'),
  updatedAsc('更新日時（古い順）'),
  createdDesc('作成日時（新しい順）'),
  createdAsc('作成日時（古い順）'),
  titleAsc('タイトル（A→Z）'),
  titleDesc('タイトル（Z→A）');

  const SortType(this.label);
  final String label;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // 日付フィルター用
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDateFilter = '全期間';
  bool _showFavoritesOnly = false; // 追加：お気に入りフィルター

  // 並び替え用
  SortType _sortType = SortType.updatedDesc;

  // カテゴリフィルター用
  String? _selectedCategoryId;

  // リマインダーフィルター（追加）
  String? _reminderFilter; // null, 'overdue', 'upcoming', 'today'

  // 高度な検索用の追加変数
  String? _searchCategoryId;
  DateTime? _searchStartDate;
  DateTime? _searchEndDate;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  String _formatReminderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDay = DateTime(date.year, date.month, date.day);

    String dateStr;
    if (targetDay == today) {
      dateStr = '今日';
    } else if (targetDay == tomorrow) {
      dateStr = '明日';
    } else {
      dateStr = '${date.month}/${date.day}';
    }

    return '$dateStr ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showReminderFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.alarm, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'リマインダーで絞り込み',
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
              // 全て表示
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Colors.blue),
                title: const Text('すべて表示'),
                trailing: _reminderFilter == null
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _reminderFilter = null;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              // 期限切れ
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.alarm_off, color: Colors.red),
                ),
                title: const Text('期限切れ'),
                subtitle: Text(
                  '${_notes.where((n) => n.reminderDate != null && n.isOverdue).length}件',
                  style: const TextStyle(color: Colors.red),
                ),
                trailing: _reminderFilter == 'overdue'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _reminderFilter = 'overdue';
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              // 今日
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.today, color: Colors.orange),
                ),
                title: const Text('今日'),
                subtitle: Text(
                  '${_notes.where((n) {
                    if (n.reminderDate == null) return false;
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final tomorrow = today.add(const Duration(days: 1));
                    return n.reminderDate!.isAfter(today) &&
                        n.reminderDate!.isBefore(tomorrow);
                  }).length}件',
                  style: TextStyle(color: Colors.orange[800]),
                ),
                trailing: _reminderFilter == 'today'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _reminderFilter = 'today';
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              // 24時間以内
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_alarm, color: Colors.amber),
                ),
                title: const Text('24時間以内'),
                subtitle: Text(
                  '${_notes.where((n) => n.reminderDate != null && n.isDueSoon).length}件',
                  style: TextStyle(color: Colors.amber[800]),
                ),
                trailing: _reminderFilter == 'upcoming'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _reminderFilter = 'upcoming';
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _quickSetReminder(Note note) async {
    final now = DateTime.now();

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'クイックリマインダー',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: const Text('1時間後'),
                onTap: () async {
                  final reminderDate = now.add(const Duration(hours: 1));
                  Navigator.pop(context); // ← 先にpop
                  await _updateReminder(note, reminderDate); // ← その後update
                },
              ),
              ListTile(
                leading: const Icon(Icons.today, color: Colors.orange),
                title: const Text('今日の18:00'),
                onTap: () async {
                  final reminderDate =
                      DateTime(now.year, now.month, now.day, 18, 0);
                  Navigator.pop(context); // ← 先にpop
                  await _updateReminder(note, reminderDate); // ← その後update
                },
              ),
              ListTile(
                leading: const Icon(Icons.event, color: Colors.green),
                title: const Text('明日の9:00'),
                onTap: () async {
                  final tomorrow = now.add(const Duration(days: 1));
                  final reminderDate = DateTime(
                      tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
                  Navigator.pop(context); // ← 先にpop
                  await _updateReminder(note, reminderDate); // ← その後update
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.purple),
                title: const Text('カスタム設定'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditorPage(note: note),
                    ),
                  ).then((_) => _loadNotes());
                },
              ),
              if (note.reminderDate != null)
                ListTile(
                  leading: const Icon(Icons.alarm_off, color: Colors.red),
                  title: const Text('リマインダーを削除'),
                  onTap: () async {
                    Navigator.pop(context); // ← 先にpop
                    await _updateReminder(note, null); // ← その後update
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateReminder(Note note, DateTime? reminderDate) async {
    try {
      await supabase.from('notes').update({
        'reminder_date': reminderDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', note.id);

      if (!mounted) {
        return;
      }

      _loadNotes();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reminderDate != null ? 'リマインダーを設定しました' : 'リマインダーを削除しました',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    try {
      await supabase.from('notes').update({
        'is_favorite': !note.isFavorite,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', note.id);

      if (!mounted) return; // ← setState前にmountedをチェック

      setState(() {
        final index = _notes.indexWhere((n) => n.id == note.id);
        if (index != -1) {
          _notes[index] = Note(
            id: note.id,
            userId: note.userId,
            title: note.title,
            content: note.content,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
            categoryId: note.categoryId,
            isFavorite: !note.isFavorite,
          );
        }
        _applyFilters();
      });

      if (!context.mounted) return; // ← context使用前にチェック

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.isFavorite ? 'お気に入りから削除しました' : 'お気に入りに追加しました',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!context.mounted) return; // ← context使用前にチェック

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase
          .from('categories')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('name', ascending: true);

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
      });
    } catch (error) {
      // カテゴリがなくても動作可能
    }
  }

  void _applyFilters() {
    setState(() {
      List<Note> filtered = List.from(_notes);

      // 検索キーワードでフィルター
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        filtered = filtered.where((note) {
          final titleLower = note.title.toLowerCase();
          final contentLower = note.content.toLowerCase();
          return titleLower.contains(query) || contentLower.contains(query);
        }).toList();
      }

      // 高度な検索：カテゴリフィルター（検索ダイアログから）
      if (_searchCategoryId != null) {
        filtered = filtered
            .where((note) => note.categoryId == _searchCategoryId)
            .toList();
      }
      // 通常のカテゴリフィルター（メニューから）
      else if (_selectedCategoryId != null) {
        if (_selectedCategoryId == 'uncategorized') {
          filtered = filtered.where((note) => note.categoryId == null).toList();
        } else {
          filtered = filtered
              .where((note) => note.categoryId == _selectedCategoryId)
              .toList();
        }
      }

      // 高度な検索：日付範囲フィルター（検索ダイアログから）
      if (_searchStartDate != null || _searchEndDate != null) {
        filtered = filtered.where((note) {
          if (_searchStartDate != null &&
              note.createdAt.isBefore(_searchStartDate!)) {
            return false;
          }
          if (_searchEndDate != null) {
            final endOfDay = DateTime(
              _searchEndDate!.year,
              _searchEndDate!.month,
              _searchEndDate!.day,
              23,
              59,
              59,
            );
            if (note.createdAt.isAfter(endOfDay)) {
              return false;
            }
          }
          return true;
        }).toList();
      }
      // 通常の日付フィルター（メニューから）
      else if (_startDate != null || _endDate != null) {
        filtered = filtered.where((note) {
          if (_startDate != null && note.updatedAt.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null) {
            final endOfDay = DateTime(
              _endDate!.year,
              _endDate!.month,
              _endDate!.day,
              23,
              59,
              59,
            );
            if (note.updatedAt.isAfter(endOfDay)) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      // お気に入りフィルター
      if (_showFavoritesOnly) {
        filtered = filtered.where((note) => note.isFavorite).toList();
      }

      // リマインダーフィルター
      if (_reminderFilter != null) {
        final now = DateTime.now();
        filtered = filtered.where((note) {
          if (note.reminderDate == null) {
            return false;
          }

          switch (_reminderFilter) {
            case 'overdue':
              return note.reminderDate!.isBefore(now);
            case 'today':
              final today = DateTime(now.year, now.month, now.day);
              final tomorrow = today.add(const Duration(days: 1));
              return note.reminderDate!.isAfter(today) &&
                  note.reminderDate!.isBefore(tomorrow);
            case 'upcoming':
              final tomorrow = now.add(const Duration(days: 1));
              return note.reminderDate!.isAfter(now) &&
                  note.reminderDate!.isBefore(tomorrow);
            default:
              return true;
          }
        }).toList();
      }

      // 並び替え
      _sortNotes(filtered);

      _filteredNotes = filtered;
    });
  }

  void _sortNotes(List<Note> notes) {
    switch (_sortType) {
      case SortType.updatedDesc:
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortType.updatedAsc:
        notes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case SortType.createdDesc:
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortType.createdAsc:
        notes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortType.titleAsc:
        notes.sort((a, b) {
          final aTitle = a.title.isEmpty ? '' : a.title.toLowerCase();
          final bTitle = b.title.isEmpty ? '' : b.title.toLowerCase();
          if (aTitle.isEmpty && bTitle.isEmpty) return 0;
          if (aTitle.isEmpty) return 1;
          if (bTitle.isEmpty) return -1;
          return aTitle.compareTo(bTitle);
        });
        break;
      case SortType.titleDesc:
        notes.sort((a, b) {
          final aTitle = a.title.isEmpty ? '' : a.title.toLowerCase();
          final bTitle = b.title.isEmpty ? '' : b.title.toLowerCase();
          if (aTitle.isEmpty && bTitle.isEmpty) return 0;
          if (aTitle.isEmpty) return 1;
          if (bTitle.isEmpty) return -1;
          return bTitle.compareTo(aTitle);
        });
        break;
    }
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id);

      setState(() {
        _notes = (response as List).map((note) => Note.fromJson(note)).toList();
        _applyFilters();
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await supabase.from('notes').delete().eq('id', noteId);
      _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモを削除しました')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _applyFilters();
      }
    });
  }

  void _showCategoryFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              // 全て表示
              ListTile(
                leading: const Icon(Icons.all_inclusive, color: Colors.blue),
                title: const Text('すべて表示'),
                trailing: _selectedCategoryId == null
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _applyFilters();
                  });
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
                trailing: _selectedCategoryId == 'uncategorized'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategoryId = 'uncategorized';
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              // カテゴリリスト
              if (_categories.isEmpty)
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
                          ).then((_) {
                            _loadCategories();
                            _loadNotes();
                          });
                        },
                      ),
                    ],
                  ),
                )
              else
                ...(_categories.map((category) {
                  final color = Color(
                    int.parse(category.color.substring(1), radix: 16) +
                        0xFF000000,
                  );
                  final isSelected = _selectedCategoryId == category.id;

                  // このカテゴリのメモ数を計算
                  final noteCount = _notes
                      .where((note) => note.categoryId == category.id)
                      .length;

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
                      setState(() {
                        _selectedCategoryId = category.id;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList()),
            ],
          ),
        );
      },
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    final isSelected = _sortType == sortType;
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
                        setState(() {
                          _sortType = sortType;
                          _applyFilters();
                        });
                        setSheetState(() {});
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
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

  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('日付で絞り込み'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'プリセット',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('今日', setDialogState),
                      _buildPresetChip('昨日', setDialogState),
                      _buildPresetChip('今週', setDialogState),
                      _buildPresetChip('先週', setDialogState),
                      _buildPresetChip('今月', setDialogState),
                      _buildPresetChip('先月', setDialogState),
                      _buildPresetChip('全期間', setDialogState),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'カスタム範囲',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('開始日'),
                    subtitle: Text(
                      _startDate != null
                          ? _formatDateFull(_startDate!)
                          : '指定なし',
                    ),
                    trailing: _startDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setDialogState(() {
                                _startDate = null;
                                _selectedDateFilter = 'カスタム';
                              });
                            },
                          )
                        : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() {
                          _startDate = date;
                          _selectedDateFilter = 'カスタム';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('終了日'),
                    subtitle: Text(
                      _endDate != null ? _formatDateFull(_endDate!) : '指定なし',
                    ),
                    trailing: _endDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setDialogState(() {
                                _endDate = null;
                                _selectedDateFilter = 'カスタム';
                              });
                            },
                          )
                        : null,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setDialogState(() {
                          _endDate = date;
                          _selectedDateFilter = 'カスタム';
                        });
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
                _selectedDateFilter = '全期間';
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('リセット'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('適用'),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, StateSetter setDialogState) {
    final isSelected = _selectedDateFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setDialogState(() {
          _selectedDateFilter = label;
          _applyDatePreset(label);
        });
      },
    );
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case '今日':
        _startDate = today;
        _endDate = today;
        break;
      case '昨日':
        final yesterday = today.subtract(const Duration(days: 1));
        _startDate = yesterday;
        _endDate = yesterday;
        break;
      case '今週':
        final weekday = now.weekday;
        final firstDayOfWeek = today.subtract(Duration(days: weekday - 1));
        _startDate = firstDayOfWeek;
        _endDate = today;
        break;
      case '先週':
        final weekday = now.weekday;
        final lastWeekEnd = today.subtract(Duration(days: weekday));
        final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
        _startDate = lastWeekStart;
        _endDate = lastWeekEnd;
        break;
      case '今月':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = today;
        break;
      case '先月':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        _startDate = lastMonth;
        _endDate = lastMonthEnd;
        break;
      case '全期間':
        _startDate = null;
        _endDate = null;
        break;
    }
  }

  Category? _getCategoryById(String? categoryId) {
    if (categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDateFilter = _startDate != null || _endDate != null;
    final hasCategoryFilter = _selectedCategoryId != null;
    final hasAnyFilter = _searchController.text.isNotEmpty ||
        hasDateFilter ||
        hasCategoryFilter ||
        _showFavoritesOnly ||
        _reminderFilter != null; // 追加

    // リマインダー統計を計算
    final overdueCount =
        _notes.where((n) => n.reminderDate != null && n.isOverdue).length;
    final dueSoonCount =
        _notes.where((n) => n.reminderDate != null && n.isDueSoon).length;
    final todayCount = _notes.where((n) {
      if (n.reminderDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      return n.reminderDate!.isAfter(today) &&
          n.reminderDate!.isBefore(tomorrow);
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'メモを検索...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                onSubmitted: (value) {
                  // ← 追加
                  if (value.isNotEmpty) {
                    SearchHistoryService.saveSearch(value);
                  }
                },
              )
            : const Text('マイメモ'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
              tooltip: 'クリア',
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? '検索を閉じる' : '検索',
          ),
          // 詳細検索ボタン（追加）
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _hasActiveAdvancedFilters() ? Colors.purple : null,
            ),
            tooltip: '詳細検索',
            onPressed: _showAdvancedSearch,
          ),
          // リマインダーフィルターボタン（追加）
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _reminderFilter != null ? Icons.alarm_on : Icons.alarm,
                  color: _reminderFilter != null ? Colors.orange : null,
                ),
                onPressed: _showReminderFilterDialog,
                tooltip: 'リマインダーで絞り込み',
              ),
              if (_reminderFilter != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // お気に入りフィルターボタン
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _showFavoritesOnly ? Icons.star : Icons.star_border,
                  color: _showFavoritesOnly ? Colors.amber : null,
                ),
                onPressed: () {
                  setState(() {
                    _showFavoritesOnly = !_showFavoritesOnly;
                    _applyFilters();
                  });
                },
                tooltip: _showFavoritesOnly ? 'すべて表示' : 'お気に入りのみ表示',
              ),
              if (_showFavoritesOnly)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // カテゴリフィルターボタン
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.category),
                onPressed: _showCategoryFilterDialog,
                tooltip: 'カテゴリで絞り込み',
              ),
              if (hasCategoryFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // 並び替えボタン
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
            tooltip: '並び替え',
          ),
          // 日付フィルターボタン
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showDateFilterDialog,
                tooltip: '日付で絞り込み',
              ),
              if (hasDateFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCategories();
              _loadNotes();
            },
            tooltip: '更新',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'categories') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                ).then((_) {
                  _loadCategories();
                  _loadNotes();
                });
              } else if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'categories',
                child: Row(
                  children: [
                    Icon(Icons.category, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('カテゴリ管理'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ログアウト'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // リマインダー統計バナー（追加）
                if (overdueCount > 0 || dueSoonCount > 0 || todayCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: overdueCount > 0
                            ? [Colors.red.shade50, Colors.red.shade100]
                            : [Colors.orange.shade50, Colors.orange.shade100],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: overdueCount > 0 ? Colors.red : Colors.orange,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              overdueCount > 0
                                  ? Icons.warning
                                  : Icons.info_outline,
                              color:
                                  overdueCount > 0 ? Colors.red : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                overdueCount > 0
                                    ? 'リマインダー通知があります'
                                    : '期限が近いメモがあります',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: overdueCount > 0
                                      ? Colors.red
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _reminderFilter = null;
                                  _applyFilters();
                                });
                              },
                              child: const Text('すべて表示'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (overdueCount > 0)
                              _buildReminderStatChip(
                                icon: Icons.alarm_off,
                                label: '期限切れ',
                                count: overdueCount,
                                color: Colors.red,
                                onTap: () {
                                  setState(() {
                                    _reminderFilter = 'overdue';
                                    _applyFilters();
                                  });
                                },
                              ),
                            if (todayCount > 0)
                              _buildReminderStatChip(
                                icon: Icons.today,
                                label: '今日',
                                count: todayCount,
                                color: Colors.orange,
                                onTap: () {
                                  setState(() {
                                    _reminderFilter = 'today';
                                    _applyFilters();
                                  });
                                },
                              ),
                            if (dueSoonCount > 0)
                              _buildReminderStatChip(
                                icon: Icons.access_alarm,
                                label: '24時間以内',
                                count: dueSoonCount,
                                color: Colors.amber,
                                onTap: () {
                                  setState(() {
                                    _reminderFilter = 'upcoming';
                                    _applyFilters();
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // フィルター情報表示
                if (hasAnyFilter ||
                    _sortType != SortType.updatedDesc ||
                    _showFavoritesOnly ||
                    _reminderFilter != null ||
                    _hasActiveAdvancedFilters())
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.withValues(alpha: 0.1),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.search, size: 18),
                            label: Text('検索: "${_searchController.text}"'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              _searchController.clear();
                            },
                          ),
                        // 高度な検索カテゴリフィルター（追加）
                        if (_searchCategoryId != null)
                          Builder(
                            builder: (context) {
                              final category =
                                  _getCategoryById(_searchCategoryId);
                              if (category == null) {
                                return const SizedBox.shrink();
                              }
                              final color = Color(
                                int.parse(category.color.substring(1),
                                        radix: 16) +
                                    0xFF000000,
                              );
                              return Chip(
                                avatar: Text(category.icon,
                                    style: const TextStyle(fontSize: 16)),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(category.name),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.tune, size: 14),
                                  ],
                                ),
                                backgroundColor: color.withValues(alpha: 0.2),
                                side: BorderSide(color: color, width: 2),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    _searchCategoryId = null;
                                    _applyFilters();
                                  });
                                },
                              );
                            },
                          ),
                        // 高度な検索日付フィルター（追加）
                        if (_searchStartDate != null || _searchEndDate != null)
                          Chip(
                            avatar: const Icon(Icons.tune,
                                size: 18, color: Colors.purple),
                            label: Text(_getAdvancedDateFilterLabel()),
                            backgroundColor:
                                Colors.purple.withValues(alpha: 0.1),
                            side: const BorderSide(
                                color: Colors.purple, width: 2),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _searchStartDate = null;
                                _searchEndDate = null;
                                _applyFilters();
                              });
                            },
                          ),
                        // リマインダーフィルターチップ
                        if (_reminderFilter != null)
                          Chip(
                            avatar: Icon(
                              _reminderFilter == 'overdue'
                                  ? Icons.alarm_off
                                  : _reminderFilter == 'today'
                                      ? Icons.today
                                      : Icons.access_alarm,
                              size: 18,
                              color: _reminderFilter == 'overdue'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                            label: Text(
                              _reminderFilter == 'overdue'
                                  ? '期限切れ'
                                  : _reminderFilter == 'today'
                                      ? '今日'
                                      : '24時間以内',
                            ),
                            backgroundColor: (_reminderFilter == 'overdue'
                                    ? Colors.red
                                    : Colors.orange)
                                .withValues(alpha: 0.1),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _reminderFilter = null;
                                _applyFilters();
                              });
                            },
                          ),
                        if (_showFavoritesOnly)
                          Chip(
                            avatar: const Icon(Icons.star,
                                size: 18, color: Colors.amber),
                            label: const Text('お気に入りのみ'),
                            backgroundColor:
                                Colors.amber.withValues(alpha: 0.1),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _showFavoritesOnly = false;
                                _applyFilters();
                              });
                            },
                          ),
                        if (hasCategoryFilter)
                          Builder(
                            builder: (context) {
                              if (_selectedCategoryId == 'uncategorized') {
                                return Chip(
                                  avatar: const Icon(Icons.inbox, size: 18),
                                  label: const Text('未分類'),
                                  backgroundColor:
                                      Colors.grey.withValues(alpha: 0.1),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedCategoryId = null;
                                      _applyFilters();
                                    });
                                  },
                                );
                              }
                              final category =
                                  _getCategoryById(_selectedCategoryId);
                              if (category == null) {
                                return const SizedBox.shrink();
                              }
                              final color = Color(
                                int.parse(category.color.substring(1),
                                        radix: 16) +
                                    0xFF000000,
                              );
                              return Chip(
                                avatar: Text(category.icon,
                                    style: const TextStyle(fontSize: 16)),
                                label: Text(category.name),
                                backgroundColor: color.withValues(alpha: 0.1),
                                side: BorderSide(color: color, width: 1),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    _selectedCategoryId = null;
                                    _applyFilters();
                                  });
                                },
                              );
                            },
                          ),
                        if (hasDateFilter)
                          Chip(
                            avatar: const Icon(Icons.calendar_today, size: 18),
                            label: Text(_getDateFilterLabel()),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _selectedDateFilter = '全期間';
                                _applyFilters();
                              });
                            },
                          ),
                        if (_sortType != SortType.updatedDesc)
                          Chip(
                            avatar: Icon(_getSortIcon(_sortType), size: 18),
                            label: Text(_sortType.label),
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.1),
                          ),
// 件数表示を更新
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_filteredNotes.length}件',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_showFavoritesOnly &&
                                _reminderFilter == null) ...[
                              Text(
                                ' / ',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              Text(
                                ' ${_notes.where((n) => n.isFavorite).length}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_notes
                                  .where((n) => n.reminderDate != null)
                                  .isNotEmpty) ...[
                                Text(
                                  ' / ',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const Icon(Icons.alarm,
                                    color: Colors.orange, size: 16),
                                Text(
                                  ' ${_notes.where((n) => n.reminderDate != null).length}',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                // メモ一覧
                Expanded(
                  child: _filteredNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasAnyFilter || _showFavoritesOnly
                                    ? Icons.search_off
                                    : Icons.note_add_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                hasAnyFilter || _showFavoritesOnly
                                    ? '該当するメモが見つかりません'
                                    : 'メモがありません',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hasAnyFilter || _showFavoritesOnly
                                    ? 'フィルター条件を変更してみてください'
                                    : '右下の + ボタンから新しいメモを作成',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              // リマインダーフィルター時の特別メッセージ
                              if (_reminderFilter != null &&
                                  _notes.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _reminderFilter == 'overdue'
                                      ? '期限切れのメモはありません'
                                      : _reminderFilter == 'today'
                                          ? '今日のリマインダーはありません'
                                          : '24時間以内のリマインダーはありません',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.alarm_add),
                                  label: const Text('メモにリマインダーを設定'),
                                  onPressed: () {
                                    setState(() {
                                      _reminderFilter = null;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ],
                              if (_showFavoritesOnly && _notes.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'お気に入りメモがまだありません',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.star_border),
                                  label: const Text('メモにスターをつけてみましょう'),
                                  onPressed: () {
                                    setState(() {
                                      _showFavoritesOnly = false;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadCategories();
                            await _loadNotes();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = _filteredNotes[index];
                              final category =
                                  _getCategoryById(note.categoryId);

                              Color? categoryColor;
                              if (category != null) {
                                categoryColor = Color(
                                  int.parse(category.color.substring(1),
                                          radix: 16) +
                                      0xFF000000,
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                // 期限切れの場合は赤枠（追加）
                                shape: note.reminderDate != null &&
                                        note.isOverdue
                                    ? RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        side: const BorderSide(
                                            color: Colors.red, width: 2),
                                      )
                                    : null,
                                child: ListTile(
                                  leading: category != null
                                      ? Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: categoryColor!
                                                .withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: categoryColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              category.icon,
                                              style:
                                                  const TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        )
                                      : note.isFavorite // お気に入りの場合はスターアイコン
                                          ? const Icon(Icons.star,
                                              color: Colors.amber, size: 32)
                                          : null,
                                  title: Row(
                                    children: [
                                      // リマインダーアイコン（追加）
                                      if (note.reminderDate != null) ...[
                                        Icon(
                                          note.isOverdue
                                              ? Icons.alarm_off
                                              : note.isDueSoon
                                                  ? Icons.alarm_on
                                                  : Icons.alarm,
                                          color: note.isOverdue
                                              ? Colors.red
                                              : note.isDueSoon
                                                  ? Colors.orange
                                                  : Colors.grey,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      // お気に入りマーク（カテゴリがある場合も表示）
                                      if (note.isFavorite &&
                                          category != null) ...[
                                        const Icon(Icons.star,
                                            color: Colors.amber, size: 18),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: _buildHighlightedText(
                                          note.title.isEmpty
                                              ? '(タイトルなし)'
                                              : note.title,
                                          _searchController.text,
                                          isTitle: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (note.content.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildHighlightedText(
                                          note.content,
                                          _searchController.text,
                                          maxLines: 2,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // リマインダー日時表示（追加）
                                          if (note.reminderDate != null) ...[
                                            Icon(
                                              Icons.alarm,
                                              size: 12,
                                              color: note.isOverdue
                                                  ? Colors.red
                                                  : note.isDueSoon
                                                      ? Colors.orange
                                                      : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatReminderDate(
                                                  note.reminderDate!),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: note.isOverdue
                                                    ? Colors.red
                                                    : note.isDueSoon
                                                        ? Colors.orange
                                                        : Colors.grey[600],
                                                fontWeight: note.isOverdue ||
                                                        note.isDueSoon
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '•',
                                              style: TextStyle(
                                                  color: Colors.grey[600]),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (category != null) ...[
                                            Text(
                                              category.icon,
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              category.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: categoryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '•',
                                              style: TextStyle(
                                                  color: Colors.grey[600]),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            '更新: ${_formatDate(note.updatedAt)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 共有ボタン（追加）
                                      IconButton(
                                        icon: const Icon(Icons.share,
                                            color: Colors.blue),
                                        onPressed: () => _showShareDialog(note),
                                        tooltip: 'メモを共有',
                                      ),
                                      // リマインダークイック設定ボタン
                                      if (note.reminderDate == null)
                                        IconButton(
                                          icon: const Icon(Icons.alarm_add,
                                              color: Colors.grey),
                                          onPressed: () =>
                                              _quickSetReminder(note),
                                          tooltip: 'リマインダーを設定',
                                        ),
                                      // お気に入りトグルボタン
                                      IconButton(
                                        icon: Icon(
                                          note.isFavorite
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: note.isFavorite
                                              ? Colors.amber
                                              : Colors.grey,
                                        ),
                                        onPressed: () => _toggleFavorite(note),
                                        tooltip: note.isFavorite
                                            ? 'お気に入りから削除'
                                            : 'お気に入りに追加',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _showDeleteDialog(note),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NoteEditorPage(note: note),
                                      ),
                                    );
                                    _loadNotes();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteEditorPage()),
          );
          _loadNotes();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

// リマインダー統計チップを作成するヘルパーメソッド
  Widget _buildReminderStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateFilterLabel() {
    if (_selectedDateFilter == 'カスタム' || _selectedDateFilter == '全期間') {
      if (_startDate != null && _endDate != null) {
        return '${_formatDateShort(_startDate!)} 〜 ${_formatDateShort(_endDate!)}';
      } else if (_startDate != null) {
        return '${_formatDateShort(_startDate!)} 以降';
      } else if (_endDate != null) {
        return '${_formatDateShort(_endDate!)} まで';
      }
    }
    return _selectedDateFilter;
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _formatDateFull(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  Widget _buildHighlightedText(
    String text,
    String query, {
    bool isTitle = false,
    int? maxLines,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Colors.black87,
          fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
          fontSize: isTitle ? 16 : 14,
        ),
        children: spans,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを削除'),
        content: const Text('このメモを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(note.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => ShareNoteDialog(note: note),
    );
  }

  // 高度な検索フィルターがアクティブか確認
  bool _hasActiveAdvancedFilters() {
    return _searchCategoryId != null ||
        _searchStartDate != null ||
        _searchEndDate != null;
  }

// 詳細検索ダイアログを表示
  Future<void> _showAdvancedSearch() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AdvancedSearchDialog(
        categories: _categories,
        initialQuery: _searchController.text,
        initialCategoryId: _searchCategoryId,
        initialStartDate: _searchStartDate,
        initialEndDate: _searchEndDate,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final query = result['query'] ?? '';
        _searchController.text = query;
        _searchCategoryId = result['categoryId'];
        _searchStartDate = result['startDate'];
        _searchEndDate = result['endDate'];
      });
      _applyFilters();
    }
  }

  // 高度な検索の日付範囲ラベル
  String _getAdvancedDateFilterLabel() {
    if (_searchStartDate != null && _searchEndDate != null) {
      return '${DateFormat('MM/dd').format(_searchStartDate!)} 〜 ${DateFormat('MM/dd').format(_searchEndDate!)}';
    } else if (_searchStartDate != null) {
      return '${DateFormat('MM/dd').format(_searchStartDate!)} 以降';
    } else if (_searchEndDate != null) {
      return '${DateFormat('MM/dd').format(_searchEndDate!)} まで';
    }
    return '日付';
  }
}
