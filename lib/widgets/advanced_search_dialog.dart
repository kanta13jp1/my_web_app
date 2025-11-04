import 'package:flutter/material.dart';
import '../models/category.dart';

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
  late TextEditingController _queryController;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _selectedCategoryId = widget.initialCategoryId;
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,  // 高さ制限を追加
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー（固定）
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    '詳細検索',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // スクロール可能なコンテンツ部分（修正）
            Flexible(  // ← 追加
              child: SingleChildScrollView(  // ← 追加
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // キーワード検索
                    TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        labelText: 'キーワードを入力',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // カテゴリで絞り込み
                    const Text(
                      'カテゴリで絞り込み',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (widget.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'カテゴリがありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // すべて
                          FilterChip(
                            label: const Text('すべて'),
                            selected: _selectedCategoryId == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = null;
                              });
                            },
                          ),
                          // カテゴリチップ
                          ...widget.categories.map((category) {
                            final isSelected = _selectedCategoryId == category.id;
                            final color = Color(
                              int.parse(category.color.substring(1), radix: 16) +
                                  0xFF000000,
                            );

                            return FilterChip(
                              avatar: Text(
                                category.icon,
                                style: TextStyle(fontSize: isMobile ? 14 : 16),
                              ),
                              label: Text(category.name),
                              selected: isSelected,
                              selectedColor: color.withValues(alpha: 0.3),
                              checkmarkColor: color,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId =
                                      selected ? category.id : null;
                                });
                              },
                            );
                          }),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // 日付範囲で絞り込み
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
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _startDate != null
                                  ? '開始日\n${_formatDate(_startDate!)}'
                                  : '開始日',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
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
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('〜'),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event),
                            label: Text(
                              _endDate != null
                                  ? '終了日\n${_formatDate(_endDate!)}'
                                  : '終了日',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
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
                            },
                          ),
                        ),
                      ],
                    ),

                    if (_startDate != null || _endDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('日付をクリア'),
                          onPressed: () {
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),  // ← 追加
            ),  // ← 追加

            // ボタン（固定）
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _queryController.clear();
                        _selectedCategoryId = null;
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: const Text('クリア'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'query': _queryController.text,
                        'categoryId': _selectedCategoryId,
                        'startDate': _startDate,
                        'endDate': _endDate,
                      });
                    },
                    child: const Text('検索'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}