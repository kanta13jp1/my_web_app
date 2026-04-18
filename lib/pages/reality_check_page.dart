import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/reality_check_service.dart';

class RealityCheckPage extends StatefulWidget {
  const RealityCheckPage({
    super.key,
    this.service = const RealityCheckService(),
  });

  final RealityCheckService service;

  @override
  State<RealityCheckPage> createState() => _RealityCheckPageState();
}

class _RealityCheckPageState extends State<RealityCheckPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<RealityCheckEntry> _entries = const <RealityCheckEntry>[];
  RealityCheckStats _stats = RealityCheckStats.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    final entries = await widget.service.loadEntries();
    final stats = await widget.service.loadStats();

    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _showAddDialog({
    String? initialCategory,
    String? initialClaim,
  }) async {
    var selectedCategory = initialCategory != null &&
            RealityCheckService.builtinCategories.contains(initialCategory)
        ? initialCategory
        : RealityCheckService.builtinCategories.first;
    final claimController = TextEditingController(text: initialClaim ?? '');
    final factsController = TextEditingController();
    final interpretationController = TextEditingController();
    final nextActionController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('現実直視ノートを追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: RealityCheckService.builtinCategories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: claimController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '向き合う主張',
                      hintText: '例: 今の収入構造では、このままでは生活が持たない',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: factsController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '観測できる事実',
                      hintText: '数字、出来事、相手の実際の発言などを書いてください',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: interpretationController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'まだ未確定な解釈',
                      hintText: '断定できない推測や感情はここへ分離します',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nextActionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '今日の現実対応',
                      hintText: '例: 固定費を見直す / 調べる / 人に確認する',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) {
        return;
      }

      final claim = claimController.text.trim();
      final facts = factsController.text.trim();
      final nextAction = nextActionController.text.trim();
      if (claim.isEmpty || facts.isEmpty || nextAction.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('主張・観測できる事実・今日の現実対応は必須です'),
          ),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      final result = await widget.service.addEntry(
        category: selectedCategory,
        claim: claim,
        observableFacts: facts,
        interpretation: interpretationController.text,
        nextAction: nextAction,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _entries = result.entries;
        _stats = result.stats;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現実直視ノートを保存しました')),
      );

      // analyze-reality Edge Function で AI 分析
      try {
        final analysisText =
            '主張: $claim\n観測事実: $facts\n解釈: ${interpretationController.text}';
        final resp = await Supabase.instance.client.functions.invoke(
          'analyze-reality',
          body: {'text': analysisText},
        );
        final data = resp.data as Map<String, dynamic>?;
        final analysis = data?['analysis'] as String?;
        if (analysis != null && analysis.isNotEmpty && mounted) {
          showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('AI 分析'),
              content: SingleChildScrollView(child: Text(analysis)),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          );
        }
      } catch (_) {
        // AI 分析失敗は無視
      }
    } finally {
      claimController.dispose();
      factsController.dispose();
      interpretationController.dispose();
      nextActionController.dispose();
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('現実直視ノート'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : () => _showAddDialog(),
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fact_check_outlined),
        label: const Text('直視ノートを追加'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 12),
                  _buildSummaryRow(),
                  const SizedBox(height: 12),
                  _buildTemplateCard(),
                  const SizedBox(height: 12),
                  _buildEntriesCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '事実と解釈を分けて現実を見る',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'この機能は、強い主張をそのまま固定化するためではなく、観測できる事実と未確定の解釈を切り分けるための習慣です。毎日ひとつ、現実対応まで書いて逃避を止めます。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStatChip(
          label: '今日の直視',
          value: '${_stats.reviewedTodayCount}件',
          color: const Color(0xFF3D5AFE),
        ),
        _buildStatChip(
          label: '連続日数',
          value: '${_stats.currentStreak}日',
          color: const Color(0xFF3D5AFE),
        ),
        _buildStatChip(
          label: '今日のカテゴリ',
          value: '${_stats.categoriesCoveredToday.length}種',
          color: const Color(0xFFFF6B35),
        ),
        _buildStatChip(
          label: '累計ノート',
          value: '${_entries.length}件',
          color: const Color(0xFF607D8B),
        ),
      ],
    );
  }

  Widget _buildTemplateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今日の直視テーマ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '苦しいテーマほど、まず観測できる事実だけを書き出します。',
            ),
            const SizedBox(height: 12),
            ...RealityCheckService.builtinTemplates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    template.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(template.prompt),
                  trailing: TextButton(
                    onPressed: () => _showAddDialog(
                      initialCategory: template.title,
                      initialClaim: template.prompt,
                    ),
                    child: const Text('書く'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近の現実直視ノート',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_entries.isEmpty)
              const Text(
                'まだノートはありません。まず1件、主張と観測できる事実を分けて書いてみてください。',
              )
            else
              ..._entries.take(10).map(_buildEntryTile),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(RealityCheckEntry entry) {
    final formatter = DateFormat('yyyy/MM/dd HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(entry.category),
                backgroundColor: const Color(0xFFE8EAF6),
              ),
              Text(
                formatter.format(entry.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildEntryBlock('向き合う主張', entry.claim),
          _buildEntryBlock('観測できる事実', entry.observableFacts),
          if (entry.interpretation.trim().isNotEmpty)
            _buildEntryBlock('まだ未確定な解釈', entry.interpretation),
          _buildEntryBlock('今日の現実対応', entry.nextAction),
        ],
      ),
    );
  }

  Widget _buildEntryBlock(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    final initial = label.isEmpty ? '?' : label.substring(0, 1);
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      label: Text('$label  $value'),
    );
  }
}
