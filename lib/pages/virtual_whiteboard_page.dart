import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// バーチャルホワイトボードページ
/// virtual-whiteboard Edge Function と連携
/// Miro / Microsoft Whiteboard / Figma FigJam 競合
class VirtualWhiteboardPage extends StatefulWidget {
  const VirtualWhiteboardPage({super.key});

  @override
  State<VirtualWhiteboardPage> createState() => _VirtualWhiteboardPageState();
}

class _VirtualWhiteboardPageState extends State<VirtualWhiteboardPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['boards', 'templates'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _boards = [];
  Map<String, dynamic>? _selectedBoard;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _elements = [];

  final _boardNameCtrl = TextEditingController();
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBoards();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _boardNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBoards() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'whiteboard.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['boards'] is List) {
        setState(
          () => _boards = (data['boards'] as List).cast<Map<String, dynamic>>(),
        );
      } else {
        setState(() => _boards = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'ボードの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTemplates() async {
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'whiteboard.config'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['templates'] is List) {
        setState(
          () => _templates =
              (data['templates'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } catch (_) {}
  }

  Future<void> _openBoard(Map<String, dynamic> board) async {
    final boardId =
        board['board_id']?.toString() ?? board['id']?.toString() ?? '';
    if (boardId.isEmpty) return;
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'whiteboard.get', 'board_id': boardId},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['board'] is Map) {
        final boardData = data['board'] as Map<String, dynamic>;
        final elems = boardData['elements'];
        setState(() {
          _selectedBoard = boardData;
          _elements = elems is List ? elems.cast<Map<String, dynamic>>() : [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ボードの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _createBoard() async {
    _boardNameCtrl.clear();
    _selectedTemplateId = null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('新しいボードを作成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _boardNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ボード名',
                  hintText: '例: プロジェクト企画ボード',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'テンプレートを選択 (任意)',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...(_templates.map((tmpl) {
                final tmplId = tmpl['id']?.toString() ?? '';
                final tmplName = tmpl['name']?.toString() ?? '';
                final tmplDesc = tmpl['description']?.toString() ?? '';
                final isSelected = _selectedTemplateId == tmplId;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  title: Text(
                    tmplName,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  subtitle: tmplDesc.isNotEmpty
                      ? Text(
                          tmplDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                          ),
                        )
                      : null,
                  selected: isSelected,
                  onTap: () => setSt(() => _selectedTemplateId = tmplId),
                );
              })),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (_boardNameCtrl.text.trim().isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'media-hub',
        body: {
          'action': 'whiteboard.create',
          'name': _boardNameCtrl.text.trim(),
          if (_selectedTemplateId != null) 'template_id': _selectedTemplateId,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ボードを作成しました')),
        );
      }
      await _fetchBoards();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _addStickyNote() async {
    final board = _selectedBoard;
    if (board == null) return;
    final boardId = board['board_id']?.toString() ?? '';
    final textCtrl = TextEditingController();
    String selectedColor = '#FFEB3B';
    final stickyColors = [
      '#FFEB3B',
      '#4CAF50',
      '#2196F3',
      '#FF5722',
      '#9C27B0',
      '#FF9800',
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('付箋を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(labelText: '付箋の内容'),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'カラーを選択',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: stickyColors.map((hex) {
                  final color = Color(int.parse('0xFF${hex.substring(1)}'));
                  return GestureDetector(
                    onTap: () => setSt(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == hex
                              ? Colors.black
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    textCtrl.dispose();
    if (confirmed != true) return;
    try {
      await _supabase.functions.invoke(
        'media-hub',
        body: {
          'action': 'whiteboard.add_element',
          'board_id': boardId,
          'type': 'sticky_note',
          'content': textCtrl.text.trim(),
          'color': selectedColor,
          'x': 100 + (_elements.length * 20) % 400,
          'y': 100 + (_elements.length * 20) % 300,
        },
      );
      await _openBoard(_selectedBoard!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加に失敗しました: $e')),
        );
      }
    }
  }

  Color _stickyColor(String hex) {
    try {
      return Color(int.parse('0xFF${hex.replaceAll('#', '')}'));
    } catch (_) {
      return const Color(0xFFFFE082);
    }
  }

  IconData _elementIcon(String type) {
    switch (type) {
      case 'sticky_note':
        return Icons.sticky_note_2;
      case 'rectangle':
        return Icons.crop_square;
      case 'circle':
        return Icons.circle_outlined;
      case 'text':
        return Icons.text_fields;
      case 'arrow':
        return Icons.arrow_forward;
      case 'image':
        return Icons.image;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          _selectedBoard != null
              ? _selectedBoard!['name']?.toString() ?? 'ホワイトボード'
              : 'バーチャルホワイトボード',
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        foregroundColor: Colors.white,
        leading: _selectedBoard != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'ボード一覧に戻る',
                onPressed: () => setState(() {
                  _selectedBoard = null;
                  _elements = [];
                }),
              )
            : null,
        bottom: _selectedBoard == null
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard), text: 'マイボード'),
                  Tab(icon: Icon(Icons.grid_view), text: 'テンプレート'),
                ],
              )
            : null,
        actions: [
          if (_selectedBoard != null)
            IconButton(
              icon: const Icon(Icons.sticky_note_2),
              tooltip: '付箋を追加',
              onPressed: _addStickyNote,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _selectedBoard == null
                ? _fetchBoards
                : () => _openBoard(_selectedBoard!),
          ),
        ],
      ),
      floatingActionButton: _selectedBoard == null
          ? FloatingActionButton(
              onPressed: _createBoard,
              backgroundColor: const Color(0xFFFF6B35),
              tooltip: '新しいボードを作成',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchBoards,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _selectedBoard != null
                  ? _buildBoardCanvas()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBoardList(),
                        _buildTemplateList(),
                      ],
                    ),
    );
  }

  Widget _buildBoardList() {
    if (_boards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'ボードがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '右下の + から新しいボードを作成してください',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _boards.length,
      itemBuilder: (context, index) {
        final board = _boards[index];
        final name = board['name']?.toString() ?? '無題のボード';
        final updatedAt = board['updatedAt']?.toString() ??
            board['createdAt']?.toString() ??
            '';
        final elemCount = (board['elementCount'] as num?)?.toInt() ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
              child: const Icon(Icons.dashboard, color: Color(0xFF6366F1)),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (elemCount > 0)
                  Text(
                    '$elemCount 個の要素',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                if (updatedAt.isNotEmpty)
                  Text(
                    updatedAt.length > 10
                        ? updatedAt.substring(0, 10)
                        : updatedAt,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openBoard(board),
          ),
        );
      },
    );
  }

  Widget _buildTemplateList() {
    if (_templates.isEmpty) {
      return const Center(
        child: Text(
          'テンプレートがありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 140,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final tmpl = _templates[index];
        final name = tmpl['name']?.toString() ?? '';
        final desc = tmpl['description']?.toString() ?? '';
        final colors = [
          const Color(0xFF6366F1),
          const Color(0xFF0EA5E9),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
        ];
        final color = colors[index % colors.length];
        return Card(
          child: InkWell(
            onTap: () {
              _boardNameCtrl.text = name;
              _selectedTemplateId = tmpl['id']?.toString();
              _createBoard();
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.dashboard_customize, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardCanvas() {
    return Column(
      children: [
        // Toolbar
        Container(
          color: const Color(0xFF6366F1).withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_elements.length} 個の要素',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _addStickyNote,
                icon: const Icon(Icons.sticky_note_2, size: 18),
                label: const Text('付箋'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
        // Canvas area (simplified list view)
        Expanded(
          child: _elements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.draw,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ボードが空です',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addStickyNote,
                        icon: const Icon(Icons.sticky_note_2),
                        label: const Text('付箋を追加'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _elements.length,
                  itemBuilder: (context, index) {
                    final el = _elements[index];
                    final type = el['type']?.toString() ?? 'text';
                    final content = el['content']?.toString() ?? '';
                    final color = el['color']?.toString() ?? '#FFEB3B';
                    if (type == 'sticky_note') {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _stickyColor(color),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Text(content.isNotEmpty ? content : '(空の付箋)'),
                      );
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _elementIcon(type),
                          color: const Color(0xFF6366F1),
                        ),
                        title: Text(content.isNotEmpty ? content : '($type)'),
                        trailing: Text(
                          type,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
