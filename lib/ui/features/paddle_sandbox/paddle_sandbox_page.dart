import 'package:flutter/material.dart';

import 'paddle_sandbox_gateway_factory.dart';
import 'paddle_sandbox_models.dart';
import 'paddle_sandbox_view_model.dart';

class PaddleSandboxPage extends StatefulWidget {
  const PaddleSandboxPage({super.key, this.viewModel, this.initialUri});

  final PaddleSandboxViewModel? viewModel;
  final Uri? initialUri;

  @override
  State<PaddleSandboxPage> createState() => _PaddleSandboxPageState();
}

class _PaddleSandboxPageState extends State<PaddleSandboxPage> {
  late final PaddleSandboxViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        PaddleSandboxViewModel(
          config: PaddleSandboxConfig.fromEnvironment(),
          gateway: createPaddleSandboxGateway(),
          currentUri: widget.initialUri ?? Uri.base,
        );
  }

  @override
  void dispose() {
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paddle Sandbox 検証')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            final snapshot = _viewModel.snapshot;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SandboxBoundaryCard(),
                      const SizedBox(height: 16),
                      _StatusCard(snapshot: snapshot),
                      const SizedBox(height: 16),
                      _CheckoutActions(
                        snapshot: snapshot,
                        onStart: _viewModel.startCheckout,
                      ),
                      const SizedBox(height: 16),
                      const _ScenarioCard(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SandboxBoundaryCard extends StatelessWidget {
  const _SandboxBoundaryCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '検証専用・実課金なし',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'この画面は test_ token と sandbox price ID だけを受け付けます。'
              '現行の Stripe 課金、契約状態、Paddle live 環境には接続しません。',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.snapshot});

  final PaddleSandboxSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _colorFor(snapshot.phase, scheme);
    return Card(
      key: const Key('paddle_sandbox_status_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(snapshot.phase), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.title,
                        key: const Key('paddle_sandbox_status_title'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(snapshot.message),
                    ],
                  ),
                ),
              ],
            ),
            if (snapshot.lastEventName.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText('event: ${snapshot.lastEventName}'),
            ],
            if (snapshot.transactionId.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText('transaction: ${snapshot.transactionId}'),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorFor(PaddleSandboxPhase phase, ColorScheme scheme) {
    return switch (phase) {
      PaddleSandboxPhase.completed => const Color(0xFF1B5E20),
      PaddleSandboxPhase.paymentFailed ||
      PaddleSandboxPhase.error =>
        scheme.error,
      PaddleSandboxPhase.cancelled => const Color(0xFF8A4B08),
      _ => scheme.primary,
    };
  }

  IconData _iconFor(PaddleSandboxPhase phase) {
    return switch (phase) {
      PaddleSandboxPhase.completed => Icons.check_circle_outline,
      PaddleSandboxPhase.paymentFailed => Icons.credit_card_off_outlined,
      PaddleSandboxPhase.cancelled => Icons.cancel_outlined,
      PaddleSandboxPhase.error ||
      PaddleSandboxPhase.misconfigured =>
        Icons.error_outline,
      PaddleSandboxPhase.disabled => Icons.lock_outline,
      PaddleSandboxPhase.unsupported => Icons.web_asset_off_outlined,
      PaddleSandboxPhase.initializing ||
      PaddleSandboxPhase.opening =>
        Icons.hourglass_top,
      _ => Icons.shopping_cart_checkout,
    };
  }
}

class _CheckoutActions extends StatelessWidget {
  const _CheckoutActions({required this.snapshot, required this.onStart});

  final PaddleSandboxSnapshot snapshot;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          key: const Key('paddle_sandbox_checkout_button'),
          onPressed: snapshot.canStart ? onStart : null,
          icon: snapshot.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.open_in_new),
          label: Text(
            snapshot.phase == PaddleSandboxPhase.ready
                ? 'Sandbox checkout を開く'
                : 'Sandbox checkout を再試行',
          ),
        ),
        const Text('設定・実行手順: docs/PADDLE_SANDBOX_CHECKOUT_RUNBOOK.md'),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '検証する3シナリオ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _ScenarioRow(
              icon: Icons.check_circle_outline,
              title: '成功',
              detail: 'checkout.completed と sandbox transaction ID を確認',
            ),
            _ScenarioRow(
              icon: Icons.credit_card_off_outlined,
              title: '失敗',
              detail: 'checkout.payment.failed / error と再試行導線を確認',
            ),
            _ScenarioRow(
              icon: Icons.close,
              title: 'キャンセル',
              detail: 'checkout.closed と「決済未完了」表示を確認',
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('$title: $detail')),
        ],
      ),
    );
  }
}
