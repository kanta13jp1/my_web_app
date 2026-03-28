import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/local_election_plan.dart';
import '../models/local_election_reality.dart';
import '../services/local_election_plan_service.dart';
import '../services/local_election_reality_service.dart';

class ElectionVictoryPage extends StatefulWidget {
  const ElectionVictoryPage({super.key});

  @override
  State<ElectionVictoryPage> createState() => _ElectionVictoryPageState();
}

class _ElectionVictoryPageState extends State<ElectionVictoryPage> {
  final LocalElectionPlanService _service = const LocalElectionPlanService();
  final LocalElectionRealityService _realityService =
      const LocalElectionRealityService();
  final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm', 'ja_JP');
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ja_JP');

  LocalElectionPlanDashboard? _plan;
  LocalElectionRealitySnapshot? _realitySnapshot;
  bool _isLoading = true;
  bool _isRealityLoading = false;
  String? _realityError;
  String _selectedRegion = 'すべて';

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final results = await Future.wait<dynamic>([
      _service.loadPlan(),
      _realityService.loadCachedSnapshot(),
    ]);
    if (!mounted) {
      return;
    }

    final plan = results[0] as LocalElectionPlanDashboard;
    final cachedSnapshot = results[1] as LocalElectionRealitySnapshot?;

    setState(() {
      _plan = plan;
      _realitySnapshot = cachedSnapshot;
      if (!plan.regionLabels.contains(_selectedRegion)) {
        _selectedRegion = 'すべて';
      }
      _isLoading = false;
    });

