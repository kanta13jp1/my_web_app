import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/billing_service.dart';
import '../widgets/paddle_approval_readiness_card.dart';

class SubscriptionBillingPage extends StatefulWidget {
  const SubscriptionBillingPage({super.key, this.service, this.initialUri});

  final BillingGateway? service;
  final Uri? initialUri;

  @override
  State<SubscriptionBillingPage> createState() =>
      _SubscriptionBillingPageState();
}

class _SubscriptionBillingPageState extends State<SubscriptionBillingPage> {
  late final BillingGateway _service;
  bool _isLoading = true;
  bool _isOpeningStripe = false;
  String? _errorMessage;
  BillingStatus? _status;
  _BillingReturnNotice? _returnNotice;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BillingService();
    _returnNotice = _BillingReturnNotice.fromUri(widget.initialUri ?? Uri.base);
    _fetchBillingInfo();
  }

  Future<void> _fetchBillingInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final status = await _service.fetchStatus();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load billing status: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCheckout(String tier) async {
    await _openStripeSession(() {
      return _service.createCheckoutSession(
        tier: tier,
        returnUrl: _currentReturnUrl,
      );
    });
  }

  Future<void> _openSupporterCheckout() async {
    await _openStripeSession(() {
      return _service.createSupporterCheckoutSession(
        returnUrl: _currentReturnUrl,
        attribution: BillingSupporterAttribution.fromUri(
          widget.initialUri ?? Uri.base,
        ),
      );
    });
  }

  Future<void> _openPortal() async {
    await _openStripeSession(() {
      return _service.createPortalSession(returnUrl: _currentReturnUrl);
    });
  }

  Future<void> _openStripeSession(
    Future<dynamic> Function() createSession,
  ) async {
    setState(() {
      _isOpeningStripe = true;
      _errorMessage = null;
    });
    try {
      final session = await createSession();
      final url = (session as dynamic).url as String;
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw BillingServiceException('Could not open Stripe URL');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Stripe session failed: $e');
    } finally {
      if (mounted) setState(() => _isOpeningStripe = false);
    }
  }

  String get _currentReturnUrl {
    final uri = Uri.base;
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri.replace(path: '/subscription-billing', query: '').toString();
    }
    return 'https://my-web-app-b67f4.web.app/subscription-billing';
  }

  @override
  Widget build(BuildContext context) {
    final status =
        _status ??
        const BillingStatus(
          tier: 'free',
          status: 'active',
          aiQueryCount: 0,
          efCallCount: 0,
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBillingInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) _ErrorBanner(_errorMessage!),
                  if (_returnNotice != null) ...[
                    _BillingReturnBanner(_returnNotice!),
                    const SizedBox(height: 12),
                  ],
                  PaddleApprovalReadinessCard(
                    compact: true,
                    touchesRegulatedData: true,
                    onOpenLegalPage: () {
                      Navigator.of(context).pushNamed('/legal-compliance');
                    },
                  ),
                  const SizedBox(height: 16),
                  _CurrentPlanCard(status: status, onOpenPortal: _openPortal),
                  const SizedBox(height: 16),
                  _SupporterCheckoutCard(
                    isBusy: _isOpeningStripe,
                    onSupport: _openSupporterCheckout,
                  ),
                  const SizedBox(height: 16),
                  _PlanGrid(
                    currentTier: status.tier,
                    isBusy: _isOpeningStripe,
                    onUpgrade: _openCheckout,
                  ),
                  const SizedBox(height: 16),
                  _UsageCard(status: status),
                  const SizedBox(height: 16),
                  const _InfoCard(
                    icon: Icons.verified_user_outlined,
                    title: 'Production readiness',
                    message:
                        'Stripe Checkout is live. A completed supporter payment is recorded by webhook for first-yen revenue evidence.',
                  ),
                ],
              ),
            ),
    );
  }
}

enum _BillingReturnKind { success, cancel, supporterSuccess, supporterCancel }

class _BillingReturnNotice {
  const _BillingReturnNotice._(this.kind);

  final _BillingReturnKind kind;

  static _BillingReturnNotice? fromUri(Uri uri) {
    final value = uri.queryParameters['billing']?.trim().toLowerCase();
    return switch (value) {
      'success' => const _BillingReturnNotice._(_BillingReturnKind.success),
      'cancel' => const _BillingReturnNotice._(_BillingReturnKind.cancel),
      'supporter_success' => const _BillingReturnNotice._(
        _BillingReturnKind.supporterSuccess,
      ),
      'supporter_cancel' => const _BillingReturnNotice._(
        _BillingReturnKind.supporterCancel,
      ),
      _ => null,
    };
  }

