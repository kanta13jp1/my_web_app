import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_share_button_preferences_service.dart';
import '../services/inbox_capture_service.dart';
import '../services/universal_x_share_service.dart';
import '../services/x_copy_guardrails.dart';
import 'ai_share_button_settings_panel.dart';
import 'inbox_quick_capture_dialog.dart';

/// 投稿済みツイートの URL を組み立てる純関数。ハンドル名は不要な
/// `https://x.com/i/status/<id>` 形式(アカウント名の @ 付き/表記ゆれに非依存)。
String? composePostedTweetUrl(String? tweetId) {
  final id = tweetId?.trim() ?? '';
  if (id.isEmpty) return null;
  return 'https://x.com/i/status/$id';
}

/// 投稿完了メッセージを組み立てる純関数。動画が付かなかった投稿では、その
/// 理由(例: Hedraクレジット不足)を末尾に残し、operator が投稿画面だけで
/// 「なぜ静止画になったか」を即視認できるようにする。理由は最初の「。」まで
/// (最大60字)に短縮する。
String? _shortenReason(String? videoFailReason) {
  final reason = videoFailReason?.trim() ?? '';
  if (reason.isEmpty) return null;
  var short = reason;
  final period = short.indexOf('。');
  if (period > 0) short = short.substring(0, period);
  final runes = short.runes.toList(growable: false);
  if (runes.length > 60) {
    short = '${String.fromCharCodes(runes.take(60))}…';
  }
  return short;
}

String composePostedStatus({
  required bool posted,
  required String? account,
  required bool videoAttached,
  required String? videoFailReason,
  bool videoReused = false,
  String? reusedVideoDate,
}) {
  if (!posted) {
    return '投稿できませんでした。X API secret設定を確認してください';
  }
  final who = account ?? '@kanta13jp1';
  if (videoAttached && videoReused) {
    // 再利用投稿は劣化系として理由を残す(🎉なし)。
    final when = reusedVideoDate == null ? '' : '$reusedVideoDate生成・';
    final short = _shortenReason(videoFailReason);
    return short == null
        ? '$who に動画付きで投稿しました（$when過去動画を再利用）'
        : '$who に動画付きで投稿しました（$when過去動画を再利用・動画生成不可: $short）';
  }
  if (videoAttached) return '$who に動画付きで投稿しました 🎉';
  final short = _shortenReason(videoFailReason);
  if (short == null) return '$who に画像付きで投稿しました 🎉';
  return '$who に画像付きで投稿しました（動画なし: $short）';
}

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
    final nextPage = UniversalSharePageContext.fromRouteName(routeName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentPage.value = nextPage;
    });
  }
}

/// R33: AI シェア FAB は Navigator の Overlay に載るため、ページの AppBar より
/// 前面に出る。top 配置で `top: 20` のままだと標準 AppBar (kToolbarHeight=56) の
/// actions を覆ってしまい、例えば /admin の「データを更新」ボタンが押せなくなる
/// (実機 build 4873/4877 で発生)。ツールバー高さぶん下げて
/// アプリの chrome を塞がないようにする。bottom 配置は元から干渉しない。
const double kAiShareFabTopOffset = kToolbarHeight + 20;
const double kAiShareFabDefaultBottomOffset = 20;
const double kAiShareFabLandingBottomOffset = 88;
const double kAiShareFabMusubiBottomOffset = 88;
const double kAiShareFabMinScreenWidth = 600;

bool shouldShowUniversalAiShareFab({
  required String routePath,
  required bool isLoggedIn,
  double screenWidth = double.infinity,
}) {
  return screenWidth >= kAiShareFabMinScreenWidth &&
      (routePath != '/' || isLoggedIn);
}

double resolveAiShareFabBottomOffset({
  required String routePath,
  required double screenWidth,
}) {
  final isMusubi = routePath == '/musubi' || routePath == '/social-feed';
  if (isMusubi) return kAiShareFabMusubiBottomOffset;

  final isLandingMobile = routePath == '/' && screenWidth < 720;
  return isLandingMobile
      ? kAiShareFabLandingBottomOffset
      : kAiShareFabDefaultBottomOffset;
}

