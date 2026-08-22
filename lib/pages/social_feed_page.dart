import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/musubi_engagement_models.dart';
import '../models/musubi_social_models.dart';
import '../services/musubi_engagement_controllers.dart';
import '../services/musubi_feature_dependencies.dart';
import '../services/musubi_social_controller.dart';
import '../theme/design_tokens.dart';
import '../widgets/musubi_post_content.dart';
import 'musubi_engagement_views.dart';

/// 既存の `/social-feed` 導線を保ったまま、MUSUBIを公開する互換エントリ。
class SocialFeedPage extends MusubiSocialPage {
  const SocialFeedPage({super.key});
}

/// 注目を奪うのではなく、文脈と信頼を中心に会話を育てるSNS MVP。
class MusubiSocialPage extends StatefulWidget {
  const MusubiSocialPage({
    super.key,
    this.controller,
    this.dependencies,
    this.autoInitialize = true,
  });

  final MusubiSocialController? controller;
  final MusubiFeatureDependencies? dependencies;
  final bool autoInitialize;

  @override
  State<MusubiSocialPage> createState() => _MusubiSocialPageState();
}

class _MusubiSocialPageState extends State<MusubiSocialPage> {
  late final MusubiSocialController _controller;
  late final MusubiDiscoveryController _discoveryController;
  late final MusubiMessagesController _messagesController;
  late final MusubiTrustController _trustController;
  late final MusubiResearchController _researchController;
  late final Listenable _pageListenable;
  late final bool _ownsController;
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  MusubiDestination _destination = MusubiDestination.feed;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    final dependencies = widget.dependencies ??
        (widget.controller == null
            ? MusubiFeatureDependencies.production()
            : MusubiFeatureDependencies.preview());
    _controller = widget.controller ??
        MusubiSocialController(
          repository: dependencies.socialRepository,
          realtimeRepository: dependencies.realtimeRepository,
        );
    _discoveryController = MusubiDiscoveryController(
      repository: dependencies.discoveryRepository,
    );
    _messagesController = MusubiMessagesController(
      repository: dependencies.messagingRepository,
    );
    _trustController = MusubiTrustController(
      repository: dependencies.trustRepository,
    );
    _researchController = MusubiResearchController(
      repository: dependencies.researchRepository,
    );
    _pageListenable = Listenable.merge(<Listenable>[
      _controller,
      _discoveryController,
      _messagesController,
      _trustController,
      _researchController,
    ]);
    if (widget.autoInitialize) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    await Future.wait<void>(<Future<void>>[
      _controller.initialize(),
      _discoveryController.initialize(),
      _messagesController.initialize(),
      _trustController.initialize(),
      _researchController.initialize(),
    ]);
    await _researchController.record('musubi.opened');
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    _discoveryController.dispose();
    _messagesController.dispose();
    _trustController.dispose();
    _researchController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final published = await _controller.createPost(_composerController.text);
    if (!mounted) return;
    if (published) {
      _composerController.clear();
      _composerFocus.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MUSUBIに投稿しました'),
          backgroundColor: DesignTokens.green,
        ),
      );
    }
  }

  void _selectDestination(MusubiDestination destination) {
    if (_destination == destination) return;
    setState(() => _destination = destination);
    unawaited(
      _researchController.record(
        'musubi.destination.opened',
        <String, Object?>{'destination': destination.name},
      ),
    );
  }

  void _compose() {
    _selectDestination(MusubiDestination.feed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  void _startMessage(MusubiSearchResult person) {
    _selectDestination(MusubiDestination.messages);
    unawaited(_messagesController.startConversation(person));
  }

  Future<void> _reportPost(MusubiPost post) async {
    final reason = await showModalBottomSheet<MusubiReportReason>(
      context: context,
      backgroundColor: DesignTokens.surface1,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: DesignTokens.space16),
          children: [
            const ListTile(
              title: Text(
                'この投稿を報告',
                style: TextStyle(
                  color: DesignTokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '報告者の情報は投稿者に共有されません。',
                style: TextStyle(color: DesignTokens.textSecondary),
              ),
            ),
            for (final item in MusubiReportReason.values)
              ListTile(
                onTap: () => Navigator.pop(context, item),
                leading: const Icon(
                  Icons.flag_outlined,
                  color: DesignTokens.orange,
                ),
                title: Text(
                  _reportReasonLabel(item),
                  style: const TextStyle(color: DesignTokens.textOnDark),
                ),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final submitted = await _trustController.reportPost(
      postId: post.id,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitted ? '報告を受け付けました' : '報告を送信できませんでした',
        ),
        backgroundColor: submitted ? DesignTokens.green : DesignTokens.orange,
      ),
    );
  }

  void _showFeedControls() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignTokens.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXl),
        ),
      ),
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.space24),
            child: _AlgorithmPanel(controller: _controller, isSheet: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pageListenable,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: DesignTokens.background,
          appBar: _buildAppBar(),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width < 760) {
                return _selectedPane(compact: true);
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LeftNavigation(
                    compact: width < 1060,
                    selected: _destination,
                    onCompose: _compose,
                    onSelected: _selectDestination,
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: DesignTokens.divider,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _destination == MusubiDestination.messages
                              ? 980
                              : 760,
                        ),
                        child: _selectedPane(),
                      ),
                    ),
                  ),
                  if (width >= 1180 &&
                      _destination == MusubiDestination.feed) ...[
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: DesignTokens.divider,
                    ),
                    SizedBox(
                      width: math.min(340, width * .25),
                      child: _RightSidebar(controller: _controller),
                    ),
                  ],
                ],
              );
            },
          ),
          bottomNavigationBar: MediaQuery.sizeOf(context).width < 760
              ? _MobileNavigation(
                  selected: _destination,
                  onSelected: _selectDestination,
                )
              : null,
        );
      },
    );
  }

  Widget _selectedPane({bool compact = false}) {
    return switch (_destination) {
      MusubiDestination.feed => _FeedPane(
          controller: _controller,
          composerController: _composerController,
          composerFocus: _composerFocus,
          onPublish: _publish,
          onFeedControls: _showFeedControls,
          onSecondaryAction: (_) {},
          onReport: _reportPost,
          compact: compact,
        ),
      MusubiDestination.discover => MusubiSearchView(
          controller: _discoveryController,
          onMessage: _startMessage,
        ),
      MusubiDestination.communities => MusubiCommunitiesView(
          communities: _controller.communities,
          onToggle: _controller.toggleCommunity,
        ),
      MusubiDestination.messages =>
        MusubiMessagesView(controller: _messagesController),
      MusubiDestination.saved =>
        MusubiSavedView(posts: _controller.bookmarkedPosts),
      MusubiDestination.safety => MusubiSafetyView(
          trustController: _trustController,
          researchController: _researchController,
        ),
    };
  }

  AppBar _buildAppBar() {
    final compactTitle = MediaQuery.sizeOf(context).width < 500;
    return AppBar(
      backgroundColor: DesignTokens.surface1,
      foregroundColor: DesignTokens.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: DesignTokens.space16,
      title: Row(
        children: [
          _KnotMark(size: compactTitle ? 30 : 34),
          SizedBox(
            width: compactTitle ? DesignTokens.space8 : DesignTokens.space12,
          ),
          Column(
            key: const Key('musubi_page_title'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MUSUBI',
                style: TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              if (!compactTitle)
                const Text(
                  '人と文脈が主役のソーシャル',
                  style: TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (!compactTitle)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: DesignTokens.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
              border: Border.all(
                color: DesignTokens.green.withValues(alpha: .35),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 13,
                  color: DesignTokens.green,
                ),
                SizedBox(width: 4),
                Text(
                  'HUMAN FIRST',
                  style: TextStyle(
                    color: DesignTokens.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
        if (!compactTitle)
          Padding(
            padding: const EdgeInsets.only(left: DesignTokens.space8),
            child: _RealtimeBadge(
              state: _controller.realtimeState,
              onReconnect: _controller.connectRealtime,
            ),
          ),
        IconButton(
          tooltip: 'セーフティセンター',
          onPressed: () => _selectDestination(MusubiDestination.safety),
          icon: const Icon(Icons.shield_outlined),
        ),
        IconButton(
          tooltip: 'フィードのしくみ',
          onPressed: _showFeedControls,
          icon: const Icon(Icons.tune_rounded),
        ),
        const SizedBox(width: DesignTokens.space4),
      ],
    );
  }
}

class _FeedPane extends StatelessWidget {
  const _FeedPane({
    required this.controller,
    required this.composerController,
    required this.composerFocus,
    required this.onPublish,
    required this.onFeedControls,
    required this.onSecondaryAction,
    required this.onReport,
    this.compact = false,
  });

  final MusubiSocialController controller;
  final TextEditingController composerController;
  final FocusNode composerFocus;
  final VoidCallback onPublish;
  final VoidCallback onFeedControls;
  final ValueChanged<String> onSecondaryAction;
  final ValueChanged<MusubiPost> onReport;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final posts = controller.visiblePosts;
    return CustomScrollView(
      key: const PageStorageKey<String>('musubi-feed-scroll'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            compact ? DesignTokens.space12 : DesignTokens.space20,
            DesignTokens.space16,
            compact ? DesignTokens.space12 : DesignTokens.space20,
            0,
          ),
          sliver: SliverList.list(
            children: [
              _MissionBanner(compact: compact, onFeedControls: onFeedControls),
              const SizedBox(height: DesignTokens.space16),
              _GatheringStrip(
                communities: controller.communities,
                onTap: (label) => onSecondaryAction(label),
              ),
              const SizedBox(height: DesignTokens.space16),
              _LensSelector(controller: controller),
              const SizedBox(height: DesignTokens.space12),
              _Composer(
                controller: controller,
                textController: composerController,
                focusNode: composerFocus,
                onPublish: onPublish,
                onSecondaryAction: onSecondaryAction,
              ),
              if (controller.notice != null) ...[
                const SizedBox(height: DesignTokens.space12),
                _NoticeBanner(
                  message: controller.notice!,
                  onDismiss: controller.clearNotice,
                ),
              ],
              const SizedBox(height: DesignTokens.space12),
              _FeedReasonBar(
                lens: controller.activeLens,
                isChronological: controller.preferences.chronological,
                onTap: onFeedControls,
              ),
              if (controller.isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: DesignTokens.space12),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: DesignTokens.orange,
                    backgroundColor: DesignTokens.surface3,
                  ),
                ),
              const SizedBox(height: DesignTokens.space12),
            ],
          ),
        ),
        if (posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFeed(
              onReset: () {
                controller.setLens(MusubiFeedLens.resonance);
              },
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              compact ? DesignTokens.space8 : DesignTokens.space20,
              0,
              compact ? DesignTokens.space8 : DesignTokens.space20,
              DesignTokens.space32,
            ),
            sliver: SliverList.separated(
              itemCount: posts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: DesignTokens.space12),
              itemBuilder: (context, index) {
                final post = posts[index];
                return _MusubiPostCard(
                  key: ValueKey<String>('musubi-post-${post.id}'),
                  post: post,
                  onLike: () => controller.toggleLike(post.id),
                  onBookmark: () => controller.toggleBookmark(post.id),
                  onReply: () => onSecondaryAction('返信'),
                  onBoost: () => onSecondaryAction('共感で広げる'),
                  onReport: () => onReport(post),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: DesignTokens.space32)),
      ],
    );
  }
}

class _MissionBanner extends StatelessWidget {
  const _MissionBanner({required this.compact, required this.onFeedControls});

  final bool compact;
  final VoidCallback onFeedControls;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? DesignTokens.space16 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF23152D), Color(0xFF121E3C), Color(0xFF111111)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: .32)),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.indigo.withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: compact ? -26 : 8,
            top: compact ? -16 : -4,
            child: Opacity(
              opacity: .32,
              child: _KnotMark(size: compact ? 112 : 134),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'SOCIAL, OWNED BY PEOPLE'),
              const SizedBox(height: DesignTokens.space8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 300 : 470),
                child: Text(
                  '注目を奪わず、\nつながりを育てる。',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: compact ? 23 : 29,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    letterSpacing: .7,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const Text(
                  'アルゴリズム、翻訳、AI利用、出典を隠しません。何を見るかは、あなたが決めます。',
                  style: TextStyle(
                    color: DesignTokens.textOnDark,
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space16),
              Wrap(
                spacing: DesignTokens.space8,
                runSpacing: DesignTokens.space8,
                children: [
                  const _MetricPill(
                    icon: Icons.block_flipped,
                    label: '監視広告 0',
                    color: DesignTokens.green,
                  ),
                  const _MetricPill(
                    icon: Icons.person_outline,
                    label: 'フィード所有者 あなた',
                    color: DesignTokens.orange,
                  ),
                  OutlinedButton.icon(
                    onPressed: onFeedControls,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.textPrimary,
                      side: BorderSide(
                        color: DesignTokens.textPrimary.withValues(alpha: .25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusCircle,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.tune, size: 15),
                    label: const Text('調整する', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GatheringStrip extends StatelessWidget {
  const _GatheringStrip({required this.communities, required this.onTap});

  final List<MusubiCommunity> communities;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: DesignTokens.space4),
          child: Text(
            'いま、集まっている場所',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: communities.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: DesignTokens.space8),
            itemBuilder: (context, index) {
              final community = communities[index];
              return Material(
                color: DesignTokens.surface1,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                child: InkWell(
                  onTap: () => onTap(community.name),
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 174),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space12,
                      vertical: DesignTokens.space8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusMedium,
                      ),
                      border: Border.all(color: DesignTokens.divider),
                    ),
                    child: Row(
                      children: [
                        Text(
                          community.emoji,
                          style: const TextStyle(fontSize: 23),
                        ),
                        const SizedBox(width: DesignTokens.space8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  community.name,
                                  style: const TextStyle(
                                    color: DesignTokens.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (community.isLive) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: DesignTokens.green,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              community.memberLabel,
                              style: const TextStyle(
                                color: DesignTokens.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LensSelector extends StatelessWidget {
  const _LensSelector({required this.controller});

  final MusubiSocialController controller;

  @override
  Widget build(BuildContext context) {
    const items = <(MusubiFeedLens, String, IconData)>[
      (MusubiFeedLens.resonance, '共鳴', Icons.hub_outlined),
      (MusubiFeedLens.following, 'フォロー中', Icons.people_outline),
      (MusubiFeedLens.local, '近くの声', Icons.near_me_outlined),
      (MusubiFeedLens.learning, '学び', Icons.lightbulb_outline),
      (MusubiFeedLens.quiet, '静かな時間', Icons.spa_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            ChoiceChip(
              key: Key('musubi-lens-${item.$1.name}'),
              selected: controller.activeLens == item.$1,
              onSelected: (_) => controller.setLens(item.$1),
              avatar: Icon(
                item.$3,
                size: 15,
                color: controller.activeLens == item.$1
                    ? DesignTokens.orange
                    : DesignTokens.textSecondary,
              ),
              label: Text(item.$2),
              labelStyle: TextStyle(
                color: controller.activeLens == item.$1
                    ? DesignTokens.textPrimary
                    : DesignTokens.textSecondary,
                fontSize: 12,
                fontWeight: controller.activeLens == item.$1
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
              backgroundColor: DesignTokens.surface1,
              selectedColor: DesignTokens.orange.withValues(alpha: .15),
              side: BorderSide(
                color: controller.activeLens == item.$1
                    ? DesignTokens.orange.withValues(alpha: .5)
                    : DesignTokens.divider,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
              ),
              showCheckmark: false,
            ),
            const SizedBox(width: DesignTokens.space8),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.textController,
    required this.focusNode,
    required this.onPublish,
    required this.onSecondaryAction,
  });

  final MusubiSocialController controller;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onPublish;
  final ValueChanged<String> onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('musubi_composer'),
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: .24)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 19,
                backgroundColor: DesignTokens.orange,
                child: Text(
                  '私',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: TextField(
                  key: const Key('musubi_composer_field'),
                  controller: textController,
                  focusNode: focusNode,
                  minLines: 2,
                  maxLines: 7,
                  maxLength: 1000,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 14,
                    height: 1.7,
                  ),
                  decoration: InputDecoration(
                    hintText: 'いま、誰と何を分かち合いたいですか？',
                    hintStyle: const TextStyle(
                      color: DesignTokens.textTertiary,
                      fontSize: 14,
                    ),
                    counterStyle: const TextStyle(
                      color: DesignTokens.textTertiary,
                      fontSize: 10,
                    ),
                    filled: true,
                    fillColor: DesignTokens.surface2,
                    contentPadding: const EdgeInsets.all(DesignTokens.space12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusMedium,
                      ),
                      borderSide: const BorderSide(color: DesignTokens.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusMedium,
                      ),
                      borderSide: const BorderSide(
                        color: DesignTokens.orange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Row(
            children: [
              _ComposerIcon(
                tooltip: '画像を追加',
                icon: Icons.image_outlined,
                onTap: () => onSecondaryAction('画像添付'),
              ),
              _ComposerIcon(
                tooltip: '出典を追加',
                icon: Icons.link_rounded,
                onTap: () => onSecondaryAction('出典追加'),
              ),
              if (MediaQuery.sizeOf(context).width >= 500)
                _ComposerIcon(
                  tooltip: 'アンケート',
                  icon: Icons.poll_outlined,
                  onTap: () => onSecondaryAction('アンケート'),
                ),
              if (MediaQuery.sizeOf(context).width >= 440)
                Tooltip(
                  message: 'AIで作成・編集した場合は表示します',
                  child: Row(
                    children: [
                      Switch(
                        value: controller.aiAssisted,
                        onChanged: controller.setAiAssisted,
                        activeTrackColor: DesignTokens.indigo.withValues(
                          alpha: .7,
                        ),
                        activeThumbColor: DesignTokens.indigoLight,
                      ),
                      const Text(
                        'AI利用を表示',
                        style: TextStyle(
                          color: DesignTokens.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<MusubiAudience>(
                  value: controller.audience,
                  dropdownColor: DesignTokens.surface2,
                  iconEnabledColor: DesignTokens.textSecondary,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 11,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MusubiAudience.public,
                      child: Text('🌏 みんな'),
                    ),
                    DropdownMenuItem(
                      value: MusubiAudience.circles,
                      child: Text('◉ サークル'),
                    ),
                    DropdownMenuItem(
                      value: MusubiAudience.local,
                      child: Text('⌖ 近くの人'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setAudience(value);
                  },
                ),
              ),
              const SizedBox(width: DesignTokens.space8),
              FilledButton(
                key: const Key('musubi_publish_button'),
                onPressed: controller.isPosting ? null : onPublish,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                  disabledBackgroundColor: DesignTokens.orangeDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusMedium,
                    ),
                  ),
                ),
                child: controller.isPosting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '結ぶ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedReasonBar extends StatelessWidget {
  const _FeedReasonBar({
    required this.lens,
    required this.isChronological,
    required this.onTap,
  });

  final MusubiFeedLens lens;
  final bool isChronological;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (lens) {
      MusubiFeedLens.resonance => '共通の関心と選択したコミュニティ',
      MusubiFeedLens.following => 'フォローしている人の投稿',
      MusubiFeedLens.local => '位置をぼかした地域の投稿',
      MusubiFeedLens.learning => '保存したテーマに近い学び',
      MusubiFeedLens.quiet => '強い刺激と拡散数を抑えた投稿',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: DesignTokens.indigoLight,
              ),
              const SizedBox(width: DesignTokens.space8),
              Expanded(
                child: Text(
                  '$label・${isChronological ? '新しい順' : '共鳴度順'}',
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
              const Text(
                'なぜ表示？',
                style: TextStyle(
                  color: DesignTokens.indigoLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusubiPostCard extends StatefulWidget {
  const _MusubiPostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onBookmark,
    required this.onReply,
    required this.onBoost,
    required this.onReport,
  });

  final MusubiPost post;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onReply;
  final VoidCallback onBoost;
  final VoidCallback onReport;

  @override
  State<_MusubiPostCard> createState() => _MusubiPostCardState();
}

class _MusubiPostCardState extends State<_MusubiPostCard> {
  bool _showTranslation = false;
  bool _showContext = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final displayedText = _showTranslation && post.translatedContent != null
        ? post.translatedContent!
        : post.content;
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(label: post.avatarLabel, seed: post.id.hashCode),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            color: DesignTokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (post.isVerifiedHuman)
                          const Tooltip(
                            message: '本人確認済み。実名公開を意味しません',
                            child: Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: DesignTokens.green,
                            ),
                          ),
                        if (post.isAiAssisted)
                          const _MiniBadge(
                            label: 'AI補助',
                            color: DesignTokens.indigoLight,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${post.handle}  ・  ${_relativeTime(post.createdAt)}  ・  ${post.community}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: DesignTokens.textTertiary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '投稿メニュー',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onReport,
                icon: const Icon(
                  Icons.flag_outlined,
                  color: DesignTokens.textTertiary,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          MusubiPostContent(text: displayedText),
          if (post.translatedContent != null) ...[
            const SizedBox(height: DesignTokens.space8),
            TextButton.icon(
              onPressed: () => setState(() {
                _showTranslation = !_showTranslation;
              }),
              style: TextButton.styleFrom(
                foregroundColor: DesignTokens.indigoLight,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.translate, size: 14),
              label: Text(
                _showTranslation ? '原文（${post.languageLabel}）を表示' : '日本語に翻訳',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
          if (post.sourceTitle != null) ...[
            const SizedBox(height: DesignTokens.space12),
            Material(
              color: DesignTokens.surface2,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              child: InkWell(
                onTap: () => setState(() => _showContext = !_showContext),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: post.hasCommunityContext
                          ? DesignTokens.green.withValues(alpha: .35)
                          : DesignTokens.indigo.withValues(alpha: .28),
                    ),
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusMedium,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            post.hasCommunityContext
                                ? Icons.fact_check_outlined
                                : Icons.link_rounded,
                            size: 15,
                            color: post.hasCommunityContext
                                ? DesignTokens.green
                                : DesignTokens.indigoLight,
                          ),
                          const SizedBox(width: DesignTokens.space8),
                          Expanded(
                            child: Text(
                              post.sourceTitle!,
                              style: const TextStyle(
                                color: DesignTokens.textOnDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                          Icon(
                            _showContext
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: DesignTokens.textTertiary,
                          ),
                        ],
                      ),
                      if (_showContext && post.contextNote != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: DesignTokens.space8,
                          ),
                          child: Divider(
                            height: 1,
                            color: DesignTokens.divider,
                          ),
                        ),
                        Text(
                          post.contextNote!,
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space12),
            Wrap(
              spacing: DesignTokens.space8,
              runSpacing: DesignTokens.space4,
              children: post.tags
                  .map(
                    (tag) => Text(
                      '#$tag',
                      style: const TextStyle(
                        color: DesignTokens.orangeLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: DesignTokens.space12),
          const Divider(height: 1, color: DesignTokens.divider),
          const SizedBox(height: DesignTokens.space8),
          Row(
            children: [
              _PostAction(
                key: Key('musubi-like-${post.id}'),
                icon: post.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: _compactCount(post.reactions),
                color: post.isLiked
                    ? DesignTokens.orange
                    : DesignTokens.textSecondary,
                tooltip: '共鳴',
                onTap: widget.onLike,
              ),
              _PostAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: _compactCount(post.replies),
                tooltip: '返信',
                onTap: widget.onReply,
              ),
              _PostAction(
                icon: Icons.hub_outlined,
                label: _compactCount(post.boosts),
                tooltip: '文脈付きで広げる',
                onTap: widget.onBoost,
              ),
              const Spacer(),
              Tooltip(
                message: '共鳴度 ${post.resonance}%：あなたが選んだ条件との一致',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.green.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusCircle,
                    ),
                  ),
                  child: Text(
                    '結び ${post.resonance}%',
                    style: const TextStyle(
                      color: DesignTokens.green,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: Key('musubi-bookmark-${post.id}'),
                tooltip: '保存',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onBookmark,
                icon: Icon(
                  post.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                  color: post.isBookmarked
                      ? DesignTokens.orange
                      : DesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeftNavigation extends StatelessWidget {
  const _LeftNavigation({
    required this.compact,
    required this.selected,
    required this.onCompose,
    required this.onSelected,
  });

  final bool compact;
  final MusubiDestination selected;
  final VoidCallback onCompose;
  final ValueChanged<MusubiDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = <(IconData, MusubiDestination)>[
      (Icons.home_rounded, MusubiDestination.feed),
      (Icons.search_rounded, MusubiDestination.discover),
      (Icons.diversity_3_outlined, MusubiDestination.communities),
      (Icons.forum_outlined, MusubiDestination.messages),
      (Icons.bookmark_border_rounded, MusubiDestination.saved),
      (Icons.shield_outlined, MusubiDestination.safety),
    ];
    return SizedBox(
      width: compact ? 82 : 228,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? DesignTokens.space8 : DesignTokens.space16,
            vertical: DesignTokens.space20,
          ),
          child: Column(
            children: [
              for (var index = 0; index < entries.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.space4),
                  child: Tooltip(
                    message: entries[index].$2.label,
                    child: Material(
                      color: entries[index].$2 == selected
                          ? DesignTokens.orange.withValues(alpha: .13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusMedium,
                      ),
                      child: InkWell(
                        onTap: () => onSelected(entries[index].$2),
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radiusMedium,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space12,
                            vertical: 11,
                          ),
                          child: Row(
                            mainAxisAlignment: compact
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                            children: [
                              Icon(
                                entries[index].$1,
                                size: 21,
                                color: entries[index].$2 == selected
                                    ? DesignTokens.orange
                                    : DesignTokens.textSecondary,
                              ),
                              if (!compact) ...[
                                const SizedBox(width: DesignTokens.space12),
                                Text(
                                  entries[index].$2.label,
                                  style: TextStyle(
                                    color: entries[index].$2 == selected
                                        ? DesignTokens.textPrimary
                                        : DesignTokens.textSecondary,
                                    fontSize: 13,
                                    fontWeight: entries[index].$2 == selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: DesignTokens.space12),
              FilledButton.icon(
                onPressed: onCompose,
                style: FilledButton.styleFrom(
                  minimumSize: Size(compact ? 48 : double.infinity, 46),
                  backgroundColor: DesignTokens.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusMedium,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: compact
                    ? const SizedBox.shrink()
                    : const Text(
                        '投稿する',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignTokens.space12),
                decoration: BoxDecoration(
                  color: DesignTokens.surface1,
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                  border: Border.all(color: DesignTokens.divider),
                ),
                child: compact
                    ? const Tooltip(
                        message: '今日の閲覧 18分／目安 30分',
                        child: Icon(
                          Icons.timelapse_rounded,
                          color: DesignTokens.green,
                        ),
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.timelapse_rounded,
                                size: 15,
                                color: DesignTokens.green,
                              ),
                              SizedBox(width: DesignTokens.space8),
                              Text(
                                '今日のバランス',
                                style: TextStyle(
                                  color: DesignTokens.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: DesignTokens.space8),
                          LinearProgressIndicator(
                            value: .6,
                            minHeight: 5,
                            color: DesignTokens.green,
                            backgroundColor: DesignTokens.surface3,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          SizedBox(height: DesignTokens.space8),
                          Text(
                            '18分 / 自分で決めた30分',
                            style: TextStyle(
                              color: DesignTokens.textTertiary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  const _RightSidebar({required this.controller});

  final MusubiSocialController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        children: [
          _AlgorithmPanel(controller: controller),
          const SizedBox(height: DesignTokens.space16),
          _CommunityPanel(controller: controller),
          const SizedBox(height: DesignTokens.space16),
          const _PortableIdentityCard(),
          const SizedBox(height: DesignTokens.space32),
        ],
      ),
    );
  }
}

class _AlgorithmPanel extends StatelessWidget {
  const _AlgorithmPanel({required this.controller, this.isSheet = false});

  final MusubiSocialController controller;
  final bool isSheet;

  @override
  Widget build(BuildContext context) {
    final preferences = controller.preferences;
    return Container(
      padding: EdgeInsets.all(isSheet ? 0 : DesignTokens.space16),
      decoration: isSheet
          ? null
          : BoxDecoration(
              color: DesignTokens.surface1,
              borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
              border: Border.all(
                color: DesignTokens.indigo.withValues(alpha: .28),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 18,
                color: DesignTokens.indigoLight,
              ),
              const SizedBox(width: DesignTokens.space8),
              const Expanded(
                child: Text(
                  'あなたが決めるフィード',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isSheet)
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: DesignTokens.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.space4),
          const Text(
            'おすすめの理由も、並び順も非公開にしません。',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space16),
          _LabeledSlider(
            label: '新しい出会い',
            value: preferences.discovery,
            color: DesignTokens.indigo,
            onChanged: controller.updateDiscovery,
          ),
          _LabeledSlider(
            label: '近くの声',
            value: preferences.local,
            color: DesignTokens.orange,
            onChanged: controller.updateLocal,
          ),
          const Divider(color: DesignTokens.divider),
          _CompactSwitch(
            title: '新しい順',
            subtitle: '反応数で並び替えない',
            value: preferences.chronological,
            onChanged: controller.setChronological,
          ),
          _CompactSwitch(
            title: '未表示AIを隠す',
            subtitle: 'AI利用表示のない生成投稿を抑える',
            value: preferences.hideUnlabeledAi,
            onChanged: controller.setHideUnlabeledAi,
          ),
          _CompactSwitch(
            title: '終わりのあるフィード',
            subtitle: '一定件数で休憩ポイントを作る',
            value: preferences.pauseInfiniteScroll,
            onChanged: controller.setPauseInfiniteScroll,
          ),
          const SizedBox(height: DesignTokens.space8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: DesignTokens.indigo.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: const Text(
              'この設定はあなたの端末に保存され、広告主には渡りません。',
              style: TextStyle(
                color: DesignTokens.indigoLight,
                fontSize: 9,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPanel extends StatelessWidget {
  const _CommunityPanel({required this.controller});

  final MusubiSocialController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '育っているコミュニティ',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          for (final community in controller.communities) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(community.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: DesignTokens.space8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(
                          color: DesignTokens.textOnDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        community.memberLabel,
                        style: const TextStyle(
                          color: DesignTokens.textTertiary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => controller.toggleCommunity(community.id),
                  style: TextButton.styleFrom(
                    foregroundColor: community.isJoined
                        ? DesignTokens.textSecondary
                        : DesignTokens.orange,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    community.isJoined ? '参加中' : '参加',
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space12),
          ],
        ],
      ),
    );
  }
}

class _PortableIdentityCard extends StatelessWidget {
  const _PortableIdentityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.orange.withValues(alpha: .14),
            DesignTokens.indigo.withValues(alpha: .10),
          ],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: .26)),
      ),
      child: const Row(
        children: [
          Icon(Icons.badge_outlined, color: DesignTokens.orangeLight),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portable ID',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '投稿・フォロー・評価をエクスポート可能',
                  style: TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 9,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: DesignTokens.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.selected,
    required this.onSelected,
  });

  final MusubiDestination selected;
  final ValueChanged<MusubiDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    const destinations = <MusubiDestination>[
      MusubiDestination.feed,
      MusubiDestination.discover,
      MusubiDestination.communities,
      MusubiDestination.messages,
    ];
    final selectedIndex = destinations.indexOf(selected);
    return NavigationBar(
      backgroundColor: DesignTokens.surface1,
      indicatorColor: DesignTokens.orange.withValues(alpha: .16),
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) => onSelected(destinations[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded, color: DesignTokens.orange),
          label: 'ホーム',
        ),
        NavigationDestination(icon: Icon(Icons.search_rounded), label: '見つける'),
        NavigationDestination(
          icon: Icon(Icons.diversity_3_outlined),
          label: 'コミュニティ',
        ),
        NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'メッセージ'),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${value.round()}%',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: DesignTokens.surface3,
            thumbColor: color,
            overlayColor: color.withValues(alpha: .12),
            trackHeight: 3,
          ),
          child: Slider(value: value, max: 100, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      value: value,
      onChanged: onChanged,
      activeTrackColor: DesignTokens.orange.withValues(alpha: .65),
      activeThumbColor: DesignTokens.orangeLight,
      title: Text(
        title,
        style: const TextStyle(
          color: DesignTokens.textOnDark,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: DesignTokens.textTertiary, fontSize: 9),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space12,
        vertical: DesignTokens.space8,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.green.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: DesignTokens.green.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: DesignTokens.green,
          ),
          const SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DesignTokens.textOnDark,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(
              Icons.close,
              size: 15,
              color: DesignTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.spa_outlined,
              size: 54,
              color: DesignTokens.orange,
            ),
            const SizedBox(height: DesignTokens.space16),
            const Text(
              'ここにはまだ静けさがあります',
              style: TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            const Text(
              '別のレンズに切り替えるか、最初の声を投稿してみましょう。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.7,
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            OutlinedButton(onPressed: onReset, child: const Text('共鳴フィードへ戻る')),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, required this.seed});

  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final reverse = seed.isOdd;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: reverse
              ? const [DesignTokens.indigo, DesignTokens.orange]
              : const [DesignTokens.orangeDark, DesignTokens.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: DesignTokens.textPrimary.withValues(alpha: .14),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.color = DesignTokens.textSecondary,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space8,
            vertical: DesignTokens.space8,
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: DesignTokens.space4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: DesignTokens.orangeLight),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: DesignTokens.space4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: DesignTokens.orangeLight,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RealtimeBadge extends StatelessWidget {
  const _RealtimeBadge({required this.state, required this.onReconnect});

  final MusubiRealtimeState state;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      MusubiRealtimeState.preview => ('PREVIEW', DesignTokens.textTertiary),
      MusubiRealtimeState.connecting => ('CONNECTING', DesignTokens.orange),
      MusubiRealtimeState.connected => ('LIVE', DesignTokens.green),
      MusubiRealtimeState.degraded => ('RETRY', DesignTokens.orangeLight),
    };
    return Tooltip(
      message: state == MusubiRealtimeState.connected
          ? '新しい投稿をリアルタイム受信中'
          : 'クリックしてリアルタイム接続を再試行',
      child: InkWell(
        onTap: state == MusubiRealtimeState.connected ? null : onReconnect,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
            border: Border.all(color: color.withValues(alpha: .30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnotMark extends StatelessWidget {
  const _KnotMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MUSUBIの結び目ロゴ',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _KnotPainter()),
    );
  }
}

class _KnotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.max(2.2, size.width * .075);
    final orange = Paint()
      ..color = DesignTokens.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final indigo = Paint()
      ..color = DesignTokens.indigoLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = DesignTokens.orange.withValues(alpha: .12)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(size.center(Offset.zero), size.width * .46, glow);
    final left = Rect.fromCenter(
      center: Offset(size.width * .39, size.height * .5),
      width: size.width * .5,
      height: size.height * .36,
    );
    final right = Rect.fromCenter(
      center: Offset(size.width * .61, size.height * .5),
      width: size.width * .5,
      height: size.height * .36,
    );
    canvas.drawOval(left, orange);
    canvas.drawOval(right, indigo);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * .055,
      Paint()..color = DesignTokens.textPrimary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'いま';
  if (difference.inMinutes < 60) return '${difference.inMinutes}分';
  if (difference.inHours < 24) return '${difference.inHours}時間';
  return '${difference.inDays}日';
}

String _compactCount(int value) {
  if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}万';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String _reportReasonLabel(MusubiReportReason reason) => switch (reason) {
      MusubiReportReason.harassment => '嫌がらせ',
      MusubiReportReason.hate => '差別・ヘイト',
      MusubiReportReason.misinformation => '誤情報',
      MusubiReportReason.impersonation => 'なりすまし',
      MusubiReportReason.spam => 'スパム',
      MusubiReportReason.selfHarm => '自傷・緊急性',
      MusubiReportReason.other => 'その他',
    };
