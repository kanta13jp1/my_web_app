import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/activation_revenue_experiment_service.dart';
import '../services/activation_revenue_tracker.dart';
import '../services/billing_service.dart';
import '../services/growth_acquisition_service.dart';
import '../services/paddle_checkout.dart';
import '../ui/features/billing/views/paddle_sandbox_checkout_card.dart';

class SubscriptionBillingPage extends StatefulWidget {
  const SubscriptionBillingPage({
    super.key,
    this.service,
    this.initialUri,
    this.acquisitionService = const GrowthAcquisitionService(),
    this.experimentService = const ActivationRevenueExperimentService(),
    this.tracker = const SupabaseActivationRevenueEventTracker(),
    this.assignment,
    this.paddleSandboxConfig,
    this.paddleCheckoutGateway,
  });

  final BillingGateway? service;
  final Uri? initialUri;
  final GrowthAcquisitionService acquisitionService;
  final ActivationRevenueExperimentService experimentService;
  final ActivationRevenueEventTracker tracker;
  final ActivationRevenueAssignment? assignment;
  final PaddleSandboxConfig? paddleSandboxConfig;
  final PaddleCheckoutGateway? paddleCheckoutGateway;

  @override
  State<SubscriptionBillingPage> createState() =>
      _SubscriptionBillingPageState();
}

class _SubscriptionBillingPageState extends State<SubscriptionBillingPage> {
  late final BillingGateway _service;
  late final Uri _sourceUri;
  ActivationRevenueAssignment? _assignment;
  bool _isLoading = true;
  bool _isOpeningStripe = false;
  String? _errorMessage;
  VoidCallback? _retryAction;
  BillingStatus? _status;
  _BillingReturnNotice? _returnNotice;