class UniversalAiShareShell extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool? isLoggedInOverride;
  final Future<void> Function(String text)? onInboxSave;

  const UniversalAiShareShell({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.isLoggedInOverride,
    this.onInboxSave,
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

        return ValueListenableBuilder<UniversalSharePageContext>(
          valueListenable: universalAiShareRouteObserver.currentPage,
          builder: (context, page, _) {
            return _positionedFab(
              preferences.position,
              SafeArea(
                child: _UniversalAiShareFab(
                  page: page,
                  navigatorKey: widget.navigatorKey,
                  showShare: preferences.visible,
                  isLoggedInOverride: widget.isLoggedInOverride,
                  onInboxSave: widget.onInboxSave,
                ),
              ),
              bottomOffset: resolveAiShareFabBottomOffset(
                routePath: page.routePath,
                screenWidth: MediaQuery.sizeOf(context).width,
              ),
            );
          },
        );
      },
    );
  }

  Widget _positionedFab(
    AiShareButtonPosition position,
    Widget child, {
    required double bottomOffset,
  }) {
    switch (position) {
      case AiShareButtonPosition.topLeft:
        return Positioned(left: 16, top: kAiShareFabTopOffset, child: child);
      case AiShareButtonPosition.topRight:
        return Positioned(right: 16, top: kAiShareFabTopOffset, child: child);
      case AiShareButtonPosition.bottomLeft:
        return Positioned(left: 16, bottom: bottomOffset, child: child);
      case AiShareButtonPosition.bottomRight:
        return Positioned(right: 16, bottom: bottomOffset, child: child);
    }
  }
}

class _UniversalAiShareFab extends StatelessWidget {
  final UniversalSharePageContext page;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool showShare;
  final bool? isLoggedInOverride;
  final Future<void> Function(String text)? onInboxSave;

  const _UniversalAiShareFab({
    required this.page,
    required this.navigatorKey,
    required this.showShare,
    this.isLoggedInOverride,
    this.onInboxSave,
  });

