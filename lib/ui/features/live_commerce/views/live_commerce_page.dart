import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../services/shop_service.dart';
import '../../../../theme/design_tokens.dart';
import '../domain/live_commerce_models.dart';
import '../view_models/live_commerce_view_model.dart';

class LiveCommercePage extends StatefulWidget {
  const LiveCommercePage({super.key});

  @override
  State<LiveCommercePage> createState() => _LiveCommercePageState();
}

class _LiveCommercePageState extends State<LiveCommercePage> {
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LiveCommerceViewModel>();
    return Scaffold(
      backgroundColor: DesignTokens.surface1,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('ライブコマース'),
        actions: <Widget>[
          _ConnectionBadge(
            state: viewModel.connectionState,
            onReconnect: viewModel.reconnect,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: switch (viewModel.loadStatus) {
        LiveCommerceLoadStatus.initial ||
        LiveCommerceLoadStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        LiveCommerceLoadStatus.failure => _FailureState(
            message: viewModel.errorMessage ?? 'ライブコマースを読み込めませんでした。',
            onRetry: viewModel.load,
          ),
        LiveCommerceLoadStatus.ready => _buildReady(context, viewModel),
      },
    );
  }

  Widget _buildReady(BuildContext context, LiveCommerceViewModel viewModel) {
    final snapshot = viewModel.snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        final video = _VideoStage(
          snapshot: snapshot,
          product: viewModel.featuredProduct,
        );
        final commerce = _CommercePanel(
          snapshot: snapshot,
          product: viewModel.featuredProduct,
          hostActionRunning: viewModel.isHostActionRunning,
          onPushProduct: viewModel.pushFeaturedProduct,
          onOpenProduct: viewModel.featuredProduct == null
              ? null
              : () => _openProduct(context, viewModel.featuredProduct!),
        );
        final questions = _QuestionPanel(
          snapshot: snapshot,
          controller: _questionController,
          canSend: viewModel.canSendQuestion,
          sending: viewModel.isSendingQuestion,
          hostActionRunning: viewModel.isHostActionRunning,
          onChanged: viewModel.setQuestionDraft,
          onSubmit: () => _submitQuestion(viewModel),
          onToggleHighlight: viewModel.setQuestionHighlighted,
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 20, wide ? 32 : 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _RoomHeader(snapshot: snapshot),
                  if (viewModel.notice != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _StatusNotice(
                      key: const Key('live-commerce-notice'),
                      message: viewModel.notice!,
                      isError: false,
                    ),
                  ],
                  if (viewModel.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _StatusNotice(
                      key: const Key('live-commerce-error'),
                      message: viewModel.errorMessage!,
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      key: const Key('live-commerce-wide'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: <Widget>[
                              video,
                              const SizedBox(height: 20),
                              questions,
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(flex: 4, child: commerce),
                      ],
                    )
                  else
                    Column(
                      key: const Key('live-commerce-compact'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        video,
                        const SizedBox(height: 16),
                        commerce,
                        const SizedBox(height: 16),
                        questions,
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitQuestion(LiveCommerceViewModel viewModel) async {
    final sent = await viewModel.sendQuestion();
    if (sent) _questionController.clear();
  }

  void _openProduct(BuildContext context, ShopProduct product) {
    Navigator.of(context).pushNamed(
      '/shop/product?product_id=${Uri.encodeQueryComponent(product.id)}',
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.snapshot});

  final LiveCommerceRoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          snapshot.title,
          style: const TextStyle(
            color: DesignTokens.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        _LabelPill(
          label: snapshot.isLive ? '配信中' : '配信準備中',
          color: snapshot.isLive ? DesignTokens.green : DesignTokens.orange,
        ),
        if (snapshot.role == LiveCommerceRole.host)
          const _LabelPill(label: '配信者モード', color: DesignTokens.indigo),
        Text(
          '配信者: ${snapshot.hostName}',
          style: const TextStyle(color: DesignTokens.textSecondary),
        ),
      ],
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.snapshot, required this.product});

  final LiveCommerceRoomSnapshot snapshot;
  final ShopProduct? product;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ライブ配信動画。再生、一時停止、音量、全画面表示。',
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          key: const Key('live-commerce-video'),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DesignTokens.divider),
          ),
          child: Stack(
            children: <Widget>[
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      snapshot.isLive
                          ? Icons.play_circle_fill
                          : Icons.videocam_off_outlined,
                      color: DesignTokens.textSecondary,
                      size: 56,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      snapshot.isLive ? 'ライブ映像' : '配信開始後に映像を表示します',
                      style: const TextStyle(
                        color: DesignTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '自動再生・自動音声は行いません',
                      style: TextStyle(
                        color: DesignTokens.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (product != null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Semantics(
                    liveRegion: true,
                    label: '紹介中の商品: ${product!.nameJa}、${product!.priceJpy}円',
                    child: Container(
                      key: const Key('live-commerce-product-overlay'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .78),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: DesignTokens.orange.withValues(alpha: .65),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: DesignTokens.orangeLight,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${product!.nameJa}  ¥${product!.priceJpy}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _CommercePanel extends StatelessWidget {
  const _CommercePanel({
    required this.snapshot,
    required this.product,
    required this.hostActionRunning,
    required this.onPushProduct,
    required this.onOpenProduct,
  });

  final LiveCommerceRoomSnapshot snapshot;
  final ShopProduct? product;
  final bool hostActionRunning;
  final VoidCallback onPushProduct;
  final VoidCallback? onOpenProduct;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '紹介中の商品',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          if (product == null)
            const Text(
              '現在紹介中の商品はありません。',
              style: TextStyle(color: DesignTokens.textSecondary),
            )
          else ...<Widget>[
            Text(
              product!.nameJa,
              style: const TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product!.summaryJa,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¥${product!.priceJpy}',
              style: const TextStyle(
                color: DesignTokens.orangeLight,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              '税込 / 買い切り。価格と購入権利はサーバーで確認します。',
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('live-commerce-checkout'),
              onPressed: product!.isPurchasable ? onOpenProduct : null,
              icon: const Icon(Icons.lock_outline),
              label: Text(
                product!.isPurchasable ? '商品詳細・購入ページへ' : '販売準備中です',
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onOpenProduct,
              child: const Text('商品詳細・利用条件を見る'),
            ),
            const Text(
              '現在は安全な既存決済画面へ移動します。購入完了後はこのライブ画面へ自動復帰しません。',
              style: TextStyle(
                color: DesignTokens.textTertiary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
          if (snapshot.role == LiveCommerceRole.host) ...<Widget>[
            const Divider(height: 32, color: DesignTokens.divider),
            Semantics(
              container: true,
              label: '配信者操作',
              child: OutlinedButton.icon(
                key: const Key('live-commerce-host-push'),
                onPressed:
                    product == null || hostActionRunning ? null : onPushProduct,
                icon: const Icon(Icons.push_pin_outlined),
                label: Text(hostActionRunning ? '更新中…' : 'この商品を紹介'),
              ),
            ),
          ],
          if (snapshot.purchaseAnnouncements.isNotEmpty) ...<Widget>[
            const Divider(height: 32, color: DesignTokens.divider),
            const Text(
              '購入のお知らせ',
              style: TextStyle(
                color: DesignTokens.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final announcement in snapshot.purchaseAnnouncements)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  announcement,
                  style: const TextStyle(color: DesignTokens.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.snapshot,
    required this.controller,
    required this.canSend,
    required this.sending,
    required this.hostActionRunning,
    required this.onChanged,
    required this.onSubmit,
    required this.onToggleHighlight,
  });

  final LiveCommerceRoomSnapshot snapshot;
  final TextEditingController controller;
  final bool canSend;
  final bool sending;
  final bool hostActionRunning;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final ValueChanged<LiveCommerceQuestion> onToggleHighlight;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'ライブ質問',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (snapshot.questions.isEmpty)
            const Text(
              'まだ質問はありません。',
              style: TextStyle(color: DesignTokens.textSecondary),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                key: const Key('live-commerce-questions'),
                shrinkWrap: true,
                itemCount: snapshot.questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final question = snapshot.questions[index];
                  return _QuestionRow(
                    question: question,
                    isHost: snapshot.role == LiveCommerceRole.host,
                    actionRunning: hostActionRunning,
                    onToggleHighlight: () => onToggleHighlight(question),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('live-commerce-question-input'),
            controller: controller,
            onChanged: onChanged,
            maxLength: 280,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(color: DesignTokens.textPrimary),
            decoration: const InputDecoration(
              labelText: '商品について質問する',
              hintText: '例: 対応環境を教えてください',
              filled: true,
              fillColor: DesignTokens.surface3,
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('live-commerce-send-question'),
              onPressed: canSend ? onSubmit : null,
              icon: const Icon(Icons.send_outlined),
              label: Text(sending ? '送信中…' : '質問を送信'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.isHost,
    required this.actionRunning,
    required this.onToggleHighlight,
  });

  final LiveCommerceQuestion question;
  final bool isHost;
  final bool actionRunning;
  final VoidCallback onToggleHighlight;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(question.createdAt).format(context);
    return Semantics(
      container: true,
      label: '${question.authorName}、$time、${question.body}、'
          '${question.isHighlighted ? '注目中' : '通常表示'}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: question.isHighlighted
              ? DesignTokens.orange.withValues(alpha: .10)
              : DesignTokens.surface3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: question.isHighlighted
                ? DesignTokens.orange
                : DesignTokens.divider,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      Text(
                        question.authorName,
                        style: const TextStyle(
                          color: DesignTokens.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          color: DesignTokens.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      if (question.isHighlighted)
                        const _LabelPill(
                          label: '注目中',
                          color: DesignTokens.orange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.body,
                    style: const TextStyle(
                      color: DesignTokens.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (isHost)
              IconButton(
                tooltip: question.isHighlighted ? '注目表示を解除' : '質問を注目表示',
                onPressed: actionRunning ? null : onToggleHighlight,
                icon: Icon(
                  question.isHighlighted
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: DesignTokens.orangeLight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.state, required this.onReconnect});

  final LiveCommerceConnectionState state;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      LiveCommerceConnectionState.preview => ('プレビュー', DesignTokens.indigo),
      LiveCommerceConnectionState.connecting => ('接続中…', DesignTokens.orange),
      LiveCommerceConnectionState.connected => ('ライブ更新中', DesignTokens.green),
      LiveCommerceConnectionState.syncing => ('再同期中…', DesignTokens.orange),
      LiveCommerceConnectionState.degraded => ('更新停止', DesignTokens.orange),
    };
    return Center(
      child: Tooltip(
        message: state == LiveCommerceConnectionState.preview
            ? '本番には接続していない安全なプレビューです'
            : state == LiveCommerceConnectionState.connected
                ? '新しい質問と商品紹介を受信中'
                : '押すと再接続します',
        child: ActionChip(
          key: const Key('live-commerce-connection'),
          avatar: Icon(Icons.circle, size: 9, color: color),
          label: Text(label),
          onPressed: state == LiveCommerceConnectionState.connected ||
                  state == LiveCommerceConnectionState.preview
              ? null
              : onReconnect,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: child,
    );
  }
}

class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? DesignTokens.orange : DesignTokens.indigoLight;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Text(message, style: TextStyle(color: color)),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: DesignTokens.orange,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesignTokens.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}
