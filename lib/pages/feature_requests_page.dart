import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 機能リクエスト公開ページ
/// 登録前ユーザーも閲覧・投票・投稿できる。
/// anon RLS で open status のリクエストのみ参照可。
class FeatureRequestsPage extends StatefulWidget {
  const FeatureRequestsPage({super.key});

  @override
  State<FeatureRequestsPage> createState() => _FeatureRequestsPageState();
}

class _FeatureRequestsPageState extends State<FeatureRequestsPage> {
  final _supabase = Supabase.instance.client;
  final _titleCtrl = TextEditingController();

  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  bool _submitting = false;
  String? _submitError;
  bool _submitSuccess = false;
  final Set<String> _votedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('feature_requests')
          .select('id, title, votes, status, created_at')
          .eq('status', 'open')
          .order('votes', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('feature_requests load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upvote(String id, int currentVotes) async {
    if (_votedIds.contains(id)) return;
    setState(() => _votedIds.add(id));
    try {
      await _supabase
          .from('feature_requests')
          .update({'votes': currentVotes + 1}).eq('id', id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.map((r) {
          if (r['id'] == id) return {...r, 'votes': currentVotes + 1};
          return r;
        }).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _votedIds.remove(id));
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await _supabase.from('feature_requests').insert({'title': title});
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitSuccess = true;
        _titleCtrl.clear();
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = '送信に失敗しました。もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('機能リクエスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ヘッダー説明
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3949AB), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 機能リクエスト',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'あなたのアイデアが次の機能になります。\n'
                        '投票数が多いリクエストを優先的に開発します。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // リクエスト投稿フォーム
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF2D2000).withAlpha(200)
                        : Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF92400E).withAlpha(180)
                          : Color(0xFFFDE68A),
                    ),
                  ),
                  child: _submitSuccess
                      ? const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'リクエストを受け付けました！\n投票数が増えると開発優先度が上がります。',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '新しいリクエストを送る',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _titleCtrl,
                              decoration: InputDecoration(
                                hintText: '例: カレンダー連携、Google Drive インポート…',
                                hintStyle: const TextStyle(fontSize: 13),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            if (_submitError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _submitError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _submitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: Color(0xFFD97706),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'リクエストを送信する',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),

                // リクエスト一覧
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_requests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'まだリクエストがありません。\n最初のリクエストを送ってください！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'みんなのリクエスト (${_requests.length}件)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._requests.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final req = entry.value;
                    final id = req['id']?.toString() ?? '';
                    final title = req['title']?.toString() ?? '';
                    final votes = (req['votes'] as num?)?.toInt() ?? 0;
                    final voted = _votedIds.contains(id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            rank <= 3 ? Color(0xFFFEFCE8) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: rank <= 3
                              ? Color(0xFFFDE68A)
                              : Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: rank <= 3
                                    ? Color(0xFFD97706)
                                    : Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: voted ? null : () => _upvote(id, votes),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: voted
                                    ? Color(0xFF3949AB)
                                    : Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.thumb_up_alt,
                                    size: 14,
                                    color: voted
                                        ? Colors.white
                                        : Color(0xFF3949AB),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$votes',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: voted
                                          ? Colors.white
                                          : Color(0xFF3949AB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
