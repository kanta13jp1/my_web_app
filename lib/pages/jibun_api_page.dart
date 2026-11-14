import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 自分API 管理ページ (Notion Developer Platform 対抗 / 2026-07-12 WEB版)
///
/// tools-hub の jibunapi.* action で API キーと Worker を管理する。
/// - API キー: 発行 (平文は1回のみ表示) / 一覧 / 失効。スコープ選択制。
/// - Worker: ユーザー自作 Agent ツール (外部 https エンドポイント) の登録 / 一覧 / 削除。
class JibunApiPage extends StatefulWidget {
  const JibunApiPage({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  State<JibunApiPage> createState() => _JibunApiPageState();
}

class _JibunApiPageState extends State<JibunApiPage> {
  late final SupabaseClient _supabase =
      widget.supabaseClient ?? Supabase.instance.client;

  // Design tokens (docs/DESIGN.md)
  static const _orange = Color(0xFFFF6B35);
  static const _indigo = Color(0xFF3D5AFE);
  static const _green = Color(0xFF4CAF50);
  static const _red = Color(0xFFE53935);
  static const _amber = Color(0xFFFFC107);

  static const List<({String id, String label})> _scopeCatalog = [
    (id: 'integrations.read', label: 'Integration registry'),
    (id: 'notes.read', label: 'ノート閲覧'),
    (id: 'notes.write', label: 'ノート作成'),
    (id: 'tasks.read', label: 'タスク閲覧'),
    (id: 'achievements.read', label: '開発実績閲覧'),
    (id: 'workers.invoke', label: 'Worker 実行'),
  ];

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _keys = [];
  List<Map<String, dynamic>> _workers = [];

  final _keyNameCtrl = TextEditingController();
  final Set<String> _selectedScopes = {'notes.read'};

  final _workerNameCtrl = TextEditingController();
  final _workerUrlCtrl = TextEditingController();
  final _workerDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _keyNameCtrl.dispose();
    _workerNameCtrl.dispose();
    _workerUrlCtrl.dispose();
    _workerDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final keyRes = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'jibunapi.key.list'},
      );
      final workerRes = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'jibunapi.worker.list'},
      );
      final keyData = keyRes.data;
      final workerData = workerRes.data;
      setState(() {
        _keys = keyData is Map && keyData['keys'] is List
            ? (keyData['keys'] as List).cast<Map<String, dynamic>>()
            : [];
        _workers = workerData is Map && workerData['workers'] is List
            ? (workerData['workers'] as List).cast<Map<String, dynamic>>()
            : [];
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '自分APIデータの取得に失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createKey() async {
    final name = _keyNameCtrl.text.trim();
    if (name.isEmpty || _selectedScopes.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'jibunapi.key.create',
          'name': name,
          'scopes': _selectedScopes.toList(),
        },
      );
      final data = response.data;
      final apiKey = data is Map ? data['api_key'] as String? : null;
      if (apiKey == null) {
        final err = data is Map ? data['error'] : null;
        messenger.showSnackBar(
          SnackBar(content: Text('キー発行に失敗: ${err ?? '不明なエラー'}')),
        );
        return;
      }
      navigator.pop();
      _keyNameCtrl.clear();
      await _fetchAll();
      if (mounted) await _showSecretDialog('APIキー', apiKey);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('キー発行に失敗: $e')));
    }
  }

  Future<void> _revokeKey(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm('このAPIキーを失効しますか？', 'この操作は取り消せません。');
    if (!confirmed) return;
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'jibunapi.key.revoke', 'id': id},
      );
      await _fetchAll();
      messenger.showSnackBar(const SnackBar(content: Text('APIキーを失効しました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('失効に失敗: $e')));
    }
  }

  Future<void> _registerWorker() async {
    final name = _workerNameCtrl.text.trim();
    final url = _workerUrlCtrl.text.trim();
    if (name.isEmpty || url.isEmpty) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'jibunapi.worker.register',
          'name': name,
          'endpoint_url': url,
          'description': _workerDescCtrl.text.trim(),
        },
      );
      final data = response.data;
      final secret = data is Map ? data['signing_secret'] as String? : null;
      if (secret == null) {
        final err = data is Map ? data['error'] : null;
        messenger.showSnackBar(
          SnackBar(content: Text('Worker登録に失敗: ${err ?? '不明なエラー'}')),
        );
        return;
      }
      navigator.pop();
      _workerNameCtrl.clear();
      _workerUrlCtrl.clear();
      _workerDescCtrl.clear();
      await _fetchAll();
      if (mounted) await _showSecretDialog('署名シークレット', secret);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Worker登録に失敗: $e')));
    }
  }

  Future<void> _deleteWorker(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirm('このWorkerを削除しますか？', 'この操作は取り消せません。');
    if (!confirmed) return;
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'jibunapi.worker.delete', 'id': id},
      );
      await _fetchAll();
      messenger.showSnackBar(const SnackBar(content: Text('Workerを削除しました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('削除に失敗: $e')));
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(height: 1.5)),
        content: Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('実行'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 平文シークレット (キー / 署名シークレット) を1回だけ表示するダイアログ。
  Future<void> _showSecretDialog(String label, String secret) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.key, color: _amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$labelを保存', style: const TextStyle(height: 1.5)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'この値は今回のみ表示されます。安全な場所に保管してください。閉じると再表示できません。',
              style: TextStyle(height: 1.5, color: _amber),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _indigo.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                secret,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFFE0E0E0),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('コピー'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              messenger.showSnackBar(
                const SnackBar(content: Text('クリップボードにコピーしました')),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('保存した'),
          ),
        ],
      ),
    );
  }

  void _showCreateKeyDialog() {
    _keyNameCtrl.clear();
    setState(() {
      _selectedScopes
        ..clear()
        ..add('notes.read');
    });
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('APIキーを発行', style: TextStyle(height: 1.5)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _keyNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'キー名 (用途がわかる名前)',
                    hintText: '例: ChatGPT 連携用',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'スコープ (許可する操作)',
                  style: TextStyle(height: 1.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ..._scopeCatalog.map(
                  (scope) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: _indigo,
                    value: _selectedScopes.contains(scope.id),
                    title: Text(
                      '${scope.label}  (${scope.id})',
                      style: const TextStyle(height: 1.5, fontSize: 13),
                    ),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          _selectedScopes.add(scope.id);
                        } else {
                          _selectedScopes.remove(scope.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _orange),
              onPressed: _selectedScopes.isEmpty ? null : _createKey,
              child: const Text('発行'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegisterWorkerDialog() {
    _workerNameCtrl.clear();
    _workerUrlCtrl.clear();
    _workerDescCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workerを登録', style: TextStyle(height: 1.5)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'あなたの自作 Agent ツール (外部 https エンドポイント) を登録します。'
                '呼び出し時に HMAC-SHA256 署名 (X-Jibun-Signature) が付与されます。',
                style: TextStyle(height: 1.5, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _workerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Worker名',
                  hintText: '例: 要約ワーカー',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workerUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'エンドポイント URL (https)',
                  hintText: 'https://your-worker.example.com/hook',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workerDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '説明 (任意)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _indigo),
            onPressed: _registerWorker,
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _supabase.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('自分API', style: TextStyle(height: 1.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
            onPressed: _isLoading ? null : _fetchAll,
          ),
        ],
      ),
      body: !isLoggedIn
          ? _buildLoggedOut()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: _fetchAll,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildIntroCard(),
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            'APIキー',
                            Icons.key,
                            _orange,
                            onAdd: _showCreateKeyDialog,
                          ),
                          const SizedBox(height: 8),
                          if (_keys.isEmpty)
                            _buildEmpty('まだAPIキーがありません。発行して外部AIから連携しましょう。')
                          else
                            ..._keys.map(_buildKeyCard),
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            'Worker (自作Agentツール)',
                            Icons.smart_toy_outlined,
                            _indigo,
                            onAdd: _showRegisterWorkerDialog,
                          ),
                          const SizedBox(height: 8),
                          if (_workers.isEmpty)
                            _buildEmpty('まだWorkerがありません。外部エンドポイントを登録できます。')
                          else
                            ..._workers.map(_buildWorkerCard),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      color: _indigo.withValues(alpha: 0.08),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自分APIで外部AIとつながる',
              style: TextStyle(
                height: 1.5,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'APIキーを発行すると、ChatGPT・Claude・自作スクリプトなど外部エージェントから'
              'あなたのノート・タスク・開発実績へ安全にアクセスできます。'
              'Worker を登録すれば、あなた自身の AI ツールを自分APIから呼び出せます。',
              style: TextStyle(height: 1.6, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              'エンドポイント: POST /functions/v1/tools-hub  '
              'Authorization: Bearer jibun_sk_...  body: {"action":"api.notes.list"}',
              style: TextStyle(
                height: 1.5,
                fontSize: 11,
                fontFamily: 'monospace',
                color: Color(0xFFB0B0B0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color, {
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            height: 1.5,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('追加'),
          style: TextButton.styleFrom(foregroundColor: color),
          onPressed: onAdd,
        ),
      ],
    );
  }

  Widget _buildKeyCard(Map<String, dynamic> key) {
    final revoked = key['revoked'] == true;
    final scopes = key['scopes'] is List
        ? (key['scopes'] as List).map((s) => s.toString()).toList()
        : <String>[];
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.key,
          color: revoked ? const Color(0xFF757575) : _green,
        ),
        title: Text(
          key['name']?.toString() ?? '(無名)',
          style: TextStyle(
            height: 1.5,
            decoration: revoked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${key['key_prefix'] ?? ''}…',
              style: const TextStyle(
                height: 1.5,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: scopes
                  .map(
                    (s) => Chip(
                      label: Text(
                        s,
                        style: const TextStyle(fontSize: 10, height: 1.2),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
            if (revoked)
              const Text(
                '失効済み',
                style: TextStyle(height: 1.5, fontSize: 11, color: _red),
              ),
          ],
        ),
        trailing: revoked
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: _red),
                tooltip: '失効',
                onPressed: () => _revokeKey(key['id']?.toString() ?? ''),
              ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    final enabled = worker['enabled'] == true;
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.smart_toy_outlined,
          color: enabled ? _indigo : const Color(0xFF757575),
        ),
        title: Text(
          worker['name']?.toString() ?? '(無名)',
          style: const TextStyle(height: 1.5),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'slug: ${worker['slug'] ?? ''}',
              style: const TextStyle(
                height: 1.5,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            Text(
              worker['endpoint_url']?.toString() ?? '',
              style: const TextStyle(
                height: 1.5,
                fontSize: 11,
                color: Color(0xFFB0B0B0),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '呼び出し ${worker['invocation_count'] ?? 0} 回'
              '${enabled ? '' : ' ・ 無効'}',
              style: const TextStyle(height: 1.5, fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: _red),
          tooltip: '削除',
          onPressed: () => _deleteWorker(worker['id']?.toString() ?? ''),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmpty(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.6, color: Color(0xFFB0B0B0)),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: _red, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'エラーが発生しました',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _fetchAll, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildLoggedOut() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '自分APIを利用するにはログインが必要です。',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.6),
        ),
      ),
    );
  }
}
