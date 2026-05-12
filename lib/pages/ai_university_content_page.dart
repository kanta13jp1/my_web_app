import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiUniversityContentPage extends StatefulWidget {
  final String? facultyCode;
  final String? facultyName;
  final String? facultyEmoji;
  final String? departmentCode;
  final String? departmentName;
  final String? departmentEmoji;

  const AiUniversityContentPage({
    super.key,
    this.facultyCode,
    this.facultyName,
    this.facultyEmoji,
    this.departmentCode,
    this.departmentName,
    this.departmentEmoji,
  });

  @override
  State<AiUniversityContentPage> createState() =>
      _AiUniversityContentPageState();
}

class _AiUniversityContentPageState extends State<AiUniversityContentPage> {
  bool _loading = false;
  List<dynamic> _items = [];
  List<dynamic> _filtered = [];
  String? _error;
  String _searchQuery = '';

  bool get _hasFacultyFilter =>
      widget.facultyCode != null && widget.facultyCode!.isNotEmpty;
  bool get _hasDeptFilter =>
      widget.departmentCode != null && widget.departmentCode!.isNotEmpty;

  Future<void> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'action': _hasFacultyFilter
            ? 'university.content_by_faculty'
            : 'university.content_all',
        'limit': 500,
      };
      if (_hasDeptFilter) body['department_code'] = widget.departmentCode;
      if (_hasFacultyFilter && !_hasDeptFilter) {
        body['faculty_code'] = widget.facultyCode;
      }

      final res = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: body,
      );
      final data = res.data;
      if (!mounted) return;
      List<dynamic> all;
      if (data is List) {
        all = data;
      } else if (data is Map && data['items'] is List) {
        all = data['items'] as List;
      } else {
        all = [];
      }
      setState(() {
        _items = all;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = _items;
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _items.where((item) {
        final m = item as Map<String, dynamic>? ?? {};
        return (m['provider']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['title']?.toString().toLowerCase().contains(q) ?? false) ||
            (m['category']?.toString().toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String get _pageTitle {
    if (_hasDeptFilter) {
      return '${widget.departmentEmoji ?? ''} ${widget.departmentName ?? '学科'}';
    }
    if (_hasFacultyFilter) {
      return '${widget.facultyEmoji ?? ''} ${widget.facultyName ?? '学部'}';
    }
    return 'AI大学 コンテンツ';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasFacultyFilter) _buildBreadcrumb(context, colorScheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '検索...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _applyFilter();
              }),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'エラー: $_error',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetch,
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? '「$_searchQuery」の結果なし'
                                  : 'コンテンツなし',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final item =
                                  _filtered[i] as Map<String, dynamic>? ?? {};
                              return ListTile(
                                dense: true,
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    size: 18,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                                title: Text(
                                  '${item['provider'] ?? ''} — ${item['category'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                subtitle: Text(
                                  item['title']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                trailing: Text(
                                  item['published_at']
                                          ?.toString()
                                          .substring(0, 10) ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFB0B0B0),
                                    height: 1.5,
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context, ColorScheme colorScheme) {
    final parts = <String>['AI大学'];
    if (_hasFacultyFilter) {
      parts.add('${widget.facultyEmoji ?? ''} ${widget.facultyName ?? ''}');
    }
    if (_hasDeptFilter) {
      parts.add(
        '${widget.departmentEmoji ?? ''} ${widget.departmentName ?? ''}',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: parts.asMap().entries.expand((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isLast = idx == parts.length - 1;
          return [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLast
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: isLast ? FontWeight.w700 : FontWeight.normal,
                  ),
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
          ];
        }).toList(),
      ),
    );
  }
}
