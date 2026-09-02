import 'package:flutter/material.dart';

import '../models/musubi_engagement_models.dart';
import '../models/musubi_social_models.dart';
import '../services/musubi_engagement_controllers.dart';
import '../theme/design_tokens.dart';
import '../widgets/musubi_post_content.dart';

enum MusubiDestination { feed, discover, communities, messages, saved, safety }

extension MusubiDestinationLabel on MusubiDestination {
  String get label => switch (this) {
        MusubiDestination.feed => 'ホーム',
        MusubiDestination.discover => '見つける',
        MusubiDestination.communities => 'コミュニティ',
        MusubiDestination.messages => 'メッセージ',
        MusubiDestination.saved => '保存',
        MusubiDestination.safety => 'セーフティ',
      };
}

class MusubiSearchView extends StatefulWidget {
  const MusubiSearchView({
    super.key,
    required this.controller,
    required this.onMessage,
  });

  final MusubiDiscoveryController controller;
  final ValueChanged<MusubiSearchResult> onMessage;

  @override
  State<MusubiSearchView> createState() => _MusubiSearchViewState();
}

class _MusubiSearchViewState extends State<MusubiSearchView> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('musubi_discovery_view'),
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        const _SectionHeading(
          eyebrow: 'DISCOVERY WITHOUT SURVEILLANCE',
          title: '人・投稿・コミュニティを横断検索',
          description: '広告プロファイルではなく、公開された言葉と文脈だけを検索します。',
          icon: Icons.search_rounded,
        ),
        const SizedBox(height: DesignTokens.space16),
        TextField(
          key: const Key('musubi_search_field'),
          controller: _queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: widget.controller.search,
          decoration: InputDecoration(
            hintText: '例：地域、防災、フィード設計、@handle',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              key: const Key('musubi_search_button'),
              tooltip: '検索',
              onPressed: () => widget.controller.search(_queryController.text),
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            filled: true,
            fillColor: DesignTokens.surface1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              borderSide: const BorderSide(color: DesignTokens.divider),
            ),
          ),
        ),
        if (widget.controller.isSearching)
          const Padding(
            padding: EdgeInsets.only(top: DesignTokens.space12),
            child: LinearProgressIndicator(color: DesignTokens.orange),
          ),
        if (widget.controller.notice != null)
          Padding(
            padding: const EdgeInsets.only(top: DesignTokens.space12),
            child: Text(
              widget.controller.notice!,
              style: const TextStyle(color: DesignTokens.textSecondary),
            ),
          ),
        const SizedBox(height: DesignTokens.space16),
        for (final result in widget.controller.results)
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.space12),
            child: _SearchResultCard(
              result: result,
              onMessage: result.kind == MusubiSearchKind.person
                  ? () => widget.onMessage(result)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, this.onMessage});

  final MusubiSearchResult result;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final icon = switch (result.kind) {
      MusubiSearchKind.post => Icons.article_outlined,
      MusubiSearchKind.person => Icons.person_outline_rounded,
      MusubiSearchKind.community => Icons.diversity_3_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: _panelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DesignTokens.indigo.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Icon(icon, color: DesignTokens.indigoLight),
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result.subtitle,
                  style: const TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (result.highlight case final highlight?) ...[
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    highlight,
                    style: const TextStyle(
                      color: DesignTokens.textOnDark,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMessage != null)
            IconButton.filledTonal(
              key: Key('musubi_message_${result.id}'),
              tooltip: '安全なDMを開始',
              onPressed: onMessage,
              icon: const Icon(Icons.forum_outlined, size: 18),
            ),
        ],
      ),
    );
  }
}

class MusubiMessagesView extends StatefulWidget {
  const MusubiMessagesView({super.key, required this.controller});

  final MusubiMessagesController controller;

  @override
  State<MusubiMessagesView> createState() => _MusubiMessagesViewState();
}

