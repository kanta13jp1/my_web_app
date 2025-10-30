import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../services/search_history_service.dart';

class AdvancedSearchDialog extends StatefulWidget {
  final List<Category> categories;
  final String? initialQuery;
  final String? initialCategoryId;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const AdvancedSearchDialog({
    super.key,
    required this.categories,
    this.initialQuery,
    this.initialCategoryId,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  late TextEditingController _searchController;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _searchHistory = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _selectedCategoryId = widget.initialCategoryId;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _loadSearchHistory();

    // 検索フィールドにフォーカスがあるときは履歴を表示
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        setState(() {
          _showHistory = true;
        });
      } else {
        setState(() {
          _showHistory = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await SearchHistoryService.getHistory();
    if (!mounted) return;
    
    setState(() {
      _searchHistory = history.map((item) => item.query).toList();
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategoryId = null;
      _startDate = null;
      _endDate = null;
    });
  }

  void _applySearch() {
    final query = _searchController.text.trim();
    
    // 検索履歴に保存
    if (query.isNotEmpty) {
      SearchHistoryService.saveSearch(query);
    }

    Navigator.pop(context, {
      'query': query,
      'categoryId': _selectedCategoryId,
      'startDate': _startDate,
      'endDate': _endDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '詳細検索',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 検索フィールド
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'キーワードを入力',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
              onSubmitted: (_) => _applySearch(),
            ),

            // 検索履歴
            if (_showHistory && _searchHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '最近の検索',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await SearchHistoryService.clearHistory();
                              _loadSearchHistory();
                            },
                            child: const Text('クリア'),
                          ),
                        ],
                      ),
                    ),
                    ..._searchHistory.take(5).map((query) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(query),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () async {
                            await SearchHistoryService.removeSearch(query);
                            _loadSearchHistory();
                          },
                        ),
                        onTap: () {
                          _searchController.text = query;
                          setState(() {
                            _showHistory = false;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // カテゴリフィルター
            const Text(
              'カテゴリで絞り込み',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('すべて'),
                  selected: _selectedCategoryId == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategoryId = null;
                    });
                  },
                ),
                ...widget.categories.map((category) {
                  final color = Color(
                    int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
                  );
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category.icon),
                        const SizedBox(width: 4),
                        Text(category.name),
                      ],
                    ),
                    selected: _selectedCategoryId == category.id,
                    selectedColor: color.withValues(alpha: 0.3),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryId = selected ? category.id : null;
                      });
                    },
                  );
                }),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // 日付範囲フィルター
            const Text(
              '日付範囲で絞り込み',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _startDate != null
                          ? DateFormat('yyyy/MM/dd').format(_startDate!)
                          : '開始日',
                    ),
                    onPressed: _selectStartDate,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('〜'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _endDate != null
                          ? DateFormat('yyyy/MM/dd').format(_endDate!)
                          : '終了日',
                    ),
                    onPressed: _selectEndDate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // アクションボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('フィルタをクリア'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('検索'),
                  onPressed: _applySearch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}