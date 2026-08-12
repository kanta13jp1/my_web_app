import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/guitar_tab_song.dart';
import '../../../../theme/design_tokens.dart';
import '../view_models/beatles_guitar_tabs_view_model.dart';
import 'widgets/guitar_tab_staff.dart';

class BeatlesGuitarTabsPage extends StatelessWidget {
  const BeatlesGuitarTabsPage({super.key});

  static const double _wideBreakpoint = 860;

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
          'Beatles Guitar Lab',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return switch (viewModel.status) {
              BeatlesGuitarTabsStatus.initial ||
              BeatlesGuitarTabsStatus.loading =>
                const Center(
                  child: CircularProgressIndicator(color: DesignTokens.orange),
                ),
              BeatlesGuitarTabsStatus.failure => _ErrorState(
                  message: viewModel.errorMessage ?? '読み込みに失敗しました。',
                  onRetry: viewModel.load,
                ),
              BeatlesGuitarTabsStatus.ready => LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= _wideBreakpoint) {
                      return _WideLayout(viewModel: viewModel);
                    }
                    return _CompactLayout(viewModel: viewModel);
                  },
                ),
            };
          },
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.viewModel});

  final BeatlesGuitarTabsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                children: <Widget>[
                  const _HeroPanel(),
                  const SizedBox(height: DesignTokens.space16),
                  _CatalogControls(viewModel: viewModel),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 340,
                    child: _SongLibrary(
                      viewModel: viewModel,
                      horizontal: false,
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: DesignTokens.divider,
                  ),
                  Expanded(
                    child: _SongDetail(viewModel: viewModel, scrollable: true),
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

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.viewModel});

  final BeatlesGuitarTabsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('beatles_tabs_compact_layout'),
      padding: const EdgeInsets.all(DesignTokens.space16),
      children: <Widget>[
        const _HeroPanel(),
        const SizedBox(height: DesignTokens.space16),
        _CatalogControls(viewModel: viewModel),
        const SizedBox(height: DesignTokens.space16),
        SizedBox(
          height: 164,
          child: _SongLibrary(viewModel: viewModel, horizontal: true),
        ),
        const SizedBox(height: DesignTokens.space24),
        _SongDetail(viewModel: viewModel, scrollable: false),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

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
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _HeroIcon(),
          SizedBox(width: DesignTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '名曲の奏法を、短い練習から',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: 0.96,
                  ),
                ),
                SizedBox(height: DesignTokens.space8),
                Text(
                  'Beatlesの代表曲を題材に、フィンガースタイル、リフ、コードチェンジを段階的に練習できます。',
                  style: TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 14,
                    height: 1.7,
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
            hintStyle: const TextStyle(color: DesignTokens.textTertiary),
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
      labelStyle: TextStyle(
        color: selected ? DesignTokens.orangeLight : DesignTokens.textSecondary,
        fontSize: 12,
      ),
      showCheckmark: false,
    );
  }
}

class _SongLibrary extends StatelessWidget {
  const _SongLibrary({required this.viewModel, required this.horizontal});

  final BeatlesGuitarTabsViewModel viewModel;
  final bool horizontal;

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
      padding: EdgeInsets.symmetric(
        horizontal: horizontal ? 0 : DesignTokens.space16,
        vertical: horizontal ? 0 : DesignTokens.space8,
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
            onTap: () => viewModel.selectSong(song.id),
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
                  color: DesignTokens.textTertiary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: <Widget>[
                  _MetaChip(
                    icon: Icons.equalizer,
                    label: _difficultyLabel(song.difficulty),
                  ),
                  const SizedBox(width: DesignTokens.space8),
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
  const _SongDetail({required this.viewModel, required this.scrollable});

  final BeatlesGuitarTabsViewModel viewModel;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final song = viewModel.selectedSong;
    if (song == null) return const _EmptyLibrary();

    final children = <Widget>[
      Row(
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
      ),
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
      const SizedBox(height: DesignTokens.space20),
      _TempoControl(viewModel: viewModel, song: song),
      const SizedBox(height: DesignTokens.space24),
      for (var index = 0; index < song.sections.length; index++) ...<Widget>[
        GuitarTabStaff(section: song.sections[index]),
        if (index != song.sections.length - 1)
          const SizedBox(height: DesignTokens.space16),
      ],
      const SizedBox(height: DesignTokens.space24),
      const _PracticeTip(),
    ];

    if (scrollable) {
      return ListView(
        key: const Key('beatles_song_detail_scroll'),
        padding: const EdgeInsets.all(DesignTokens.space24),
        children: <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _TempoControl extends StatelessWidget {
  const _TempoControl({required this.viewModel, required this.song});

  final BeatlesGuitarTabsViewModel viewModel;
  final GuitarTabSong song;

  @override
  Widget build(BuildContext context) {
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
            onChanged: viewModel.setPracticeBpm,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: viewModel.practiceBpm == song.practiceBpm
                  ? null
                  : viewModel.resetPracticeBpm,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text('推奨 ${song.practiceBpm} BPM に戻す'),
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.orange,
                disabledForegroundColor: DesignTokens.textDisabled,
              ),
            ),
          ),
        ],
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
