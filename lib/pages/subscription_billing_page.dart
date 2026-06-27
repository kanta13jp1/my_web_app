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
        setState(() => _errorMessage = '課金情報の取得に失敗しました: $e');
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
        throw BillingServiceException('Stripe URL を開けませんでした');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Stripe連携に失敗しました: $e');
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
        title: const Text('サブスクリプション・課金'),
        actions: [
          IconButton(
            tooltip: '更新',
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
                  _PlanGrid(
                    currentTier: status.tier,
                    isBusy: _isOpeningStripe,
                    onUpgrade: _openCheckout,
                  ),
                  const SizedBox(height: 16),
                  _UsageCard(status: status),
                  const SizedBox(height: 16),
                  const _LegalLinksCard(),
                  const SizedBox(height: 16),
                  const _SetupNoticeCard(),
                ],
              ),
            ),
    );
  }
}

enum _BillingReturnKind { success, cancel }

class _BillingReturnNotice {
  const _BillingReturnNotice._(this.kind);

  final _BillingReturnKind kind;

  static _BillingReturnNotice? fromUri(Uri uri) {
    final value = uri.queryParameters['billing']?.trim().toLowerCase();
    return switch (value) {
      'success' => const _BillingReturnNotice._(_BillingReturnKind.success),
      'cancel' => const _BillingReturnNotice._(_BillingReturnKind.cancel),
      _ => null,
    };
  }

  bool get isSuccess => kind == _BillingReturnKind.success;

  IconData get icon =>
      isSuccess ? Icons.celebration_outlined : Icons.info_outline;

  String get title => isSuccess ? 'ありがとうございます。決済を確認しています' : 'チェックアウトをキャンセルしました';

  String get message => isSuccess
      ? 'Stripeから戻りました。最新のプラン情報を再取得しました。反映に少し時間がかかる場合があります。'
      : '請求は発生していません。必要になったらいつでも再開できます。';
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
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
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
                    '現在のプラン',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: status.isPro ? onOpenPortal : null,
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('管理'),
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
                      '次回更新 ${_formatDate(status.currentPeriodEnd!)}',
                    ),
                  ),
                if (status.cancelAtPeriodEnd)
                  const Chip(label: Text('期間末で解約予定')),
              ],
            ),
          ],
        ),
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
      _Plan('free', 'Free', '¥0', 'AI質問 30回/月・基本機能'),
      _Plan('pro', 'Pro', '¥980/月', '無制限利用・AI大学フル機能・優先処理'),
      _Plan('team', 'Team', '¥2,980/席', 'チーム共有・監査ログ・高度な自動化'),
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
                if (isCurrent) const Chip(label: Text('利用中')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              plan.price,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(child: Text(plan.description)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isFree || isCurrent || isBusy ? null : onUpgrade,
                icon: isBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_outlined),
                label: Text(isCurrent ? '現在のプラン' : 'Stripeで開始'),
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
            const Text(
              '今月の利用量',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _metric('AI質問', '${status.aiQueryCount} 回'),
            _metric('Edge Function 呼び出し', '${status.efCallCount} 回'),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _LegalLinksCard extends StatelessWidget {
  const _LegalLinksCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ご購入前にご確認ください',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '有料プランのお申し込みは、以下の規約・表記に同意のうえお手続きください。',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _LegalLinkButton(label: '特定商取引法に基づく表記', route: '/tokusho'),
                _LegalLinkButton(label: '利用規約', route: '/terms'),
                _LegalLinkButton(label: 'プライバシーポリシー', route: '/privacy'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinkButton extends StatelessWidget {
  const _LegalLinkButton({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).pushNamed(route),
      icon: const Icon(Icons.description_outlined, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SetupNoticeCard extends StatelessWidget {
  const _SetupNoticeCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Stripe本番連携には Supabase secrets に STRIPE_SECRET_KEY、'
          'STRIPE_WEBHOOK_SECRET、STRIPE_PRO_PRICE_ID を設定してください。',
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

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
      '${local.day.toString().padLeft(2, '0')}';
}
