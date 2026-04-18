import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// バイラル広告ジェネレーターページ
/// viral-video-ad-generator / x-media-post / viral-growth-engine と連携
/// Dark War風動画広告の生成・X投稿・バイラル指標を管理
class ViralAdGeneratorPage extends StatefulWidget {
  const ViralAdGeneratorPage({super.key});

  @override
  State<ViralAdGeneratorPage> createState() => _ViralAdGeneratorPageState();
}

class _ViralAdGeneratorPageState extends State<ViralAdGeneratorPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _loading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _generatedAd;
  Map<String, dynamic>? _viralStats;

  String _selectedTemplate = 'dark_war';
  String _selectedLang = 'ja';
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _supabase.functions.invoke(
          'viral-video-ad-generator',
          method: HttpMethod.get,
          queryParameters: {'view': 'templates'},
        ),
        _supabase.functions.invoke(
          'viral-video-ad-generator',
          method: HttpMethod.get,
          queryParameters: {'view': 'history'},
        ),
        _supabase.functions.invoke(
          'viral-growth-engine',
          method: HttpMethod.get,
          queryParameters: {'view': 'stats'},
        ),
      ]);

      final templatesData = results[0].data;
      if (templatesData is Map<String, dynamic> &&
          templatesData['templates'] is List) {
        setState(
          () => _templates =
              (templatesData['templates'] as List).cast<Map<String, dynamic>>(),
        );
      }

      final historyData = results[1].data;
      if (historyData is Map<String, dynamic> &&
          historyData['history'] is List) {
        setState(
          () => _history =
              (historyData['history'] as List).cast<Map<String, dynamic>>(),
        );
      }

      final statsData = results[2].data;
      if (statsData is Map<String, dynamic>) {
        setState(
          () => _viralStats = statsData['stats'] as Map<String, dynamic>?,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'データ取得エラー: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateAd() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _generatedAd = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'viral-video-ad-generator',
        body: {
          'template': _selectedTemplate,
          'lang': _selectedLang,
          'type': 'image',
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() => _generatedAd = data);
        _tabController.animateTo(0);
      }
    } catch (e) {
      setState(() => _errorMessage = '生成エラー: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _postToX() async {
    if (_generatedAd == null) return;
    setState(() => _isPosting = true);
    try {
      final caption = _generatedAd!['caption']?.toString() ?? '';
      final imageUrl = _generatedAd!['generatedImageUrl']?.toString();
      final adId = _generatedAd!['id']?.toString();

      String endpoint;
      Map<String, dynamic> body;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        endpoint = 'x-media-post';
        body = {
          'text': caption.length > 280 ? caption.substring(0, 280) : caption,
          'mediaUrl': imageUrl,
          'adGenerationId': adId,
        };
      } else {
        endpoint = 'post-x-update';
        body = {
          'text': caption.length > 280 ? caption.substring(0, 280) : caption,
        };
      }

      final res = await _supabase.functions.invoke(endpoint, body: body);
      final result = res.data as Map<String, dynamic>?;

      if (mounted) {
        final tweetUrl =
            result?['tweetLink']?.toString() ?? result?['tweetUrl']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tweetUrl != null ? '✅ X投稿成功! $tweetUrl' : '✅ 投稿完了'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        if (tweetUrl != null) {
          final uri = Uri.tryParse(tweetUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('投稿エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _generateInviteCode() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _supabase.functions.invoke(
        'viral-growth-engine',
        body: {'action': 'generate_invite', 'userId': user.id},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && mounted) {
        final code = data['code']?.toString() ?? '';
        final xUrl = data['xPostUrl']?.toString();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('招待コード生成完了'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'コード: $code',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('友達に共有するとお互いにポイントがもらえます！'),
                const SizedBox(height: 12),
                if (xUrl != null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(xUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Xでシェア'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('招待コード生成エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('バイラル広告ジェネレーター'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: '生成'),
            Tab(icon: Icon(Icons.bar_chart), text: '指標'),
            Tab(icon: Icon(Icons.history), text: '履歴'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _loading && _templates.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneratorTab(isDark),
                _buildStatsTab(isDark),
                _buildHistoryTab(isDark),
              ],
            ),
    );
  }

  Widget _buildGeneratorTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // テンプレート選択
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '広告テンプレート',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    ('dark_war', '⚔️ Dark War風バトル広告', '21競合との戦いを演出'),
                    ('competitor_comparison', '💸 競合比較・コスト削減', '料金比較でお得感を訴求'),
                    ('feature_highlight', '📱 機能ハイライト', '実装済み機能をスピードで紹介'),
                    ('user_growth', '🚀 ユーザー成長ストーリー', '0人から始めたソロ開発'),
                  ].map(
                    (item) =>
                        _buildTemplateCard(item.$1, item.$2, item.$3, isDark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 言語選択
          Row(
            children: [
              const Text('言語: ', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('日本語'),
                selected: _selectedLang == 'ja',
                onSelected: (_) => setState(() => _selectedLang = 'ja'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('English'),
                selected: _selectedLang == 'en',
                onSelected: (_) => setState(() => _selectedLang = 'en'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 生成ボタン
          ElevatedButton.icon(
            onPressed: _loading ? null : _generateAd,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_loading ? '生成中...' : '広告スクリプトを生成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],

          // 生成結果
          if (_generatedAd != null) ...[
            const SizedBox(height: 20),
            _buildGeneratedAdCard(_generatedAd!, isDark),
          ],

          const SizedBox(height: 20),

          // 招待コード生成
          OutlinedButton.icon(
            onPressed: _generateInviteCode,
            icon: const Icon(Icons.person_add),
            label: const Text('招待コードを生成してシェア'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(
    String key,
    String title,
    String desc,
    bool isDark,
  ) {
    final selected = _selectedTemplate == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6366F1).withAlpha(25)
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          border: Border.all(
            color: selected ? const Color(0xFF6366F1) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: const Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedAdCard(Map<String, dynamic> ad, bool isDark) {
    final caption = ad['caption']?.toString() ?? '';
    final hasImage = ad['generatedImageUrl'] != null;
    final imageUrl = ad['generatedImageUrl']?.toString();
    final script = ad['script'] as List? ?? [];

    return Card(
      color: isDark ? Colors.grey[850] : Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Text(
                  '生成された広告',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasImage
                        ? Colors.green.withAlpha(30)
                        : Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasImage ? '🖼️ 画像付き' : '📝 テキストのみ',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasImage ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.image, size: 48, color: const Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('スクリプト:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...script.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child:
                    Text(line.toString(), style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'X投稿キャプション:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              child: Text(
                caption.length > 280
                    ? '${caption.substring(0, 280)}...'
                    : caption,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPosting ? null : _postToX,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isPosting ? '投稿中...' : 'Xに投稿'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // バイラル係数K
          if (_viralStats != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 バイラル指標',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow(
                      'バイラル係数 K',
                      _viralStats!['kFactor']?.toString() ?? '0',
                      '目標: K ≥ 1.0',
                    ),
                    _buildStatRow(
                      '総シェア数',
                      _viralStats!['totalShares']?.toString() ?? '0',
                      '',
                    ),
                    _buildStatRow(
                      '総コンバージョン',
                      _viralStats!['totalConversions']?.toString() ?? '0',
                      '',
                    ),
                    _buildStatRow(
                      'ランディング訪問',
                      _viralStats!['totalViews']?.toString() ?? '0',
                      '',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _viralStats!['current']?.toString() ?? '計測中...',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 最適投稿時間
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⏰ 最適X投稿時間帯 (JST)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [7, 8, 12, 19, 21, 22]
                        .map(
                          (h) => Chip(
                            label: Text('$h:00'),
                            backgroundColor:
                                const Color(0xFF6366F1).withAlpha(25),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Claude Schedule (daily-report) が自動で最適時間に広告を投稿します',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 広告テンプレートローテーション
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔄 広告ローテーション計画',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    ('⚔️ Dark War風', '24時間ごと'),
                    ('💸 競合比較', '48時間ごと'),
                    ('📱 機能紹介', '36時間ごと'),
                    ('🚀 成長ストーリー', '72時間ごと'),
                  ].map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.$1),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 手動で今すぐ自動投稿
          ElevatedButton.icon(
            onPressed: () => _autoPostNow(),
            icon: const Icon(Icons.rocket_launch),
            label: const Text('今すぐ最適広告を自動投稿'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11, color: const Color(0xFF9CA3AF)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: const Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text('まだ広告を生成していません', style: TextStyle(color: const Color(0xFF9CA3AF))),
            SizedBox(height: 8),
            Text(
              '「生成」タブで広告を作成しましょう',
              style: TextStyle(fontSize: 12, color: const Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final templateKey = item['template_key']?.toString() ?? '';
        final status = item['status']?.toString() ?? 'draft';
        final postedAt = item['posted_at']?.toString();
        final tweetUrl = item['posted_tweet_url']?.toString();
        final createdAt = item['created_at']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'posted'
                  ? Colors.green.withAlpha(30)
                  : const Color(0xFF6366F1).withAlpha(25),
              child: Icon(
                status == 'posted' ? Icons.check : Icons.auto_awesome,
                color:
                    status == 'posted' ? Colors.green : const Color(0xFF6366F1),
                size: 20,
              ),
            ),
            title: Text(
              _templateLabel(templateKey),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${item['lang']?.toString().toUpperCase() ?? 'JA'}  |  ${createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt}'
              '${postedAt != null ? '  |  投稿: ${postedAt.substring(0, 10)}' : ''}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: status == 'posted' && tweetUrl != null
                ? IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () async {
                      final uri = Uri.tryParse(tweetUrl);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    tooltip: 'Xで見る',
                  )
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _autoPostNow() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase.functions.invoke(
        'viral-growth-engine',
        body: {'action': 'auto_post_now'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data?['success'] == true ? '✅ 自動投稿完了!' : '⚠️ ${data?['error']}',
            ),
            backgroundColor:
                data?['success'] == true ? Colors.green : Colors.orange,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _templateLabel(String key) {
    switch (key) {
      case 'dark_war':
        return '⚔️ Dark War風バトル広告';
      case 'competitor_comparison':
        return '💸 競合比較・コスト削減';
      case 'feature_highlight':
        return '📱 機能ハイライト';
      case 'user_growth':
        return '🚀 ユーザー成長ストーリー';
      default:
        return key;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'posted':
        return Colors.green;
      case 'ready_to_post':
        return Colors.blue;
      case 'script_only':
        return Colors.orange;
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'posted':
        return '投稿済み';
      case 'ready_to_post':
        return '投稿可能';
      case 'script_only':
        return 'スクリプトのみ';
      default:
        return '下書き';
    }
  }
}
