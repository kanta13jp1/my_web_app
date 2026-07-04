import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool get _statusIsError {
    final s = _statusMessage;
    if (s == null) return false;
    return s.contains('失敗') ||
        s.contains('エラー') ||
        s.contains('できませんでした') ||
        s.contains('不足') ||
        s.contains('確認してください');
  }

  /// ワンボタン: 文章(生成済)→画像→音声+動画(Hedra/ElevenLabs, 非同期はポーリング)
  /// →X投稿 を一括実行する。ユーザーは「AI生成して投稿」を押すだけ。失敗時は原因を
  /// 画面に明確表示する。
  Future<void> _generateAndPost() async {
    final draft = _draft;
    if (_posting || _loadingDraft) return;
    if (draft == null) {
      setState(() => _statusMessage = 'AIが文章を生成中です。数秒待ってからもう一度押してください。');
      return;
    }
    setState(() {
      _posting = true;
      _statusMessage = null;
    });
    try {
      // 1. 画像(presenter/舞台がローテ)
      if (_imageUrl == null) {
        setState(() {
          _generatingImage = true;
          _statusMessage = 'AIが画像を生成しています…';
        });
        final image = await _service.generateImage(
          context: widget.page,
          draft: draft,
        );
        if (_disposed || !mounted) return;
        _imageUrl = image.url;
        setState(() => _generatingImage = false);
      }
      // 2. 音声+動画(Hedra は非同期。生成IDが返ったら完了までポーリング)
      if (_videoUrl == null) {
        setState(() {
          _generatingVideo = true;
          _statusMessage = 'AIが音声と動画を生成しています…（30〜60秒かかります）';
        });
        var video = await _service.generateVideo(
          context: widget.page,
          draft: draft,
          imageUrl: _imageUrl,
        );
        var generationId = video.url == null
            ? _extractString(video.raw, 'hedraGenerationId')
            : null;
        var polls = 0;
        while (video.url == null && generationId != null && polls < 12) {
          await Future<void>.delayed(const Duration(seconds: 8));
          if (_disposed || !mounted) return;
          video = await _service.generateVideo(
            context: widget.page,
            draft: draft,
            imageUrl: _imageUrl,
            hedraGenerationId: generationId,
          );
          generationId = video.url == null
              ? (_extractString(video.raw, 'hedraGenerationId') ?? generationId)
              : null;
          polls += 1;
        }
        if (_disposed || !mounted) return;
        _videoUrl = video.url;
        setState(() => _generatingVideo = false);
        if (_videoUrl == null) {
          final reason =
              _extractString(video.raw, 'videoReason') ?? '完了しませんでした';
          setState(() => _statusMessage = '動画は生成できませんでした（$reason）。画像付きで投稿します。');
        }
      }
      // 3. X 投稿(URLはリプライへ、スレッド返信も投稿)
      setState(() => _statusMessage = 'Xに投稿しています…');
      final result = await _service.postToX(
        context: widget.page,
        text: _textController.text,
        mediaUrl: _videoUrl ?? _imageUrl,
        threadReplies: draft.threadReplies,
        linkInReply: true,
      );
      if (_disposed || !mounted) return;
      setState(() {
        _statusMessage = result.posted
            ? '${result.account ?? '@kanta13jp1'} に投稿しました 🎉'
            : '投稿できませんでした。X API secret設定を確認してください';
      });
    } catch (error) {
      if (_disposed || !mounted) return;
      setState(() => _statusMessage = '投稿に失敗しました: $error');
    } finally {
      if (!_disposed && mounted) {
        setState(() {
          _posting = false;
          _generatingImage = false;
          _generatingVideo = false;
        });
      }
    }
  }

  static String? _extractString(Map<String, dynamic> raw, String key) {
    final value = raw[key]?.toString().trim();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  static String _mediaDisplayText(String mediaUrl) {
    if (UniversalXShareService.isEmbeddedDataUrl(mediaUrl)) {
      return 'Generated image is embedded data. Regenerate it to store a public URL before video generation or X posting.';
    }
    return mediaUrl.length <= 240
        ? mediaUrl
        : '${mediaUrl.substring(0, 220)}...';
  }

  @override
  Widget build(BuildContext context) {
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
              if (mediaUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText('添付メディア: ${_mediaDisplayText(mediaUrl)}'),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                // 失敗時は赤で原因を明確に表示する。
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusIsError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      // 操作はワンボタン。「AI生成して投稿」で 文章→画像→音声→動画→投稿 を自動実行。
      actions: [
        TextButton(
          onPressed: _posting ? null : () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        FilledButton.icon(
          onPressed: _loadingDraft || _posting ? null : _generateAndPost,
          icon: _posting ? const _TinyProgress() : const Icon(Icons.send),
          label: Text(_posting ? '生成して投稿中…' : 'AI生成して投稿'),
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
      // 実際に使うツールを正確に表示する(嘘のパイプラインにしない)。
      // 文章=GPT-5.5(ai-hub) / 画像=GPT image / 音声=ElevenLabs / 動画=Hedra。
      _PipelineStepData(
        index: 1,
        model: 'GPT-5.5',
        role: '文章',
        icon: Icons.edit_note,
        state: _stateFor(ready: textReady, running: generatingText),
      ),
      _PipelineStepData(
        index: 2,
        model: 'GPT image',
        role: '画像',
        icon: Icons.image_outlined,
        state: _stateFor(ready: imageReady, running: generatingImage),
      ),
      _PipelineStepData(
        index: 3,
        model: 'ElevenLabs',
        role: '音声',
        icon: Icons.record_voice_over_outlined,
        state: _stateFor(ready: videoReady, running: generatingVideo),
      ),
      _PipelineStepData(
        index: 4,
        model: 'Hedra',
        role: '動画',
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