  bool get _isLoggedIn {
    if (isLoggedInOverride != null) return isLoggedInOverride!;
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

  void _openInboxDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final overlayContext = navigatorKey.currentState?.overlay?.context;
      if (overlayContext == null || !overlayContext.mounted) return;

      final save = onInboxSave ?? _saveInboxWithSupabase;
      final saved = await showDialog<bool>(
        context: overlayContext,
        useRootNavigator: true,
        builder: (_) => InboxQuickCaptureDialog(onSave: save),
      );
      if (saved != true || !overlayContext.mounted) return;

      final isAlreadyOnNotes =
          page.routePath == '/notes' || page.routePath == '/note-list';
      ScaffoldMessenger.maybeOf(overlayContext)?.showSnackBar(
        SnackBar(
          content: const Text('Inboxに保存しました'),
          action: isAlreadyOnNotes
              ? null
              : SnackBarAction(
                  label: 'Inboxを見る',
                  onPressed: () =>
                      navigatorKey.currentState?.pushNamed('/notes'),
                ),
        ),
      );
    });
  }

  Future<void> _saveInboxWithSupabase(String text) async {
    final service = InboxCaptureService(Supabase.instance.client);
    await service.save(text);
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
    final showInbox = isLoggedIn;
    final showShareAction = showShare &&
        shouldShowUniversalAiShareFab(
          routePath: page.routePath,
          isLoggedIn: isLoggedIn,
          screenWidth: MediaQuery.sizeOf(context).width,
        );
    if (!showInbox && !showShareAction) {
      return const SizedBox.shrink();
    }

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
          if (showInbox)
            Tooltip(
              message: 'Inboxへメモ',
              child: IconButton(
                key: const Key('universal_inbox_capture_button'),
                onPressed: _openInboxDialog,
                icon: const Icon(Icons.inbox_outlined),
                color: foregroundColor,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          if (showInbox && showShareAction)
            Container(
              width: 1,
              height: 28,
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          if (showShareAction) ...[
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
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
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
  // 動画エンジン等のユーザー設定(設定パネルと同一のグローバル controller)。
  AiShareButtonPreferencesController get _preferencesController =>
      aiShareButtonPreferencesController;

  late final UniversalXShareService _service;
  late final TextEditingController _textController;
  UniversalXShareDraft? _draft;
  String? _imageUrl;
  String? _videoUrl;
  // 過去生成動画の再利用状態(新規生成が不可のとき静止画の代わりに使う)。
  bool _videoReused = false;
  bool _reusedVideoSameDay = false;
  String? _reusedVideoDateLabel; // 例 '7/6'
  String? _statusMessage;
  String? _postedTweetUrl;
  bool _loadingDraft = true;
  bool _generatingImage = false;
  bool _generatingVideo = false;
  bool _posting = false;
  bool _disposed = false;

  /// R24: リンク位置。既定は「リードにURL」= false。
  ///
  /// 従来は `linkInReply: true` をハードコードしていたが、実測 (X analytics
  /// 2026-04-27〜07-25 / 350投稿) がこの既定を否定した:
  ///   - リンクをリードに置く経路 (地方議員集計 / `'$body\n\n$publicUrl'`)
  ///     … 5本で URL クリック 286件 = アカウント全クリックの 94%
  ///   - この経路が生成した最終CTAリプライ「試せるURLはこちらです。5分だけ
  ///     触って…」… 30 impressions / プロダクト系24本で計 2クリック
  /// A/B の余地は残す (performance_context の "link placement" lift は両方の
  /// バケットに n>=2 が無いと沈黙するため、切り替え自体は残す必要がある)。
  bool _linkInReply = false;

  @override
  void initState() {
    super.initState();
    // 通常は shell 側で読込済(冪等)。ダイアログ単体表示でも設定を反映する。
    _preferencesController.load();
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
      // R22: exact 禁止語はプロンプトだけでは毎回すり抜けが出る(実測 2026-07-11:
      // 「ウェブアプリ」「ぜひ試して」等)。決定的検出で非ブロッキング警告を出す
      // (投稿は止めない・自動再生成もしない = 有償生成 foot-gun 回避)。
      final slopWarning = composeSlopWarning(
        detectSlop(draft.text, draft.threadReplies.join('\n')),
      );
      // R27: 年号は事実主張なのでスロップより優先して出す。プロンプトに
      // 「never invent another year (e.g. never write 2024)」があるにも関わらず、
      // 実際に `デイリーブリーフィング — 2024/07/05 朝` が出荷された実例がある。
      final staleYearWarning = composeStaleYearWarning(
        detectStaleYears('${draft.text}\n${draft.threadReplies.join('\n')}'),
      );
      setState(() {
        _draft = draft;
        _textController.text = draft.text;
        _loadingDraft = false;
        _statusMessage = draft.fallbackUsed
            ? 'AI生成が不安定なため、安全な定型文を使っています'
            : (staleYearWarning ?? slopWarning);
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
  Future<void> _openPostedTweet() async {
    final url = _postedTweetUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

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
      _postedTweetUrl = null;
    });
    // 動画が生成できなかった理由。投稿完了メッセージへ残し、静止画になった
    // 原因(例: Hedraクレジット不足)を operator が投稿画面で即視認できるようにする
    // (従来は投稿前の一瞬のステータスにしか出ず、気づけなかった)。
    String? videoFailReason;
    try {
      // 0. X spend-cap preflight(R15)。cap 到達中は投稿が確定失敗するのに、
      // 従来は GPT画像+ElevenLabs+Hedra(~119クレジット+最大7.5分)を全部生成
      // してから投稿で失敗していた(実障害 2026-07-08)。ブロック中は有償生成と
      // 投稿試行を丸ごとスキップし、解除手段を即提示する。文面は生成済みなので
      // このダイアログからコピーして X の投稿画面で手動投稿は引き続き可能。
      final preflight = await _service.checkXPostPreflight();
      if (_disposed || !mounted) return;
      if (preflight.blocked) {
        final resetNote = preflight.resetAt == null
            ? ''
            : '（${preflight.resetAt} に自動リセット見込み）';
        setState(() {
          _posting = false;
          _statusMessage = 'X APIのspend cap到達中のため、画像・音声・動画の生成と'
              'API投稿をスキップしました$resetNote。console.x.com の'
              '「支出上限を管理」で引き上げると即時解除されます。上の文面を'
              'コピーして X で手動投稿することは可能です。';
        });
        return;
      }
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
      // 2. 音声+動画(Hedra / fal.ai とも非同期。生成IDが返ったら完了までポーリング)
      // 動画エンジンは設定パネルで選択(既定は従来どおり Hedra プレゼンター動画)。
      final videoEngine = _preferencesController.preferences.videoEngine;
      final cinematic = videoEngine == AiShareVideoEngine.cinematic;
      if (_videoUrl == null) {
        setState(() {
          _generatingVideo = true;
          _statusMessage = cinematic
              ? 'AIがシネマティック動画を生成しています…（fal.aiは数分かかる場合があります）'
              : 'AIが音声と動画を生成しています…（Hedraは数分かかる場合があります）';
        });
        // preflight: 直近24h以内の Hedra クレジット不足失敗(以後の成功なし)を
        // 検出したら、ElevenLabs TTS を含む生成経路を丸ごとスキップして過去
        // 動画の再利用へ直行する(枯渇中の試行毎の TTS 代 + 30-60 秒待ちを除去)。
        // クレジット補充後は TTL 24h 失効時の実試行で自動復帰する。
        // Hedra 固有の課金失敗検出なので cinematic エンジンでは適用しない。
        List<Map<String, dynamic>> shareHistory = const [];
        try {
          shareHistory = await _service.fetchShareVideoHistory();
        } catch (_) {}
        if (_disposed || !mounted) return;
        var skipGeneration = false;
        if (!cinematic) {
          skipGeneration = UniversalXShareService.shouldSkipVideoGeneration(
            shareHistory,
            nowUtc: DateTime.now().toUtc(),
          );
        }
        var video = skipGeneration
            ? const UniversalXMediaResult(
                url: null,
                status: 'billing_preflight_skipped',
                raw: {
                  'videoReason': 'Hedra クレジット不足（直近24h内の失敗を検出し生成をスキップ）',
                },
              )
            : await _service.generateVideo(
                context: widget.page,
                draft: draft,
                imageUrl: _imageUrl,
                engine: videoEngine,
              );
        final generationIdKey =
            cinematic ? 'falRequestId' : 'hedraGenerationId';
        var generationId = video.url == null
            ? _extractString(video.raw, generationIdKey)
            : null;
        // Hedra / fal.ai は非同期で数分かかる。静止画で投稿されないよう、
        // 動画URLが返るまでポーリングして完成を待つ。Hedra の台本は短尺(<=450字)に
        // 制限済で通常数分内に完成するが、キュー変動に備え約7分半まで待つ
        // (defense-in-depth)。fal.ai text-to-video も同予算内に収まる。
        const maxPolls = 45;
        for (var polls = 0;
            video.url == null && generationId != null && polls < maxPolls;
            polls += 1) {
          await Future<void>.delayed(const Duration(seconds: 10));
          if (_disposed || !mounted) return;
          final elapsed = (polls + 1) * 10;
          setState(() {
            _statusMessage = cinematic
                ? 'シネマティック動画を生成しています…（約$elapsed秒経過 / 最大約7分半）'
                : '音声と動画を生成しています…（約$elapsed秒経過 / 最大約7分半）';
          });
          video = await _service.generateVideo(
            context: widget.page,
            draft: draft,
            imageUrl: _imageUrl,
            hedraGenerationId: cinematic ? null : generationId,
            falRequestId: cinematic ? generationId : null,
            engine: videoEngine,
          );
          generationId = video.url == null
              ? (_extractString(video.raw, generationIdKey) ?? generationId)
              : null;
        }
        if (_disposed || !mounted) return;
        _videoUrl = video.url;
        setState(() => _generatingVideo = false);
        if (_videoUrl == null) {
          final reason =
              _extractString(video.raw, 'videoReason') ?? '時間内に完了しませんでした';
          videoFailReason = reason;
          // 静止画へ降格する前に、保存済みの過去生成動画(7日以内・同日/字幕優先)
          // を再利用する。取得失敗時は従来どおり静止画(never-throw)。
          try {
            final reused = await _service.fetchReusableVideo(
              context: widget.page,
              history: shareHistory.isNotEmpty ? shareHistory : null,
            );
            if (_disposed || !mounted) return;
            if (reused != null) {
              _videoUrl = reused.url;
              _videoReused = true;
              _reusedVideoSameDay = reused.sameDay;
              _reusedVideoDateLabel = reused.dateLabel;
            }
          } catch (_) {}
          if (_disposed || !mounted) return;
          setState(
            () => _statusMessage = _videoReused
                ? '新規動画は生成できませんでした（$reason）。過去の生成動画'
                    '（${_reusedVideoDateLabel ?? '?'}生成）を再利用して投稿します。'
                : '動画は生成できませんでした（$reason）。画像付きで投稿します。',
          );
        }
      }
      // 3. X 投稿(既定はリードにURL / スレッド返信も投稿)
      final postedMedia = _videoUrl != null ? '動画' : '画像';
      setState(() => _statusMessage = 'Xに投稿しています…（$postedMedia付き）');
      // 非同日の再利用動画のみ最終リプへ1行開示する(リード1行目のフックには
      // 触れない)。同日生成の再利用は内容が今日の話題なので注記不要。
      final threadReplies = (_videoReused &&
              !_reusedVideoSameDay &&
              _reusedVideoDateLabel != null)
          ? <String>[
              ...draft.threadReplies,
              '※動画は過去生成分（$_reusedVideoDateLabel）を再利用しています',
            ]
          : draft.threadReplies;
      final result = await _service.postToX(
        context: widget.page,
        text: _textController.text,
        mediaUrl: _videoUrl ?? _imageUrl,
        threadReplies: threadReplies,
        linkInReply: _linkInReply,
        // ネイティブ投票(H7 / impressions ブースター)。draft.poll が null の
        // ときは従来と完全に同一の投稿になる(additive / default-off)。
        poll: draft.poll,
        // 定型文フォールバック投稿を perf 計測で分離するためのタグ。
        fallbackUsed: draft.fallbackUsed,
      );
      if (_disposed || !mounted) return;
      setState(() {
        _statusMessage = composePostedStatus(
          posted: result.posted,
          account: result.account,
          videoAttached: _videoUrl != null,
          videoFailReason: videoFailReason,
          videoReused: _videoReused,
          reusedVideoDate: _reusedVideoDateLabel,
        );
        // ゴールデンアワー導線用(投稿を開くボタン)。
        _postedTweetUrl =
            result.posted ? composePostedTweetUrl(result.tweetId) : null;
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
              AnimatedBuilder(
                animation: _preferencesController,
                builder: (context, _) => _CreativePipelineCard(
                  textReady: !_loadingDraft && _draft != null,
                  imageReady: _imageUrl != null,
                  videoReady: _videoUrl != null,
                  generatingText: _loadingDraft,
                  generatingImage: _generatingImage,
                  generatingVideo: _generatingVideo,
                  videoReused: _videoReused,
                  cinematic: _preferencesController.preferences.videoEngine ==
                      AiShareVideoEngine.cinematic,
                ),
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
              // R24: リンク位置の A/B スイッチ。既定 (リードにURL) は実測に
              // 従う。切り替えを残すのは、performance_context の
              // "link placement" lift が両バケット n>=2 で初めて出るため。
              SwitchListTile.adaptive(
                value: _linkInReply,
                onChanged: _posting
                    ? null
                    : (value) => setState(() => _linkInReply = value),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('URLを最終リプライに置く'),
                subtitle: Text(
                  _linkInReply
                      ? 'A/B用。実測ではこの配置のCTAリプライは30impに留まりました'
                      : '既定。実測でクリックの94%はリードにURLがある投稿から出ています',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (mediaUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  _videoReused
                      ? '添付メディア（過去動画を再利用）: ${_mediaDisplayText(mediaUrl)}'
                      : '添付メディア: ${_mediaDisplayText(mediaUrl)}',
                ),
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
              if (_postedTweetUrl != null) ...[
                const SizedBox(height: 4),
                // ゴールデンアワー導線: 投稿直後 30-60 分の初速エンゲージが
                // リーチを複利で伸ばす。開いて確認・当日の看板ならピン留め・
                // 実コメントには手動で返信する(自動返信はしない)。
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _openPostedTweet,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('投稿を開く（最初の30分の反応が伸びを決めます）'),
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
  final bool videoReused;
  final bool cinematic;

  const _CreativePipelineCard({
    required this.textReady,
    required this.imageReady,
    required this.videoReady,
    required this.generatingText,
    required this.generatingImage,
    required this.generatingVideo,
    this.videoReused = false,
    this.cinematic = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = <_PipelineStepData>[
      // 実際に使うツールを正確に表示する(嘘のパイプラインにしない)。
      // presenter: 文章=GPT-5.5(ai-hub) / 画像=GPT image / 音声=ElevenLabs / 動画=Hedra。
      // cinematic: 文章=GPT-5.5 / 画像=GPT image(静止画フォールバック用) /
      //            動画=fal.ai text-to-video(音声・アバターなし)。
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
      if (!cinematic)
        _PipelineStepData(
          index: 3,
          model: 'ElevenLabs',
          role: '音声',
          icon: Icons.record_voice_over_outlined,
          state: _stateFor(
            ready: videoReady,
            running: generatingVideo,
            reused: videoReused,
          ),
        ),
      _PipelineStepData(
        index: cinematic ? 3 : 4,
        model: cinematic ? 'fal.ai' : 'Hedra',
        role: '動画',
        icon: Icons.movie_creation_outlined,
        state: _stateFor(
          ready: videoReady,
          running: generatingVideo,
          reused: videoReused,
        ),
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
    bool reused = false,
  }) {
    if (running) return _PipelineStepState.running;
    if (ready) {
      // 再利用時は ElevenLabs/Hedra とも新規生成していないことを正直に表示。
      return reused ? _PipelineStepState.reused : _PipelineStepState.ready;
    }
    return _PipelineStepState.waiting;
  }
}

enum _PipelineStepState { waiting, running, ready, reused }

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
      _PipelineStepState.reused => const Color(0xFF2563EB),
      _PipelineStepState.waiting => theme.colorScheme.onSurfaceVariant,
    };
    final status = switch (step.state) {
      _PipelineStepState.ready => 'ready',
      _PipelineStepState.running => 'running',
      _PipelineStepState.reused => '再利用',
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
