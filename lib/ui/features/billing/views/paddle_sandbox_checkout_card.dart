import 'package:flutter/material.dart';

import '../../../../services/paddle_checkout.dart';
import '../../../../services/paddle_js_checkout_gateway.dart';
import '../view_models/paddle_sandbox_checkout_controller.dart';

class PaddleSandboxCheckoutCard extends StatefulWidget {
  const PaddleSandboxCheckoutCard({
    super.key,
    required this.config,
    this.gateway,
    this.onContinue,
  });

  final PaddleSandboxConfig config;
  final PaddleCheckoutGateway? gateway;
  final VoidCallback? onContinue;

  @override
  State<PaddleSandboxCheckoutCard> createState() =>
      _PaddleSandboxCheckoutCardState();
}

class _PaddleSandboxCheckoutCardState extends State<PaddleSandboxCheckoutCard> {
  late final PaddleSandboxCheckoutController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PaddleSandboxCheckoutController(
      config: widget.config,
      gateway: widget.gateway ?? createPaddleCheckoutGateway(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('paddle_sandbox_checkout_card'),
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final state = _controller.state;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.science_outlined),
                    Text(
                      'Paddle checkout 検証',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Chip(label: Text('SANDBOX ONLY')),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Stripe の既存課金は変更せず、Paddle.js のモーダルとイベント処理だけを検証します。'),
                const SizedBox(height: 12),
                _PaddleCheckoutStatusBanner(state: state),
                if (state.hasFinancialSnapshot) ...[
                  const SizedBox(height: 10),
                  _PaddleTaxEvidenceSummary(state: state),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const Key('paddle_sandbox_checkout_button'),
                      onPressed: state.isBusy || !widget.config.canOpen
                          ? null
                          : _controller.openCheckout,
                      icon: state.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new),
                      label: Text(
                        state.phase == PaddleCheckoutPhase.failed ||
                                state.phase == PaddleCheckoutPhase.canceled
                            ? 'もう一度試す'
                            : 'Paddle sandbox を開く',
                      ),
                    ),
                    if (state.phase == PaddleCheckoutPhase.completed &&
                        widget.onContinue != null)
                      OutlinedButton.icon(
                        key: const Key('paddle_sandbox_continue_button'),
                        onPressed: widget.onContinue,
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('ホームへ戻る'),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PaddleTaxEvidenceSummary extends StatelessWidget {
  const _PaddleTaxEvidenceSummary({required this.state});

  final PaddleCheckoutState state;

  @override
  Widget build(BuildContext context) {
    final currency = state.currencyCode ?? '—';
    return Container(
      key: const Key('paddle_sandbox_tax_evidence'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.hasTaxIdentifier
                ? 'VAT / Tax ID 適用済み（番号は保存しません）'
                : '税額スナップショット',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('通貨: $currency'),
              Text('小計: ${state.subtotal ?? '—'}'),
              Text('税額: ${state.tax ?? '—'}'),
              Text('合計: ${state.total ?? '—'}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaddleCheckoutStatusBanner extends StatelessWidget {
  const _PaddleCheckoutStatusBanner({required this.state});

  final PaddleCheckoutState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state.phase) {
      PaddleCheckoutPhase.completed => (
          Icons.check_circle_outline,
          const Color(0xFF15803D),
        ),
      PaddleCheckoutPhase.failed || PaddleCheckoutPhase.unavailable => (
          Icons.error_outline,
          const Color(0xFFB91C1C),
        ),
      PaddleCheckoutPhase.canceled => (
          Icons.info_outline,
          const Color(0xFFB45309),
        ),
      PaddleCheckoutPhase.opening || PaddleCheckoutPhase.opened => (
          Icons.hourglass_top,
          const Color(0xFF1D4ED8),
        ),
      PaddleCheckoutPhase.idle => (
          Icons.shield_outlined,
          const Color(0xFF475569),
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('paddle_sandbox_status'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(state.message)),
          ],
        ),
      ),
    );
  }
}