  bool get isSuccess =>
      kind == _BillingReturnKind.success ||
      kind == _BillingReturnKind.supporterSuccess;

  IconData get icon =>
      isSuccess ? Icons.celebration_outlined : Icons.info_outline;

  String get title => switch (kind) {
    _BillingReturnKind.supporterSuccess => 'Support received',
    _BillingReturnKind.supporterCancel => 'Support checkout canceled',
    _BillingReturnKind.success => 'Checkout completed',
    _BillingReturnKind.cancel => 'Checkout canceled',
  };

  String get message => switch (kind) {
    _BillingReturnKind.supporterSuccess =>
      'Stripe accepted the one-time support payment. The webhook will store the first revenue evidence shortly.',
    _BillingReturnKind.supporterCancel =>
      'No payment was created. You can open the 100 JPY support checkout again anytime.',
    _BillingReturnKind.success =>
      'Stripe returned successfully. The latest billing status will be refreshed shortly.',
    _BillingReturnKind.cancel =>
      'No subscription payment was created. You can retry checkout anytime.',
  };
}

class _BillingReturnBanner extends StatelessWidget {
  const _BillingReturnBanner(this.notice);

  final _BillingReturnNotice notice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = notice.isSuccess ? scheme.primary : scheme.secondary;
    return Container(
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
          Icon(notice.icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(notice.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        border: Border.all(color: const Color(0xFFE57373)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFC62828))),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.status, required this.onOpenPortal});

  final BillingStatus status;
  final VoidCallback onOpenPortal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Current plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: status.isPro ? onOpenPortal : null,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(status.tier.toUpperCase())),
                Chip(label: Text(status.status)),
                if (status.currentPeriodEnd != null)
                  Chip(
                    label: Text(
                      'Renews ${_formatDate(status.currentPeriodEnd!)}',
                    ),
                  ),
                if (status.cancelAtPeriodEnd)
                  const Chip(label: Text('Cancels at period end')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupporterCheckoutCard extends StatelessWidget {
  const _SupporterCheckoutCard({required this.isBusy, required this.onSupport});

  final bool isBusy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_border, color: scheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Founding Supporter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('One-time 100 JPY support for first revenue proof.'),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: isBusy ? null : onSupport,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: const Text('Support 100 JPY'),
          );
          return Padding(
            padding: const EdgeInsets.all(16),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [title, const SizedBox(height: 12), button],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      button,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({
    required this.currentTier,
    required this.isBusy,
    required this.onUpgrade,
  });

  final String currentTier;
  final bool isBusy;
  final Future<void> Function(String tier) onUpgrade;

  @override
  Widget build(BuildContext context) {
    const plans = [
      _Plan('free', 'Free', 'JPY 0', 'Basic AI usage for trial runs.'),
      _Plan('pro', 'Pro', 'JPY 980/mo', 'More AI usage and priority features.'),
      _Plan('team', 'Team', 'JPY 2,980/mo', 'Shared workspace and audit logs.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 2.8 : 1.45,
          children: [
            for (final plan in plans)
              _PlanCard(
                plan: plan,
                isCurrent: currentTier == plan.tier,
                isBusy: isBusy,
                onUpgrade: () => onUpgrade(plan.tier),
              ),
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isBusy,
    required this.onUpgrade,
  });

  final _Plan plan;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final isFree = plan.tier == 'free';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isFree ? Icons.spa_outlined : Icons.auto_awesome),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCurrent) const Chip(label: Text('Current')),
              ],
            ),
            const SizedBox(height: 12),
            Text(plan.price, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(child: Text(plan.description)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isFree || isCurrent || isBusy ? null : onUpgrade,
                child: Text(isCurrent ? 'Selected' : 'Choose ${plan.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.status});

  final BillingStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed_outlined),
                SizedBox(width: 8),
                Text(
                  'Current period usage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _UsageChip(label: 'AI queries', value: status.aiQueryCount),
                _UsageChip(
                  label: 'Edge function calls',
                  value: status.efCallCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Plan {
  const _Plan(this.tier, this.name, this.price, this.description);

  final String tier;
  final String name;
  final String price;
  final String description;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
