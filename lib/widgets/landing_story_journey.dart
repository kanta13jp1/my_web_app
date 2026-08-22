import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class LandingStoryChapter {
  final String label;
  final String eyebrow;
  final String title;
  final String body;
  final String note;
  final String assetPath;

  const LandingStoryChapter({
    required this.label,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.note,
    required this.assetPath,
  });
}

/// LP の通常スクロールを 4 章のストーリー進捗へ変換する固定ステージ。
///
/// 親の [ScrollController] を共有するため、入れ子スクロールやホイール操作の
/// 横取りを行わない。背景は独自生成した軽量 WebP で、縮小表示時も同じ意味を
/// 保つようテキストは画像へ焼き込まず Flutter の Semantics 上に残す。
class LandingStoryJourney extends StatefulWidget {
  static const List<LandingStoryChapter> chapters = <LandingStoryChapter>[
    LandingStoryChapter(
      label: '分散',
      eyebrow: '01 · 迷いの正体',
      title: '情報が増えるほど、\n次の一手が遠くなる。',
      body: '予定、メモ、お金、学び。大切な情報が別々の場所に散らばると、判断だけで一日が終わってしまいます。',
      note: '予定 · メモ · 家計 · 学習',
      assetPath: 'assets/landing_journey/01-scattered.webp',
    ),
    LandingStoryChapter(
      label: '集約',
      eyebrow: '02 · ひとつの仕事OSへ',
      title: '人生の情報を、\n一か所へ戻す。',
      body: '仕事・学習・お金・健康を同じ作業空間へ。探す時間を減らし、自分が決めるための全体像をつくります。',
      note: '自分自身を、一つの会社として見る',
      assetPath: 'assets/landing_journey/02-unified.webp',
    ),
    LandingStoryChapter(
      label: '整理',
      eyebrow: '03 · AIが優先順位をつくる',
      title: '複雑さを、\n今日の優先順位へ。',
      body: 'AIが状況を整理し、止まっている理由と最初の確認先を提案。最後に決めるのは、あなたです。',
      note: '整理 · 提案 · 最終判断',
      assetPath: 'assets/landing_journey/03-prioritized.webp',
    ),
    LandingStoryChapter(
      label: '実行',
      eyebrow: '04 · 今日の1件',
      title: 'いま動かす、\n1件だけが見える。',
      body: '短時間で着手できる一手から始め、結果を保存して明日へつなぐ。前進が、毎日の履歴になります。',
      note: '登録前に体験 · 無料登録時カード不要',
      assetPath: 'assets/landing_journey/04-action.webp',
    ),
  ];

  final ScrollController scrollController;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  const LandingStoryJourney({
    super.key,
    required this.scrollController,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  @override
  State<LandingStoryJourney> createState() => _LandingStoryJourneyState();
}

class _LandingStoryJourneyState extends State<LandingStoryJourney> {
  static const double _compactBreakpoint = 720;

  final GlobalKey _trackKey = GlobalKey();
  double _progress = 0;
  double _pinOffset = 0;
  double _maxPinDistance = 0;
  double _lastStageHeight = 0;
  int _activeChapter = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_syncWithScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWithScroll());
  }