class _MusubiMessagesViewState extends State<MusubiMessagesView> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (await widget.controller.sendMessage(_messageController.text)) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final conversationList =
            _ConversationList(controller: widget.controller);
        final conversation = _ConversationPane(
          controller: widget.controller,
          messageController: _messageController,
          onSend: _send,
        );
        return Container(
          key: const Key('musubi_messages_view'),
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Column(
            children: [
              const _SectionHeading(
                eyebrow: 'PRIVATE BY DEFAULT',
                title: '追跡されないダイレクトメッセージ',
                description: '参加者だけが読めるRLS保護とリアルタイム受信を使います。',
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: DesignTokens.space16),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          SizedBox(width: 230, child: conversationList),
                          const SizedBox(width: DesignTokens.space12),
                          Expanded(child: conversation),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(height: 108, child: conversationList),
                          const SizedBox(height: DesignTokens.space12),
                          Expanded(child: conversation),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.controller});

  final MusubiMessagesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.conversations.isEmpty) {
      return const Center(
        child: Text(
          '検索から人を選ぶと会話を開始できます',
          textAlign: TextAlign.center,
          style: TextStyle(color: DesignTokens.textSecondary, fontSize: 11),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: MediaQuery.sizeOf(context).width < 620
          ? Axis.horizontal
          : Axis.vertical,
      itemCount: controller.conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6, width: 6),
      itemBuilder: (context, index) {
        final item = controller.conversations[index];
        final active = item.id == controller.activeThreadId;
        return SizedBox(
          width: MediaQuery.sizeOf(context).width < 620 ? 190 : null,
          child: Material(
            color: active
                ? DesignTokens.orange.withValues(alpha: .12)
                : DesignTokens.surface1,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            child: ListTile(
              key: Key('musubi_thread_${item.id}'),
              onTap: () => controller.selectConversation(item.id),
              dense: true,
              leading: CircleAvatar(
                backgroundColor: DesignTokens.indigo.withValues(alpha: .18),
                foregroundColor: DesignTokens.indigoLight,
                child: Text(item.avatarLabel),
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              subtitle: Text(
                item.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DesignTokens.textTertiary,
                  fontSize: 9,
                ),
              ),
              trailing: item.unreadCount > 0
                  ? Badge(label: Text('${item.unreadCount}'))
                  : item.isOnline
                      ? const Icon(
                          Icons.circle,
                          size: 8,
                          color: DesignTokens.green,
                        )
                      : null,
            ),
          ),
        );
      },
    );
  }
}

class _ConversationPane extends StatelessWidget {
  const _ConversationPane({
    required this.controller,
    required this.messageController,
    required this.onSend,
  });