    unawaited(_refreshRealityData(showSnackBar: false));
  }

  Future<void> _loadPlan() async {
    final plan = await _service.loadPlan();
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = plan;
      if (!plan.regionLabels.contains(_selectedRegion)) {
        _selectedRegion = 'すべて';
      }
      _isLoading = false;
    });
  }

  Future<void> _refreshAll() async {
    await _loadPlan();
    await _refreshRealityData(showSnackBar: false);
  }

  Future<void> _savePlan(LocalElectionPlanDashboard plan) async {
    final saved = await _service.savePlan(
      plan.copyWith(updatedAt: DateTime.now()),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = saved;
    });
  }

  Future<void> _refreshRealityData({required bool showSnackBar}) async {
    if (_isRealityLoading) {
      return;
    }
    setState(() {
      _isRealityLoading = true;
      _realityError = null;
    });

    try {
      final snapshot = await _realityService.fetchLatestSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _realitySnapshot = snapshot;
        _realityError = null;
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '最新の実データを取得しました '
              '(${_dateTimeFormat.format(snapshot.fetchedAt.toLocal())})',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _describeRealityError(error);
      setState(() {
        _realityError = message;
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRealityLoading = false;
        });
      }
    }
  }

  Future<void> _copySummary() async {
    final plan = _plan;
    if (plan == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _buildClipboardSummary(plan)));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('管理サマリーをクリップボードにコピーしました')),
    );
  }

  Future<void> _syncRealityIntoPlan() async {
    final plan = _plan;
    final snapshot = _realitySnapshot;
    if (plan == null || snapshot == null || !snapshot.hasData) {
      return;
    }

    await _savePlan(
      plan.copyWith(
        currentLocalMembers: snapshot.officialCurrentLocalMembers,
        previousUnifiedElectionWins: snapshot.official2023TotalWins,
        previousUnifiedElectionFirstHalfWins:
            snapshot.official2023FirstHalfWins,
        previousUnifiedElectionSecondHalfWins:
            snapshot.official2023SecondHalfWins,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最新の公式実数を計画値へ反映しました')),
    );
  }

  Future<void> _resetPlan(LocalElectionPlanTemplate template) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テンプレートを再適用'),
        content: Text(
          template == LocalElectionPlanTemplate.focused
              ? '重点配分テンプレートで現在の県連配分を上書きします。'
              : '均等配分テンプレートで現在の県連配分を上書きします。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('上書きする'),
          ),
        ],
      ),
    );
    if (shouldReset != true) {
      return;
    }

    final plan = await _service.resetPlan(template: template);
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = plan;
      _selectedRegion = 'すべて';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          template == LocalElectionPlanTemplate.focused
              ? '重点配分テンプレートに戻しました'
              : '均等配分テンプレートに戻しました',
        ),
      ),
    );
  }

  Future<void> _editPrefecture(LocalElectionPrefecturePlan target) async {
    final additionalController = TextEditingController(
      text: '${target.additionalSeatTarget}',
    );
    final retentionController = TextEditingController(
      text: '${target.incumbentRetentionTarget}',
    );
    final focusController = TextEditingController(
      text: '${target.focusMunicipalityCount}',
    );
    final newCandidateController = TextEditingController(
      text: '${target.newCandidateTarget}',
    );
    final supportController = TextEditingController(
      text: '${target.closeRaceSupportRounds}',
    );
    final notesController = TextEditingController(text: target.notes);
    var selectedDeadline =
        planningMonthKeys.contains(target.endorsementDeadlineMonth)
            ? target.endorsementDeadlineMonth
            : planningMonthKeys.first;
    var endorsementConfirmed = target.endorsementConfirmed;

    final updated = await showDialog<LocalElectionPrefecturePlan>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${target.prefecture} 県連プラン'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNumberField(
                      controller: additionalController,
                      label: '純増目標',
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: retentionController,
                      label: '現職維持目標',
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: focusController,
                      label: '重点自治体数',
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: newCandidateController,
                      label: '新人擁立数',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDeadline,
                      decoration: const InputDecoration(
                        labelText: '公認内定期限',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final monthKey in planningMonthKeys)
                          DropdownMenuItem<String>(
                            value: monthKey,
                            child: Text(formatMonthKey(monthKey)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedDeadline = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildNumberField(
                      controller: supportController,
                      label: '接戦区支援回数',
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: endorsementConfirmed,
                      title: const Text('公認内定済み'),
                      subtitle: const Text('月次管理表の期限超過アラートから除外'),
                      onChanged: (value) {
                        setDialogState(() {
                          endorsementConfirmed = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'メモ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    target.copyWith(
                      additionalSeatTarget: _parsePositiveInt(
                        additionalController.text,
                      ),
                      incumbentRetentionTarget: _parsePositiveInt(
                        retentionController.text,
                      ),
                      focusMunicipalityCount: _parsePositiveInt(
                        focusController.text,
                      ),
                      newCandidateTarget: _parsePositiveInt(
                        newCandidateController.text,
                      ),
                      endorsementDeadlineMonth: selectedDeadline,
                      closeRaceSupportRounds: _parsePositiveInt(
                        supportController.text,
                      ),
                      endorsementConfirmed: endorsementConfirmed,
                      notes: notesController.text.trim(),
                    ),
                  );
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    additionalController.dispose();
    retentionController.dispose();
    focusController.dispose();
    newCandidateController.dispose();
    supportController.dispose();
    notesController.dispose();

    if (updated == null || _plan == null) {
      return;
    }

    final next = [
      for (final item in _plan!.prefectures)
        if (item.prefecture == updated.prefecture) updated else item,
    ];
    await _savePlan(_plan!.copyWith(prefectures: next));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.prefecture} の計画を保存しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('統一地方選700 必達管理室'),
        actions: [
          IconButton(
            onPressed: plan == null ? null : _copySummary,
            tooltip: '管理サマリーをコピー',
            icon: const Icon(Icons.content_copy),
          ),
          IconButton(
            onPressed: _isRealityLoading
                ? null
                : () => _refreshRealityData(showSnackBar: true),
            tooltip: '最新の実データを取得',
            icon: _isRealityLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'focused') {
                _resetPlan(LocalElectionPlanTemplate.focused);
              } else if (value == 'balanced') {
                _resetPlan(LocalElectionPlanTemplate.balanced);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'focused',
                child: Text('重点配分テンプレートへ戻す'),
              ),
              PopupMenuItem<String>(
                value: 'balanced',
                child: Text('均等配分テンプレートへ戻す'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading || plan == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeroCard(plan),
                  const SizedBox(height: 16),
                  _buildRealitySection(plan),
                  const SizedBox(height: 16),
                  _buildAlertStrip(plan),
                  const SizedBox(height: 24),
                  _buildSummaryGrid(plan),
                  const SizedBox(height: 24),
                  _buildTopPrioritySection(plan),
                  const SizedBox(height: 24),
                  _buildMonthlySection(plan),
                  const SizedBox(height: 24),
                  _buildRegionFilter(plan),
                  const SizedBox(height: 12),
                  ...plan
                      .prefecturesForRegion(_selectedRegion)
                      .map(_buildPrefectureCard),
                  const SizedBox(height: 24),
                  Text(
                    '注記: 実データは公式議員ページと2023年の公式選挙結果ページを '
                    'Supabase Edge Function が巡回して取得します。'
                    'AIコメントは公式データの整理用で、未取得時は固定ロジックの要約へフォールバックします。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '注記: 初期配分と月次KPIはテンプレート計算です。'
                    '2026年4月から2027年3月までの管理ボードとして、各県連の実数で上書きして使う前提です。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(LocalElectionPlanDashboard plan) {
    final theme = Theme.of(context);
    final snapshot = _realitySnapshot;
    final hasSnapshot = snapshot?.hasData == true;
    final officialCount = hasSnapshot
        ? snapshot!.officialCurrentLocalMembers
        : plan.currentLocalMembers;
    final gapToTarget = hasSnapshot
        ? snapshot!.actualNetIncreaseRequired
        : plan.requiredNetIncrease;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2027年春の統一地方選に向けた管理型ダッシュボード',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSnapshot
                  ? '計画基準 ${_formatInt(plan.currentLocalMembers)}人に対し、'
                      '公式議員ページの最新集計は ${_formatInt(officialCount)}人です。'
                      '700人まで残り ${_formatInt(gapToTarget)}人を、'
                      '県連別配分と月次KPIで管理します。'
                  : '現在 ${_formatInt(plan.currentLocalMembers)}人から '
                      '${_formatInt(plan.targetLocalMembers)}人へ。'
                      '必要純増 ${_formatInt(plan.requiredNetIncrease)}人を、'
                      '県連別配分と月次KPIで管理します。',
              style: theme.textTheme.bodyMedium,
            ),
            if (hasSnapshot) ...[
              const SizedBox(height: 8),
              Text(
                '最新取得 ${_dateTimeFormat.format(snapshot!.fetchedAt.toLocal())}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildHeroMetric(
                  label: '計画現在',
                  value: _formatInt(plan.currentLocalMembers),
                  color: const Color(0xFF0F766E),
                ),
                _buildHeroMetric(
                  label: '公式現在',
                  value: _formatInt(officialCount),
                  color: const Color(0xFF0891B2),
                ),
                _buildHeroMetric(
                  label: '目標',
                  value: _formatInt(plan.targetLocalMembers),
                  color: const Color(0xFF2563EB),
                ),
                _buildHeroMetric(
                  label: '残り必要純増',
                  value: _formatInt(gapToTarget),
                  color: const Color(0xFFB91C1C),
                ),
                _buildHeroMetric(
                  label: '2023実績',
                  value:
                      '${plan.previousUnifiedElectionFirstHalfWins}+${plan.previousUnifiedElectionSecondHalfWins}',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealitySection(LocalElectionPlanDashboard plan) {
    final snapshot = _realitySnapshot;
    final realitySnapshot = snapshot?.hasData == true ? snapshot : null;
    final hasSnapshot = realitySnapshot != null;
    final activePrefectures = hasSnapshot
        ? realitySnapshot.prefectures
            .where((item) => item.currentMembers > 0)
            .length
        : 0;
    final needsSync = hasSnapshot &&
        (realitySnapshot.officialCurrentLocalMembers !=
                plan.currentLocalMembers ||
            realitySnapshot.official2023FirstHalfWins !=
                plan.previousUnifiedElectionFirstHalfWins ||
            realitySnapshot.official2023SecondHalfWins !=
                plan.previousUnifiedElectionSecondHalfWins);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '最新の実データ',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasSnapshot
                            ? '公式議員ページと2023年の公式選挙結果ページを取得して、'
                                'AIで実務向けに要点を整理します。'
                            : 'まだ最新データを取得できていません。'
                                'ネット経由で公式ソースを再取得すると、'
                                '計画値とのズレを把握できます。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _isRealityLoading
                          ? null
                          : () => _refreshRealityData(showSnackBar: true),
                      icon: _isRealityLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isRealityLoading ? '取得中' : '最新取得'),
                    ),
                    if (needsSync)
                      FilledButton.tonalIcon(
                        onPressed: _syncRealityIntoPlan,
                        icon: const Icon(Icons.sync_alt),
                        label: const Text('計画へ反映'),
                      ),
                  ],
                ),
              ],
            ),
            if (realitySnapshot != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(
                    realitySnapshot.isStale ? 'キャッシュ表示中' : '最新取得済み',
                    color:
                        realitySnapshot.isStale ? Colors.orange : Colors.green,
                  ),
                  _buildStatusChip(
                    '取得日時 ${_dateTimeFormat.format(realitySnapshot.fetchedAt.toLocal())}',
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ],
            if (_realityError != null) ...[
              const SizedBox(height: 12),
              _buildInlineNotice(
                _realityError!,
                color: Colors.orange,
                icon: Icons.info_outline,
              ),
            ],
            const SizedBox(height: 16),
            if (realitySnapshot == null && _isRealityLoading)
              const Center(child: CircularProgressIndicator())
            else if (realitySnapshot == null)
              _buildEmptyRealityState()
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSummaryCard(
                    title: '公式地方議員数',
                    value:
                        _formatInt(realitySnapshot.officialCurrentLocalMembers),
                    subtitle: '議員ページ集計',
                    color: const Color(0xFF0891B2),
                  ),
                  _buildSummaryCard(
                    title: '基準340との差分',
                    value: _formatSignedInt(realitySnapshot.deltaFromBaseline),
                    subtitle: '初期前提とのズレ',
                    color: realitySnapshot.deltaFromBaseline >= 0
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB91C1C),
                  ),
                  _buildSummaryCard(
                    title: '実数基準の残り',
                    value:
                        _formatInt(realitySnapshot.actualNetIncreaseRequired),
                    subtitle: '700人まで',
                    color: const Color(0xFFB91C1C),
                  ),
                  _buildSummaryCard(
                    title: '議員在籍県数',
                    value: _formatInt(activePrefectures),
                    subtitle: '公式ページで確認できた県',
                    color: const Color(0xFF7C3AED),
                  ),
                  _buildSummaryCard(
                    title: '2023前半戦',
                    value: _formatInt(
                      realitySnapshot.official2023FirstHalfWins,
                    ),
                    subtitle: '公式結果ベース',
                    color: const Color(0xFFB45309),
                  ),
                  _buildSummaryCard(
                    title: '2023後半戦',
                    value: _formatInt(
                      realitySnapshot.official2023SecondHalfWins,
                    ),
                    subtitle: '公式結果ベース',
                    color: const Color(0xFFBE123C),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAiInsightSection(realitySnapshot),
              const SizedBox(height: 20),
              _buildRealityPrefectureSection(realitySnapshot),
              const SizedBox(height: 20),
              _buildSourceSection(realitySnapshot),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRealityState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ネットからの最新取得待ち',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '公式ソースから地方議員数と2023年実績を再取得すると、'
            '計画値と実数のズレ、上位県、AI要約がここに表示されます。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightSection(LocalElectionRealitySnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI整理メモ',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.aiSummary.isEmpty
                    ? '公式データの要約はまだありません。'
                    : snapshot.aiSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (snapshot.aiAlerts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '注視ポイント',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final item in snapshot.aiAlerts) _buildBulletLine(item),
              ],
              if (snapshot.aiStrategicNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '運用メモ',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final item in snapshot.aiStrategicNotes)
                  _buildBulletLine(item),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealityPrefectureSection(LocalElectionRealitySnapshot snapshot) {
    final topPrefectures = snapshot.topPrefectures(limit: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '公式集計の上位県',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in topPrefectures)
              SizedBox(
                width: 250,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.prefecture,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (item.sourceUrl.isNotEmpty)
                              IconButton(
                                onPressed: () => _openUrl(item.sourceUrl),
                                tooltip: '県別ソースを開く',
                                icon: const Icon(Icons.open_in_new, size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('地方議員 ${_formatInt(item.currentMembers)}人'),
                        Text(
                          '都道府県議 ${_formatInt(item.prefecturalAssemblyMembers)}'
                          ' / 市区町村議 ${_formatInt(item.municipalAssemblyMembers)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceSection(LocalElectionRealitySnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '公式ソース',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        for (final source in snapshot.sources)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(source.label),
              subtitle: Text(
                source.note.isEmpty
                    ? source.url
                    : '${source.note}\n${source.url}',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openUrl(source.url),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertStrip(LocalElectionPlanDashboard plan) {
    final gap = plan.allocationGap;
    final overdue = plan.overdueEndorsementCount();
    final dueSoon = plan.dueSoonEndorsementCount();
    final snapshot = _realitySnapshot;
    final gapLabel = gap >= 0 ? '未配分ギャップ $gap人' : '超過配分 ${gap.abs()}人';
    final realityLabel = snapshot?.hasData == true
        ? '公式実数ベースでは残り ${_formatInt(snapshot!.actualNetIncreaseRequired)}人'
        : '計画基準は ${_formatInt(plan.currentLocalMembers)}人';
    final color = gap == 0 && overdue == 0
        ? Colors.green
        : overdue > 0 || gap != 0
            ? Colors.red
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gap == 0 && overdue == 0
                  ? '県連配分は必要純増 ${_formatInt(plan.requiredNetIncrease)}人を満たしています。'
                      ' $realityLabel。'
                      '次は公認内定の前倒しと月次レビューの固定化です。'
                  : '$gapLabel、期限超過県連 $overdue、'
                      '60日以内に期限到来 $dueSoon。'
                      ' $realityLabel。'
                      '「700」の看板ではなく、月次レビューで詰める運用が必要です。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(LocalElectionPlanDashboard plan) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          title: '県連配分済み純増',
          value: _formatInt(plan.allocatedNetIncrease),
          subtitle: '必要 ${_formatInt(plan.requiredNetIncrease)} に対して',
          color: const Color(0xFF0F766E),
        ),
        _buildSummaryCard(
          title: '現職維持目標',
          value: _formatInt(plan.totalIncumbentRetentionTarget),
          subtitle: '県連入力の合計値',
          color: const Color(0xFFB45309),
        ),
        _buildSummaryCard(
          title: '重点自治体',
          value: _formatInt(plan.totalFocusMunicipalityCount),
          subtitle: '全国合計',
          color: const Color(0xFF1D4ED8),
        ),
        _buildSummaryCard(
          title: '新人擁立',
          value: _formatInt(plan.totalNewCandidateTarget),
          subtitle: '全国合計',
          color: const Color(0xFF7C3AED),
        ),
        _buildSummaryCard(
          title: '公認内定済み県連',
          value:
              '${_formatInt(plan.confirmedEndorsementCount)}/${_formatInt(plan.prefectures.length)}',
          subtitle: '期限管理に使用',
          color: const Color(0xFF0F766E),
        ),
        _buildSummaryCard(
          title: '接戦区支援回数',
          value: _formatInt(plan.totalCloseRaceSupportRounds),
          subtitle: '全国合計',
          color: const Color(0xFFBE123C),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPrioritySection(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '重点県連',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in plan.topPriorityPrefectures(limit: 8))
              _buildTopPriorityCard(item),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPriorityCard(LocalElectionPrefecturePlan item) {
    final reality = _realityForPrefecture(item.prefecture);

    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.prefecture,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '純増 ${_formatInt(item.additionalSeatTarget)} / '
                '新人 ${_formatInt(item.newCandidateTarget)}',
              ),
              Text(
                '重点自治体 ${_formatInt(item.focusMunicipalityCount)} / '
                '支援 ${_formatInt(item.closeRaceSupportRounds)}回',
              ),
              Text(
                '公認内定期限 ${formatMonthKey(item.endorsementDeadlineMonth)}',
              ),
              if (reality != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '公式現在 ${_formatInt(reality.currentMembers)}人 '
                    '(都道府県議 ${_formatInt(reality.prefecturalAssemblyMembers)} / '
                    '市区町村議 ${_formatInt(reality.municipalAssemblyMembers)})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySection(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月次KPI',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '2026年4月から2027年3月までの累計管理です。'
          '公認内定は「その月に期限到来する県連数」を別列で表示します。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('月')),
              DataColumn(label: Text('現職維持累計')),
              DataColumn(label: Text('重点自治体累計')),
              DataColumn(label: Text('新人擁立累計')),
              DataColumn(label: Text('内定期限到来')),
              DataColumn(label: Text('内定期限累計')),
              DataColumn(label: Text('接戦区支援累計')),
            ],
            rows: [
              for (final month in plan.monthlyCheckpoints)
                DataRow(
                  cells: [
                    DataCell(Text(month.label)),
                    DataCell(
                      Text(
                        _formatInt(month.cumulativeIncumbentRetentionTarget),
                      ),
                    ),
                    DataCell(
                      Text(_formatInt(month.cumulativeFocusMunicipalityCount)),
                    ),
                    DataCell(
                      Text(_formatInt(month.cumulativeNewCandidateTarget)),
                    ),
                    DataCell(
                      Text(
                        '${_formatInt(month.endorsementsDueThisMonth)}県連',
                      ),
                    ),
                    DataCell(
                      Text('${_formatInt(month.cumulativeEndorsementsDue)}県連'),
                    ),
                    DataCell(
                      Text(_formatInt(month.cumulativeCloseRaceSupportRounds)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegionFilter(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '県連別配分',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in plan.regionLabels)
              ChoiceChip(
                label: Text(label),
                selected: _selectedRegion == label,
                onSelected: (_) {
                  setState(() {
                    _selectedRegion = label;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrefectureCard(LocalElectionPrefecturePlan plan) {
    final now = DateTime.now();
    final overdue = plan.isEndorsementOverdue(now);
    final dueSoon = plan.isEndorsementDueSoon(now);
    final reality = _realityForPrefecture(plan.prefecture);
    final accent = overdue
        ? Colors.red
        : dueSoon
            ? Colors.orange
            : plan.endorsementConfirmed
                ? Colors.green
                : Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${plan.prefecture} 県連',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(plan.region),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _editPrefecture(plan),
                  icon: const Icon(Icons.edit),
                  label: const Text('編集'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip('純増', _formatInt(plan.additionalSeatTarget)),
                _buildMetricChip(
                  '現職維持',
                  _formatInt(plan.incumbentRetentionTarget),
                ),
                _buildMetricChip(
                  '重点自治体',
                  _formatInt(plan.focusMunicipalityCount),
                ),
                _buildMetricChip('新人', _formatInt(plan.newCandidateTarget)),
                _buildMetricChip(
                  '公認内定期限',
                  formatMonthKey(plan.endorsementDeadlineMonth),
                  color: accent,
                ),
                _buildMetricChip(
                  '接戦区支援',
                  '${_formatInt(plan.closeRaceSupportRounds)}回',
                ),
                _buildMetricChip(
                  '内定状況',
                  plan.endorsementConfirmed
                      ? '完了'
                      : overdue
                          ? '期限超過'
                          : dueSoon
                              ? '期限接近'
                              : '進行中',
                  color: accent,
                ),
                if (reality != null)
                  _buildMetricChip(
                    '公式実数',
                    '${_formatInt(reality.currentMembers)}人',
                    color: const Color(0xFF0891B2),
                  ),
              ],
            ),
            if (reality != null) ...[
              const SizedBox(height: 12),
              Text(
                '公式内訳: 都道府県議 ${_formatInt(reality.prefecturalAssemblyMembers)} / '
                '市区町村議 ${_formatInt(reality.municipalAssemblyMembers)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (plan.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                plan.notes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, {Color? color}) {
    final chipColor = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: chipColor.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInlineNotice(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color.withValues(alpha: 0.95)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('• '),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  LocalElectionPrefectureReality? _realityForPrefecture(String prefecture) {
    final snapshot = _realitySnapshot;
    if (snapshot == null) {
      return null;
    }
    final target = _normalizePrefectureKey(prefecture);
    for (final item in snapshot.prefectures) {
      if (_normalizePrefectureKey(item.prefecture) == target) {
        return item;
      }
    }
    return null;
  }

  String _normalizePrefectureKey(String value) {
    final trimmed = value.trim();
    if (trimmed == '北海道') {
      return trimmed;
    }
    if (trimmed.endsWith('都') ||
        trimmed.endsWith('府') ||
        trimmed.endsWith('県')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _buildClipboardSummary(LocalElectionPlanDashboard plan) {
    final base = StringBuffer(plan.buildClipboardSummary());
    final snapshot = _realitySnapshot;
    if (snapshot != null && snapshot.hasData) {
      base
        ..writeln()
        ..writeln()
        ..writeln('最新実データ')
        ..writeln(
          '取得日時: ${_dateTimeFormat.format(snapshot.fetchedAt.toLocal())}',
        )
        ..writeln('公式地方議員数: ${snapshot.officialCurrentLocalMembers}')
        ..writeln('基準340との差分: ${snapshot.deltaFromBaseline}')
        ..writeln('700まで残り: ${snapshot.actualNetIncreaseRequired}')
        ..writeln(
          '2023公式実績: ${snapshot.official2023FirstHalfWins} + '
          '${snapshot.official2023SecondHalfWins} = ${snapshot.official2023TotalWins}',
        );
      if (snapshot.aiSummary.isNotEmpty) {
        base.writeln('AI要約: ${snapshot.aiSummary}');
      }
      final topPrefectures = snapshot.topPrefectures(limit: 5);
      if (topPrefectures.isNotEmpty) {
        base.writeln('上位県:');
        for (final item in topPrefectures) {
          base.writeln(
            '- ${item.prefecture}: ${item.currentMembers}人 '
            '(都道府県議 ${item.prefecturalAssemblyMembers} / '
            '市区町村議 ${item.municipalAssemblyMembers})',
          );
        }
      }
    }
    return base.toString();
  }

  String _describeRealityError(Object error) {
    final message = error.toString();
    if (message.contains('Unauthorized') ||
        message.contains('authorization') ||
        message.contains('authorization header')) {
      return '最新データの取得にはログイン済みのSupabaseセッションが必要です。';
    }
    if (message.contains('Supabase client is not available')) {
      return 'Supabaseクライアントが初期化されていないため、最新データを取得できません。';
    }
    return '最新データの取得に失敗しました。通信状態と Edge Function の設定を確認してください。';
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched || !mounted) {
      return;
    }
  }

  String _formatInt(int value) => _numberFormat.format(value);

  String _formatSignedInt(int value) {
    if (value > 0) {
      return '+${_formatInt(value)}';
    }
    return _formatInt(value);
  }

  int _parsePositiveInt(String raw) {
    final value = int.tryParse(raw.trim()) ?? 0;
    return clampPositiveInt(value);
  }
}
