import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import '../models/category.dart';
import '../models/sort_type.dart';
import 'auth_page.dart';
import 'note_editor_page.dart';
import 'categories_page.dart';
import 'share_note_dialog.dart';
import '../widgets/advanced_search_dialog.dart';
import '../services/search_history_service.dart';
import '../services/attachment_cache_service.dart';
import 'archive_page.dart';
import '../services/auto_archive_service.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'leaderboard_page.dart';
import '../services/gamification_service.dart';
import '../models/user_stats.dart';
import '../widgets/level_display_widget.dart';
import '../utils/date_formatter.dart';
import '../widgets/home_page/sort_dialog.dart';
import '../widgets/home_page/date_filter_dialog.dart';
import '../widgets/home_page/reminder_filter_dialog.dart';
import '../widgets/home_page/category_filter_dialog.dart';
import '../widgets/home_page/reminder_stats_banner.dart';
import '../widgets/home_page/filter_chips_area.dart';
import '../widgets/home_page/note_card_item.dart';
import '../widgets/home_page/note_dialogs.dart' as dialogs;
import '../services/note_operations_service.dart';
import '../services/note_filter_service.dart';
import '../widgets/home_page/home_app_bar.dart';

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
    final category = _getCategoryById(note.categoryId);
    dialogs.showShareOptionsDialog(
      context: context,
      note: note,
      category: category,
      onShareAsCard: () => _showNoteCardDialog(note),
      onShareAsLink: () => _showShareDialog(note),
    );
  }

  void _showNoteCardDialog(Note note) {
    final category = _getCategoryById(note.categoryId);
    dialogs.showNoteCardDialog(
      context: context,
      note: note,
      category: category,
    );
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  Future<void> _togglePin(Note note) async {
    try {
      await NoteOperationsService.togglePin(note);

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

  void _showReminderFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReminderFilterDialog(
        currentFilter: _reminderFilter,
        notes: _notes,
        onFilterChanged: (filter) {
          setState(() {
            _reminderFilter = filter;
            _applyFilters();
          });
        },
      ),
    );
  }

  Future<void> _archiveNote(Note note) async {
    try {
      await NoteOperationsService.archiveNote(note);

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
      await NoteOperationsService.restoreNote(noteId);

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
    dialogs.showArchiveDialog(
      context: context,
      note: note,
      onArchive: () => _archiveNote(note),
    );
  }

  Future<void> _quickSetReminder(Note note) async {
    await dialogs.showQuickReminderDialog(
      context: context,
      note: note,
      onReminderSet: (reminderDate) => _updateReminder(note, reminderDate),
      onLoadNotes: _loadNotes,
    );
  }

  Future<void> _updateReminder(Note note, DateTime? reminderDate) async {
    try {
      await NoteOperationsService.updateReminder(note, reminderDate);

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
      await NoteOperationsService.toggleFavorite(note);

      if (!mounted) return;

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

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.isFavorite ? 'お気に入りから削除しました' : 'お気に入りに追加しました',
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
      final filterService = NoteFilterService(
        searchQuery: _searchController.text,
        searchCategoryId: _searchCategoryId,
        searchStartDate: _searchStartDate,
        searchEndDate: _searchEndDate,
        selectedCategoryId: _selectedCategoryId,
        startDate: _startDate,
        endDate: _endDate,
        showFavoritesOnly: _showFavoritesOnly,
        reminderFilter: _reminderFilter,
      );

      final filtered = filterService.filterNotes(_notes);
      NoteFilterService.sortNotes(filtered, _sortType);
      _filteredNotes = filtered;
    });
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      AttachmentCacheService.clearCache();
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
      await NoteOperationsService.deleteNote(noteId);
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
      builder: (context) => CategoryFilterDialog(
        selectedCategoryId: _selectedCategoryId,
        categories: _categories,
        notes: _notes,
        onCategoryChanged: (categoryId) {
          setState(() {
            _selectedCategoryId = categoryId;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SortDialog(
        currentSortType: _sortType,
        onSortTypeChanged: (sortType) {
          setState(() {
            _sortType = sortType;
            _applyFilters();
          });
        },
      ),
    );
  }

  void _showDateFilterDialog() async {
    final result = await showDialog<DateFilterResult>(
      context: context,
      builder: (context) => DateFilterDialog(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        initialPreset: _selectedDateFilter,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _startDate = result.startDate;
        _endDate = result.endDate;
        _selectedDateFilter = result.selectedPreset;
        _applyFilters();
      });
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

  IconData _getSortIcon(SortType sortType) {
    switch (sortType) {
      case SortType.updatedDesc:
      case SortType.updatedAsc:
        return Icons.update;
      case SortType.createdDesc:
      case SortType.createdAsc:
        return Icons.event;
      case SortType.titleAsc:
      case SortType.titleDesc:
        return Icons.sort_by_alpha;
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
    final reminderStats = NoteFilterService.calculateReminderStats(_notes);
    final overdueCount = reminderStats['overdue'] ?? 0;
    final dueSoonCount = reminderStats['dueSoon'] ?? 0;
    final todayCount = reminderStats['today'] ?? 0;

    return Scaffold(
      appBar: HomeAppBar(
        isSearching: _isSearching,
        searchController: _searchController,
        onToggleSearch: _toggleSearch,
        onShowAdvancedSearch: _showAdvancedSearch,
        onShowReminderFilter: _showReminderFilterDialog,
        onShowCategoryFilter: _showCategoryFilterDialog,
        onShowSortDialog: _showSortDialog,
        onShowDateFilter: _showDateFilterDialog,
        onToggleFavorites: () {
          setState(() {
            _showFavoritesOnly = !_showFavoritesOnly;
            _applyFilters();
          });
        },
        onRefresh: () {
          _loadCategories();
          _loadNotes();
        },
        onSignOut: _signOut,
        onLoadUserStats: _loadUserStats,
        isMobile: _isMobile,
        hasActiveAdvancedFilters: _hasActiveAdvancedFilters(),
        reminderFilter: _reminderFilter,
        showFavoritesOnly: _showFavoritesOnly,
        hasCategoryFilter: hasCategoryFilter,
        hasDateFilter: hasDateFilter,
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
                // リマインダー統計バナー
                ReminderStatsBanner(
                  notes: _notes,
                  overdueCount: overdueCount,
                  dueSoonCount: dueSoonCount,
                  todayCount: todayCount,
                  isMobile: _isMobile,
                  onFilterChanged: (filter) {
                    setState(() {
                      _reminderFilter = filter;
                      _applyFilters();
                    });
                  },
                ),
                // フィルター情報表示
                FilterChipsArea(
                  hasAnyFilter: hasAnyFilter,
                  sortType: _sortType,
                  showFavoritesOnly: _showFavoritesOnly,
                  reminderFilter: _reminderFilter,
                  searchText: _searchController.text,
                  searchCategoryId: _searchCategoryId,
                  searchStartDate: _searchStartDate,
                  searchEndDate: _searchEndDate,
                  selectedCategoryId: _selectedCategoryId,
                  startDate: _startDate,
                  endDate: _endDate,
                  selectedDateFilter: _selectedDateFilter,
                  filteredNotes: _filteredNotes,
                  notes: _notes,
                  categories: _categories,
                  isMobile: _isMobile,
                  onClearSearch: (_) => _searchController.clear(),
                  onClearSearchCategory: (_) {
                    setState(() {
                      _searchCategoryId = null;
                      _applyFilters();
                    });
                  },
                  onClearSearchDates: (_, __) {
                    setState(() {
                      _searchStartDate = null;
                      _searchEndDate = null;
                      _applyFilters();
                    });
                  },
                  onClearReminderFilter: (_) {
                    setState(() {
                      _reminderFilter = null;
                      _applyFilters();
                    });
                  },
                  onClearFavoriteFilter: (value) {
                    setState(() {
                      _showFavoritesOnly = value;
                      _applyFilters();
                    });
                  },
                  onClearCategoryFilter: (_) {
                    setState(() {
                      _selectedCategoryId = null;
                      _applyFilters();
                    });
                  },
                  onClearDateFilter: (_, __, filter) {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _selectedDateFilter = filter;
                      _applyFilters();
                    });
                  },
                  getSortIcon: _getSortIcon,
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
                              final category = _getCategoryById(note.categoryId);

                              return NoteCardItem(
                                note: note,
                                category: category,
                                searchQuery: _searchController.text,
                                isMobile: _isMobile,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteEditorPage(note: note),
                                    ),
                                  );
                                  _loadNotes();
                                },
                                onTogglePin: _togglePin,
                                onArchive: _showArchiveDialog,
                                onShare: _showShareOptionsDialog,
                                onSetReminder: _quickSetReminder,
                                onToggleFavorite: _toggleFavorite,
                                onDelete: _showDeleteDialog,
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



  void _showDeleteDialog(Note note) {
    dialogs.showDeleteDialog(
      context: context,
      note: note,
      onDelete: () => _deleteNote(note.id),
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
}