  final MusubiMessagesController controller;
  final TextEditingController messageController;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final active = controller.activeConversation;
    return Container(
      decoration: _panelDecoration(),
      child: active == null
          ? const Center(
              child: Text(
                '会話を選択してください',
                style: TextStyle(color: DesignTokens.textSecondary),
              ),
            )
          : Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: DesignTokens.green,
                  ),
                  title: Text(
                    active.title,
                    style: const TextStyle(
                      color: DesignTokens.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    '参加者限定 ・ 広告スキャンなし',
                    style: TextStyle(
                      color: DesignTokens.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Divider(height: 1, color: DesignTokens.divider),
                Expanded(
                  child: controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.all(DesignTokens.space12),
                          itemCount: controller.messages.length,
                          itemBuilder: (context, index) {
                            final message = controller.messages[index];
                            return Align(
                              alignment: message.isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 430),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: message.isMine
                                      ? DesignTokens.indigo
                                          .withValues(alpha: .22)
                                      : DesignTokens.surface3,
                                  borderRadius: BorderRadius.circular(
                                    DesignTokens.radiusMedium,
                                  ),
                                ),
                                child: Text(
                                  message.body,
                                  style: const TextStyle(
                                    color: DesignTokens.textOnDark,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (controller.notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      controller.notice!,
                      style: const TextStyle(
                        color: DesignTokens.orangeLight,
                        fontSize: 10,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.space12),
                  child: TextField(
                    key: const Key('musubi_message_field'),
                    controller: messageController,
                    maxLength: 5000,
                    maxLines: 3,
                    minLines: 1,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: '丁寧に話しかける…',
                      counterText: '',
                      suffixIcon: IconButton(
                        key: const Key('musubi_send_message'),
                        tooltip: '送信',
                        onPressed: controller.isSending ? null : onSend,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class MusubiSafetyView extends StatelessWidget {
  const MusubiSafetyView({
    super.key,
    required this.trustController,
    required this.researchController,
  });

  final MusubiTrustController trustController;
  final MusubiResearchController researchController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('musubi_safety_view'),
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        const _SectionHeading(
          eyebrow: 'TRUST & SAFETY',
          title: '判断を隠さないモデレーション',
          description: '通報、審査、解決の状態を監査可能にし、緊急性の高いケースを優先します。',
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: DesignTokens.space16),
        const Wrap(
          spacing: DesignTokens.space12,
          runSpacing: DesignTokens.space12,
          children: [
            _SafetyMetric(
              label: '初動目標',
              value: '15分',
              color: DesignTokens.orange,
            ),
            _SafetyMetric(
              label: '再審査窓口',
              value: '常時',
              color: DesignTokens.indigoLight,
            ),
            _SafetyMetric(
              label: '監査ログ',
              value: '100%',
              color: DesignTokens.green,
            ),
          ],
        ),
        if (trustController.notice != null) ...[
          const SizedBox(height: DesignTokens.space12),
          Text(
            trustController.notice!,
            style: const TextStyle(color: DesignTokens.orangeLight),
          ),
        ],
        const SizedBox(height: DesignTokens.space20),
        _ModerationQueue(controller: trustController),
        const SizedBox(height: DesignTokens.space20),
        MusubiResearchPanel(controller: researchController),
      ],
    );
  }
}

class _ModerationQueue extends StatelessWidget {
  const _ModerationQueue({required this.controller});

  final MusubiTrustController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'モデレーションキュー',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '管理者だけが詳細を閲覧・解決できます。一般ユーザーには自分の通報だけが表示されます。',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          if (controller.isLoading)
            const LinearProgressIndicator(color: DesignTokens.orange)
          else if (controller.queue.isEmpty)
            const Text(
              '現在、表示できる未解決ケースはありません。',
              style: TextStyle(color: DesignTokens.textTertiary, fontSize: 11),
            )
          else
            for (final item in controller.queue)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.flag_outlined,
                  color: DesignTokens.orange,
                ),
                title: Text(
                  _reportReasonLabel(item.reason),
                  style: const TextStyle(color: DesignTokens.textPrimary),
                ),
                subtitle: Text(
                  item.targetExcerpt.isEmpty
                      ? item.details
                      : item.targetExcerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DesignTokens.textSecondary),
                ),
                trailing: PopupMenuButton<MusubiModerationStatus>(
                  tooltip: '審査状態を変更',
                  onSelected: (status) =>
                      controller.resolveCase(item.id, status),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: MusubiModerationStatus.reviewing,
                      child: Text('審査中'),
                    ),
                    PopupMenuItem(
                      value: MusubiModerationStatus.resolved,
                      child: Text('解決'),
                    ),
                    PopupMenuItem(
                      value: MusubiModerationStatus.dismissed,
                      child: Text('却下'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class MusubiResearchPanel extends StatefulWidget {
  const MusubiResearchPanel({super.key, required this.controller});

  final MusubiResearchController controller;

  @override
  State<MusubiResearchPanel> createState() => _MusubiResearchPanelState();
}

class _MusubiResearchPanelState extends State<MusubiResearchPanel> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('musubi_research_panel'),
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: _panelDecoration(
        borderColor: DesignTokens.green.withValues(alpha: .35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '実ユーザー検証：7日間チェックイン',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '滞在時間ではなく、疲労・信頼・居場所感を成功指標にします。回答は研究同意後のみ保存されます。',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 11,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.controller.hasActiveConsent
                ? '研究同意済み：${widget.controller.activeConsent!.consentVersion}'
                : '未同意：回答・操作イベントは保存されません（同意文 $musubiResearchConsentVersion）',
            style: TextStyle(
              color: widget.controller.hasActiveConsent
                  ? DesignTokens.green
                  : DesignTokens.textTertiary,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          _ResearchScale(
            label: '利用後の疲労感（低いほど良い）',
            value: widget.controller.fatigue,
            onChanged: widget.controller.setFatigue,
          ),
          _ResearchScale(
            label: '情報への信頼',
            value: widget.controller.trust,
            onChanged: widget.controller.setTrust,
          ),
          _ResearchScale(
            label: '居場所・つながりの感覚',
            value: widget.controller.belonging,
            onChanged: widget.controller.setBelonging,
          ),
          TextField(
            key: const Key('musubi_research_comment'),
            controller: _commentController,
            maxLength: 2000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '自由記述（任意）',
              hintText: '安心できた点、迷った点、やめたくなった瞬間など',
            ),
          ),
          CheckboxListTile(
            key: const Key('musubi_research_consent'),
            value: widget.controller.consent,
            onChanged: widget.controller.hasActiveConsent
                ? null
                : (value) => widget.controller.setConsent(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '匿名化した改善研究への利用に同意します',
              style: TextStyle(color: DesignTokens.textOnDark, fontSize: 11),
            ),
            subtitle: const Text(
              '参加は任意です。回答と操作イベントは撤回時に削除し、広告目的には利用しません。',
              style: TextStyle(color: DesignTokens.textTertiary, fontSize: 9),
            ),
          ),
          if (widget.controller.notice != null)
            Text(
              widget.controller.notice!,
              style: const TextStyle(
                color: DesignTokens.green,
                fontSize: 10,
              ),
            ),
          const SizedBox(height: DesignTokens.space8),
          FilledButton.icon(
            key: const Key('musubi_research_submit'),
            onPressed: widget.controller.isSubmitting
                ? null
                : () => widget.controller.submit(_commentController.text),
            icon: const Icon(Icons.science_outlined),
            label: const Text('チェックインを送信'),
          ),
          TextButton.icon(
            key: const Key('musubi_research_withdraw'),
            onPressed: widget.controller.isSubmitting
                ? null
                : widget.controller.withdraw,
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: const Text('研究参加を取り消して研究データを削除'),
          ),
        ],
      ),
    );
  }
}

class _ResearchScale extends StatelessWidget {
  const _ResearchScale({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 10,
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$value',
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
      ],
    );
  }
}

class MusubiSavedView extends StatelessWidget {
  const MusubiSavedView({super.key, required this.posts});

  final List<MusubiPost> posts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('musubi_saved_view'),
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        const _SectionHeading(
          eyebrow: 'YOUR LIBRARY',
          title: '保存した文脈',
          description: '後で読み返す投稿を、反応数ではなく自分の判断で残します。',
          icon: Icons.bookmark_border_rounded,
        ),
        const SizedBox(height: DesignTokens.space16),
        if (posts.isEmpty)
          const _EmptyPanel(message: '保存した投稿はまだありません。')
        else
          for (final post in posts)
            Container(
              margin: const EdgeInsets.only(bottom: DesignTokens.space12),
              padding: const EdgeInsets.all(DesignTokens.space16),
              decoration: _panelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${post.authorName}  ${post.handle}',
                    style: const TextStyle(
                      color: DesignTokens.orangeLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MusubiPostContent(text: post.content),
                ],
              ),
            ),
      ],
    );
  }
}

