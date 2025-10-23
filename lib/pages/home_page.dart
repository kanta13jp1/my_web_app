import 'package:flutter/material.dart';
import '../main.dart';
import '../models/note.dart';
import 'auth_page.dart';
import 'note_editor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  // 日付フィルター用
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDateFilter = '全期間';

  @override
  void initState() {
    super.initState();
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

      // 日付範囲でフィルター
      if (_startDate != null || _endDate != null) {
        filtered = filtered.where((note) {
          if (_startDate != null && note.updatedAt.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null) {
            // 終了日の23:59:59まで含める
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

      _filteredNotes = filtered;
    });
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('updated_at', ascending: false);

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
                  // プリセットボタン
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
                  // カスタム日付範囲
                  const Text(
                    'カスタム範囲',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 開始日
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
                  // 終了日
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('終了日'),
                    subtitle: Text(
                      _endDate != null
                          ? _formatDateFull(_endDate!)
                          : '指定なし',
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
        _endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      case '昨日':
        final yesterday = today.subtract(const Duration(days: 1));
        _startDate = yesterday;
        _endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case '今週':
        final weekday = now.weekday;
        final firstDayOfWeek = today.subtract(Duration(days: weekday - 1));
        _startDate = firstDayOfWeek;
        _endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      case '先週':
        final weekday = now.weekday;
        final lastWeekEnd = today.subtract(Duration(days: weekday));
        final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
        _startDate = lastWeekStart;
        _endDate = DateTime(lastWeekEnd.year, lastWeekEnd.month, lastWeekEnd.day, 23, 59, 59);
        break;
      case '今月':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
        break;
      case '先月':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 0);
        _startDate = lastMonth;
        _endDate = DateTime(lastMonthEnd.year, lastMonthEnd.month, lastMonthEnd.day, 23, 59, 59);
        break;
      case '全期間':
        _startDate = null;
        _endDate = null;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDateFilter = _startDate != null || _endDate != null;
    final hasAnyFilter = _searchController.text.isNotEmpty || hasDateFilter;

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
            onPressed: _loadNotes,
            tooltip: '更新',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // フィルター情報表示
                if (hasAnyFilter)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.withOpacity(0.1),
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
                        Text(
                          '${_filteredNotes.length}件',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
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
                                hasAnyFilter
                                    ? Icons.search_off
                                    : Icons.note_add_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                hasAnyFilter
                                    ? '該当するメモが見つかりません'
                                    : 'メモがありません',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                hasAnyFilter
                                    ? 'フィルター条件を変更してみてください'
                                    : '右下の + ボタンから新しいメモを作成',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadNotes,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _filteredNotes.length,
                            itemBuilder: (context, index) {
                              final note = _filteredNotes[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                child: ListTile(
                                  title: _buildHighlightedText(
                                    note.title.isEmpty ? '(タイトルなし)' : note.title,
                                    _searchController.text,
                                    isTitle: true,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      Text(
                                        '更新: ${_formatDate(note.updatedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteDialog(note),
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NoteEditorPage(note: note),
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
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
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
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
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
}