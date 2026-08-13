import 'package:flutter/material.dart';

class AiUniversityPublishedVideoBanner extends StatelessWidget {
  const AiUniversityPublishedVideoBanner({
    super.key,
    required this.title,
    required this.providerLabel,
    required this.videoCount,
    required this.onPlay,
  });

  final String title;
  final String providerLabel;
  final int videoCount;
  final VoidCallback onPlay;

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
              final summary = _VideoSummary(
                title: title,
                providerLabel: providerLabel,
                videoCount: videoCount,
              );
              final playButton = SizedBox(
                key: const Key('published-video-play-button'),
                width: compact ? double.infinity : null,
                height: 44,
                child: FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text('今すぐ見る'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: 14),
                    playButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 20),
                  playButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoSummary extends StatelessWidget {
  const _VideoSummary({
    required this.title,
    required this.providerLabel,
    required this.videoCount,
  });

  final String title;
  final String providerLabel;
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
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$providerLabel の公開済み動画教材',
                style: const TextStyle(
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
