import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/activation_revenue_experiment_service.dart';
import '../services/activation_revenue_tracker.dart';
import '../services/onboarding_activation_gateway.dart';
import '../services/pending_landing_trial_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    this.gateway = const SupabaseOnboardingActivationGateway(),
    this.tracker = const SupabaseActivationRevenueEventTracker(),
    this.experimentService = const ActivationRevenueExperimentService(),
    this.pendingTrialService = const PendingLandingTrialService(),
    this.assignment,
    this.initialUri,
  });

  final OnboardingActivationGateway gateway;
  final ActivationRevenueEventTracker tracker;
  final ActivationRevenueExperimentService experimentService;
  final PendingLandingTrialService pendingTrialService;
  final ActivationRevenueAssignment? assignment;
  final Uri? initialUri;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _draftKeyPrefix = 'activation_onboarding_draft_v1';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _challengeController = TextEditingController();

  ActivationRevenueAssignment? _assignment;
  _ActivationIntent _intent = _ActivationIntent.work;
  int _stage = 0;
  bool _isLoading = false;
  bool _restoredLandingTrial = false;
  String? _firstAction;
  String? _reason;
  String? _tenMinuteStep;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _challengeController.dispose();
    super.dispose();
  }

  bool _enabled(String id) => _assignment?.enables(id) ?? true;

  Future<void> _initialize() async {
    final assignment = widget.assignment ??
        await widget.experimentService.resolve(
          uri: widget.initialUri ?? Uri.base,
        );
    final restoredLandingTrial = await _restoreDraft();
    if (!mounted) return;
    setState(() {
      _assignment = assignment;
      _restoredLandingTrial = restoredLandingTrial;
    });
    await _record('onboarding_view');
    if (restoredLandingTrial) {
      await _record('first_action_completed');
    }
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

  String get _draftKey {
    final userId = widget.gateway.currentUser()?.id ?? 'anonymous';
    return '${_draftKeyPrefix}_$userId';
  }

  Future<bool> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _draftKey;
    final hasExistingDraft = const [
      'intent',
      'stage',
      'challenge',
      'name',
      'first_action',
      'reason',
      'ten_minute_step',
    ].any((suffix) => prefs.containsKey('${prefix}_$suffix'));
    final savedIntent = prefs.getString('${prefix}_intent');
    final savedStage = prefs.getInt('${prefix}_stage') ?? 0;
    final savedChallenge = prefs.getString('${prefix}_challenge') ?? '';
    final savedName = prefs.getString('${prefix}_name') ?? '';
    final savedAction = prefs.getString('${prefix}_first_action');
    final savedReason = prefs.getString('${prefix}_reason');
    final savedTenMinuteStep = prefs.getString('${prefix}_ten_minute_step');

    _intent = _ActivationIntent.values.firstWhere(
      (candidate) => candidate.name == savedIntent,
      orElse: () => _ActivationIntent.work,
    );
    _stage = savedStage.clamp(0, 1).toInt();
    _challengeController.text = savedChallenge;
    _nameController.text = savedName;
    _firstAction = savedAction;
    _reason = savedReason;
    _tenMinuteStep = savedTenMinuteStep;
    if (_stage == 1 && _firstAction == null) {
      _buildFirstAction();
    }
    if (hasExistingDraft) return false;

    final userEmail = widget.gateway.currentUser()?.email;
    final pending = await widget.pendingTrialService.loadForEmail(
      userEmail,
      preferences: prefs,
    );
    if (pending == null) return false;

    _intent = _ActivationIntent.values.firstWhere(
      (candidate) => candidate.name == pending.intent,
      orElse: () => _ActivationIntent.work,
    );
    _stage = 1;
    _challengeController.text = pending.prompt;
    _firstAction = pending.action;
    _reason = pending.reason;
    _tenMinuteStep = '「${pending.action}」に必要な画面か資料を1つ開き、10分だけ着手する';
    await _saveDraft(preferences: prefs);
    await widget.pendingTrialService.clearForEmail(
      userEmail,
      preferences: prefs,
    );
    return true;
  }

  Future<void> _saveDraft({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final prefix = _draftKey;
    await prefs.setString('${prefix}_intent', _intent.name);
    await prefs.setInt('${prefix}_stage', _stage);
    await prefs.setString('${prefix}_challenge', _challengeController.text);
    await prefs.setString('${prefix}_name', _nameController.text);
    if (_firstAction != null) {
      await prefs.setString('${prefix}_first_action', _firstAction!);
    }
    if (_reason != null) await prefs.setString('${prefix}_reason', _reason!);
    if (_tenMinuteStep != null) {
      await prefs.setString('${prefix}_ten_minute_step', _tenMinuteStep!);
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _draftKey;
    for (final suffix in const [
      'intent',
      'stage',
      'challenge',
      'name',
      'first_action',
      'reason',
      'ten_minute_step',
    ]) {
      await prefs.remove('${prefix}_$suffix');
    }
  }

  void _selectIntent(_ActivationIntent intent) {
    if (_intent == intent) return;
    setState(() => _intent = intent);
    unawaited(_saveDraft());
    unawaited(_record('intent_selected'));
  }

  void _applyExample(String example) {
    _challengeController.text = example;
    _challengeController.selection = TextSelection.collapsed(
      offset: example.length,
    );
    setState(() {});
    unawaited(_saveDraft());
  }

  Future<void> _generateFirstAction() async {
    final challenge = _challengeController.text.trim();
    if (_enabled('a03') && challenge.isEmpty) {
      _showMessage('いま一番困っていることを、短い言葉で入力してください。');
      return;
    }

    setState(() => _isLoading = true);
    await _record('first_action_started');
    _buildFirstAction();
    if (mounted) {
      setState(() {
        _stage = 1;
        _isLoading = false;
      });
    }
    await _saveDraft();
    await _record('first_action_completed');
  }

  void _buildFirstAction() {
    final challenge = _challengeController.text.trim();
    final personalized = _enabled('a05') && challenge.isNotEmpty;
    switch (_intent) {
      case _ActivationIntent.work:
        _firstAction = personalized
            ? '「$challenge」を、今日終える最小単位に1つだけ分解する'
            : '今日終える仕事を1つだけ選び、完了条件を書く';
        _reason = '優先順位を増やすより、完了条件を1つ固定した方が実行に移れます。';
        _tenMinuteStep = '関係する資料を1か所に集め、最初の10分だけ着手する';
        break;
      case _ActivationIntent.learning:
        _firstAction = personalized
            ? '「$challenge」を25分で学べる問い1つに変える'
            : '今日学ぶ問いを1つ決め、25分だけ集中する';
        _reason = '広いテーマを問いに変えると、学習の終点と成果が明確になります。';
        _tenMinuteStep = '知りたいことを3行で書き、最初の教材を1つ開く';
        break;
      case _ActivationIntent.money:
        _firstAction = personalized
            ? '「$challenge」に関係する直近7日分の数字を1つ確認する'
            : '直近7日で一番大きい支出を1件確認する';
        _reason = '将来予測の前に、いま動かせる数字を1つ特定すると判断が速くなります。';
        _tenMinuteStep = '口座か明細を開き、金額・日付・次の判断を記録する';
        break;
    }
  }

  Future<void> _completeOnboarding() async {
    if (_firstAction == null) return;
    final user = widget.gateway.currentUser();
    if (user == null) {
      _showMessage('ログイン情報を確認できませんでした。もう一度ログインしてください。');
      return;
    }

    var displayName = _nameController.text.trim();
    if (!_enabled('a06') && displayName.isEmpty) {
      _showMessage('表示名を入力してください。');
      return;
    }
    if (displayName.isEmpty) {
      displayName = _nameFromEmail(user.email) ?? '新しいユーザー';
    }

    setState(() => _isLoading = true);
    try {
      await widget.gateway.complete(
        OnboardingCompletion(
          displayName: displayName,
          intent: _intent.name,
          challenge: _challengeController.text.trim(),
          firstAction: _firstAction!,
          saveAsDailyTask: _enabled('a08'),
        ),
      );
      await _record('onboarding_completed');
      await _record('value_recap_view');
      await _clearDraft();
      if (!mounted) return;
      setState(() {
        _stage = 2;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('保存に失敗しました。通信状態を確認して、もう一度お試しください。');
      debugPrint('Onboarding completion failed: $error');
    }
  }

  String? _nameFromEmail(String? email) {
    final normalized = email?.trim();
    if (normalized == null || normalized.isEmpty || !normalized.contains('@')) {
      return null;
    }
    final local = normalized.split('@').first.trim();
    return local.isEmpty ? null : local;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _continueFree() {
    Navigator.of(context).pushReplacementNamed(_intent.destinationRoute);
  }

  void _openBilling({required String offer}) {
    final assignment = _assignment;
    final params = <String, String>{
      'entry': 'onboarding',
      'offer': offer,
      if (assignment != null) 'activation_hypothesis': assignment.hypothesis.id,
      if (assignment != null) 'activation_variant': assignment.variant.name,
    };
    final route = Uri(
      path: '/subscription-billing',
      queryParameters: params,
    ).toString();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 600 ? 20 : 32,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(
                        onExit: () {
                          Navigator.of(context).pushReplacementNamed('/home');
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_enabled('a07')) ...[
                        _ActivationProgress(currentStage: _stage),
                        const SizedBox(height: 28),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: switch (_stage) {
                          0 => _buildInputStage(),
                          1 => _buildPlanStage(),
                          _ => _buildValueRecapStage(),
                        },
                      ),
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

  Widget _buildInputStage() {
    final examples = _intent.examples;
    return Column(
      key: const ValueKey('activation_input_stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _enabled('a01') ? '最短60秒で、今日やる1件を決めます' : '初期設定を始めます',
          key: const Key('onboarding_headline'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          _enabled('a01')
              ? '細かいプロフィール設定より先に、すぐ使える最初の実行プランを作ります。'
              : '必要な情報を入力してください。',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
        ),
        const SizedBox(height: 28),
        if (_enabled('a02')) ...[
          const _SectionLabel(number: '1', title: 'いま一番整えたいもの'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final intent in _ActivationIntent.values)
                ChoiceChip(
                  key: Key('intent_${intent.name}'),
                  selected: _intent == intent,
                  avatar: Icon(intent.icon, size: 18),
                  label: Text(intent.label),
                  onSelected: (_) => _selectIntent(intent),
                ),
            ],
          ),
          const SizedBox(height: 28),
        ],
        if (_enabled('a03')) ...[
          const _SectionLabel(number: '2', title: 'いま困っていること'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('challenge_input'),
            controller: _challengeController,
            minLines: 2,
            maxLines: 4,
            maxLength: 160,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: _intent.hint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => unawaited(_saveDraft()),
          ),
          if (_enabled('a04')) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < examples.length; index++)
                  ActionChip(
                    key: Key('challenge_example_$index'),
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(examples[index]),
                    onPressed: () => _applyExample(examples[index]),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
        ],
        _SectionLabel(
          number: _enabled('a03') ? '3' : '2',
          title: _enabled('a06') ? '表示名（任意）' : '表示名',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('display_name_input'),
          controller: _nameController,
          maxLength: 40,
          decoration: InputDecoration(
            hintText: _enabled('a06') ? '未入力ならメール名を使います' : '表示名を入力',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => unawaited(_saveDraft()),
        ),
        const SizedBox(height: 12),
        if (_enabled('a08'))
          const _TrustLine(
            icon: Icons.bookmark_outline,
            text: '作った提案は保存され、次回も続きから再開できます。',
          ),
        const _TrustLine(
          icon: Icons.lock_outline,
          text: '入力内容はあなたのアカウント内だけに保存されます。',
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('generate_first_action_button'),
            onPressed: _isLoading ? null : _generateFirstAction,
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('最初の一手を作る'),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanStage() {
    return Column(
      key: const ValueKey('activation_plan_stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_restoredLandingTrial) ...[
          Container(
            key: const Key('pending_landing_trial_restored'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.sync_alt),
                SizedBox(width: 10),
                Expanded(child: Text('登録前に試した提案を、そのまま引き継ぎました。')),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          _enabled('a05') ? 'あなた向けの最初の一手' : '最初に行うこと',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text('全部を整える必要はありません。まず、この1件だけ始めます。'),
        const SizedBox(height: 24),
        Container(
          key: const Key('first_action_plan_card'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最優先の1件',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _firstAction ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              _PlanDetail(
                icon: Icons.lightbulb_outline,
                label: 'なぜ今やるか',
                value: _reason ?? '',
              ),
              const SizedBox(height: 14),
              _PlanDetail(
                icon: Icons.timer_outlined,
                label: '最初の10分',
                value: _tenMinuteStep ?? '',
              ),
            ],
          ),
        ),
        if (_enabled('a08')) ...[
          const SizedBox(height: 16),
          const _TrustLine(
            icon: Icons.cloud_done_outlined,
            text: 'この提案を保存し、ホームからいつでも再開できます。',
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('complete_onboarding_button'),
            onPressed: _isLoading ? null : _completeOnboarding,
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('保存して始める'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isLoading ? null : () => setState(() => _stage = 0),
          icon: const Icon(Icons.arrow_back),
          label: const Text('入力を直す'),
        ),
      ],
    );
  }

  Widget _buildValueRecapStage() {
    final valueFraming = _enabled('a10');
    return Column(
      key: const ValueKey('activation_value_recap_stage'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '最初の一手を保存しました',
          key: const Key('value_recap_title'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          _firstAction ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('continue_free_button'),
            onPressed: _continueFree,
            icon: Icon(_intent.icon),
            label: Text('${_intent.destinationLabel}を無料で始める'),
          ),
        ),
        if (_enabled('a09')) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            valueFraming ? '役に立ったら、続け方を選べます' : '料金プラン',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            valueFraming
                ? '無料のまま続けても大丈夫です。応援または利用量に合わせたProを選べます。'
                : '料金ページでプランを確認できます。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final cards = [
                _PaidChoice(
                  key: const Key('onboarding_supporter_choice'),
                  icon: Icons.favorite_border,
                  title: valueFraming ? '1回100円で応援' : 'サポーター',
                  description:
                      valueFraming ? '自動更新なし。無料機能はそのまま使えます。' : '支援ページを開きます。',
                  buttonLabel: '100円支援を見る',
                  onPressed: () => _openBilling(offer: 'supporter'),
                ),
                _PaidChoice(
                  key: const Key('onboarding_pro_choice'),
                  icon: Icons.workspace_premium_outlined,
                  title: valueFraming ? 'ProでAI利用量を増やす' : 'Pro',
                  description: valueFraming
                      ? '月980円。AI質問枠と優先機能を増やします。'
                      : 'Proプランを確認します。',
                  buttonLabel: 'Proを見る',
                  onPressed: () => _openBilling(offer: 'pro'),
                ),
              ];
              return narrow
                  ? Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                      ],
                    );
            },
          ),
        ],
      ],
    );
  }
}

enum _ActivationIntent { work, learning, money }

extension on _ActivationIntent {
  String get label => switch (this) {
        _ActivationIntent.work => '仕事',
        _ActivationIntent.learning => '学習',
        _ActivationIntent.money => 'お金',
      };

  IconData get icon => switch (this) {
        _ActivationIntent.work => Icons.task_alt_outlined,
        _ActivationIntent.learning => Icons.school_outlined,
        _ActivationIntent.money => Icons.account_balance_wallet_outlined,
      };

  String get hint => switch (this) {
        _ActivationIntent.work => '例: タスクが多く、何から始めるか決められない',
        _ActivationIntent.learning => '例: AIを学びたいが、教材を選べない',
        _ActivationIntent.money => '例: 支出を減らしたいが、数字を把握できていない',
      };

  List<String> get examples => switch (this) {
        _ActivationIntent.work => const [
            '優先順位を決めたい',
            '仕事ログを整理したい',
            '今日の1件を終えたい',
          ],
        _ActivationIntent.learning => const [
            'AIを体系的に学びたい',
            '英語学習を続けたい',
            'メモを知識に変えたい',
          ],
        _ActivationIntent.money => const ['支出を減らしたい', '資産を整理したい', '今月の収支を見たい'],
      };

  String get destinationRoute => switch (this) {
        _ActivationIntent.work => '/morning-briefing',
        _ActivationIntent.learning => '/ai-university',
        _ActivationIntent.money => '/asset-management',
      };

  String get destinationLabel => switch (this) {
        _ActivationIntent.work => '今日のブリーフィング',
        _ActivationIntent.learning => 'AI大学',
        _ActivationIntent.money => '資産管理',
      };
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '自分株式会社',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: '後で設定する',
          onPressed: onExit,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _ActivationProgress extends StatelessWidget {
  const _ActivationProgress({required this.currentStage});

  final int currentStage;

  @override
  Widget build(BuildContext context) {
    const labels = ['目的', '最初の一手', '開始'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= currentStage
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: index == currentStage
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (index < labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            number,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaidChoice extends StatelessWidget {
  const _PaidChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
