import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/ai_university_video_lesson_service.dart';
import '../utils/platform_view.dart' as platform_view;

class AiUniversityYoutubeEmbed extends StatefulWidget {
  const AiUniversityYoutubeEmbed({
    super.key,
    required this.videoId,
    required this.title,
    required this.onOpen,
    this.maxPlayerHeight,
  });

  final String videoId;
  final String title;
  final VoidCallback onOpen;

  /// Height available for the picture, excluding the controls below it.
  final double? maxPlayerHeight;

  @override
  State<AiUniversityYoutubeEmbed> createState() =>
      _AiUniversityYoutubeEmbedState();
}

class _AiUniversityYoutubeEmbedState extends State<AiUniversityYoutubeEmbed> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant AiUniversityYoutubeEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) _registerView();
  }

  void _registerView() {
    _viewType =
        'ai-university-youtube-${widget.videoId}-${identityHashCode(this)}';
    if (!kIsWeb) return;
    platform_view.registerIframeViewFactory(
      _viewType,
      AiUniversityVideoLessonService.youtubeEmbedUrl(widget.videoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.title}のYouTube埋め込み動画',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final heightLimit = widget.maxPlayerHeight ??
                  MediaQuery.sizeOf(context).height * 0.6;
              final width =
                  math.min(constraints.maxWidth, heightLimit * 16 / 9);
              return Center(
                child: SizedBox(
                  width: width,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: kIsWeb
                          ? HtmlElementView(viewType: _viewType)
                          : Container(
                              color: const Color(0xFF111827),
                              alignment: Alignment.center,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.smart_display_rounded,
                                      color: Color(0xFFFF6B35),
                                      size: 52,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'YouTubeで動画を再生できます',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.28),
                  ),
                ),
                child: const Text(
                  'YouTube 教材',
                  style: TextStyle(
                    color: Color(0xFFFF8A80),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onOpen,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('YouTubeで開く'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF90CAF9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
