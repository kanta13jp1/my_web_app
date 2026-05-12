import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/tome_deck_studio_service.dart';

class TomeDeckStudioPage extends StatefulWidget {
  const TomeDeckStudioPage({super.key});

  @override
  State<TomeDeckStudioPage> createState() => _TomeDeckStudioPageState();
}

class _TomeDeckStudioPageState extends State<TomeDeckStudioPage> {
  final _service = const TomeDeckStudioService();
  final _topicCtrl = TextEditingController(text: 'ライフマネジメント AI OS');
  final _audienceCtrl = TextEditingController(
    text: '投資家 / 経営会議',
  );
  final _sourceCtrl = TextEditingController();
  bool _isSyncingCompetitors = false;
  String? _syncStatus;
  TomeDeckScenario _scenario = TomeDeckScenario.investorDeck;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _audienceCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  TomeDeckPlan get _plan => _service.buildPlan(
        scenario: _scenario,
        topic: _topicCtrl.text,
        audience: _audienceCtrl.text,
        sourceText: _sourceCtrl.text,
      );

  void _setScenario(TomeDeckScenario scenario) {
    setState(() {
      _scenario = scenario;
      _topicCtrl.text = _scenarioTopic(scenario);
      _audienceCtrl.text = _scenarioAudience(scenario);
      _sourceCtrl.text = _scenarioSource(scenario);
      _syncStatus = null;
    });
  }

  Future<void> _copyMarkdown() async {
    await Clipboard.setData(ClipboardData(text: _service.buildMarkdown(_plan)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tome 貼り付け用マークダウンをコピーしました')),
    );
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: _plan.tomePrompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tome AI プロンプトをコピーしました')),
    );
  }

  Future<void> _syncCompetitorSource() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    setState(() {
      _isSyncingCompetitors = true;
      _syncStatus = '競合ソースを同期中...';
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'tome.competitor_airtable_deck',
          'topic': _topicCtrl.text,
          'audience': _audienceCtrl.text,
        },
      );
      final data = response.data;
      if (data is! Map || data['success'] != true || data['csv'] is! String) {
        throw StateError('予期しない同期レスポンス');
      }
      final rowCount = data['rowCount'] ?? 0;
      final source = data['source'] ?? '不明';
      final warning = data['warning'];
      setState(() {
        _sourceCtrl.text = data['csv'] as String;
        _syncStatus = warning is String && warning.isNotEmpty
            ? '$source から $rowCount 行をロードしました。$warning'
            : '$source から $rowCount 行をロードしました。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _syncStatus = '同期に失敗: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('競合同期に失敗: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingCompetitors = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tome デッキスタジオ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_outlined),
            tooltip: 'マークダウンをコピー',
            onPressed: _copyMarkdown,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Hero(plan: plan),
          const SizedBox(height: 16),
          _ScenarioSelector(
            selected: _scenario,
            onChanged: _setScenario,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1040;
              final editor = _EditorPanel(
                topicCtrl: _topicCtrl,
                audienceCtrl: _audienceCtrl,
                sourceCtrl: _sourceCtrl,
                scenario: _scenario,
                onChanged: () => setState(() {}),
                onCopyPrompt: _copyPrompt,
                onSyncCompetitors: _syncCompetitorSource,
                isSyncingCompetitors: _isSyncingCompetitors,
                syncStatus: _syncStatus,
              );
              final outline = _OutlinePanel(plan: plan);
              if (!wide) {
                return Column(
                  children: [
                    editor,
                    const SizedBox(height: 16),
                    _StrategyPanel(plan: plan),
                    const SizedBox(height: 16),
                    outline,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: editor),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        _StrategyPanel(plan: plan),
                        const SizedBox(height: 16),
                        outline,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.plan});

  final TomeDeckPlan plan;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD8E2EA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2040) : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_motion_outlined,
              color: Color(0xFF6D28D9),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.kgi,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ScoreBadge(score: plan.readinessScore, pages: plan.pageCount),
        ],
      ),
    );
  }
}

class _ScenarioSelector extends StatelessWidget {
  const _ScenarioSelector({
    required this.selected,
    required this.onChanged,
  });

