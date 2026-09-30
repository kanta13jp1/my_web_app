import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ai_university_curated_videos.dart';
import '../services/ai_university_video_lesson_service.dart';
import '../widgets/ai_university_youtube_embed.dart';

class AiUniversityVideoPage extends StatefulWidget {
  const AiUniversityVideoPage({
    super.key,
    this.initialProvider,
    this.initialCategory,
  });

  final String? initialProvider;
  final String? initialCategory;

  @override
  State<AiUniversityVideoPage> createState() => _AiUniversityVideoPageState();
}

class _AiUniversityVideoPageState extends State<AiUniversityVideoPage> {
  final _supabase = Supabase.instance.client;

  int _curatedVideoIndex = 0;
  bool _loadingCatalog = true;
  bool _generating = false;
  String? _catalogError;
  String? _provider;
  String? _topicId;
  List<String> _providers = const [];
  final Map<String, List<AiUniversityVideoLessonTopic>> _topicsByProvider = {};

  String? _videoUrl;
  String? _videoStatus;
  String? _videoProvider;
  String? _videoReason;
  String? _script;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  List<AiUniversityVideoLessonTopic> get _currentTopics =>
      _topicsByProvider[_provider] ?? const [];

  AiUniversityVideoLessonTopic? get _selectedTopic {
    final id = _topicId;
    if (id == null) return null;
    for (final topic in _currentTopics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });

    try {
      final rows = await _supabase
          .from('ai_university_content')
          .select('provider, category, title, content, source_url')
          .eq('is_active', true)
          .order('provider')
          .order('category')
          .order('title')
          .timeout(const Duration(seconds: 10));

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final raw in (rows as List).cast<Map<String, dynamic>>()) {
        final provider = (raw['provider'] as String? ?? '').trim();
        if (provider.isEmpty) continue;
        grouped.putIfAbsent(provider, () => <Map<String, dynamic>>[]).add(raw);
      }

      final providers = grouped.keys.toList()..sort();
      final topicsByProvider = <String, List<AiUniversityVideoLessonTopic>>{};
      for (final provider in providers) {
        topicsByProvider[provider] =
            AiUniversityVideoLessonService.topicsFromRows(grouped[provider]!);
      }

      final initialProvider = providers.contains(widget.initialProvider)
          ? widget.initialProvider
          : (providers.isNotEmpty ? providers.first : null);
      final initialTopic = initialProvider == null
          ? null
          : AiUniversityVideoLessonService.pickInitialTopic(
              topicsByProvider[initialProvider] ?? const [],
              preferredCategory: widget.initialCategory,
            );

