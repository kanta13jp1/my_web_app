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

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VideoBannerHeader(videoCount: videos.length),
                  const SizedBox(height: 14),
                  if (compact)
                    SizedBox(
                      key: const Key('published-video-mobile-carousel'),
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: videos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: (constraints.maxWidth * 0.82).clamp(
                              220.0,
                              340.0,
                            ),
                            child: _VideoLessonTile(
                              index: index,
                              video: videos[index],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    _DesktopVideoGrid(videos: videos),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopVideoGrid extends StatefulWidget {
  const _DesktopVideoGrid({required this.videos});

  final List<AiUniversityPublishedVideoBannerItem> videos;

  @override
  State<_DesktopVideoGrid> createState() => _DesktopVideoGridState();
}

class _DesktopVideoGridState extends State<_DesktopVideoGrid> {
  static const _itemHeight = 86.0;
  static const _spacing = 12.0;
  static const _maxVisibleRows = 2;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowCount = (widget.videos.length + 1) ~/ 2;
    final contentHeight = rowCount * _itemHeight + (rowCount - 1) * _spacing;
    const maxHeight =
        _maxVisibleRows * _itemHeight + (_maxVisibleRows - 1) * _spacing;
    final viewportHeight = contentHeight.clamp(0.0, maxHeight).toDouble();
    final isScrollable = rowCount > _maxVisibleRows;

    return SizedBox(
      key: const Key('published-video-desktop-grid'),
      height: viewportHeight,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: isScrollable,
        interactive: true,
        thickness: 6,
        radius: const Radius.circular(999),
        child: GridView.builder(
          key: const Key('published-video-desktop-scroll-view'),
          controller: _scrollController,
          primary: false,
          padding: EdgeInsets.only(right: isScrollable ? 12 : 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: _itemHeight,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
          ),
          itemCount: widget.videos.length,
          itemBuilder: (context, index) =>
              _VideoLessonTile(index: index, video: widget.videos[index]),
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