  bool _enabled(String id) => _assignment?.enables(id) ?? true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? BillingService();
    _sourceUri = widget.initialUri ?? Uri.base;
    _returnNotice = _BillingReturnNotice.fromUri(_sourceUri);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final assignment = widget.assignment ??
        await widget.experimentService.resolve(uri: _sourceUri);
    if (!mounted) return;
    setState(() => _assignment = assignment);
    unawaited(_record('billing_view'));
    unawaited(
      widget.acquisitionService.recordBillingFunnelStage(
        stage: GrowthAcquisitionService.funnelBillingView,
      ),
    );
    unawaited(
      widget.acquisitionService.recordFirstUserFunnelStage(
        stage: 'billing_view',
      ),
    );
    final returnNotice = _returnNotice;
    if (returnNotice != null) {
      unawaited(_record('checkout_return'));
      if (returnNotice.isPlanCheckout) {
        unawaited(
          widget.acquisitionService.recordBillingFunnelStage(
            stage: returnNotice.isSuccess
                ? GrowthAcquisitionService.funnelCheckoutSuccess
                : GrowthAcquisitionService.funnelCheckoutCancel,
          ),
        );
      }
    }
    await _fetchBillingInfo();
  }

  Future<void> _record(String stage) async {
    final assignment = _assignment ?? widget.assignment;
    if (assignment == null) return;
    try {
      await widget.tracker.record(assignment: assignment, stage: stage);
    } catch (error) {
      debugPrint('Activation revenue event failed: $error');
    }
  }

  Future<void> _fetchBillingInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _retryAction = null;
    });
    try {
      final status = await _service.fetchStatus();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      debugPrint('Billing status fetch failed: $error');
      if (mounted) {
        setState(() {
          _errorMessage = 'プラン情報を読み込めませんでした。時間をおいて再度お試しください。';
          _retryAction = _fetchBillingInfo;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCheckout(String tier) async {
    await _record('pro_checkout');
    await widget.acquisitionService.recordBillingFunnelStage(
      stage: GrowthAcquisitionService.funnelUpgradeClick,
    );
    await _openStripeSession(() {
      return widget.acquisitionService.loadLatestTouchpoint().then(
            (latestTouchpoint) => _service.createCheckoutSession(
              tier: tier,
              returnUrl: _currentReturnUrl,
              attribution: BillingCheckoutAttribution.fromLatestTouchpoint(
                latestTouchpoint,
              ),
            ),
          );
    });
  }

  Future<void> _openSupporterCheckout() async {
    await _record('supporter_checkout');
    await widget.acquisitionService.recordFirstUserFunnelStage(
      stage: 'supporter_checkout',
    );
    await _openStripeSession(() async {
      final latestTouchpoint =
          await widget.acquisitionService.loadLatestTouchpoint();
      final firstUserAttribution =
          await widget.acquisitionService.loadFirstUserAttribution();
      return _service.createSupporterCheckoutSession(
        returnUrl: _currentReturnUrl,
        attribution: BillingSupporterAttribution.fromUri(
          _sourceUri,
          fallbackTouchpoint: latestTouchpoint,
          firstUserAttribution: firstUserAttribution,
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
      _retryAction = null;
    });
    try {
      final session = await createSession();
      final url = (session as dynamic).url as String;
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw BillingServiceException('Stripe決済画面を開けませんでした');
      }
    } catch (error) {
      debugPrint('Billing session preparation failed: $error');
      if (mounted) {
        setState(() {
          _errorMessage = '決済画面を準備できませんでした。時間をおいて再度お試しください。';
          _retryAction = () => _openStripeSession(createSession);
        });
      }
    } finally {
      if (mounted) setState(() => _isOpeningStripe = false);
    }
  }

  String get _currentReturnUrl {
    final uri = _sourceUri.hasScheme ? _sourceUri : Uri.base;
    if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final query = Map<String, String>.from(uri.queryParameters)
        ..remove('billing')
        ..remove('offer');
      return uri
          .replace(
            path: '/subscription-billing',
            queryParameters: query.isEmpty ? null : query,
            fragment: '',
          )
          .toString();
    }
    return 'https://my-web-app-b67f4.web.app/subscription-billing';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status ??
        const BillingStatus(
          tier: 'free',
          status: 'active',
          aiQueryCount: 0,
          efCallCount: 0,
        );
    final fromOnboarding = _sourceUri.queryParameters['entry'] == 'onboarding';
    final valueFraming = _enabled('a10');
    final paddleSandboxConfig =
        widget.paddleSandboxConfig ?? PaddleSandboxConfig.fromEnvironment();
    return Scaffold(
      appBar: AppBar(
        title: const Text('プランと応援'),
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        _ErrorBanner(
                          _errorMessage!,
                          onRetry: _retryAction,
                        ),
                      if (_returnNotice != null) ...[
                        _BillingReturnBanner(_returnNotice!),
                        const SizedBox(height: 12),
                      ],
                      if (fromOnboarding) ...[
                        const _OnboardingValueBanner(),
                        const SizedBox(height: 16),
                      ],
                      const _BillingHero(),
                      const SizedBox(height: 20),
                      _CurrentPlanCard(
                        status: status,
                        onOpenPortal: _openPortal,
                      ),
                      const SizedBox(height: 16),
                      _SupporterCheckoutCard(
                        valueFraming: valueFraming,
                        isBusy: _isOpeningStripe,
                        onSupport: _openSupporterCheckout,
                      ),
                      const SizedBox(height: 16),
                      _PlanGrid(
                        valueFraming: valueFraming,
                        currentTier: status.tier,
                        isBusy: _isOpeningStripe,
                        onContinueFree: () {
                          Navigator.of(context).pushReplacementNamed('/home');
                        },
                        onUpgrade: _openCheckout,
                      ),
                      if (paddleSandboxConfig.shouldExpose) ...[
                        const SizedBox(height: 16),
                        PaddleSandboxCheckoutCard(
                          config: paddleSandboxConfig,
                          gateway: widget.paddleCheckoutGateway,
                          onContinue: () {
                            Navigator.of(context).pushReplacementNamed('/home');
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      _UsageCard(status: status),
                      const SizedBox(height: 16),
                      const _InfoCard(
                        icon: Icons.shield_outlined,
                        title: '安心して選べます',
                        message:
                            '決済はStripe上で安全に行われます。100円応援は1回限り、Pro・Teamは契約管理画面からいつでも解約できます。',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _OnboardingValueBanner extends StatelessWidget {
  const _OnboardingValueBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('billing_onboarding_value_banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.task_alt),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '最初の一手を作成できました。無料のまま続けることも、開発を応援することもできます。',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingHero extends StatelessWidget {
  const _BillingHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '役に立ったら、続け方を選べます',
          key: const Key('billing_value_headline'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          '登録だけで無料機能を利用できます。応援は1回100円・自動更新なし、ProはAI利用量を増やしたい方向けです。',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: Icon(Icons.lock_outline, size: 18),
              label: Text('Stripeの安全な決済'),
            ),
            Chip(
              avatar: Icon(Icons.credit_card_off_outlined, size: 18),
              label: Text('カード情報は当サイトに保存しません'),
            ),
            Chip(
              avatar: Icon(Icons.restart_alt, size: 18),
              label: Text('Proはいつでも解約可能'),
            ),
          ],
        ),
      ],
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

  bool get isPlanCheckout =>
      kind == _BillingReturnKind.success || kind == _BillingReturnKind.cancel;

  IconData get icon =>
      isSuccess ? Icons.check_circle_outline : Icons.info_outline;

  String get title => switch (kind) {
        _BillingReturnKind.supporterSuccess => '100円の応援を受け付けました',
        _BillingReturnKind.supporterCancel => '応援の決済をキャンセルしました',
        _BillingReturnKind.success => 'プランの決済を受け付けました',
        _BillingReturnKind.cancel => 'プランの決済をキャンセルしました',
      };

  String get message => switch (kind) {
        _BillingReturnKind.supporterSuccess =>
          'ありがとうございます。反映まで少し時間がかかる場合があります。',
        _BillingReturnKind.supporterCancel =>
          '請求は発生していません。必要になったときに、いつでも再開できます。',
        _BillingReturnKind.success => 'Stripeから戻りました。最新のプラン状態を確認しています。',
        _BillingReturnKind.cancel => '請求は発生していません。無料プランはそのまま利用できます。',
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
  const _ErrorBanner(this.message, {required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Color(0xFFC62828))),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('billing_error_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ),
          ],
        ],
      ),
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
                  label: const Text('契約を管理'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(_tierLabel(status.tier))),
                Chip(label: Text(_statusLabel(status.status))),
                if (status.currentPeriodEnd != null)
                  Chip(
                    label: Text(
                      '次回更新 ${_formatDate(status.currentPeriodEnd!)}',
                    ),
                  ),
                if (status.cancelAtPeriodEnd)
                  const Chip(label: Text('期間終了時に解約')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupporterCheckoutCard extends StatelessWidget {
  const _SupporterCheckoutCard({
    required this.valueFraming,
    required this.isBusy,
    required this.onSupport,
  });

  final bool valueFraming;
  final bool isBusy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('billing_supporter_offer'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final title = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_border, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valueFraming ? '初期サポーター（1回100円）' : 'サポーター',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      valueFraming
                          ? 'このサービスが役に立ったと感じたら、開発継続を応援できます。自動更新はなく、無料機能はそのまま使えます。'
                          : '1回100円の応援です。自動更新はありません。',
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            key: const Key('billing_supporter_checkout_button'),
            onPressed: isBusy ? null : onSupport,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: const Text('100円で応援する'),
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
    required this.valueFraming,
    required this.currentTier,
    required this.isBusy,
    required this.onContinueFree,
    required this.onUpgrade,
  });

  final bool valueFraming;
  final String currentTier;
  final bool isBusy;
  final VoidCallback onContinueFree;
  final Future<void> Function(String tier) onUpgrade;

  @override
  Widget build(BuildContext context) {
    final plans = [
      const _Plan('free', 'Free', '0円', '最初の一手、ノート、学習・資産管理の基本機能を試せます。'),
      _Plan(
        'pro',
        'Pro',
        '月額980円',
        valueFraming ? 'AIの利用量を増やし、毎日の整理と振り返りを継続したい方向けです。' : 'AI利用量と優先機能が増えます。',
        recommended: true,
      ),
      const _Plan('team', 'Team', '月額2,980円', '共有ワークスペースと監査ログを使うチーム向けです。'),
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
          childAspectRatio: columns == 1 ? 1.6 : 1.15,
          children: [
            for (final plan in plans)
              _PlanCard(
                plan: plan,
                isCurrent: currentTier == plan.tier,
                isBusy: isBusy,
                onChoose: plan.tier == 'free'
                    ? onContinueFree
                    : () => onUpgrade(plan.tier),
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
    required this.onChoose,
  });

  final _Plan plan;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback onChoose;

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
                if (plan.recommended)
                  const Chip(label: Text('おすすめ'))
                else if (isCurrent)
                  const Chip(label: Text('利用中')),
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
                key: plan.tier == 'pro'
                    ? const Key('billing_pro_checkout_button')
                    : null,
                onPressed: isBusy || (isCurrent && !isFree) ? null : onChoose,
                child: Text(
                  isFree
                      ? '無料で使い続ける'
                      : isCurrent
                          ? '利用中'
                          : '${plan.name}を始める',
                ),
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
    final isUnlimited = status.isPro;
    return Card(
      key: const Key('billing_usage_card'),
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
                  '今月の利用状況',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isUnlimited)
              const Row(
                key: Key('billing_ai_usage_unlimited'),
                children: [
                  Icon(Icons.all_inclusive, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'AI質問: 無制限',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI質問 今月 ${status.aiQueryCount}/${BillingStatus.freeAiQueryLimit}',
                      key: const Key('billing_ai_usage_label'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '残り ${status.remainingAiQueries}回',
                    key: const Key('billing_ai_usage_remaining'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: const Key('billing_ai_usage_progress'),
                value: status.aiQueryUsageRatio,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [_UsageChip(label: '処理実行', value: status.efCallCount)],
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
  const _Plan(
    this.tier,
    this.name,
    this.price,
    this.description, {
    this.recommended = false,
  });

  final String tier;
  final String name;
  final String price;
  final String description;
  final bool recommended;
}

String _tierLabel(String tier) => switch (tier) {
      'pro' => 'Pro（月額980円）',
      'team' => 'Team（月額2,980円）',
      _ => 'Free（無料）',
    };

String _statusLabel(String status) => switch (status) {
      'active' => '利用中',
      'trialing' => '無料体験中',
      'past_due' => '支払い確認が必要',
      'canceled' => '解約済み',
      _ => status,
    };

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}/$month/$day';
}