class MusubiCommunitiesView extends StatelessWidget {
  const MusubiCommunitiesView({
    super.key,
    required this.communities,
    required this.onToggle,
  });

  final List<MusubiCommunity> communities;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('musubi_communities_view'),
      padding: const EdgeInsets.all(DesignTokens.space20),
      children: [
        const _SectionHeading(
          eyebrow: 'COMMUNITY GOVERNANCE',
          title: 'ルールを一緒につくる場所',
          description: '参加前に目的、運営者、モデレーション基準を確認できます。',
          icon: Icons.diversity_3_outlined,
        ),
        const SizedBox(height: DesignTokens.space16),
        for (final community in communities)
          Container(
            margin: const EdgeInsets.only(bottom: DesignTokens.space12),
            padding: const EdgeInsets.all(DesignTokens.space16),
            decoration: _panelDecoration(),
            child: Row(
              children: [
                Text(community.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community.name,
                        style: const TextStyle(
                          color: DesignTokens.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        community.description,
                        style: const TextStyle(
                          color: DesignTokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${community.memberLabel} ・ 公開ガバナンス',
                        style: const TextStyle(
                          color: DesignTokens.textTertiary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () => onToggle(community.id),
                  child: Text(community.isJoined ? '参加中' : '参加'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [DesignTokens.orange, DesignTokens.indigo],
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: DesignTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: DesignTokens.orangeLight,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SafetyMetric extends StatelessWidget {
  const _SafetyMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: _panelDecoration(borderColor: color.withValues(alpha: .35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: DesignTokens.textTertiary,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space32),
      decoration: _panelDecoration(),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: DesignTokens.textSecondary),
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration({Color borderColor = DesignTokens.divider}) {
  return BoxDecoration(
    color: DesignTokens.surface1,
    borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
    border: Border.all(color: borderColor),
  );
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