  @override
  void didUpdateWidget(covariant LandingStoryJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController == widget.scrollController) return;
    oldWidget.scrollController.removeListener(_syncWithScroll);
    widget.scrollController.addListener(_syncWithScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWithScroll());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWithScroll());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_syncWithScroll);
    super.dispose();
  }

  double _stageHeight(Size viewport, double availableWidth) {
    final compact = availableWidth < _compactBreakpoint;
    final target = viewport.height * (compact ? 0.72 : 0.78);
    return target.clamp(compact ? 500.0 : 560.0, compact ? 660.0 : 720.0);
  }

  void _syncWithScroll() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final trackRenderObject = _trackKey.currentContext?.findRenderObject();
    if (trackRenderObject is! RenderBox || !trackRenderObject.hasSize) return;

    final trackTop = trackRenderObject.localToGlobal(Offset.zero).dy;
    final notificationContext =
        widget.scrollController.position.context.notificationContext;
    final viewportRenderObject = notificationContext?.findRenderObject();
    final viewportTop = viewportRenderObject is RenderBox
        ? viewportRenderObject.localToGlobal(Offset.zero).dy
        : MediaQuery.paddingOf(context).top;
    final stageHeight = _stageHeight(
      MediaQuery.sizeOf(context),
      trackRenderObject.size.width,
    );
    final maxPinDistance = math.max(
      0.0,
      trackRenderObject.size.height - stageHeight,
    );
    final nextPinOffset = (viewportTop + 8 - trackTop).clamp(
      0.0,
      maxPinDistance,
    );
    final nextProgress =
        maxPinDistance == 0 ? 0.0 : nextPinOffset / maxPinDistance;
    final nextActive =
        (nextProgress * (LandingStoryJourney.chapters.length - 1))
            .round()
            .clamp(0, LandingStoryJourney.chapters.length - 1);

    if ((nextProgress - _progress).abs() < 0.001 &&
        (nextPinOffset - _pinOffset).abs() < 0.5 &&
        (maxPinDistance - _maxPinDistance).abs() < 0.5 &&
        nextActive == _activeChapter) {
      return;
    }
    setState(() {
      _progress = nextProgress;
      _pinOffset = nextPinOffset;
      _maxPinDistance = maxPinDistance;
      _activeChapter = nextActive;
    });
  }

  void _goToChapter(int index) {
    if (!widget.scrollController.hasClients || _maxPinDistance <= 0) return;
    final trackRenderObject = _trackKey.currentContext?.findRenderObject();
    if (trackRenderObject is! RenderBox || !trackRenderObject.hasSize) return;

    final position = widget.scrollController.position;
    final notificationContext = position.context.notificationContext;
    final viewportRenderObject = notificationContext?.findRenderObject();
    final viewportTop = viewportRenderObject is RenderBox
        ? viewportRenderObject.localToGlobal(Offset.zero).dy
        : MediaQuery.paddingOf(context).top;
    final trackTop = trackRenderObject.localToGlobal(Offset.zero).dy;
    final trackStartOffset =
        widget.scrollController.offset + trackTop - viewportTop - 8;
    final chapterProgress = index / (LandingStoryJourney.chapters.length - 1);
    final targetOffset = trackStartOffset + (_maxPinDistance * chapterProgress);
    final clampedTarget = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.scrollController.jumpTo(clampedTarget);
      return;
    }
    widget.scrollController.animateTo(
      clampedTarget,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  double _imageOpacity(int index, bool reduceMotion) {
    if (reduceMotion) return index == _activeChapter ? 1 : 0;
    final exact = _progress * (LandingStoryJourney.chapters.length - 1);
    return (1 - (exact - index).abs()).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        final stageHeight = _stageHeight(viewport, constraints.maxWidth);
        final trackHeight = stageHeight * (compact ? 3.35 : 3.75);
        if ((_lastStageHeight - stageHeight).abs() > 0.5) {
          _lastStageHeight = stageHeight;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _syncWithScroll(),
          );
        }

        return Semantics(
          key: const Key('landing_story_journey'),
          container: true,
          label: '自分株式会社で、迷いが今日の1件に変わるまで',
          child: SizedBox(
            key: _trackKey,
            height: trackHeight,
            child: ClipRect(
              child: Stack(
                children: [
                  Transform.translate(
                    offset: Offset(0, _pinOffset),
                    child: SizedBox(
                      height: stageHeight,
                      width: double.infinity,
                      child: _JourneyStage(
                        progress: _progress,
                        activeChapter: _activeChapter,
                        compact: compact,
                        reduceMotion: reduceMotion,
                        imageOpacity: _imageOpacity,
                        onChapterSelected: _goToChapter,
                        onPrimaryAction: widget.onPrimaryAction,
                        onSecondaryAction: widget.onSecondaryAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JourneyStage extends StatelessWidget {
  static const double _mediaWarmupThreshold = 0.02;

  final double progress;
  final int activeChapter;
  final bool compact;
  final bool reduceMotion;
  final double Function(int index, bool reduceMotion) imageOpacity;
  final ValueChanged<int> onChapterSelected;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  const _JourneyStage({
    required this.progress,
    required this.activeChapter,
    required this.compact,
    required this.reduceMotion,
    required this.imageOpacity,
    required this.onChapterSelected,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  Set<int> _visibleMediaIndices() {
    if (reduceMotion) return <int>{activeChapter};

    final exact = progress * (LandingStoryJourney.chapters.length - 1);
    final lower =
        exact.floor().clamp(0, LandingStoryJourney.chapters.length - 1).toInt();
    final upper =
        exact.ceil().clamp(0, LandingStoryJourney.chapters.length - 1).toInt();
    return <int>{
      lower,
      if (upper != lower && exact - lower > _mediaWarmupThreshold) upper,
    };
  }

  @override
  Widget build(BuildContext context) {
    final chapter = LandingStoryJourney.chapters[activeChapter];
    final isFinal = activeChapter == LandingStoryJourney.chapters.length - 1;
    final visibleMediaIndices = _visibleMediaIndices();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF061126),
        borderRadius: BorderRadius.circular(compact ? 18 : 28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102A5C).withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 18 : 28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final index in visibleMediaIndices)
              Positioned.fill(
                key: Key('landing_story_media_$index'),
                child: Opacity(
                  opacity: imageOpacity(index, reduceMotion),
                  child: RepaintBoundary(
                    child: ExcludeSemantics(
                      child: Image.asset(
                        LandingStoryJourney.chapters[index].assetPath,
                        key: Key('landing_story_media_image_$index'),
                        fit: BoxFit.cover,
                        alignment:
                            compact ? Alignment.center : Alignment.centerRight,
                        cacheWidth: compact ? 900 : 1600,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) =>
                            const _JourneyMediaFallback(),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: compact
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x1A020817),
                            Color(0x33020817),
                            Color(0xF2020817),
                          ],
                          stops: [0, 0.42, 0.82],
                        )
                      : const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xF2050C1D),
                            Color(0xD9050C1D),
                            Color(0x33050C1D),
                          ],
                          stops: [0, 0.44, 0.76],
                        ),
                ),
              ),
            ),
            Positioned(
              left: compact ? 18 : 36,
              right: compact ? 18 : 36,
              top: compact ? 16 : 24,
              child: _JourneyTopBar(compact: compact),
            ),
            Positioned(
              left: compact ? 18 : 48,
              right: compact ? 42 : 120,
              top: compact ? null : 0,
              bottom: compact ? 58 : 0,
              child: Align(
                alignment:
                    compact ? Alignment.bottomLeft : Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: reduceMotion
                      ? (child, animation) => child
                      : (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.035),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                  child: _JourneyCopy(
                    key: ValueKey<int>(activeChapter),
                    chapter: chapter,
                    chapterIndex: activeChapter,
                    compact: compact,
                    showActions: isFinal,
                    onPrimaryAction: onPrimaryAction,
                    onSecondaryAction: onSecondaryAction,
                  ),
                ),
              ),
            ),
            Positioned(
              right: compact ? 4 : 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _JourneyRail(
                  activeChapter: activeChapter,
                  compact: compact,
                  reduceMotion: reduceMotion,
                  onChapterSelected: onChapterSelected,
                ),
              ),
            ),
            Positioned(
              left: compact ? 18 : 36,
              right: compact ? 18 : 36,
              bottom: compact ? 18 : 24,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        key: const Key('landing_story_progress'),
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFA85C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${activeChapter + 1} / ${LandingStoryJourney.chapters.length}',
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyMediaFallback extends StatelessWidget {
  const _JourneyMediaFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: Key('landing_story_media_fallback'),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.58, -0.34),
          radius: 1.18,
          colors: [Color(0xFF163553), Color(0xFF061126)],
        ),
      ),
    );
  }
}

