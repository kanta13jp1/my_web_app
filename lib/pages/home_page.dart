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
import 'package:intl/intl.dart';
import 'archive_page.dart';
import '../services/auto_archive_service.dart';
import 'settings_page.dart';
import '../widgets/share_note_card_dialog.dart';
import 'stats_page.dart';
import 'leaderboard_page.dart';
import '../services/gamification_service.dart';
import '../models/user_stats.dart';
import '../widgets/level_display_widget.dart';

// クラスの先頭に追加
final Map<int, int> _attachmentCountCache = {};

Future<int> _getAttachmentCount(int noteId) async {
  // キャッシュをチェック
  if (_attachmentCountCache.containsKey(noteId)) {
    return _attachmentCountCache[noteId]!;
  }

  try {
    final response =
        await supabase.from('attachments').select('id').eq('note_id', noteId);
    final count = (response as List).length;

    // キャッシュに保存
    _attachmentCountCache[noteId] = count;

    return count;
  } catch (e) {
    return 0;
  }
}

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

  // モバイル判定用（追加）
  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  // ゲーミフィケーション用
  late final GamificationService _gamificationService;
  UserStats? _userStats;

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService(supabase);
    _loadCategories();
    _loadNotes();
    _loadUserStats();
    _searchController.addListener(_onSearchChanged);

    // 自動アーカイブを実行（追加）
    _runAutoArchive();
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      var stats = await _gamificationService.getUserStats(userId);
      if (stats == null) {
        stats = await _gamificationService.initializeUserStats(userId);
      }

      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showShareOptionsDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('共有方法を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('メモカードとして共有'),
              subtitle: const Text('SNSで映える画像を作成'),
              onTap: () {
                Navigator.pop(context);
                _showNoteCardDialog(note);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.green),
              title: const Text('リンクとして共有'),
              subtitle: const Text('テキストURLで共有'),
              onTap: () {
                Navigator.pop(context);
                _showShareOptionsDialog(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteCardDialog(Note note) {
    final category = _getCategoryById(note.categoryId);
    showDialog(
      context: context,
      builder: (context) => ShareNoteCardDialog(
        note: note,
        category: category,
      ),
    );
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _togglePin(Note note) async {
    try {
      await supabase.from('notes').update({
        'is_pinned': !note.isPinned,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', note.id);

      if (!mounted) return;

      _loadNotes();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.isPinned ? 'ピン留めを解除しました' : 'ピン留めしました',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _runAutoArchive() async {
    final archivedCount = await AutoArchiveService.autoArchiveOverdueNotes();

    if (archivedCount > 0 && mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('期限切れのメモ$archivedCount件を自動アーカイブしました'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '表示',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivePage()),
              ).then((_) => _loadNotes());
            },
          ),
        ),
      );
    }
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
              // ヘッダー部分（固定）
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

              // スクロール可能なコンテンツ部分（修正）
              Flexible(
                // ← 追加
                child: SingleChildScrollView(
                  // ← 追加
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 全て表示
                      ListTile(
                        leading:
                            const Icon(Icons.all_inclusive, color: Colors.blue),
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
                            final today =
                                DateTime(now.year, now.month, now.day);
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
                          child: const Icon(Icons.access_alarm,
                              color: Colors.amber),
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
                ), // ← 追加
              ), // ← 追加
            ],
          ),
        );
      },
    );
  }

  Future<void> _archiveNote(Note note) async {
    try {
      await supabase.from('notes').update({
        'is_archived': true,
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', note.id);

      if (!mounted) return;

      _loadNotes();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('メモをアーカイブしました'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: '元に戻す',
            onPressed: () => _restoreNote(note.id),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  Future<void> _restoreNote(int noteId) async {
    try {
      await supabase.from('notes').update({
        'is_archived': false,
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', noteId);

      if (!mounted) return;

      _loadNotes();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモを復元しました'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $error')),
      );
    }
  }

  void _showArchiveDialog(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモをアーカイブ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '「${note.title.isEmpty ? '(タイトルなし)' : note.title}」をアーカイブしますか？'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'アーカイブから復元できます',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _archiveNote(note);
            },
            child: const Text('アーカイブ'),
          ),
        ],
      ),
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
    // まず通常のソートを適用
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

    // ピン留めメモを最上部に移動（安定ソート）
    notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _attachmentCountCache.clear(); // 追加
    });

    try {
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('is_archived', false); // ← アーカイブされていないメモのみ取得

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

  Future<void> _deleteNote(int noteId) async {
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
            mainAxisSize: MainAxisSize.min, // これを保持
            children: [
              // ヘッダー部分（固定）
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

              // スクロール可能なコンテンツ部分（修正）
              Flexible(
                // ← 追加
                child: SingleChildScrollView(
                  // ← 追加
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 全て表示
                      ListTile(
                        leading:
                            const Icon(Icons.all_inclusive, color: Colors.blue),
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
                ), // ← 追加
              ), // ← 追加
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
          // モバイルでは主要なアイコンのみ表示（修正）
          if (!_isMobile) ...[
            // 詳細検索ボタン
            IconButton(
              icon: Icon(
                Icons.tune,
                color: _hasActiveAdvancedFilters() ? Colors.purple : null,
              ),
              tooltip: '詳細検索',
              onPressed: _showAdvancedSearch,
            ),
            // リマインダーフィルターボタン
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
          ],
          // 更新ボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCategories();
              _loadNotes();
            },
            tooltip: '更新',
          ),
          // メニュー（モバイル時はフィルターも含む）
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'advanced_search') {
                _showAdvancedSearch();
              } else if (value == 'reminder_filter') {
                _showReminderFilterDialog();
              } else if (value == 'favorite_filter') {
                setState(() {
                  _showFavoritesOnly = !_showFavoritesOnly;
                  _applyFilters();
                });
              } else if (value == 'category_filter') {
                _showCategoryFilterDialog();
              } else if (value == 'sort') {
                _showSortDialog();
              } else if (value == 'date_filter') {
                _showDateFilterDialog();
              } else if (value == 'categories') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                ).then((_) {
                  _loadCategories();
                  _loadNotes();
                });
              } else if (value == 'archive') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArchivePage()),
                ).then((_) {
                  _loadNotes();
                });
              } else if (value == 'stats') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsPage()),
                ).then((_) {
                  _loadUserStats();
                });
              } else if (value == 'leaderboard') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                ).then((_) {
                  _loadUserStats();
                });
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              } else if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              // モバイル専用のフィルターメニュー項目
              if (_isMobile) ...[
                const PopupMenuItem(
                  value: 'advanced_search',
                  child: Row(
                    children: [
                      Icon(Icons.tune, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('詳細検索'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reminder_filter',
                  child: Row(
                    children: [
                      Icon(Icons.alarm, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('リマインダー'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'favorite_filter',
                  child: Row(
                    children: [
                      Icon(
                        _showFavoritesOnly ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(_showFavoritesOnly ? 'すべて表示' : 'お気に入り'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'category_filter',
                  child: Row(
                    children: [
                      Icon(Icons.category, color: Colors.green),
                      SizedBox(width: 8),
                      Text('カテゴリ'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sort',
                  child: Row(
                    children: [
                      Icon(Icons.sort, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('並び替え'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'date_filter',
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.red),
                      SizedBox(width: 8),
                      Text('日付'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
              ],
              // 共通メニュー項目
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
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('アーカイブ'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('統計・実績'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'leaderboard',
                child: Row(
                  children: [
                    Icon(Icons.leaderboard, color: Colors.purple),
                    SizedBox(width: 8),
                    Text('リーダーボード'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.green),
                    SizedBox(width: 8),
                    Text('設定'),
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
                // レベル表示（ゲーミフィケーション）
                if (_userStats != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StatsPage()),
                      ).then((_) {
                        _loadUserStats();
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer,
                            Theme.of(context).colorScheme.secondaryContainer,
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'レベル ${_userStats!.currentLevel}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _userStats!.levelTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.stars,
                                      size: 16,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_userStats!.totalPoints} pt',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (_userStats!.currentStreak > 0) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.local_fire_department,
                                        size: 16,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_userStats!.currentStreak}日連続',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color:
                                Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                // リマインダー統計バナー（追加）
                if (overdueCount > 0 || dueSoonCount > 0 || todayCount > 0)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 12 : 16, // モバイルで小さく
                      vertical: _isMobile ? 8 : 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: overdueCount > 0
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? [Colors.red.shade900, Colors.red.shade800]
                                : [Colors.red.shade50, Colors.red.shade100])
                            : (Theme.of(context).brightness == Brightness.dark
                                ? [
                                    Colors.orange.shade900,
                                    Colors.orange.shade800
                                  ]
                                : [
                                    Colors.orange.shade50,
                                    Colors.orange.shade100
                                  ]),
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
                              size: _isMobile ? 18 : 20, // モバイルで小さく
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                overdueCount > 0
                                    ? 'リマインダー通知があります'
                                    : '期限が近いメモがあります',
                                style: TextStyle(
                                  fontSize: _isMobile ? 14 : 16, // モバイルで小さく
                                  fontWeight: FontWeight.bold,
                                  color: overdueCount > 0
                                      ? Colors.red
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                            if (!_isMobile) // モバイルではボタンを非表示
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
                        SizedBox(height: _isMobile ? 6 : 8), // モバイルで小さく
                        Wrap(
                          spacing: _isMobile ? 8 : 12, // モバイルで小さく
                          runSpacing: _isMobile ? 6 : 8,
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
                    padding: EdgeInsets.all(_isMobile ? 8 : 12), // モバイルで小さく
                    color: Colors.blue.withValues(alpha: 0.1),
                    child: Wrap(
                      spacing: _isMobile ? 6 : 8, // モバイルで小さく
                      runSpacing: _isMobile ? 6 : 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // 検索キーワード
                        if (_searchController.text.isNotEmpty)
                          Chip(
                            avatar:
                                const Icon(Icons.search, size: 16), // アイコンを小さく
                            label: Text(
                              '検索: "${_searchController.text}"',
                              style: TextStyle(
                                  fontSize: _isMobile ? 11 : 13), // モバイルで小さく
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              _searchController.clear();
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap, // 追加
                            visualDensity: VisualDensity.compact, // 追加
                          ),

                        // 高度な検索カテゴリフィルター
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
                                avatar: Text(
                                  category.icon,
                                  style:
                                      TextStyle(fontSize: _isMobile ? 14 : 16),
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                          fontSize: _isMobile ? 11 : 13),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.tune, size: _isMobile ? 12 : 14),
                                  ],
                                ),
                                backgroundColor: color.withValues(alpha: 0.2),
                                side: BorderSide(color: color, width: 2),
                                deleteIcon: Icon(Icons.close,
                                    size: _isMobile ? 14 : 16),
                                onDeleted: () {
                                  setState(() {
                                    _searchCategoryId = null;
                                    _applyFilters();
                                  });
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),

                        // 高度な検索日付フィルター
                        if (_searchStartDate != null || _searchEndDate != null)
                          Chip(
                            avatar: const Icon(Icons.tune,
                                size: 16, color: Colors.purple),
                            label: Text(
                              _getAdvancedDateFilterLabel(),
                              style: TextStyle(fontSize: _isMobile ? 11 : 13),
                            ),
                            backgroundColor:
                                Colors.purple.withValues(alpha: 0.1),
                            side: const BorderSide(
                                color: Colors.purple, width: 2),
                            deleteIcon:
                                Icon(Icons.close, size: _isMobile ? 14 : 16),
                            onDeleted: () {
                              setState(() {
                                _searchStartDate = null;
                                _searchEndDate = null;
                                _applyFilters();
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
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
                              size: 16,
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
                              style: TextStyle(fontSize: _isMobile ? 11 : 13),
                            ),
                            backgroundColor: (_reminderFilter == 'overdue'
                                    ? Colors.red
                                    : Colors.orange)
                                .withValues(alpha: 0.1),
                            deleteIcon:
                                Icon(Icons.close, size: _isMobile ? 14 : 16),
                            onDeleted: () {
                              setState(() {
                                _reminderFilter = null;
                                _applyFilters();
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),

                        // お気に入りフィルター
                        if (_showFavoritesOnly)
                          Chip(
                            avatar: const Icon(Icons.star,
                                size: 16, color: Colors.amber),
                            label: Text(
                              'お気に入りのみ',
                              style: TextStyle(fontSize: _isMobile ? 11 : 13),
                            ),
                            backgroundColor:
                                Colors.amber.withValues(alpha: 0.1),
                            deleteIcon:
                                Icon(Icons.close, size: _isMobile ? 14 : 16),
                            onDeleted: () {
                              setState(() {
                                _showFavoritesOnly = false;
                                _applyFilters();
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),

                        // カテゴリフィルター
                        if (hasCategoryFilter)
                          Builder(
                            builder: (context) {
                              if (_selectedCategoryId == 'uncategorized') {
                                return Chip(
                                  avatar: const Icon(Icons.inbox, size: 16),
                                  label: Text(
                                    '未分類',
                                    style: TextStyle(
                                        fontSize: _isMobile ? 11 : 13),
                                  ),
                                  backgroundColor:
                                      Colors.grey.withValues(alpha: 0.1),
                                  deleteIcon: Icon(Icons.close,
                                      size: _isMobile ? 14 : 16),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedCategoryId = null;
                                      _applyFilters();
                                    });
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
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
                                avatar: Text(
                                  category.icon,
                                  style:
                                      TextStyle(fontSize: _isMobile ? 14 : 16),
                                ),
                                label: Text(
                                  category.name,
                                  style:
                                      TextStyle(fontSize: _isMobile ? 11 : 13),
                                ),
                                backgroundColor: color.withValues(alpha: 0.1),
                                side: BorderSide(color: color, width: 1),
                                deleteIcon: Icon(Icons.close,
                                    size: _isMobile ? 14 : 16),
                                onDeleted: () {
                                  setState(() {
                                    _selectedCategoryId = null;
                                    _applyFilters();
                                  });
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),

                        // 日付フィルター
                        if (hasDateFilter)
                          Chip(
                            avatar: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _getDateFilterLabel(),
                              style: TextStyle(fontSize: _isMobile ? 11 : 13),
                            ),
                            deleteIcon:
                                Icon(Icons.close, size: _isMobile ? 14 : 16),
                            onDeleted: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _selectedDateFilter = '全期間';
                                _applyFilters();
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),

                        // ソート表示
                        if (_sortType != SortType.updatedDesc)
                          Chip(
                            avatar: Icon(_getSortIcon(_sortType), size: 16),
                            label: Text(
                              _sortType.label,
                              style: TextStyle(fontSize: _isMobile ? 11 : 13),
                            ),
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.1),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),

                        // 件数表示
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_filteredNotes.length}件',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: _isMobile ? 11 : 13,
                              ),
                            ),
                            if (!_showFavoritesOnly &&
                                _reminderFilter == null) ...[
                              Text(
                                ' / ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: _isMobile ? 11 : 13,
                                ),
                              ),
                              Icon(Icons.push_pin,
                                  color: Colors.amber,
                                  size: _isMobile ? 14 : 16),
                              Text(
                                ' ${_notes.where((n) => n.isPinned).length}',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _isMobile ? 11 : 13,
                                ),
                              ),
                              Text(
                                ' / ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: _isMobile ? 11 : 13,
                                ),
                              ),
                              Icon(Icons.star,
                                  color: Colors.amber,
                                  size: _isMobile ? 14 : 16),
                              Text(
                                ' ${_notes.where((n) => n.isFavorite).length}',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: _isMobile ? 11 : 13,
                                ),
                              ),
                              if (_notes
                                  .where((n) => n.reminderDate != null)
                                  .isNotEmpty) ...[
                                Text(
                                  ' / ',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: _isMobile ? 11 : 13,
                                  ),
                                ),
                                Icon(Icons.alarm,
                                    color: Colors.orange,
                                    size: _isMobile ? 14 : 16),
                                Text(
                                  ' ${_notes.where((n) => n.reminderDate != null).length}',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: _isMobile ? 11 : 13,
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
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[700]
                                    : Colors.grey[400],
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
                                    : '右下の + ボタンから新しいメモを作成\n📌でピン留めして重要なメモを上部に固定',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
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
                                // ピン留めメモの背景色を変更（ダークモード対応）
                                color: note.isPinned
                                    ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.1))
                                    : note.reminderDate != null &&
                                            note.isOverdue
                                        ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : Colors.red
                                                .withValues(alpha: 0.05))
                                        : null,
                                // 期限切れの場合は赤枠、ピン留めの場合は黄色枠
                                shape: note.reminderDate != null &&
                                        note.isOverdue
                                    ? RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                        side: const BorderSide(
                                            color: Colors.red, width: 2),
                                      )
                                    : note.isPinned
                                        ? RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            side: BorderSide(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.amber.shade600
                                                  : Colors.amber.shade700,
                                              width: 2,
                                            ),
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
                                      // ピン留めアイコン（追加）
                                      if (note.isPinned) ...[
                                        Icon(Icons.push_pin,
                                            color: Colors.amber.shade700,
                                            size: 18),
                                        const SizedBox(width: 4),
                                      ],
                                      // リマインダーアイコン
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
                                        SizedBox(height: _isMobile ? 2 : 4),
                                        _buildHighlightedText(
                                          note.content,
                                          _searchController.text,
                                          maxLines: _isMobile ? 1 : 2,
                                        ),
                                      ],
                                      SizedBox(height: _isMobile ? 2 : 4),
                                      // メタ情報を2行に分ける（修正）
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // 1行目：ピン留め、リマインダー、カテゴリ
                                          Row(
                                            children: [
                                              // ピン留めバッジ
                                              if (note.isPinned) ...[
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.amber.shade700,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.push_pin,
                                                          size: 10,
                                                          color: Colors.white),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'ピン留め',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              // リマインダー日時表示
                                              if (note.reminderDate !=
                                                  null) ...[
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
                                                    fontWeight:
                                                        note.isOverdue ||
                                                                note.isDueSoon
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('•',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[600])),
                                                const SizedBox(width: 8),
                                              ],
                                              // カテゴリ表示（Flexibleでラップ）
                                              if (category != null) ...[
                                                Text(category.icon,
                                                    style: const TextStyle(
                                                        fontSize: 12)),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    category.name,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: categoryColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          // 2行目：添付ファイル数と更新日時
                                          SizedBox(height: _isMobile ? 2 : 4),
                                          Row(
                                            children: [
                                              // 添付ファイル数表示
                                              FutureBuilder<int>(
                                                future: _getAttachmentCount(
                                                    note.id),
                                                builder: (context, snapshot) {
                                                  final count =
                                                      snapshot.data ?? 0;
                                                  if (count == 0) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                          Icons.attach_file,
                                                          size: 12,
                                                          color: Colors.blue),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$count',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.blue,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text('•',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[600])),
                                                      const SizedBox(width: 8),
                                                    ],
                                                  );
                                                },
                                              ),
                                              // 更新日時
                                              Flexible(
                                                child: Text(
                                                  '更新: ${_formatDate(note.updatedAt)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: _isMobile
                                      ? PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (value) {
                                            if (value == 'pin') {
                                              _togglePin(note);
                                            } else if (value == 'archive') {
                                              _showArchiveDialog(note);
                                            } else if (value == 'share') {
                                              _showShareOptionsDialog(note);
                                            } else if (value == 'reminder') {
                                              _quickSetReminder(note);
                                            } else if (value == 'favorite') {
                                              _toggleFavorite(note);
                                            } else if (value == 'delete') {
                                              _showDeleteDialog(note);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'pin',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    note.isPinned
                                                        ? Icons.push_pin
                                                        : Icons
                                                            .push_pin_outlined,
                                                    color: note.isPinned
                                                        ? Colors.amber
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(note.isPinned
                                                      ? 'ピン留め解除'
                                                      : 'ピン留め'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'favorite',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    note.isFavorite
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: note.isFavorite
                                                        ? Colors.amber
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(note.isFavorite
                                                      ? 'お気に入り解除'
                                                      : 'お気に入り'),
                                                ],
                                              ),
                                            ),
                                            if (note.reminderDate == null)
                                              const PopupMenuItem(
                                                value: 'reminder',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.alarm_add,
                                                        color: Colors.orange),
                                                    SizedBox(width: 8),
                                                    Text('リマインダー'),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'share',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.share,
                                                      color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('共有'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'archive',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.archive,
                                                      color: Colors.grey),
                                                  SizedBox(width: 8),
                                                  Text('アーカイブ'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuDivider(),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('削除'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // デスクトップ版（既存のコード）
                                            IconButton(
                                              icon: Icon(
                                                note.isPinned
                                                    ? Icons.push_pin
                                                    : Icons.push_pin_outlined,
                                                color: note.isPinned
                                                    ? Colors.amber.shade700
                                                    : Colors.grey,
                                              ),
                                              onPressed: () => _togglePin(note),
                                              tooltip: note.isPinned
                                                  ? 'ピン留めを解除'
                                                  : 'ピン留め',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.archive,
                                                  color: Colors.grey),
                                              onPressed: () =>
                                                  _showArchiveDialog(note),
                                              tooltip: 'アーカイブ',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.share,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  _showShareOptionsDialog(note),
                                              tooltip: 'メモを共有',
                                            ),
                                            if (note.reminderDate == null)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.alarm_add,
                                                    color: Colors.grey),
                                                onPressed: () =>
                                                    _quickSetReminder(note),
                                                tooltip: 'リマインダーを設定',
                                              ),
                                            IconButton(
                                              icon: Icon(
                                                note.isFavorite
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: note.isFavorite
                                                    ? Colors.amber
                                                    : Colors.grey,
                                              ),
                                              onPressed: () =>
                                                  _toggleFavorite(note),
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
        mini: _isMobile, // モバイルでは小さいサイズ
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
          fontSize: _isMobile
              ? (isTitle ? 14 : 12) // モバイルで小さく
              : (isTitle ? 16 : 14),
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
          fontSize: _isMobile
              ? (isTitle ? 14 : 12) // モバイルで小さく
              : (isTitle ? 16 : 14),
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
