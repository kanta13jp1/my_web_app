import 'package:flutter/material.dart';

import 'application/multilingual_video_player_controller.dart';
import 'data/supabase_multilingual_video_repository.dart';
import 'domain/multilingual_video_player_models.dart';
import 'presentation/multilingual_video_player_view.dart';

/// 多言語リップシンク動画プレイヤー Feature の公開 Container ウィジェット (#2660).
class MultilingualVideoPlayerContainer extends StatefulWidget {
  const MultilingualVideoPlayerContainer({
    super.key,
    this.repository,
    this.controller,
    this.sourceVideoId,
    this.autoLoad = true,
  });

  final MultilingualVideoRepository? repository;
  final MultilingualVideoPlayerController? controller;
  final String? sourceVideoId;
  final bool autoLoad;

  @override
  State<MultilingualVideoPlayerContainer> createState() =>
      _MultilingualVideoPlayerContainerState();
}

class _MultilingualVideoPlayerContainerState
    extends State<MultilingualVideoPlayerContainer> {
  late final MultilingualVideoPlayerController _controller;
  late final bool _ownsController;
  final TextEditingController _sourceVideoIdController =
      TextEditingController(text: 'intro_philosophy_01');
  final TextEditingController _sourceVideoUrlController = TextEditingController(
    text: 'https://example.com/videos/jibun_company_intro.mp4',
  );
  final TextEditingController _durationController =
      TextEditingController(text: '45');
  String _selectedTargetLanguage = 'es';

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        MultilingualVideoPlayerController(
          repository:
              widget.repository ?? SupabaseMultilingualVideoRepository(),
        );
    if (widget.sourceVideoId != null &&
        widget.sourceVideoId!.trim().isNotEmpty) {
      _sourceVideoIdController.text = widget.sourceVideoId!.trim();
    }
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((final Duration _) {
        if (mounted) {
          _controller.loadTranslations(sourceVideoId: widget.sourceVideoId);
        }
      });
    }
  }

  @override
  void dispose() {
    _sourceVideoIdController.dispose();
    _sourceVideoUrlController.dispose();
    _durationController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmit() {
    final double durationSeconds =
        double.tryParse(_durationController.text.trim()) ?? 0.0;
    _controller.queueTranslation(
      QueueVideoTranslationInput(
        sourceVideoId: _sourceVideoIdController.text,
        sourceVideoUrl: _sourceVideoUrlController.text,
        languageCode: _selectedTargetLanguage,
        durationSeconds: durationSeconds,
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return MultilingualVideoPlayerView(
          controller: _controller,
          sourceVideoIdController: _sourceVideoIdController,
          sourceVideoUrlController: _sourceVideoUrlController,
          durationController: _durationController,
          selectedTargetLanguage: _selectedTargetLanguage,
          onTargetLanguageChanged: (final String lang) {
            setState(() {
              _selectedTargetLanguage = lang;
            });
          },
          onQueueSubmitted: _handleSubmit,
          onRefresh: () {
            _controller.loadTranslations(sourceVideoId: widget.sourceVideoId);
          },
        );
      },
    );
  }
}