  final TomeDeckScenario selected;
  final ValueChanged<TomeDeckScenario> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TomeDeckScenario>(
      showSelectedIcon: false,
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
      segments: const [
        ButtonSegment(
          value: TomeDeckScenario.investorDeck,
          icon: Icon(Icons.request_quote_outlined),
          label: Text('投資家 / レポート'),
        ),
        ButtonSegment(
          value: TomeDeckScenario.aiUniversityInfographic,
          icon: Icon(Icons.school_outlined),
          label: Text('AI 大学'),
        ),
        ButtonSegment(
          value: TomeDeckScenario.competitorAirtable,
          icon: Icon(Icons.table_chart_outlined),
          label: Text('競合 / Airtable'),
        ),
      ],
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.topicCtrl,
    required this.audienceCtrl,
    required this.sourceCtrl,
    required this.scenario,
    required this.onChanged,
    required this.onCopyPrompt,
    required this.onSyncCompetitors,
    required this.isSyncingCompetitors,
    required this.syncStatus,
  });

  final TextEditingController topicCtrl;
  final TextEditingController audienceCtrl;
  final TextEditingController sourceCtrl;
  final TomeDeckScenario scenario;
  final VoidCallback onChanged;
  final VoidCallback onCopyPrompt;
  final VoidCallback onSyncCompetitors;
  final bool isSyncingCompetitors;
  final String? syncStatus;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'ソース',
      icon: Icons.edit_note_outlined,
      child: Column(
        children: [
          TextField(
            controller: topicCtrl,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'トピック',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: audienceCtrl,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'ターゲット読者',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.people_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: sourceCtrl,
            onChanged: (_) => onChanged(),
            minLines: 8,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: _sourceLabel(scenario),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.dataset_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCopyPrompt,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text('Tome AI プロンプトをコピー'),
            ),
          ),
          if (scenario == TomeDeckScenario.competitorAirtable) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSyncingCompetitors ? null : onSyncCompetitors,
                icon: isSyncingCompetitors
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_outlined),
                label: const Text('Airtable / 競合ソースを同期'),
              ),
            ),
            if (syncStatus != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  syncStatus!,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StrategyPanel extends StatelessWidget {
  const _StrategyPanel({required this.plan});

  final TomeDeckPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'KGI / CSF / KPI',
      icon: Icons.account_tree_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.kgi,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plan.kpi.entries
                .map(
                  (entry) => Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    avatar: const Icon(Icons.speed_outlined, size: 16),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          ...plan.csf.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF6D28D9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          ...plan.automationNotes.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sync_alt_outlined,
                    size: 18,
                    color: Color(0xFF0369A1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinePanel extends StatelessWidget {
  const _OutlinePanel({required this.plan});

  final TomeDeckPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Tome アウトライン',
      icon: Icons.view_carousel_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            plan.tomePrompt,
            style: const TextStyle(
              color: Color(0xFF334155),
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < plan.pages.length; i++)
            _PageCard(index: i + 1, page: plan.pages[i]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: plan.sourceHints
                .map(
                  (hint) => Chip(
                    label: Text(hint),
                    avatar: const Icon(Icons.link_outlined, size: 16),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.index,
    required this.page,
  });

  final int index;
  final TomePageSpec page;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    isDark ? const Color(0xFF4A3A7A) : const Color(0xFFDDD6FE),
                foregroundColor:
                    isDark ? const Color(0xFFDDD6FE) : const Color(0xFF5B21B6),
                child: Text('$index'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  page.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(page.narrative),
          const SizedBox(height: 8),
          Text(
            'ビジュアル: ${page.visualDirection}',
            style: const TextStyle(
              color: Color(0xFF0369A1),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...page.blocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(block)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '備考: ${page.speakerNote}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD8E2EA),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF6D28D9)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({
    required this.score,
    required this.pages,
  });

  final int score;
  final int pages;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2040) : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF4A3A7A) : const Color(0xFFDDD6FE),
        ),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: const TextStyle(
              color: Color(0xFF6D28D9),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text('$pages ページ'),
        ],
      ),
    );
  }
}

String _sourceLabel(TomeDeckScenario scenario) {
  switch (scenario) {
    case TomeDeckScenario.investorDeck:
      return 'ソースメモ、トラクション、KPI、会議ノート';
    case TomeDeckScenario.aiUniversityInfographic:
      return 'AI 大学記事、クイズ結果、学習者フィードバック';
    case TomeDeckScenario.competitorAirtable:
      return 'Airtable CSV/TSV 行';
  }
}

String _scenarioTopic(TomeDeckScenario scenario) {
  switch (scenario) {
    case TomeDeckScenario.investorDeck:
      return 'ライフマネジメント AI OS';
    case TomeDeckScenario.aiUniversityInfographic:
      return 'AI 大学向け Tome レッスン';
    case TomeDeckScenario.competitorAirtable:
      return '競合比較と週次プロダクト判断';
  }
}

String _scenarioAudience(TomeDeckScenario scenario) {
  switch (scenario) {
    case TomeDeckScenario.investorDeck:
      return '投資家 / 経営会議';
    case TomeDeckScenario.aiUniversityInfographic:
      return 'AI 大学学習者';
    case TomeDeckScenario.competitorAirtable:
      return 'プロダクト / マーケティングチーム';
  }
}

String _scenarioSource(TomeDeckScenario scenario) {
  switch (scenario) {
    case TomeDeckScenario.investorDeck:
      return '本プロダクトは AI 分析・KGI/CSF/KPI・WBS・改善ループを結合することで、時間・お金・健康・体力・知能・集中の無駄を削減する。';
    case TomeDeckScenario.aiUniversityInfographic:
      return 'Tome は AI プレゼン・ドキュメント生成ツール。AI 大学のページは provider レッスンをビジュアルブロック・比較表・演習問題・フィードバックループに圧縮する。';
    case TomeDeckScenario.competitorAirtable:
      return 'プロダクト,機能,価格,リスク,対抗策\nTome,AI デッキ生成,Pro,プレゼン workflow,Tome-ready エクスポート追加\nGamma,AI ドキュメントデッキ,Pro,高速デッキ作成,KGI/CSF/KPI デッキ構造を改善\nAirtable,構造化ソース,Team,データ鮮度,Tome へライブビュー埋込み';
  }
}