class _JourneyTopBar extends StatelessWidget {
  final bool compact;

  const _JourneyTopBar({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 16,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
            gradient: LinearGradient(
              colors: [Color(0xFF70B8FF), Color(0xFFFFA85C)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          '迷いが、今日の1件に変わるまで',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const Spacer(),
        if (!compact)
          const Text(
            'SCROLL TO FOCUS',
            style: TextStyle(
              color: Color(0x99FFFFFF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
      ],
    );
  }
}

class _JourneyCopy extends StatelessWidget {
  final LandingStoryChapter chapter;
  final int chapterIndex;
  final bool compact;
  final bool showActions;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  const _JourneyCopy({
    super.key,
    required this.chapter,
    required this.chapterIndex,
    required this.compact,
    required this.showActions,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('landing_story_chapter_$chapterIndex'),
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 520 : 510),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.eyebrow,
              style: const TextStyle(
                color: Color(0xFF9DD2FF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: compact ? 10 : 18),
            Semantics(
              header: true,
              child: Text(
                chapter.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 30 : 52,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 20),
            Text(
              chapter.body,
              style: TextStyle(
                color: const Color(0xD9FFFFFF),
                fontSize: compact ? 13 : 16,
                height: compact ? 1.55 : 1.75,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text(
                chapter.note,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showActions) ...[
              SizedBox(height: compact ? 14 : 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const Key('landing_story_primary_cta'),
                    onPressed: onPrimaryAction,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('無料で保存を始める'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C42),
                      foregroundColor: const Color(0xFF111827),
                      minimumSize: const Size(184, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('landing_story_secondary_cta'),
                    onPressed: onSecondaryAction,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('登録なしで1件試す'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(184, 48),
                      side: const BorderSide(color: Color(0x80FFFFFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JourneyRail extends StatelessWidget {
  final int activeChapter;
  final bool compact;
  final bool reduceMotion;
  final ValueChanged<int> onChapterSelected;

  const _JourneyRail({
    required this.activeChapter,
    required this.compact,
    required this.reduceMotion,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0;
            index < LandingStoryJourney.chapters.length;
            index++)
          Semantics(
            button: true,
            selected: index == activeChapter,
            label: '${LandingStoryJourney.chapters[index].label}の章へ移動',
            onTap: () => onChapterSelected(index),
            child: ExcludeSemantics(
              child: IconButton(
                key: Key('landing_story_dot_$index'),
                onPressed: () => onChapterSelected(index),
                tooltip: LandingStoryJourney.chapters[index].label,
                icon: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  width: index == activeChapter ? 12 : 7,
                  height: index == activeChapter ? 12 : 7,
                  decoration: BoxDecoration(
                    color: index == activeChapter
                        ? const Color(0xFFFFA85C)
                        : const Color(0x99FFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: index == activeChapter
                        ? const [
                            BoxShadow(
                              color: Color(0x66FFA85C),
                              blurRadius: 10,
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                ),
                color: Colors.white,
                padding: EdgeInsets.all(compact ? 10 : 12),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
          ),
      ],
    );
  }
}
