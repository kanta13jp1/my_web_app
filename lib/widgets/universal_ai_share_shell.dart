import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_share_button_preferences_service.dart';
import '../services/universal_x_share_service.dart';
import 'ai_share_button_settings_panel.dart';

final universalAiShareRouteObserver = UniversalAiShareRouteObserver();

class UniversalAiShareRouteObserver extends NavigatorObserver {
  final ValueNotifier<UniversalSharePageContext> currentPage =
      ValueNotifier<UniversalSharePageContext>(
    UniversalSharePageContext.fromRouteName('/'),
  );

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route.settings.name);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update(newRoute?.settings.name);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(previousRoute?.settings.name);
    super.didPop(route, previousRoute);
  }

  void _update(String? routeName) {
    currentPage.value = UniversalSharePageContext.fromRouteName(routeName);
  }
}

class UniversalAiShareShell extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const UniversalAiShareShell({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<UniversalAiShareShell> createState() => _UniversalAiShareShellState();
}

class _UniversalAiShareShellState extends State<UniversalAiShareShell> {
  OverlayEntry? _overlayEntry;
  OverlayState? _overlayState;

  AiShareButtonPreferencesController get _preferencesController =>
      aiShareButtonPreferencesController;

  @override
  void initState() {
    super.initState();
    _preferencesController.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOverlayEntry();
    });
  }

  @override
  void didUpdateWidget(covariant UniversalAiShareShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigatorKey != widget.navigatorKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncOverlayEntry();
      });
    }
  }

  @override
  void dispose() {
    _removeOverlayEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _syncOverlayEntry() {
    if (!mounted) return;

    final overlayState = widget.navigatorKey.currentState?.overlay;
    if (overlayState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncOverlayEntry();
      });
      return;
    }

    if (_overlayEntry != null && identical(_overlayState, overlayState)) {
      return;
    }

    _removeOverlayEntry();
    _overlayState = overlayState;
    _overlayEntry = OverlayEntry(builder: _buildOverlayEntry);
    overlayState.insert(_overlayEntry!);
  }

  void _removeOverlayEntry() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayState = null;
  }

  Widget _buildOverlayEntry(BuildContext context) {
    return AnimatedBuilder(
      animation: _preferencesController,
      builder: (context, _) {
        final preferences = _preferencesController.preferences;
        if (!preferences.visible) return const SizedBox.shrink();

        return ValueListenableBuilder<UniversalSharePageContext>(
          valueListenable: universalAiShareRouteObserver.currentPage,
          builder: (context, page, _) {
            return _positionedFab(
              preferences.position,
              SafeArea(
                child: _UniversalAiShareFab(
                  page: page,
                  navigatorKey: widget.navigatorKey,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _positionedFab(AiShareButtonPosition position, Widget child) {
    switch (position) {
      case AiShareButtonPosition.topLeft:
        return Positioned(left: 16, top: 20, child: child);
      case AiShareButtonPosition.topRight:
        return Positioned(right: 16, top: 20, child: child);
      case AiShareButtonPosition.bottomLeft:
        return Positioned(left: 16, bottom: 20, child: child);
      case AiShareButtonPosition.bottomRight:
        return Positioned(right: 16, bottom: 20, child: child);
    }
  }
}

class _UniversalAiShareFab extends StatelessWidget {
  final UniversalSharePageContext page;
  final GlobalKey<NavigatorState> navigatorKey;

  const _UniversalAiShareFab({required this.page, required this.navigatorKey});

  bool get _isLoggedIn {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  void _openShareDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlayContext = navigatorKey.currentState?.overlay?.context;
      if (overlayContext == null || !overlayContext.mounted) return;
      showDialog<void>(
        context: overlayContext,
        useRootNavigator: true,
        builder: (_) => UniversalAiShareDialog(page: page),
      );
    });
  }

  void _openSettingsSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlayContext = navigatorKey.currentState?.overlay?.context;
      if (overlayContext == null || !overlayContext.mounted) return;
      showModalBottomSheet<void>(
        context: overlayContext,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (_) => const SafeArea(
          child: AiShareButtonSettingsPanel(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _isLoggedIn;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isLoggedIn
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor =
        isLoggedIn ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    return Material(
      color: backgroundColor,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.24),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'AIシェア',
            child: InkWell(
              onTap: _openShareDialog,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: foregroundColor),
                    const SizedBox(width: 8),
                    Text(
                      'AIシェア',
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: colorScheme.outlineVariant.withValues(alpha: 0.78),
          ),
          Tooltip(
            message: 'AIシェアボタン設定',
            child: IconButton(
              onPressed: _openSettingsSheet,
              icon: const Icon(Icons.tune),
              color: foregroundColor,
              constraints: const BoxConstraints.tightFor(width: 44, height: 48),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class UniversalAiShareDialog extends StatefulWidget {
  final UniversalSharePageContext page;

  const UniversalAiShareDialog({super.key, required this.page});

  @override
  State<UniversalAiShareDialog> createState() => _UniversalAiShareDialogState();
}

class _UniversalAiShareDialogState extends State<UniversalAiShareDialog> {
  late final UniversalXShareService _service;
  late final TextEditingController _textController;
  UniversalXShareDraft? _draft;
  String? _imageUrl;
  String? _videoUrl;
  String? _hedraGenerationId;
  String? _statusMessage;
  bool _loadingDraft = true;
  bool _generatingImage = false;
  bool _generatingVideo = false;
  bool _posting = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _service = UniversalXShareService(supabase: Supabase.instance.client);
    _textController = TextEditingController();
    _generateDraft();
  }

  @override
  void dispose() {
    _disposed = true;
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateDraft() async {
    setState(() {
      _loadingDraft = true;
      _statusMessage = null;
    });
    try {
      final draft = await _service.generateDraft(widget.page);
      if (_disposed || !mounted) return;
      setState(() {
        _draft = draft;
        _textController.text = draft.text;
        _loadingDraft = false;
        _statusMessage =
            draft.fallbackUsed ? 'AI生成が不安定なため、安全な定型文を使っています' : null;
      });
    } catch (error) {
      if (_disposed || !mounted) return;
      setState(() {
        _loadingDraft = false;
        _statusMessage = 'ドラフト生成に失敗しました。手動で入力してください。';
      });
    }
  }

  Future<void> _generateImage() async {
    final draft = _draft;
    if (draft == null || _generatingImage) return;
    setState(() {
      _generatingImage = true;
      _statusMessage = null;
    });
    try {
      final result = await _service.generateImage(
        context: widget.page,
        draft: draft,
      );
      if (_disposed || !mounted) return;
      setState(() {
        _imageUrl = result.url;
        _statusMessage =
            result.url == null ? '画像生成URLを取得できませんでした' : 'シェア画像を生成しました';
      });
    } catch (error) {
      if (_disposed || !mounted) return;
      setState(() => _statusMessage = '画像生成に失敗しました: $error');
    } finally {
      if (!_disposed && mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _generateVideo() async {
    final draft = _draft;
    if (draft == null || _generatingVideo) return;
    setState(() {
      _generatingVideo = true;
      _statusMessage = null;
    });
    try {
      final result = await _service.generateVideo(
        context: widget.page,
        draft: draft,
        imageUrl: _imageUrl,
        hedraGenerationId: _hedraGenerationId,
      );
      if (_disposed || !mounted) return;
      setState(() {
        _videoUrl = result.url;
        _hedraGenerationId = result.url == null
            ? _extractString(result.raw, 'hedraGenerationId')
            : null;
        _statusMessage = _videoStatusMessage(result);
      });
    } catch (error) {
      if (_disposed || !mounted) return;
      setState(() => _statusMessage = '動画生成に失敗しました: $error');
    } finally {
      if (!_disposed && mounted) setState(() => _generatingVideo = false);
    }
  }

  Future<void> _postToX() async {
    if (_posting) return;
    setState(() {
      _posting = true;
      _statusMessage = null;
    });
    try {
      final mediaUrl = _videoUrl ?? _imageUrl;
      final result = await _service.postToX(
        context: widget.page,
        text: _textController.text,
        mediaUrl: mediaUrl,
      );
      if (_disposed || !mounted) return;
      setState(() {
        _statusMessage = result.posted
            ? '${result.account ?? '@kanta13jp1'} に投稿しました'
            : '投稿文を保存しました。X API secret設定を確認してください';
      });
    } catch (error) {
      if (_disposed || !mounted) return;
      setState(() => _statusMessage = 'X投稿に失敗しました: $error');
    } finally {
      if (!_disposed && mounted) setState(() => _posting = false);
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _textController.text));
    if (mounted) {
      setState(() => _statusMessage = '投稿文をコピーしました');
    }
  }

  Future<void> _openXComposer() async {
    final uri = Uri.https('x.com', '/intent/tweet', {
      'text': _textController.text,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String? _extractString(Map<String, dynamic> raw, String key) {
    final value = raw[key]?.toString().trim();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  static String _videoStatusMessage(UniversalXMediaResult result) {
    if (result.url != null) return 'シェア動画を生成しました';
    final reason = _extractString(result.raw, 'videoReason');
    if (reason == 'Hedra avatar video requires imageUrl') {
      return '先に画像生成を実行してから、動画生成を開始してください';
    }
    final status = _extractString(result.raw, 'videoStatus') ?? result.status;
    final generationId = _extractString(result.raw, 'hedraGenerationId');
    final eta = _extractString(result.raw, 'hedraEtaSec');
    if (generationId != null &&
        const {'queued', 'processing', 'submitted'}.contains(status)) {
      final etaText = eta == null ? '' : ' 目安: 約$eta秒';
      return 'Hedra動画生成ジョブを開始しました。少し待ってからもう一度「動画生成」を押すと結果を確認します。$etaText';
    }
    if (reason != null) return '動画生成結果を確認してください: $reason';
    return '動画生成は完了待ちです。少し待ってからもう一度確認してください';
  }

  @override
  Widget build(BuildContext context) {
    final textLength = _textController.text.length;
    final mediaUrl = _videoUrl ?? _imageUrl;
    return AlertDialog(
      title: Text('${widget.page.title} をAIシェア'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.page.url,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _CreativePipelineCard(
                textReady: !_loadingDraft && _draft != null,
                imageReady: _imageUrl != null,
                videoReady: _videoUrl != null,
                generatingText: _loadingDraft,
                generatingImage: _generatingImage,
                generatingVideo: _generatingVideo,
              ),
              const SizedBox(height: 12),
              if (_loadingDraft)
                const LinearProgressIndicator()
              else
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  minLines: 5,
                  maxLength: UniversalXShareService.maxTweetLength,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'AI生成シェア文言',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadingDraft ? null : _generateDraft,
                    icon: const Icon(Icons.refresh),
                    label: const Text('文言再生成'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _generatingImage ? null : _generateImage,
                    icon: _generatingImage
                        ? const _TinyProgress()
                        : const Icon(Icons.image_outlined),
                    label: Text(_generatingImage ? '画像生成中' : '画像生成'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _generatingVideo ? null : _generateVideo,
                    icon: _generatingVideo
                        ? const _TinyProgress()
                        : const Icon(Icons.movie_creation_outlined),
                    label: Text(
                      _generatingVideo
                          ? '動画生成中'
                          : _hedraGenerationId == null
                              ? '動画生成'
                              : '動画確認',
                    ),
                  ),
                ],
              ),
              if (mediaUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText('添付メディア: $mediaUrl'),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (textLength > UniversalXShareService.maxTweetLength)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '280文字を超えています。投稿前に短くしてください。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        OutlinedButton.icon(
          onPressed: _loadingDraft ? null : _copyText,
          icon: const Icon(Icons.copy),
          label: const Text('コピー'),
        ),
        OutlinedButton.icon(
          onPressed: _loadingDraft ? null : _openXComposer,
          icon: const Icon(Icons.open_in_new),
          label: const Text('X画面'),
        ),
        FilledButton.icon(
          onPressed: _loadingDraft ||
                  _posting ||
                  textLength > UniversalXShareService.maxTweetLength
              ? null
              : _postToX,
          icon: _posting ? const _TinyProgress() : const Icon(Icons.send),
          label: Text(_posting ? '投稿中' : 'AI生成して投稿'),
        ),
      ],
    );
  }
}

class _CreativePipelineCard extends StatelessWidget {
  final bool textReady;
  final bool imageReady;
  final bool videoReady;
  final bool generatingText;
  final bool generatingImage;
  final bool generatingVideo;

  const _CreativePipelineCard({
    required this.textReady,
    required this.imageReady,
    required this.videoReady,
    required this.generatingText,
    required this.generatingImage,
    required this.generatingVideo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = <_PipelineStepData>[
      _PipelineStepData(
        index: 1,
        model: 'GPT image2',
        role: 'share image',
        icon: Icons.image_outlined,
        state: _stateFor(ready: imageReady, running: generatingImage),
      ),
      _PipelineStepData(
        index: 2,
        model: 'GPT-5.5',
        role: 'X copy',
        icon: Icons.edit_note,
        state: _stateFor(ready: textReady, running: generatingText),
      ),
      _PipelineStepData(
        index: 3,
        model: 'Seedance 2.0',
        role: 'short video',
        icon: Icons.movie_creation_outlined,
        state: _stateFor(ready: videoReady, running: generatingVideo),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.62,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI creative pipeline',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: steps.map(_PipelineStepChip.new).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static _PipelineStepState _stateFor({
    required bool ready,
    required bool running,
  }) {
    if (running) return _PipelineStepState.running;
    if (ready) return _PipelineStepState.ready;
    return _PipelineStepState.waiting;
  }
}

enum _PipelineStepState { waiting, running, ready }

class _PipelineStepData {
  final int index;
  final String model;
  final String role;
  final IconData icon;
  final _PipelineStepState state;

  const _PipelineStepData({
    required this.index,
    required this.model,
    required this.role,
    required this.icon,
    required this.state,
  });
}

class _PipelineStepChip extends StatelessWidget {
  final _PipelineStepData step;

  const _PipelineStepChip(this.step);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (step.state) {
      _PipelineStepState.ready => const Color(0xFF059669),
      _PipelineStepState.running => const Color(0xFFF97316),
      _PipelineStepState.waiting => theme.colorScheme.onSurfaceVariant,
    };
    final status = switch (step.state) {
      _PipelineStepState.ready => 'ready',
      _PipelineStepState.running => 'running',
      _PipelineStepState.waiting => 'waiting',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(step.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${step.index}. ${step.model}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${step.role} / $status',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyProgress extends StatelessWidget {
  const _TinyProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
