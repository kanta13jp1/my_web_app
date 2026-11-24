import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/services/guitar_metronome_audio_service.dart';
import '../../../../data/services/structured_tab_catalog_service.dart';
import '../../../../data/services/structured_tab_pdf_service.dart';
import '../../../../data/services/user_structured_tab_storage_service.dart';
import '../../../../domain/models/guitar_daily_course.dart';
import '../../../../domain/models/guitar_tab_song.dart';
import '../../../../theme/design_tokens.dart';
import '../view_models/beatles_guitar_tabs_view_model.dart';
import 'widgets/guitar_tab_staff.dart';
import 'widgets/structured_tab_studio_panel.dart';

/// dark surface2(#1E1E1E)・surface3(#2A2A2A) 上で WCAG 2.1 AA (4.5:1 以上) を満たす補助文字色。
const Color _mutedAccessibleText = Color(0xFF9CA3AF);

class BeatlesGuitarTabsPage extends StatefulWidget {
  const BeatlesGuitarTabsPage({
    super.key,
    this.structuredCatalogService,
    this.userTabStorageService,
    this.pdfService,
    this.metronomeAudioService,
  });

  final StructuredTabCatalogService? structuredCatalogService;
  final UserStructuredTabStorageService? userTabStorageService;
  final StructuredTabPdfService? pdfService;
  final GuitarMetronomeAudioService? metronomeAudioService;

  static const double _wideBreakpoint = 860;

  @override
  State<BeatlesGuitarTabsPage> createState() => _BeatlesGuitarTabsPageState();
}

