import 'package:flutter/material.dart';

import 'application/image_moderation_controller.dart';
import 'data/supabase_image_moderation_repository.dart';
import 'domain/image_moderation_models.dart';
import 'presentation/image_moderation_view.dart';

/// ImageModerationController と View・入力コントローラを接続する Container (#2644).
class ImageModerationContainer extends StatefulWidget {
  const ImageModerationContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final ImageModerationRepository? repository;
  final ImageModerationController? controller;

  @override
  State<ImageModerationContainer> createState() =>
      _ImageModerationContainerState();
}

class _ImageModerationContainerState extends State<ImageModerationContainer> {
  late ImageModerationController _controller;
  late bool _ownsController;
  final TextEditingController _uploadPathController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initController();
    Future<void>.microtask(_loadInitial);
  }

  void _initController() {
    final provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ??
        ImageModerationController(
          repository: widget.repository ?? SupabaseImageModerationRepository(),
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadAssets();
  }

  @override
  void didUpdateWidget(covariant ImageModerationContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.repository != oldWidget.repository) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      Future<void>.microtask(_loadInitial);
    }
  }

  @override
  void dispose() {
    _uploadPathController.dispose();
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmitUpload() {
    _controller.submitImageForModeration(
      storagePath: _uploadPathController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return ImageModerationView(
          state: _controller.state,
          uploadPathController: _uploadPathController,
          searchController: _searchController,
          onRetryLoad: _loadInitial,
          onSearchChanged: _controller.setSearchQuery,
          onSelectTag: _controller.selectTag,
          onToggleIncludeRestricted: (bool include) =>
              _controller.toggleIncludeRestricted(include: include),
          onToggleExternalConsent: (bool consented) =>
              _controller.setExternalTransferConsented(consented: consented),
          onSubmitUpload: _handleSubmitUpload,
        );
      },
    );
  }
}
