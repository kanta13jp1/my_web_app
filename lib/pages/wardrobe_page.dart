import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

// =====================================================
// モデル
// =====================================================
class ClothingItem {
  final String id;
  final String name;
  final String category;
  final String color;
  final String status; // keep / donate / sell / discard
  final DateTime? lastWornAt;
  final DateTime createdAt;
  final String? memo;

  ClothingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.status,
    this.lastWornAt,
    required this.createdAt,
    this.memo,
  });

  factory ClothingItem.fromMap(Map<String, dynamic> m) => ClothingItem(
        id: m['id'] as String,
        name: m['name'] as String,
        category: m['category'] as String? ?? 'その他',
        color: m['color'] as String? ?? 'その他',
        status: m['status'] as String? ?? 'keep',
        lastWornAt: m['last_worn_at'] != null
            ? DateTime.parse(m['last_worn_at'] as String).toLocal()
            : null,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        memo: m['memo'] as String?,
      );
}

// =====================================================
// ページ本体
// =====================================================
class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['list', 'analysis'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<ClothingItem> _items = [];
  bool _isLoading = true;
  String _filterCategory = 'すべて';
  String _filterStatus = 'すべて';

  static const List<String> _categories = [
    'すべて',
    'トップス',
    'ボトムス',
    'アウター',
    'スーツ',
    'シューズ',
    'バッグ',
    'アクセサリー',
    'その他',
  ];
  static const List<String> _statusFilters = [
    'すべて',
    'keep',
    'donate',
    'sell',
    'discard',
  ];
  // ignore: unused_field
  static const List<String> _colors = [
    'ブラック',
    'ホワイト',
    'グレー',
    'ネイビー',
    'ブルー',
    'グリーン',
    'レッド',
    'ブラウン',
    'ベージュ',
    'ピンク',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('wardrobe_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _items = (data as List)
              .map((e) => ClothingItem.fromMap(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wardrobe: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ClothingItem> get _filtered {
    return _items.where((item) {
      final catOk =
          _filterCategory == 'すべて' || item.category == _filterCategory;
      final stOk = _filterStatus == 'すべて' || item.status == _filterStatus;
      return catOk && stOk;
    }).toList();
  }

  // ステータス別カウント
  Map<String, int> get _statusCount {
    final map = <String, int>{'keep': 0, 'donate': 0, 'sell': 0, 'discard': 0};
    for (final item in _items) {
      map[item.status] = (map[item.status] ?? 0) + 1;
    }
    return map;
  }

  Future<void> _addItem() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddItemSheet(
        onSaved: () {
          Navigator.pop(context);
          _fetchItems();
        },
      ),
    );
  }

  Future<void> _updateStatus(ClothingItem item, String newStatus) async {
    try {
      await _supabase
          .from('wardrobe_items')
          .update({'status': newStatus}).eq('id', item.id);
      _fetchItems();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Future<void> _markWorn(ClothingItem item) async {
    try {
      await _supabase.from('wardrobe_items').update({
        'last_worn_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('「${item.name}」を着用記録しました'),
            backgroundColor: const Color(0xFF388E3C),
          ),
        );
      }
      _fetchItems();
    } catch (e) {
      debugPrint('Error marking worn: $e');
    }
  }

  Future<void> _deleteItem(ClothingItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${item.name}」を削除'),
        content: const Text('この衣類を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _supabase
          .from('wardrobe_items')
          .delete()
          .eq('id', item.id)
          .select();
      _fetchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _statusCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ワードローブ管理'),
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: const Color(0xFFE5E7EB),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE5E7EB),
          labelColor: const Color(0xFFE5E7EB),
          unselectedLabelColor: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
          tabs: const [
            Tab(icon: Icon(Icons.checkroom), text: '一覧'),
            Tab(icon: Icon(Icons.pie_chart), text: '断捨離分析'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFEFEBE9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: const Color(0xFFE5E7EB),
        icon: const Icon(Icons.add),
        label: const Text('衣類を追加'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListTab(),
          _buildAnalysisTab(counts),
        ],
      ),
    );
  }

  // =====================================================
  // タブ1: 一覧
  // =====================================================
  Widget _buildListTab() {
    final filtered = _filtered;
    return Column(
      children: [
        // フィルター
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              // カテゴリフィルター
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final selected = _filterCategory == cat;
                    return FilterChip(
                      label: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFFBCAAA4),
                      onSelected: (_) => setState(() => _filterCategory = cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              // ステータスフィルター
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statusFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final st = _statusFilters[i];
                    final selected = _filterStatus == st;
                    return FilterChip(
                      label: Text(
                        _statusLabel(st),
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      selected: selected,
                      selectedColor: _statusColor(st).withValues(alpha: 0.3),
                      onSelected: (_) => setState(() => _filterStatus = st),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // 件数
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${filtered.length}件',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        // リスト
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.checkroom,
                            size: 60,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '衣類を追加してください',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildItemCard(filtered[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildItemCard(ClothingItem item) {
    final daysSinceWorn = item.lastWornAt != null
        ? DateTime.now().difference(item.lastWornAt!).inDays
        : null;
    final isOld = daysSinceWorn != null && daysSinceWorn > 180;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: item.status != 'keep'
            ? BorderSide(color: _statusColor(item.status), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // カラーサークル
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _colorToFlutter(item.color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      Row(
                        children: [
                          _chip(
                            item.category,
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF4E342E)
                                    .withValues(alpha: 0.47)
                                : const Color(0xFFD7CCC8),
                          ),
                          const SizedBox(width: 4),
                          _chip(
                            item.color,
                            Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ステータスバッジ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(item.status),
                    style: TextStyle(
                      color: _statusColor(item.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (item.memo != null && item.memo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.memo!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color:
                      isOld ? const Color(0xFFE53935) : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  item.lastWornAt != null
                      ? '最終着用: ${DateFormat('yyyy/MM/dd').format(item.lastWornAt!)}（$daysSinceWorn日前）'
                      : '着用記録なし',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOld
                        ? const Color(0xFFE53935)
                        : const Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
                if (isOld) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF3A1010)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '長期未使用',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // アクションボタン行
            Row(
              children: [
                _actionBtn(
                  '着用',
                  Icons.check,
                  const Color(0xFF4CAF50),
                  () => _markWorn(item),
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  '寄付',
                  Icons.favorite,
                  const Color(0xFF3D5AFE),
                  () => _updateStatus(item, 'donate'),
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  '売却',
                  Icons.sell,
                  const Color(0xFFFF6B35),
                  () => _updateStatus(item, 'sell'),
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  '処分',
                  Icons.delete_outline,
                  const Color(0xFFE53935),
                  () => _updateStatus(item, 'discard'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                  onPressed: () => _deleteItem(item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            height: 1.5,
          ),
        ),
      );

  // =====================================================
  // タブ2: 断捨離分析
  // =====================================================
  Widget _buildAnalysisTab(Map<String, int> counts) {
    final total = _items.length;
    // 180日以上着用なし
    final longUnused = _items
        .where(
          (i) =>
              i.status == 'keep' &&
              (i.lastWornAt == null ||
                  DateTime.now().difference(i.lastWornAt!).inDays > 180),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // サマリーカード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ワードローブサマリー',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryItem('総数', '$total件', const Color(0xFF795548)),
                      _summaryItem(
                        '保持',
                        '${counts['keep']}件',
                        const Color(0xFF4CAF50),
                      ),
                      _summaryItem(
                        '寄付',
                        '${counts['donate']}件',
                        const Color(0xFF3D5AFE),
                      ),
                      _summaryItem(
                        '売却',
                        '${counts['sell']}件',
                        const Color(0xFFFF6B35),
                      ),
                      _summaryItem(
                        '処分',
                        '${counts['discard']}件',
                        const Color(0xFFE53935),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 断捨離候補
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFFB74D), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Color(0xFFF57C00),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '断捨離候補（180日以上未着用）',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF6C00),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${longUnused.length}件の衣類が半年以上着用されていません',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  if (longUnused.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...longUnused.take(5).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _colorToFlutter(item.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.lastWornAt != null
                                      ? '${DateTime.now().difference(item.lastWornAt!).inDays}日前'
                                      : '記録なし',
                                  style: const TextStyle(
                                    color: Color(0xFFEF5350),
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _updateStatus(item, 'donate'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF0C1A2A)
                                          : const Color(0xFFE3F2FD),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '寄付',
                                      style: TextStyle(
                                        color: Color(0xFF3D5AFE),
                                        fontSize: 11,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (longUnused.length > 5)
                      Text(
                        '+${longUnused.length - 5}件...',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // カテゴリ内訳
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'カテゴリ別内訳',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._categories.skip(1).map((cat) {
                    final count = _items.where((i) => i.category == cat).length;
                    if (count == 0) return const SizedBox.shrink();
                    final pct = total > 0 ? count / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              cat,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                color: const Color(0xFF8D6E63),
                                minHeight: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count件',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) => Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
              height: 1.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      );

  // =====================================================
  // ユーティリティ
  // =====================================================
  String _statusLabel(String status) {
    switch (status) {
      case 'keep':
        return '保持';
      case 'donate':
        return '寄付';
      case 'sell':
        return '売却';
      case 'discard':
        return '処分';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'keep':
        return const Color(0xFF4CAF50);
      case 'donate':
        return const Color(0xFF3D5AFE);
      case 'sell':
        return const Color(0xFFFF6B35);
      case 'discard':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color _colorToFlutter(String color) {
    switch (color) {
      case 'ブラック':
        return Colors.black;
      case 'ホワイト':
        return Colors.white;
      case 'グレー':
        return const Color(0xFF9CA3AF);
      case 'ネイビー':
        return const Color(0xFF001F5B);
      case 'ブルー':
        return const Color(0xFF3D5AFE);
      case 'グリーン':
        return const Color(0xFF4CAF50);
      case 'レッド':
        return const Color(0xFFE53935);
      case 'ブラウン':
        return const Color(0xFF795548);
      case 'ベージュ':
        return const Color(0xFFF5F5DC);
      case 'ピンク':
        return const Color(0xFFFF6B35);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}

// =====================================================
// 衣類追加シート
// =====================================================
class _AddItemSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddItemSheet({required this.onSaved});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  String _category = 'トップス';
  String _color = 'ブラック';
  bool _isSaving = false;

  static const List<String> _categories = [
    'トップス',
    'ボトムス',
    'アウター',
    'スーツ',
    'シューズ',
    'バッグ',
    'アクセサリー',
    'その他',
  ];
  static const List<String> _colors = [
    'ブラック',
    'ホワイト',
    'グレー',
    'ネイビー',
    'ブルー',
    'グリーン',
    'レッド',
    'ブラウン',
    'ベージュ',
    'ピンク',
    'その他',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('名前を入力してください')));
      return;
    }
    setState(() => _isSaving = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('wardrobe_items').insert({
        'user_id': userId,
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'color': _color,
        'status': 'keep',
        'memo': _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      widget.onSaved();
    } catch (e) {
      debugPrint('Error adding item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '衣類を追加',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '名前 (例: ネイビーのトレンチコート)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _color,
                  decoration: const InputDecoration(
                    labelText: 'カラー',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _colors
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _color = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoCtrl,
            decoration: const InputDecoration(
              labelText: 'メモ (任意)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: const Color(0xFFE5E7EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE5E7EB),
                      ),
                    )
                  : const Text(
                      '追加する',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
