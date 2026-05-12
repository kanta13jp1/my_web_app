import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// GitHub PR管理ページ (#74)
/// github-pr-manager Edge Function と連携して PR 一覧・レビュー状況を表示
class GithubPrPage extends StatefulWidget {
  const GithubPrPage({super.key});

  @override
  State<GithubPrPage> createState() => _GithubPrPageState();
}

class _GithubPrPageState extends State<GithubPrPage> {
  final _supabase = Supabase.instance.client;
  final _tokenController = TextEditingController();
  final _repoController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _pullRequests = [];
  Map<String, dynamic>? _repoStats;

  static const _githubColor = Color(0xFF24292F);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'github.list_prs'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          if (data['token_set'] == true) {
            _tokenController.text = '••••••••••••••••';
          }
          if (data['repo'] != null) {
            _repoController.text = data['repo'].toString();
          }
          if (data['pull_requests'] is List) {
            _pullRequests = List<Map<String, dynamic>>.from(
              (data['pull_requests'] as List).whereType<Map>(),
            );
          }
          if (data['stats'] is Map) {
            _repoStats = Map<String, dynamic>.from(
              data['stats'] as Map,
            );
          }
        });
      }
    } catch (_) {
      // EF未デプロイ時も0件で正常表示
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final token = _tokenController.text.trim();
    final repo = _repoController.text.trim();
    if (token.isEmpty || token == '••••••••••••••••') {
      setState(() => _errorMessage = 'GitHub Personal Access Token を入力してください');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'github.configure',
          'token': token,
          'repo': repo,
        },
      );
      if (mounted) {
        setState(() {
          _successMessage = '設定を保存しました';
          _tokenController.text = '••••••••••••••••';
        });
      }
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub PR 管理'),
        backgroundColor: _githubColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _fetchData,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              _buildAlert(_errorMessage!, isError: true),
            if (_successMessage != null)
              _buildAlert(_successMessage!, isError: false),
            _buildConfigCard(),
            const SizedBox(height: 12),
            if (_repoStats != null) _buildStatsCard(),
            if (_pullRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Pull Requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ..._pullRequests.take(20).map((pr) => _PrTile(pr: pr)),
            ] else if (!_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Pull Request がありません',
                  style: TextStyle(
                    color: Colors.black45,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _githubColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _githubColor.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: _githubColor, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'GitHub Personal Access Token とリポジトリを設定すると、PR 一覧・レビュー状況をアプリ内で確認できます。',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String message, {required bool isError}) {
    final color = isError ? Colors.red : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color.shade700,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color.shade700,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: _githubColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'GitHub 設定',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'ghp_...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _repoController,
              decoration: const InputDecoration(
                labelText: 'リポジトリ (owner/repo)',
                hintText: 'username/repository',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.source),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Settings → Developer settings → Personal access tokens で発行できます',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black45,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 16),
                label: Text(_isSaving ? '保存中...' : '設定を保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _githubColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _repoStats!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'リポジトリ統計',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  label: 'Open PR',
                  value: '${stats['open_prs'] ?? 0}',
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Merged',
                  value: '${stats['merged_prs'] ?? 0}',
                  color: const Color(0xFF8957E5),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Stars',
                  value: '${stats['stars'] ?? 0}',
                  color: const Color(0xFFFFC107),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrTile extends StatelessWidget {
  const _PrTile({required this.pr});
  final Map<String, dynamic> pr;

  @override
  Widget build(BuildContext context) {
    final state = pr['state']?.toString();
    final stateColor = _stateColor(state);
    final stateLabel = _stateLabel(state);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: stateColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          pr['title']?.toString() ?? 'PR',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '#${pr['number'] ?? ''} · ${pr['author'] ?? ''} · ${pr['updated_at'] ?? ''}',
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: stateColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            stateLabel,
            style: TextStyle(
              color: stateColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Color _stateColor(String? state) {
    switch (state) {
      case 'open':
        return Colors.green;
      case 'closed':
        return Colors.red;
      case 'merged':
        return const Color(0xFF8957E5);
      default:
        return const Color(0xFFB0B0B0);
    }
  }

  String _stateLabel(String? state) {
    switch (state) {
      case 'open':
        return 'Open';
      case 'closed':
        return 'Closed';
      case 'merged':
        return 'Merged';
      default:
        return state ?? '-';
    }
  }
}
