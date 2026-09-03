import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hedra_audio_start.dart';
import '../models/hedra_video_batch.dart';
import '../models/kgi_csf_kpi.dart';
import '../services/heygen_multilingual_sns_service.dart';
import '../services/viral_ad_legacy_history_service.dart';
import '../services/x_post_attribution.dart';
import '../widgets/kgi_csf_kpi_panel.dart';
import '../widgets/hedra_audio_start_field.dart';
import '../widgets/hedra_batch_selector.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// バイラル広告ジェネレーターページ
/// viral-video-ad-generator / growth-hub (x.post / engine.run / engine.stats) と連携
/// Dark War風動画広告の生成・X投稿・バイラル指標を管理
class ViralAdGeneratorPage extends StatefulWidget {
  const ViralAdGeneratorPage({super.key});

  @override
  State<ViralAdGeneratorPage> createState() => _ViralAdGeneratorPageState();
}

class _ViralAdGeneratorPageState extends State<ViralAdGeneratorPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['generator', 'stats', 'history'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  late final ViralAdLegacyHistoryService _legacyHistoryService;

  bool _loading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _history = [];
  List<ViralAdLegacyHistoryEntry> _legacyHistory = [];
  List<String> _legacyHistoryWarnings = [];
  Map<String, dynamic>? _generatedAd;
  Map<String, dynamic>? _viralStats;

  String _selectedTemplate = 'dark_war';
  String _selectedLang = 'ja';
  String _selectedOutputType = 'image';
  int _hedraBatchSize = 1;
  String _hedraAudioStartInput = '0';
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _legacyHistoryService = ViralAdLegacyHistoryService(client: _supabase);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
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
          'growth-hub',
          body: {'action': 'engine.stats'},
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
          () => _viralStats =
              (statsData['stats'] ?? statsData) as Map<String, dynamic>?,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'データ取得エラー: $e');
    } finally {
      await _loadLegacyHistory();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLegacyHistory() async {
    final result = await _legacyHistoryService.load();
    if (!mounted) return;
    setState(() {
      _legacyHistory = result.entries;
      _legacyHistoryWarnings = result.warnings;
    });
  }

  Future<void> _generateAd() async {
    final hedraAudioStartMs = _selectedOutputType == 'presenter_video'
        ? parseHedraAudioStartMs(_hedraAudioStartInput)
        : 0;
    if (hedraAudioStartMs == null) {
      setState(
        () => _errorMessage =
            '音声開始オフセットは$hedraAudioStartMinMs〜$hedraAudioStartMaxMs msの整数で入力してください。',
      );
      return;
    }
    if (!await _confirmHedraBatchCost()) return;
    final previousImageUrl = _generatedAd?['generatedImageUrl']?.toString();
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
          'type': _selectedOutputType,
          'batchSize':
              _selectedOutputType == 'presenter_video' ? _hedraBatchSize : 1,
          'confirmBatchCost':
              _selectedOutputType == 'presenter_video' && _hedraBatchSize > 1,
          'audioStartMs': hedraAudioStartMs,
          if (previousImageUrl != null && previousImageUrl.isNotEmpty)
            'generatedImageUrl': previousImageUrl,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() => _generatedAd = data);
        _tabController.animateTo(0);
        await _pollPendingHedraBatch(data);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '生成エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmHedraBatchCost() async {
    if (_selectedOutputType != 'presenter_video' || _hedraBatchSize == 1) {
      return true;
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('$_hedraBatchSize件の動画を生成しますか？'),
            content: Text(
              'Hedraへ$_hedraBatchSize件を一括送信します。'
              '1件生成と比べてクレジット消費と待ち時間が増えます。'
              'この操作を続ける場合だけ「生成する」を選んでください。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('生成する'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pollPendingHedraBatch(Map<String, dynamic> initial) async {
    var current = initial;
    for (var attempt = 0; attempt < 6; attempt += 1) {
      final batch = HedraVideoBatch.fromMap(current);
      if (!batch.isBatch || !batch.isPending || batch.generationIds.isEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 6));
      if (!mounted) return;
      final response = await _supabase.functions.invoke(
        'viral-video-ad-generator',
        body: {
          'template': current['template'] ?? _selectedTemplate,
          'lang': current['lang'] ?? _selectedLang,
          'type': 'presenter_video',
          'batchSize': batch.requestedSize,
          'hedraGenerationIds': batch.generationIds,
          'hedraBatchGenerationId': batch.batchGenerationId,
          if (current['generatedImageUrl'] != null)
            'generatedImageUrl': current['generatedImageUrl'],
        },
      );
      if (response.data is! Map) return;
      current = Map<String, dynamic>.from(response.data as Map);
      setState(() => _generatedAd = current);
    }
  }

  Future<void> _postToX() async {
    if (_generatedAd == null) return;
    setState(() => _isPosting = true);
    try {
      final caption = _generatedAd!['caption']?.toString() ?? '';
      final imageUrl = _generatedAd!['generatedImageUrl']?.toString();
      final videoUrl = _generatedAd!['generatedVideoUrl']?.toString();

      final mediaUrl =
          (videoUrl != null && videoUrl.isNotEmpty) ? videoUrl : imageUrl;
      final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;

      final tracking = buildViralAdXPostAttribution(
        videoUrl: videoUrl,
        imageUrl: imageUrl,
      );

      // 旧 post-x-update / x-media-post は EF 統合で削除済み (呼ぶと 404)。
      // growth-hub x.post が text / media 両方を 1 action で受ける
      // (= universal_x_share_service と同じ経路)。
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'x.post',
          'text': caption.length > 280 ? caption.substring(0, 280) : caption,
          'mediaUrl': hasMedia ? mediaUrl : null,
          'source': 'viral_ad_generator',
          'contentKind': hasMedia ? 'media' : 'text',
          ...tracking,
        },
      );
      final result = res.data as Map<String, dynamic>?;
      // 旧実装は success を見ずに tweetLink だけ読んでいたため、
      // 失敗レスポンスでも「投稿完了」と表示されていた。
      if (result?['success'] != true) {
        throw Exception(result?['error']?.toString() ?? 'X post failed');
      }

      if (mounted) {
        final tweetId = result?['tweetId']?.toString();
        final tweetUrl = (tweetId != null && tweetId.isNotEmpty)
            ? 'https://x.com/i/web/status/$tweetId'
            : null;
        // posted=false は dryRun か X 認証情報の未設定。success=true で返るので、
        // ここを分けないと「投稿していないのに投稿成功」と表示されてしまう。
        final posted = result?['posted'] == true;
        final warning = result?['warning']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !posted
                  ? '⚠️ 未投稿: ${warning ?? 'dryRun または X 認証情報が未設定です'}'
                  : tweetUrl != null
                      ? '✅ X投稿成功! $tweetUrl'
                      : '✅ 投稿完了',
            ),
            backgroundColor:
                posted ? const Color(0xFF4CAF50) : const Color(0xFFF59E0B),
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
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _copyToClipboard(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
  }

  Future<void> _openXComposer(String text) async {
    final uri = Uri.https('twitter.com', '/intent/tweet', {'text': text});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _generateInviteCode() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {'action': 'engine.run', 'trigger': 'invite', 'target': user.id},
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
                    height: 1.5,
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
            backgroundColor: const Color(0xFFE53935),
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
    final previousImageUrl = _generatedAd?['generatedImageUrl']?.toString();
    final presenterNeedsImage = _selectedOutputType == 'presenter_video' &&
        (previousImageUrl == null || previousImageUrl.isEmpty);
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
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
              const Text(
                '言語: ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '出力: ',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('画像広告'),
                selected: _selectedOutputType == 'image',
                onSelected: (_) =>
                    setState(() => _selectedOutputType = 'image'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('プレゼンター動画'),
                selected: _selectedOutputType == 'presenter_video',
                onSelected: (_) => setState(
                  () => _selectedOutputType = 'presenter_video',
                ),
              ),
            ],
          ),
          if (_selectedOutputType == 'presenter_video') ...[
            const SizedBox(height: 16),
            HedraAudioStartField(
              value: _hedraAudioStartInput,
              enabled: !_loading,
              onChanged: (value) => _hedraAudioStartInput = value,
            ),
            const SizedBox(height: 16),
            HedraBatchSelector(
              value: _hedraBatchSize,
              enabled: !_loading,
              onChanged: (value) => setState(() => _hedraBatchSize = value),
            ),
            const SizedBox(height: 8),
            const Text(
              '複数生成では各動画を同じ batch_generation_id の履歴グループとして保存します。',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 16),

          if (presenterNeedsImage) ...[
            const Text(
              'プレゼンター動画には開始画像が必要です。先に「画像広告」を1件生成してから動画を選んでください。',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 生成ボタン
          ElevatedButton.icon(
            onPressed: _loading || presenterNeedsImage ? null : _generateAd,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _loading
                  ? '生成中...'
                  : _selectedOutputType == 'presenter_video'
                      ? 'プレゼンター動画を生成'
                      : '広告を生成',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFE53935),
                height: 1.5,
              ),
            ),
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
              : (isDark ? const Color(0xFF424242) : const Color(0xFFF5F5F5)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
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
    final imageUrl = ad['generatedImageUrl']?.toString();
    final hedraBatch = HedraVideoBatch.fromMap(ad);
    final videoUrl = hedraBatch.videoUrls.isNotEmpty
        ? hedraBatch.videoUrls.first
        : ad['generatedVideoUrl']?.toString();
    final videoStatus = ad['videoStatus']?.toString();
    final videoReason = ad['videoReason']?.toString();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final script = ad['script'] as List? ?? [];
    final mediaReady = hasVideo || hasImage;

    return Card(
      color: isDark ? const Color(0xFF303030) : const Color(0xFFE8EAF6),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasVideo
                        ? const Color(0xFF7C3AED).withAlpha(30)
                        : hasImage
                            ? const Color(0xFF4CAF50).withAlpha(30)
                            : const Color(0xFFFF6B35).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasVideo
                        ? '🎬 プレゼンター動画'
                        : hasImage
                            ? '🖼️ 画像付き'
                            : '📝 テキストのみ',
                    style: TextStyle(
                      fontSize: 11,
                      color: hasVideo
                          ? const Color(0xFF7C3AED)
                          : hasImage
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF6B35),
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (hedraBatch.isBatch) ...[
              const SizedBox(height: 12),
              _buildHedraBatchResults(hedraBatch, isDark),
            ] else if (hasVideo) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.videocam_outlined,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            videoStatus == null || videoStatus.isEmpty
                                ? 'Hedra プレゼンター動画'
                                : 'Hedra プレゼンター動画 / $videoStatus',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(videoUrl);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('動画を開く'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (hasImage) ...[
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
                      child: Icon(
                        Icons.image,
                        size: 48,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (!hasVideo && videoReason != null && videoReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A1F0A)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Text(
                  '動画生成メモ: $videoReason',
                  style: const TextStyle(
                    color: Color(0xFF8A4B00),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'スクリプト:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            ...script.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'X投稿キャプション:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
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
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            ..._buildHeyGenMultilingualSnsSection(ad, isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPosting || !mediaReady ? null : _postToX,
                    icon: _isPosting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isPosting
                          ? '投稿中...'
                          : mediaReady
                              ? 'Xに投稿'
                              : 'メディア準備待ち',
                    ),
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

  Widget _buildHedraBatchResults(HedraVideoBatch batch, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 680
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.video_collection_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hedra バッチ ${batch.requestedSize}件'
                    '${batch.isPending ? '（生成中）' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (batch.batchGenerationId != null) ...[
              const SizedBox(height: 4),
              SelectableText(
                'グループID: ${batch.batchGenerationId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < batch.variants.length; index += 1)
                  SizedBox(
                    width: cardWidth,
                    child: _buildHedraVariantCard(
                      batch.variants[index],
                      index,
                      isDark,
                    ),
                  ),
              ],
            ),
            if (batch.videoUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'X投稿では先頭の完成動画を使用します。各バリエーションは個別に開いて比較できます。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHedraVariantCard(
    HedraVideoVariant variant,
    int index,
    bool isDark,
  ) {
    final openUrl = variant.videoUrl ?? variant.previewUrl;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'バリエーション ${index + 1} / ${variant.status}',
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5),
          ),
          if (variant.id != null)
            Text(
              'ID: ${variant.id}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          if (openUrl != null)
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(openUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('プレビューを開く'),
            )
          else
            Row(
              children: [
                if (variant.isPending) ...[
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    variant.reason ?? '動画URLを待っています',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildHeyGenMultilingualSnsSection(
    Map<String, dynamic> ad,
    bool isDark,
  ) {
    final caption = ad['caption']?.toString() ?? '';
    final rawScript = ad['script'] as List? ?? const <Object?>[];
    final script = rawScript
        .map((line) => line.toString().trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (caption.trim().isEmpty && script.isEmpty) return const [];

    final kit = HeyGenMultilingualSnsService.buildKit(
      templateKey: ad['template']?.toString() ?? _selectedTemplate,
      sourceLanguage: ad['lang']?.toString() ?? _selectedLang,
      caption: caption,
      script: script,
    );
    final borderColor = Theme.of(context).colorScheme.surfaceContainerHighest;

    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'HeyGen 多言語SNS展開',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copyToClipboard(
                    kit.allPostsForClipboard,
                    '全言語のSNS投稿をコピーしました',
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('一括コピー'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '生成済み広告を HeyGen のリップシンク翻訳に流し込む前提で、各国向けの短尺動画原稿とSNS投稿文を自動展開します。',
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFD1D5DB) : const Color(0xFF475569),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kit.variants
                  .map(
                    (variant) => Chip(
                      label: Text(variant.localeLabel),
                      backgroundColor: const Color(0xFF0EA5E9).withAlpha(24),
                      side: BorderSide(
                        color: const Color(0xFF0EA5E9).withAlpha(64),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            ...kit.variants.map(
              (variant) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    title: Text(
                      variant.localeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    subtitle: Text(
                      variant.audienceHook,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                    children: [
                      _buildVariantTextBlock(
                        'HeyGen指示',
                        variant.heygenBrief,
                        isDark,
                      ),
                      _buildVariantTextBlock(
                        '動画原稿',
                        variant.videoScript.join('\n'),
                        isDark,
                      ),
                      _buildVariantTextBlock('X投稿', variant.xPost, isDark),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copyToClipboard(
                              variant.clipboardBundle,
                              '${variant.localeLabel}の投稿キットをコピーしました',
                            ),
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('コピー'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openXComposer(variant.xPost),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Xで開く'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildVariantTextBlock(String label, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              text,
              style: const TextStyle(fontSize: 12, height: 1.45),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    KgiCsfKpiPanel(
                      plan: _buildViralKgiPlan(_viralStats!),
                      accentColor: const Color(0xFF6366F1),
                      initiallyExpanded: true,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
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
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                              height: 1.5,
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
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  KgiCsfKpiPlan _buildViralKgiPlan(Map<String, dynamic> stats) {
    final kFactor = _readStatNum(stats['kFactor']);
    final shares = _readStatNum(stats['totalShares']);
    final conversions = _readStatNum(stats['totalConversions']);
    final views = _readStatNum(stats['totalViews']);
    final conversionRate = views <= 0 ? 0.0 : conversions / views * 100;
    return KgiCsfKpiPlan(
      domain: 'バイラル広告',
      kgi: 'Kファクター1.0以上で自走する獲得ループを作る',
      actualLabel: 'K ${kFactor.toStringAsFixed(2)}',
      targetLabel: 'K 1.00以上',
      progress: kFactor.clamp(0, 1).toDouble(),
      metrics: <KgiCsfKpiMetric>[
        KgiCsfKpiMetric.number(
          csf: '拡散量',
          kpi: '総シェア数',
          actual: shares,
          target: 100,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '獲得効率',
          kpi: '総コンバージョン',
          actual: conversions,
          target: 25,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '導線母数',
          kpi: 'ランディング訪問',
          actual: views,
          target: 1000,
          unit: '件',
        ),
        KgiCsfKpiMetric.number(
          csf: '訴求品質',
          kpi: 'CVR',
          actual: conversionRate,
          target: 2.5,
          unit: '%',
        ),
      ],
    );
  }

  double _readStatNum(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
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
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_history.isEmpty &&
        _legacyHistory.isEmpty &&
        _legacyHistoryWarnings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'まだ広告を生成していません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '「生成」タブで広告を作成しましょう',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_history.isNotEmpty) ...[
          Text('現在の広告履歴', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in _history) _buildCurrentHistoryCard(item),
        ],
        if (_legacyHistory.isNotEmpty) ...[
          if (_history.isNotEmpty) const SizedBox(height: 16),
          Text('旧ツールの生成履歴', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '統合前の「動画広告」「バイラル動画」で保存した履歴です。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final item in _legacyHistory) _buildLegacyHistoryCard(item),
        ],
        if (_legacyHistoryWarnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('旧ツール履歴の一部を取得できませんでした'),
              subtitle: Text(_legacyHistoryWarnings.join('\n')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentHistoryCard(Map<String, dynamic> item) {
    final templateKey = item['template_key']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'draft';
    final type = item['type']?.toString() ?? 'image';
    final postedAt = item['posted_at']?.toString();
    final tweetUrl = item['posted_tweet_url']?.toString();
    final hedraBatch = HedraVideoBatch.fromMap(item);
    final generatedVideoUrl = hedraBatch.videoUrls.isNotEmpty
        ? hedraBatch.videoUrls.first
        : item['generated_video_url']?.toString();
    final createdAt = item['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status == 'posted'
              ? const Color(0xFF4CAF50).withAlpha(30)
              : const Color(0xFF6366F1).withAlpha(25),
          child: Icon(
            status == 'posted' ? Icons.check : Icons.auto_awesome,
            color: status == 'posted'
                ? const Color(0xFF4CAF50)
                : const Color(0xFF6366F1),
            size: 20,
          ),
        ),
        title: Text(
          '${_templateLabel(templateKey)}'
          '${type == 'presenter_video' ? ' / 動画' : ' / 画像'}'
          '${hedraBatch.isBatch ? ' / ${hedraBatch.requestedSize}件バッチ' : ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          '${item['lang']?.toString().toUpperCase() ?? 'JA'}  |  '
          '${_shortDate(createdAt)}'
          '${postedAt != null ? '  |  投稿: ${_shortDate(postedAt)}' : ''}'
          '${hedraBatch.batchGenerationId != null ? '  |  グループ: ${hedraBatch.batchGenerationId}' : ''}',
          style: const TextStyle(
            fontSize: 11,
            height: 1.5,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (generatedVideoUrl != null && generatedVideoUrl.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.videocam_outlined, size: 18),
                onPressed: () async {
                  final uri = Uri.tryParse(generatedVideoUrl);
                  if (uri != null) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                tooltip: '動画を開く',
              ),
            if (status == 'posted' && tweetUrl != null)
              IconButton(
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
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyHistoryCard(ViralAdLegacyHistoryEntry item) {
    final createdAt = item.createdAt?.toIso8601String() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.history, size: 20)),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${item.sourceLabel}  |  ${item.detail}  |  '
          '${_statusLabel(item.status)}'
          '${createdAt.isEmpty ? '' : '  |  ${_shortDate(createdAt)}'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _autoPostNow() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {'action': 'engine.run', 'trigger': 'auto_post'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data?['success'] == true ? '✅ 自動投稿完了!' : '⚠️ ${data?['error']}',
            ),
            backgroundColor: data?['success'] == true
                ? const Color(0xFF4CAF50)
                : const Color(0xFFFF6B35),
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
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
        return const Color(0xFF4CAF50);
      case 'ready_to_post':
        return const Color(0xFF3D5AFE);
      case 'script_only':
        return const Color(0xFFFF6B35);
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

  String _shortDate(String raw) =>
      raw.length >= 10 ? raw.substring(0, 10) : raw;
}