class _BeatlesGuitarTabsPageState extends State<BeatlesGuitarTabsPage> {
  bool _showStructuredScore = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<BeatlesGuitarTabsViewModel>();

    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 0,
        title: const Text(
          'Blackbird Guitar Studio',
          style: TextStyle(
            color: DesignTokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _GuitarModeSwitcher(
              showStructuredScore: _showStructuredScore,
              onChanged: (bool next) {
                if (_showStructuredScore == next) return;
                setState(() {
                  _showStructuredScore = next;
                });
              },
            ),
            Expanded(
              child: _showStructuredScore
                  ? StructuredTabStudioPanel(
                      catalogService: widget.structuredCatalogService,
                      userStorageService: widget.userTabStorageService,
                      pdfService: widget.pdfService,
                      metronomeAudioService: widget.metronomeAudioService,
                    )
                  : ListenableBuilder(
                      listenable: viewModel,
                      builder: (BuildContext context, _) {
                        return switch (viewModel.status) {
                          BeatlesGuitarTabsStatus.initial ||
                          BeatlesGuitarTabsStatus.loading =>
                            const Center(
                              child: CircularProgressIndicator(
                                color: DesignTokens.orange,
                              ),
                            ),
                          BeatlesGuitarTabsStatus.failure => _ErrorState(
                              message: viewModel.errorMessage ?? '読み込みに失敗しました。',
                              onRetry: viewModel.load,
                            ),
                          BeatlesGuitarTabsStatus.ready => LayoutBuilder(
                              builder: (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                if (constraints.maxWidth >=
                                    BeatlesGuitarTabsPage._wideBreakpoint) {
                                  return _WideLayout(
                                    viewModel: viewModel,
                                    metronomeAudioService:
                                        widget.metronomeAudioService,
                                  );
                                }
                                return _CompactLayout(
                                  viewModel: viewModel,
                                  metronomeAudioService:
                                      widget.metronomeAudioService,
                                );
                              },
                            ),
                        };
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuitarModeSwitcher extends StatelessWidget {
  const _GuitarModeSwitcher({
    required this.showStructuredScore,
    required this.onChanged,
  });

  final bool showStructuredScore;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: DesignTokens.surface1,
        border: Border(
          bottom: BorderSide(color: DesignTokens.divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _ModeTabButton(
                  buttonKey: const Key('guitar_mode_catalog'),
                  icon: Icons.library_music_outlined,
                  label: '練習カタログ',
                  selected: !showStructuredScore,
                  onTap: () => onChanged(false),
                ),
              ),
              const SizedBox(width: DesignTokens.space8),
              Expanded(
                child: _ModeTabButton(
                  buttonKey: const Key('guitar_mode_structured_score'),
                  icon: Icons.queue_music,
                  label: '構造化TABスコア',
                  selected: showStructuredScore,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? DesignTokens.orange.withValues(alpha: 0.18)
          : DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            border: Border.all(
              color: selected ? DesignTokens.orange : DesignTokens.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? DesignTokens.orangeLight
                    : DesignTokens.textSecondary,
              ),
              const SizedBox(width: DesignTokens.space8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? DesignTokens.orangeLight
                        : DesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideLayout extends StatefulWidget {
  const _WideLayout({
    required this.viewModel,
    this.metronomeAudioService,
  });

  final BeatlesGuitarTabsViewModel viewModel;
  final GuitarMetronomeAudioService? metronomeAudioService;

  @override
  State<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends State<_WideLayout> {
  final GlobalKey _songSectionKey = GlobalKey();

  void _scrollToSelectedSong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _songSectionKey.currentContext;
      if (targetContext == null || !targetContext.mounted) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: 320,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _CatalogControls(viewModel: widget.viewModel),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: DesignTokens.divider,
                  ),
                  Expanded(
                    child: _SongLibrary(
                      viewModel: widget.viewModel,
                      horizontal: false,
                      onSongSelected: _scrollToSelectedSong,
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: DesignTokens.divider,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('beatles_song_detail_scroll'),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _HeroPanel(compact: true),
                        const SizedBox(height: DesignTokens.space16),
                        _DailyCoursePanel(
                          viewModel: widget.viewModel,
                          onOpenPractice: _scrollToSelectedSong,
                        ),
                        const SizedBox(height: DesignTokens.space24),
                        _SongDetail(
                          viewModel: widget.viewModel,
                          headerKey: _songSectionKey,
                          metronomeAudioService: widget.metronomeAudioService,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.viewModel,
    this.metronomeAudioService,
  });

  final BeatlesGuitarTabsViewModel viewModel;
  final GuitarMetronomeAudioService? metronomeAudioService;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(
          1.0,
          2.0,
        );
    return ListView(
      key: const Key('beatles_tabs_compact_layout'),
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space16,
        DesignTokens.space16,
        DesignTokens.space16,
        96,
      ),
      children: <Widget>[
        const _HeroPanel(),
        const SizedBox(height: DesignTokens.space16),
        _DailyCoursePanel(viewModel: viewModel),
        const SizedBox(height: DesignTokens.space16),
        _CatalogControls(viewModel: viewModel),
        const SizedBox(height: DesignTokens.space16),
        SizedBox(
          height: 164 + (textScale - 1.0) * 80,
          child: _SongLibrary(viewModel: viewModel, horizontal: true),
        ),
        const SizedBox(height: DesignTokens.space24),
        _SongDetail(
          viewModel: viewModel,
          metronomeAudioService: metronomeAudioService,
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.3)),
      ),
      padding: compact
          ? const EdgeInsets.symmetric(
              horizontal: DesignTokens.space16,
              vertical: DesignTokens.space12,
            )
          : const EdgeInsets.all(DesignTokens.space20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _HeroIcon(),
          const SizedBox(width: DesignTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '毎日ひとつ、ギターが弾ける自分へ。',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: compact ? 18 : 24,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: compact ? 0.4 : 0.96,
                  ),
                ),
                SizedBox(
                  height: compact ? DesignTokens.space4 : DesignTokens.space8,
                ),
                Text(
                  '今日の3課題を順番にクリアして、基礎からフィンガースタイル演奏まで14日間で積み上げます。',
                  style: TextStyle(
                    color: DesignTokens.textOnDark,
                    fontSize: compact ? 13 : 14,
                    height: 1.6,
                  ),
                ),
                SizedBox(
                  height: compact ? DesignTokens.space8 : DesignTokens.space12,
                ),
                const Wrap(
                  spacing: DesignTokens.space8,
                  runSpacing: DesignTokens.space8,
                  children: <Widget>[
                    _HeroBadge(icon: Icons.calendar_month, label: '14日コース'),
                    _HeroBadge(icon: Icons.timer_outlined, label: '毎日15〜20分'),
                    _HeroBadge(icon: Icons.save_outlined, label: '進捗を端末保存'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: DesignTokens.orange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      ),
      child: const Icon(Icons.music_note, color: DesignTokens.orange, size: 30),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DesignTokens.indigo.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: DesignTokens.indigoLight.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: DesignTokens.indigoLight),
          const SizedBox(width: DesignTokens.space4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCoursePanel extends StatefulWidget {
  const _DailyCoursePanel({
    required this.viewModel,
    this.onOpenPractice,
  });

  final BeatlesGuitarTabsViewModel viewModel;
  final VoidCallback? onOpenPractice;

  @override
  State<_DailyCoursePanel> createState() => _DailyCoursePanelState();
}

class _DailyCoursePanelState extends State<_DailyCoursePanel> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final snapshot = viewModel.courseSnapshot;
    if (snapshot == null) return const SizedBox.shrink();
    if (snapshot.isCourseCompleted) {
      return _CourseCompletedCard(snapshot: snapshot);
    }

    final day = snapshot.currentDay!;
    return Container(
      key: const Key('guitar_daily_course_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: DesignTokens.space12,
              runSpacing: DesignTokens.space8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space12,
                        vertical: DesignTokens.space8,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.orange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusSmall,
                        ),
                      ),
                      child: Text(
                        'DAY ${day.dayNumber}',
                        key: const Key('guitar_current_course_day'),
                        style: const TextStyle(
                          color: DesignTokens.orangeLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.space12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _phaseLabel(day.phase),
                            style: const TextStyle(
                              color: DesignTokens.indigoLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.space4),
                          Text(
                            day.title,
                            style: const TextStyle(
                              color: DesignTokens.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: DesignTokens.space8,
                  runSpacing: DesignTokens.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _CourseMetric(
                      icon: Icons.local_fire_department_outlined,
                      label: '${snapshot.currentStreak}日連続',
                    ),
                    TextButton.icon(
                      key: const Key('guitar_course_collapse_toggle'),
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                      icon: Icon(
                        _collapsed ? Icons.expand_more : Icons.expand_less,
                        size: 18,
                      ),
                      label: Text(_collapsed ? '課題を開く' : '折りたたむ'),
                      style: TextButton.styleFrom(
                        foregroundColor: DesignTokens.textSecondary,
                        minimumSize: const Size(48, 44),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const Key('guitar_course_progress'),
                    value: snapshot.courseProgress,
                    minHeight: 8,
                    color: DesignTokens.orange,
                    backgroundColor: DesignTokens.surface3,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text(
                '${snapshot.completedDayCount} / ${snapshot.totalDayCount}日',
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!_collapsed) ...<Widget>[
            const SizedBox(height: DesignTokens.space12),
            Text(
              day.objective,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 13,
                height: 1.7,
              ),
            ),
            const SizedBox(height: DesignTokens.space12),
            _CourseDayRail(snapshot: snapshot),
            const SizedBox(height: DesignTokens.space16),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.today_outlined,
                  color: DesignTokens.orange,
                  size: 18,
                ),
                const SizedBox(width: DesignTokens.space8),
                Expanded(
                  child: Text(
                    '今日の3課題  ${snapshot.completedCurrentTaskCount}/${day.tasks.length}',
                    maxLines: 2,
                    style: const TextStyle(
                      color: DesignTokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: DesignTokens.space8),
                Text(
                  '${day.totalMinutes}分  •  ${day.recommendedBpm} BPM',
                  style: const TextStyle(
                    color: _mutedAccessibleText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = DesignTokens.space12;
                final columns = constraints.maxWidth >= 680
                    ? 3
                    : constraints.maxWidth >= 460
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final task in day.tasks)
                      SizedBox(
                        width: width,
                        child: _DailyTaskCard(
                          task: task,
                          completed: viewModel.isDailyTaskCompleted(task.id),
                          enabled: !viewModel.courseActionInProgress,
                          onTap: () => viewModel.toggleDailyTask(task.id),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: DesignTokens.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: DesignTokens.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_outline,
                    color: DesignTokens.indigoLight,
                    size: 18,
                  ),
                  const SizedBox(width: DesignTokens.space8),
                  Expanded(
                    child: Text(
                      day.coachNote,
                      style: const TextStyle(
                        color: DesignTokens.textSecondary,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (viewModel.courseActionError != null) ...<Widget>[
              const SizedBox(height: DesignTokens.space8),
              Text(
                viewModel.courseActionError!,
                style: const TextStyle(color: DesignTokens.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: DesignTokens.space16),
            Wrap(
              spacing: DesignTokens.space12,
              runSpacing: DesignTokens.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('guitar_complete_course_day'),
                  onPressed: snapshot.canCompleteCurrentDay &&
                          !viewModel.courseActionInProgress
                      ? () => _completeDay(context, day.dayNumber)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: DesignTokens.orange,
                    foregroundColor: DesignTokens.textPrimary,
                    disabledBackgroundColor: DesignTokens.surface3,
                    disabledForegroundColor: DesignTokens.textSecondary,
                    minimumSize: const Size(48, 44),
                    side: snapshot.canCompleteCurrentDay
                        ? null
                        : const BorderSide(color: Color(0xFF4B5563)),
                  ),
                  icon: viewModel.courseActionInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text('Day ${day.dayNumber}を完了'),
                ),
                if (day.relatedSongId != null)
                  OutlinedButton.icon(
                    key: const Key('guitar_open_course_practice'),
                    onPressed: () {
                      viewModel.openCurrentCoursePractice();
                      widget.onOpenPractice?.call();
                    },
                    icon: const Icon(Icons.queue_music),
                    label: const Text('関連TABを選択'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.orangeLight,
                      side: BorderSide(
                        color: DesignTokens.orange.withValues(alpha: 0.65),
                      ),
                      minimumSize: const Size(48, 44),
                    ),
                  ),
              ],
            ),
            if (!snapshot.canCompleteCurrentDay) ...<Widget>[
              const SizedBox(height: DesignTokens.space8),
              const Text(
                '今日の3課題をすべてチェックすると完了できます',
                style: TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _completeDay(BuildContext context, int dayNumber) async {
    final completed = await widget.viewModel.completeCurrentCourseDay();
    if (!context.mounted || !completed) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Day $dayNumber 完了！次の課題が解放されました。')),
      );
  }

  String _phaseLabel(GuitarCoursePhase phase) {
    return switch (phase) {
      GuitarCoursePhase.foundation => 'FOUNDATION • 基礎',
      GuitarCoursePhase.rhythm => 'RHYTHM • リズム',
      GuitarCoursePhase.fingerstyle => 'FINGERSTYLE • 指弾き',
      GuitarCoursePhase.performance => 'PERFORMANCE • 演奏',
    };
  }
}

class _DailyTaskCard extends StatelessWidget {
  const _DailyTaskCard({
    required this.task,
    required this.completed,
    required this.enabled,
    required this.onTap,
  });

  final GuitarDailyTask task;
  final bool completed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: completed
          ? DesignTokens.orange.withValues(alpha: 0.08)
          : DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: InkWell(
        key: Key('guitar_daily_task_${task.id}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 156),
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(
              color: completed ? DesignTokens.orange : DesignTokens.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        completed ? DesignTokens.orange : _mutedAccessibleText,
                    size: 22,
                  ),
                  const Spacer(),
                  Text(
                    '${task.minutes}分',
                    style: const TextStyle(
                      color: _mutedAccessibleText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              Text(
                task.title,
                style: TextStyle(
                  color: completed
                      ? DesignTokens.orangeLight
                      : DesignTokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                task.instruction,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                '完了条件：${task.completionCriteria}',
                style: const TextStyle(
                  color: _mutedAccessibleText,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseDayRail extends StatelessWidget {
  const _CourseDayRail({required this.snapshot});

  final GuitarCourseSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final day in snapshot.days) ...<Widget>[
            _CourseDayMarker(
              dayNumber: day.dayNumber,
              completed: snapshot.progress.completedDayNumbers.contains(
                day.dayNumber,
              ),
              current: snapshot.currentDay?.dayNumber == day.dayNumber,
            ),
            if (day != snapshot.days.last)
              const SizedBox(width: DesignTokens.space8),
          ],
        ],
      ),
    );
  }
}

class _CourseDayMarker extends StatelessWidget {
  const _CourseDayMarker({
    required this.dayNumber,
    required this.completed,
    required this.current,
  });

  final int dayNumber;
  final bool completed;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? DesignTokens.orange
        : current
            ? DesignTokens.indigoLight
            : _mutedAccessibleText;
    return Container(
      key: Key('guitar_course_day_$dayNumber'),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: completed || current ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: completed
          ? const Icon(Icons.check, size: 17, color: DesignTokens.orange)
          : Text(
              '$dayNumber',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _CourseMetric extends StatelessWidget {
  const _CourseMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: DesignTokens.orange, size: 18),
        const SizedBox(width: DesignTokens.space4),
        Text(
          label,
          style: const TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CourseCompletedCard extends StatelessWidget {
  const _CourseCompletedCard({required this.snapshot});

  final GuitarCourseSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('guitar_course_completed'),
      width: double.infinity,
      padding: const EdgeInsets.all(DesignTokens.space24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            DesignTokens.orange.withValues(alpha: 0.2),
            DesignTokens.indigo.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.emoji_events, color: DesignTokens.orange, size: 36),
          const SizedBox(height: DesignTokens.space12),
          const Text(
            '14日間コース完了！',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            '${snapshot.completedDayCount}日分の課題を積み上げました。下のTABライブラリで、好きな練習を自分のテンポで続けましょう。',
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 13,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogControls extends StatelessWidget {
  const _CatalogControls({required this.viewModel});

  final BeatlesGuitarTabsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: const Key('beatles_tabs_search'),
          onChanged: viewModel.setQuery,
          style: const TextStyle(color: DesignTokens.textPrimary),
          decoration: InputDecoration(
            hintText: '曲名・アルバム・奏法で検索',
            hintStyle: const TextStyle(color: _mutedAccessibleText),
            prefixIcon: const Icon(
              Icons.search,
              color: DesignTokens.textSecondary,
            ),
            filled: true,
            fillColor: DesignTokens.surface3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              borderSide: const BorderSide(
                color: DesignTokens.orange,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space12),
        Wrap(
          spacing: DesignTokens.space8,
          runSpacing: DesignTokens.space8,
          children: <Widget>[
            _DifficultyChip(
              label: 'すべて',
              selected: viewModel.difficulty == null,
              onSelected: () => viewModel.setDifficulty(null),
            ),
            for (final difficulty in GuitarTabDifficulty.values)
              _DifficultyChip(
                label: _difficultyLabel(difficulty),
                selected: viewModel.difficulty == difficulty,
                onSelected: () => viewModel.setDifficulty(difficulty),
              ),
          ],
        ),
      ],
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: DesignTokens.orange.withValues(alpha: 0.24),
      backgroundColor: DesignTokens.surface3,
      side: BorderSide(
        color: selected ? DesignTokens.orange : DesignTokens.divider,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space8),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelStyle: TextStyle(
        color: selected ? DesignTokens.orangeLight : DesignTokens.textSecondary,
        fontSize: 12,
      ),
      showCheckmark: false,
    );
  }
}

class _SongLibrary extends StatelessWidget {
  const _SongLibrary({
    required this.viewModel,
    required this.horizontal,
    this.onSongSelected,
  });

  final BeatlesGuitarTabsViewModel viewModel;
  final bool horizontal;
  final VoidCallback? onSongSelected;

  @override
  Widget build(BuildContext context) {
    final songs = viewModel.filteredSongs;
    if (songs.isEmpty) {
      return const _EmptyLibrary();
    }

    return ListView.separated(
      key: Key(
        horizontal ? 'beatles_song_list_horizontal' : 'beatles_song_list',
      ),
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      padding: horizontal
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(
              DesignTokens.space16,
              DesignTokens.space8,
              DesignTokens.space16,
              96,
            ),
      itemCount: songs.length,
      separatorBuilder: (_, __) => SizedBox(
        width: horizontal ? DesignTokens.space12 : 0,
        height: horizontal ? 0 : DesignTokens.space12,
      ),
      itemBuilder: (context, index) {
        final song = songs[index];
        return SizedBox(
          width: horizontal ? 272 : null,
          child: _SongCard(
            song: song,
            selected: viewModel.selectedSong?.id == song.id,
            onTap: () {
              viewModel.selectSong(song.id);
              onSongSelected?.call();
            },
          ),
        );
      },
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({
    required this.song,
    required this.selected,
    required this.onTap,
  });

  final GuitarTabSong song;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2A211E) : DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: InkWell(
        key: Key('beatles_song_${song.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(
              color: selected
                  ? DesignTokens.orange
                  : DesignTokens.orange.withValues(alpha: 0.16),
            ),
          ),
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DesignTokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: DesignTokens.orange,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(
                '${song.album} • ${song.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _mutedAccessibleText,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              Wrap(
                spacing: DesignTokens.space8,
                runSpacing: DesignTokens.space4,
                children: <Widget>[
                  _MetaChip(
                    icon: Icons.equalizer,
                    label: _difficultyLabel(song.difficulty),
                  ),
                  _MetaChip(
                    icon: Icons.speed,
                    label: '${song.practiceBpm} BPM',
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

class _SongDetail extends StatelessWidget {
  const _SongDetail({
    required this.viewModel,
    this.headerKey,
    this.metronomeAudioService,
  });

  final BeatlesGuitarTabsViewModel viewModel;
  final GlobalKey? headerKey;
  final GuitarMetronomeAudioService? metronomeAudioService;

  @override
  Widget build(BuildContext context) {
    final song = viewModel.selectedSong;
    if (song == null) return const _EmptyLibrary();

    final titleHeader = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                song.title,
                key: const Key('beatles_selected_song_title'),
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: 0.96,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
              Text(
                'The Beatles • ${song.album} • ${song.year}',
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.graphic_eq, color: DesignTokens.orange, size: 32),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        KeyedSubtree(key: headerKey, child: titleHeader),
        const SizedBox(height: DesignTokens.space16),
        Text(
          song.summary,
          style: const TextStyle(
            color: DesignTokens.textOnDark,
            fontSize: 14,
            height: 1.7,
          ),
        ),
        const SizedBox(height: DesignTokens.space16),
        Wrap(
          spacing: DesignTokens.space8,
          runSpacing: DesignTokens.space8,
          children: <Widget>[
            _MetaChip(icon: Icons.tune, label: song.tuning),
            _MetaChip(
              icon: Icons.vertical_align_top,
              label: 'Capo: ${song.capo}',
            ),
            for (final technique in song.techniques)
              _MetaChip(icon: Icons.auto_awesome, label: technique),
          ],
        ),
        const SizedBox(height: DesignTokens.space20),
        const _RightsNotice(),
        if (song.practiceSteps.isNotEmpty) ...<Widget>[
          const SizedBox(height: DesignTokens.space24),
          _PracticeRoadmap(viewModel: viewModel, song: song),
        ],
        const SizedBox(height: DesignTokens.space20),
        _TempoControl(
          viewModel: viewModel,
          metronomeAudioService: metronomeAudioService,
        ),
        const SizedBox(height: DesignTokens.space24),
        for (var index = 0; index < song.sections.length; index++) ...<Widget>[
          GuitarTabStaff(section: song.sections[index]),
          if (index != song.sections.length - 1)
            const SizedBox(height: DesignTokens.space16),
        ],
        if (song.resources.isNotEmpty) ...<Widget>[
          const SizedBox(height: DesignTokens.space24),
          _LearningResources(viewModel: viewModel, resources: song.resources),
        ],
        const SizedBox(height: DesignTokens.space24),
        const _PracticeTip(),
      ],
    );
  }
}

class _PracticeRoadmap extends StatelessWidget {
  const _PracticeRoadmap({required this.viewModel, required this.song});

  final BeatlesGuitarTabsViewModel viewModel;
  final GuitarTabSong song;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading(
          eyebrow: '20 MINUTE ROUTINE',
          title: '今日の3ステップ',
          description: 'カードを選ぶと、そのステップの開始テンポに切り替わります。',
        ),
        const SizedBox(height: DesignTokens.space16),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = DesignTokens.space12;
            final columns = constraints.maxWidth >= 680
                ? 3
                : constraints.maxWidth >= 460
                    ? 2
                    : 1;
            final cardWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (var index = 0; index < song.practiceSteps.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _PracticeStepCard(
                      index: index,
                      step: song.practiceSteps[index],
                      selected: viewModel.selectedPracticeStep?.id ==
                          song.practiceSteps[index].id,
                      onTap: () => viewModel.selectPracticeStep(
                        song.practiceSteps[index].id,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PracticeStepCard extends StatelessWidget {
  const _PracticeStepCard({
    required this.index,
    required this.step,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final GuitarPracticeStep step;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2A211E) : DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: InkWell(
        key: Key('blackbird_practice_step_${step.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 164),
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(
              color: selected ? DesignTokens.orange : DesignTokens.divider,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? DesignTokens.orange
                          : DesignTokens.surface3,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSmall,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: selected
                            ? DesignTokens.textPrimary
                            : DesignTokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${step.minutes}分  •  ${step.recommendedBpm} BPM',
                    style: TextStyle(
                      color: selected
                          ? DesignTokens.orangeLight
                          : _mutedAccessibleText,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              Text(
                step.title,
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                step.goal,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                step.cue,
                style: const TextStyle(
                  color: _mutedAccessibleText,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningResources extends StatelessWidget {
  const _LearningResources({required this.viewModel, required this.resources});

  final BeatlesGuitarTabsViewModel viewModel;
  final List<GuitarLessonResource> resources;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionHeading(
          eyebrow: 'EXTERNAL REFERENCES',
          title: '参考資料で深掘りする',
          description: '原曲の譜面・再生・動画は、提供元の利用条件を確認して外部サイトでご覧ください。',
        ),
        const SizedBox(height: DesignTokens.space16),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = DesignTokens.space12;
            final columns = constraints.maxWidth >= 680
                ? 3
                : constraints.maxWidth >= 460
                    ? 2
                    : 1;
            final cardWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final resource in resources)
                  SizedBox(
                    width: cardWidth,
                    child: _ResourceCard(
                      resource: resource,
                      onOpen: () => _openResource(context, resource),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openResource(
    BuildContext context,
    GuitarLessonResource resource,
  ) async {
    final opened = await viewModel.openResource(resource.id);
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('外部サイトを開けませんでした。時間をおいて再度お試しください。'),
        backgroundColor: DesignTokens.red,
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.onOpen});

  final GuitarLessonResource resource;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (resource.kind) {
      GuitarLessonResourceKind.pdfGuide => (
          Icons.picture_as_pdf_outlined,
          'PDF',
        ),
      GuitarLessonResourceKind.interactiveScore => (
          Icons.queue_music_outlined,
          'SCORE',
        ),
      GuitarLessonResourceKind.videoLesson => (
          Icons.ondemand_video_outlined,
          'VIDEO',
        ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 204),
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: DesignTokens.indigoLight, size: 24),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: DesignTokens.indigoLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          Text(
            resource.title,
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            resource.provider,
            style: const TextStyle(
              color: DesignTokens.orangeLight,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            resource.description,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: Key('blackbird_resource_${resource.id}'),
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(resource.actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.orangeLight,
                side: const BorderSide(color: DesignTokens.orange),
                minimumSize: const Size(48, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: const TextStyle(
            color: DesignTokens.orange,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            height: 1.5,
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          title,
          style: const TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
            letterSpacing: 0.72,
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          description,
          style: const TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

class _TempoControl extends StatefulWidget {
  const _TempoControl({
    required this.viewModel,
    this.metronomeAudioService,
  });

  final BeatlesGuitarTabsViewModel viewModel;
  final GuitarMetronomeAudioService? metronomeAudioService;

  @override
  State<_TempoControl> createState() => _TempoControlState();
}

class _TempoControlState extends State<_TempoControl> {
  late final GuitarMetronomeAudioService _audioService;
  late final bool _ownsAudioService;
  final Stopwatch _tickStopwatch = Stopwatch();
  Timer? _timer;
  bool _isPlaying = false;
  int _beatIndex = 0;
  int _scheduledDelayMs = 500;

  @override
  void initState() {
    super.initState();
    _ownsAudioService = widget.metronomeAudioService == null;
    _audioService =
        widget.metronomeAudioService ?? createGuitarMetronomeAudioService();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _tickStopwatch.stop();
    if (_ownsAudioService) {
      _audioService.dispose();
    }
    super.dispose();
  }

  int _intervalMsForCurrentBpm() {
    final bpm = widget.viewModel.practiceBpm.clamp(30, 260);
    return (60000.0 / bpm).round().clamp(150, 2500);
  }

  void _toggleMetronome() {
    if (_isPlaying) {
      _stopMetronome();
      return;
    }
    setState(() {
      _isPlaying = true;
      _beatIndex = 0;
    });
    _audioService.playClick(accent: true);
    _scheduleNextTick(overdueMs: 0);
  }

  void _scheduleNextTick({required int overdueMs}) {
    if (!mounted || !_isPlaying) return;
    final rawIntervalMs = _intervalMsForCurrentBpm();
    final nextDelayMs = (rawIntervalMs - overdueMs).clamp(20, rawIntervalMs);
    _scheduledDelayMs = nextDelayMs;
    _tickStopwatch
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: nextDelayMs), () {
      if (!mounted || !_isPlaying) return;
      final elapsed = _tickStopwatch.elapsedMilliseconds;
      final lag = elapsed > _scheduledDelayMs ? elapsed - _scheduledDelayMs : 0;
      final nextBeat = (_beatIndex + 1) % 4;
      setState(() {
        _beatIndex = nextBeat;
      });
      _audioService.playClick(accent: nextBeat == 0);
      _scheduleNextTick(overdueMs: lag);
    });
  }

  void _stopMetronome() {
    _timer?.cancel();
    _timer = null;
    _tickStopwatch.stop();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _beatIndex = 0;
    });
  }

  void _onBpmChanged(double value) {
    widget.viewModel.setPracticeBpm(value);
    if (_isPlaying) {
      _scheduleNextTick(overdueMs: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final isAtRecommended =
        viewModel.practiceBpm == viewModel.recommendedPracticeBpm;
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.speed, color: DesignTokens.indigoLight),
              const SizedBox(width: DesignTokens.space8),
              const Expanded(
                child: Text(
                  '練習テンポ',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${viewModel.practiceBpm} BPM',
                key: const Key('beatles_practice_bpm'),
                style: const TextStyle(
                  color: DesignTokens.orangeLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            key: const Key('beatles_tempo_slider'),
            value: viewModel.practiceBpm.toDouble(),
            min: 60,
            max: 180,
            divisions: 120,
            activeColor: DesignTokens.orange,
            inactiveColor: DesignTokens.surface3,
            label: '${viewModel.practiceBpm} BPM',
            onChanged: _onBpmChanged,
          ),
          const SizedBox(height: DesignTokens.space8),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: DesignTokens.space12,
              runSpacing: DesignTokens.space8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Wrap(
                  spacing: DesignTokens.space12,
                  runSpacing: DesignTokens.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const Key('beatles_metronome_toggle'),
                      onPressed: _toggleMetronome,
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(_isPlaying ? 'メトロノーム停止' : 'メトロノーム再生'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isPlaying
                            ? DesignTokens.indigo
                            : DesignTokens.orange,
                        foregroundColor: DesignTokens.textPrimary,
                        minimumSize: const Size(48, 44),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (var b = 0; b < 4; b++) ...<Widget>[
                          _MetronomeBeatDot(
                            beatIndex: b,
                            active: _isPlaying && _beatIndex == b,
                          ),
                          if (b != 3)
                            const SizedBox(width: DesignTokens.space4),
                        ],
                        const SizedBox(width: DesignTokens.space8),
                        Text(
                          _isPlaying ? '${_beatIndex + 1}/4拍' : '待機中',
                          style: const TextStyle(
                            color: _mutedAccessibleText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton.icon(
                  key: const Key('guitar_reset_recommended_bpm'),
                  onPressed:
                      isAtRecommended ? null : viewModel.resetPracticeBpm,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text('推奨 ${viewModel.recommendedPracticeBpm} BPM に戻す'),
                  style: TextButton.styleFrom(
                    foregroundColor: DesignTokens.orangeLight,
                    disabledForegroundColor: _mutedAccessibleText,
                    minimumSize: const Size(48, 44),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetronomeBeatDot extends StatelessWidget {
  const _MetronomeBeatDot({
    required this.beatIndex,
    required this.active,
  });

  final int beatIndex;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        beatIndex == 0 ? DesignTokens.orange : DesignTokens.indigoLight;
    return Container(
      key: Key('beatles_metronome_beat_$beatIndex'),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? activeColor : DesignTokens.surface3,
        border: Border.all(
          color: active ? activeColor : _mutedAccessibleText,
          width: 1.2,
        ),
      ),
    );
  }
}

class _RightsNotice extends StatelessWidget {
  const _RightsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.indigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: DesignTokens.indigoLight, size: 20),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              '掲載譜面は奏法学習用のオリジナル練習フレーズです。原曲の完全な採譜ではありません。原曲どおりに演奏する場合は、権利者が許諾した公式楽譜をご利用ください。',
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTip extends StatelessWidget {
  const _PracticeTip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lightbulb_outline, color: DesignTokens.amber, size: 20),
        SizedBox(width: DesignTokens.space8),
        Expanded(
          child: Text(
            'まず推奨テンポの70%で3回連続ノーミスを目指し、5 BPMずつ上げると安定します。',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DesignTokens.surface3,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: DesignTokens.textSecondary),
          const SizedBox(width: DesignTokens.space4),
          Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off, color: DesignTokens.orange, size: 42),
            SizedBox(height: DesignTokens.space12),
            Text(
              '条件に合う練習曲がありません',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: DesignTokens.red, size: 48),
            const SizedBox(height: DesignTokens.space16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.orange,
                foregroundColor: DesignTokens.textPrimary,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _difficultyLabel(GuitarTabDifficulty difficulty) {
  return switch (difficulty) {
    GuitarTabDifficulty.beginner => '初級',
    GuitarTabDifficulty.intermediate => '中級',
    GuitarTabDifficulty.advanced => '上級',
  };
}
