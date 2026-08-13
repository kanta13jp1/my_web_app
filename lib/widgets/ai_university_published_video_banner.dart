import 'package:flutter/material.dart';

class AiUniversityPublishedVideoBannerItem {
  const AiUniversityPublishedVideoBannerItem({
    required this.title,
    required this.providerLabel,
    required this.onPlay,
  });

  final String title;
  final String providerLabel;
  final VoidCallback onPlay;
}

class AiUniversityPublishedVideoBanner extends StatelessWidget {
  const AiUniversityPublishedVideoBanner({super.key, required this.videos})
      : assert(videos.length > 0);

  final List<AiUniversityPublishedVideoBannerItem> videos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('published-video-banner'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF211A18), Color(0xFF161A24)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.34),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final itemWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VideoBannerHeader(videoCount: videos.length),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var index = 0; index < videos.length; index++)
                        SizedBox(
                          width: itemWidth,
                          child: _VideoLessonTile(
                            index: index,
                            video: videos[index],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoBannerHeader extends StatelessWidget {
  const _VideoBannerHeader({required this.videoCount});

  final int videoCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.smart_display_rounded,
            color: Color(0xFFFF6B35),
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '公開動画で学ぶ',
                    style: TextStyle(
                      color: Color(0xFFF5F5F5),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$videoCount本',
                      style: const TextStyle(
                        color: Color(0xFFFFA07A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                '見たい教材を選んで再生できます',
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoLessonTile extends StatelessWidget {
  const _VideoLessonTile({required this.index, required this.video});

  final int index;
  final AiUniversityPublishedVideoBannerItem video;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF10131B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('published-video-play-button-$index'),
        onTap: video.onPlay,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.providerLabel,
                      style: const TextStyle(
                        color: Color(0xFFFFA07A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFFFF6B35),
                    size: 28,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '今すぐ見る',
                    style: TextStyle(
                      color: Color(0xFFFFA07A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
