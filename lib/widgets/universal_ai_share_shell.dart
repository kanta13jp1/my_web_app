import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/universal_x_share_service.dart';

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

class UniversalAiShareShell extends StatelessWidget {
  final Widget child;

  const UniversalAiShareShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        ValueListenableBuilder<UniversalSharePageContext>(
          valueListenable: universalAiShareRouteObserver.currentPage,
          builder: (context, page, _) {
            return Positioned(
              right: 16,
              bottom: 20,
              child: SafeArea(
                child: _UniversalAiShareFab(page: page),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _UniversalAiShareFab extends StatelessWidget {
  final UniversalSharePageContext page;

  const _UniversalAiShareFab({required this.page});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      heroTag: 'universal-ai-share-fab',
      tooltip: 'AIでこのページをXシェア',
      backgroundColor: isLoggedIn
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      foregroundColor:
          isLoggedIn ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => UniversalAiShareDialog(page: page),
      ),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('AIシェア'),
    );
  }
}

class UniversalAiShareDialog extends StatefulWidget {
  final UniversalSharePageContext page;

  const UniversalAiShareDialog({
    super.key,
    required this.page,
  });

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

  @override
  void initState() {
    super.initState();
    _service = UniversalXShareService(supabase: Supabase.instance.client);
    _textController = TextEditingController();
    _generateDraft();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateDraft() async {
    setState(() {
      _loadingDraft = true;
      _statusMessage = null;
    });
    final draft = await _service.generateDraft(widget.page);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _textController.text = draft.text;
      _loadingDraft = false;
      _statusMessage = draft.fallbackUsed ? 'AI生成が不安定なため、安全な定型文を使っています' : null;
    });
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
      if (!mounted) return;
      setState(() {
        _imageUrl = result.url;
        _statusMessage =
            result.url == null ? '画像生成URLを取得できませんでした' : 'シェア画像を生成しました';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = '画像生成に失敗しました: $error');
    } finally {
      if (mounted) setState(() => _generatingImage = false);
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
      );
      if (!mounted) return;
      setState(() {
        _videoUrl = result.url;
        _statusMessage = result.url == null
            ? '動画生成は準備中です。HEDRA_API_KEYや生成結果を確認してください'
            : 'シェア動画を生成しました';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = '動画生成に失敗しました: $error');
    } finally {
      if (mounted) setState(() => _generatingVideo = false);
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
      if (!mounted) return;
      setState(() {
        _statusMessage = result.posted
            ? '${result.account ?? '@kanta13jp1'} に投稿しました'
            : '投稿文を保存しました。X API secret設定を確認してください';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'X投稿に失敗しました: $error');
    } finally {
      if (mounted) setState(() => _posting = false);
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
                    label: Text(_generatingVideo ? '動画生成中' : '動画生成'),
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