      if (!mounted) return;
      setState(() {
        _providers = providers;
        _topicsByProvider
          ..clear()
          ..addAll(topicsByProvider);
        _provider = initialProvider;
        _topicId = initialTopic?.id;
        _loadingCatalog = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _catalogError = '$error';
      });
    }
  }

  Future<void> _generateVideoLesson() async {
    final user = _supabase.auth.currentUser;
    final topic = _selectedTopic;
    if (user == null) {
      setState(() {
        _generationError = '動画レッスン生成はログイン後に利用できます。';
      });
      return;
    }
    if (_provider == null || topic == null || _generating) return;

    final providerLabel =
        AiUniversityVideoLessonService.providerLabel(_provider!);
    final prompt = AiUniversityVideoLessonService.buildHeyGenV3Prompt(
      providerLabel: providerLabel,
      topic: topic,
    );

    setState(() {
      _generating = true;
      _generationError = null;
      _videoUrl = null;
      _videoStatus = null;
      _videoProvider = null;
      _videoReason = null;
      _script = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'my_agent.chat',
          'message': prompt,
          'response_mode': 'video',
          'title': 'AI University Lesson: ${topic.title}',
          'voice': 'ja-JP',
          'conversation_context': 'ai_university_lesson',
        },
      );
      final data = response.data as Map<String, dynamic>? ?? const {};
      final video = data['video'] as Map<String, dynamic>? ?? const {};

      if (!mounted) return;
      setState(() {
        _generating = false;
        _script = data['response']?.toString();
        _videoUrl = video['video_url']?.toString() ??
            video['download_url']?.toString() ??
            video['preview_url']?.toString();
        _videoStatus = video['status']?.toString();
        _videoProvider = video['provider']?.toString();
        _videoReason = video['reason']?.toString();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _generationError = '$error';
      });
    }
  }

  Future<void> _openUrl(String rawUrl) async {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return;
    final uri = parsed.hasScheme ? parsed : Uri.base.resolveUri(parsed);
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('HeyGen v3設計をコピーしました'),
        backgroundColor: Color(0xFF26A69A),
      ),
    );
  }

  void _onProviderChanged(String? value) {
    if (value == null) return;
    final topic = AiUniversityVideoLessonService.pickInitialTopic(
      _topicsByProvider[value] ?? const [],
    );
    setState(() {
      _provider = value;
      _topicId = topic?.id;
      _videoUrl = null;
      _videoStatus = null;
      _videoProvider = null;
      _videoReason = null;
      _script = null;
      _generationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFF0A0A0A);
    const surface1 = Color(0xFF1A1A1A);
    const surface2 = Color(0xFF1E1E1E);
    const accent = Color(0xFFFF6B35);
    final topic = _selectedTopic;
    final curatedVideo = aiUniversityCuratedVideos[_curatedVideoIndex];
    final youtubeVideoId = topic?.youtubeVideoId;
    final providerLabel = _provider == null
        ? null
        : AiUniversityVideoLessonService.providerLabel(_provider!);
    final v3Plan = topic == null || providerLabel == null
        ? null
        : AiUniversityVideoLessonService.buildHeyGenV3Plan(
            providerLabel: providerLabel,
            topic: topic,
          );

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: surface1,
        foregroundColor: Colors.white,
        title: const Text(
          'AI大学 動画レッスン',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.5),
        ),
      ),
      body: _loadingCatalog
          ? const Center(child: CircularProgressIndicator(color: accent))
          : RefreshIndicator(
              onRefresh: _loadCatalog,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CuratedVideoLibrary(
                    selectedIndex: _curatedVideoIndex,
                    video: curatedVideo,
                    onSelected: (index) => setState(
                      () => _curatedVideoIndex = index,
                    ),
                    onOpen: () => _openUrl(curatedVideo.sourceUrl),
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    title: 'テキスト教材をアバター動画に変換',
                    subtitle:
                        'AI大学の教材をもとに、各プロバイダーごとの短い動画レッスンを生成します。動画化に失敗したときも、生成スクリプトは確認できます。',
                    accent: accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_supabase.auth.currentUser == null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFC107)
                                    .withValues(alpha: 0.28),
                              ),
                            ),
                            child: const Text(
                              'ログインすると動画レッスンを生成できます。教材のプレビューはこのまま確認できます。',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                        if (_catalogError != null)
                          Text(
                            '教材読み込みエラー: $_catalogError',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectorCard(
                    title: 'プロバイダー',
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_provider),
                      initialValue: _provider,
                      dropdownColor: surface2,
                      decoration: _inputDecoration('AIプロバイダーを選択'),
                      style: const TextStyle(color: Colors.white, height: 1.5),
                      items: _providers
                          .map(
                            (provider) => DropdownMenuItem(
                              value: provider,
                              child: Text(
                                AiUniversityVideoLessonService.providerLabel(
                                  provider,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onProviderChanged,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectorCard(
                    title: '教材トピック',
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_topicId),
                      initialValue: _topicId,
                      dropdownColor: surface2,
                      decoration: _inputDecoration('動画にする教材を選択'),
                      style: const TextStyle(color: Colors.white, height: 1.5),
                      items: _currentTopics
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${AiUniversityVideoLessonService.categoryLabel(item.category)} / ${item.title}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _topicId = value;
                        _videoUrl = null;
                        _videoStatus = null;
                        _videoProvider = null;
                        _videoReason = null;
                        _script = null;
                        _generationError = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (topic != null && youtubeVideoId != null) ...[
                    _InfoCard(
                      title: '公開済み動画を視聴',
                      subtitle:
                          '${AiUniversityVideoLessonService.categoryLabel(topic.category)} / ${topic.title}',
                      accent: const Color(0xFFFF0000),
                      child: AiUniversityYoutubeEmbed(
                        key: ValueKey(topic.id),
                        videoId: youtubeVideoId,
                        title: topic.title,
                        onOpen: () => _openUrl(topic.sourceUrl ?? ''),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generating ? null : _generateVideoLesson,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _generating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.videocam_outlined),
                      label: Text(_generating ? '動画レッスン生成中...' : '動画レッスンを生成'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (topic != null)
                    _InfoCard(
                      title: '今回の教材プレビュー',
                      subtitle:
                          '${AiUniversityVideoLessonService.categoryLabel(topic.category)} / ${topic.title}',
                      accent: const Color(0xFF3D5AFE),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AiUniversityVideoLessonService.previewText(
                              topic.content,
                              maxChars: 320,
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.7,
                            ),
                          ),
                          if (topic.sourceUrl != null &&
                              topic.sourceUrl!.trim().isNotEmpty &&
                              youtubeVideoId == null) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () => _openUrl(topic.sourceUrl ?? ''),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('ソースを開く'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF90CAF9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (v3Plan != null) ...[
                    const SizedBox(height: 12),
                    _HeyGenV3PlanCard(
                      plan: v3Plan,
                      onCopy: () => _copyToClipboard(v3Plan.clipboardText),
                    ),
                  ],
                  if (_generationError != null) ...[
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: '生成エラー',
                      subtitle: _generationError,
                      accent: Colors.redAccent,
                    ),
                  ],
                  if (_script != null ||
                      _videoStatus != null ||
                      _videoUrl != null ||
                      _videoReason != null) ...[
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: '生成結果',
                      subtitle: _videoProvider == null
                          ? 'Hedra動画応答'
                          : 'Hedra動画応答 / $_videoProvider',
                      accent: accent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (_videoStatus != null)
                                _StatusChip(
                                  label: _videoStatus!,
                                  color: accent,
                                ),
                              if (_videoUrl != null &&
                                  _videoUrl!.trim().isNotEmpty)
                                const _StatusChip(
                                  label: '動画URLあり',
                                  color: Color(0xFF26A69A),
                                ),
                              if ((_videoStatus ?? '') == 'fallback_text')
                                const _StatusChip(
                                  label: 'テキストへフォールバック',
                                  color: Color(0xFFFFC107),
                                ),
                            ],
                          ),
                          if (_videoReason != null &&
                              _videoReason!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _videoReason!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ],
                          if (_videoUrl != null &&
                              _videoUrl!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _openUrl(_videoUrl!),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('動画を開く'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                              ),
                            ),
                          ],
                          if (_script != null &&
                              _script!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: surface2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                _script!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, height: 1.5),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B35)),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
    );
  }
}

class _CuratedVideoLibrary extends StatelessWidget {
  const _CuratedVideoLibrary({
    required this.selectedIndex,
    required this.video,
    required this.onSelected,
    required this.onOpen,
  });

  final int selectedIndex;
  final AiUniversityCuratedVideo video;
  final ValueChanged<int> onSelected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '公開済みAI大学動画',
      subtitle: '理念ページから移管したAI学習教材です。理念動画とは分けて、ここで選んで視聴できます。',
      accent: const Color(0xFF3D5AFE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(
                aiUniversityCuratedVideos.length,
                (index) {
                  final candidate = aiUniversityCuratedVideos[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('ai_university_curated_${candidate.id}'),
                      label: Text('${candidate.title} • ${candidate.duration}'),
                      selected: selectedIndex == index,
                      onSelected: (_) => onSelected(index),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            video.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          if (video.youtubeVideoId case final videoId?)
            AiUniversityYoutubeEmbed(
              key: ValueKey(video.id),
              videoId: videoId,
              title: video.title,
              onOpen: onOpen,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.smart_display_rounded,
                    color: Color(0xFFFF6B35),
                    size: 52,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'サイト内の公開動画を再生します',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('動画を開く'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeyGenV3PlanCard extends StatelessWidget {
  const _HeyGenV3PlanCard({
    required this.plan,
    required this.onCopy,
  });

  final AiUniversityVideoV3Plan plan;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_display, color: Color(0xFF26A69A)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'HeyGen AI大学 v3 設計',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('コピー'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF80CBC4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.learningGoal,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              plan.heygenBrief,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...plan.scenes.map(
            (scene) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.label,
                      style: const TextStyle(
                        color: Color(0xFF80CBC4),
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scene.narration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scene.onScreenText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plan.localizationNotes
                .map(
                  (note) => Chip(
                    label: Text(note),
                    backgroundColor:
                        const Color(0xFF26A69A).withValues(alpha: 0.14),
                    side: BorderSide(
                      color: const Color(0xFF26A69A).withValues(alpha: 0.24),
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.accent,
    this.subtitle,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}
