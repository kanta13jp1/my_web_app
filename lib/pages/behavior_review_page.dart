import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_service.dart';
import '../services/behavior_review_service.dart';

enum _BehaviorReviewWindow {
  sevenDays(7, '7日'),
  thirtyDays(30, '30日'),
  ninetyDays(90, '90日');

  const _BehaviorReviewWindow(this.days, this.label);

  final int days;
  final String label;
}

class BehaviorReviewPage extends StatefulWidget {
  final AIService aiService;
  final SupabaseClient? supabaseClient;

  BehaviorReviewPage({
    super.key,
    AIService? aiService,
    this.supabaseClient,
  }) : aiService = aiService ?? AIService();

  @override
  State<BehaviorReviewPage> createState() => _BehaviorReviewPageState();
}

class _BehaviorReviewPageState extends State<BehaviorReviewPage> {
  late final SupabaseClient _supabase =
      widget.supabaseClient ?? Supabase.instance.client;

  _BehaviorReviewWindow _window = _BehaviorReviewWindow.thirtyDays;
  bool _isLoading = true;
  bool _isGeneratingReflection = false;
  bool _isGeneratingColumn = false;
  String? _reflection;
  String? _myStruggleColumn;
  List<BehaviorReviewEntry> _entries = const <BehaviorReviewEntry>[];
  BehaviorReviewSummary _summary = const BehaviorReviewSummary(
    totalCount: 0,
    actionCount: 0,
    utteranceCount: 0,
    sourceCounts: <String, int>{},
  );

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _entries = const <BehaviorReviewEntry>[];
        _summary = const BehaviorReviewSummary(
          totalCount: 0,
          actionCount: 0,
          utteranceCount: 0,
          sourceCounts: <String, int>{},
        );
        _isLoading = false;
        _reflection = null;
        _myStruggleColumn = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _reflection = null;
      _myStruggleColumn = null;
    });

    final since = DateTime.now().subtract(Duration(days: _window.days));

    try {
      final results = await Future.wait<dynamic>([
        _supabase
            .from('notes')
            .select('id,title,content,created_at')
            .eq('user_id', userId)
            .eq('is_archived', false)
            .gte('created_at', since.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(80),
        _supabase
            .from('agent_messages')
            .select('id,summary,message_kind,created_at')
            .eq('user_id', userId)
            .gte('created_at', since.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(80),
        _supabase
            .from('wealth_struggles')
            .select('id,action_type,amount,description,occurred_at')
            .eq('user_id', userId)
            .gte('occurred_at', since.toUtc().toIso8601String())
            .order('occurred_at', ascending: false)
            .limit(120),
      ]);

      final noteRows = results[0] is List ? results[0] as List<dynamic> : const [];
      final messageRows =
          results[1] is List ? results[1] as List<dynamic> : const [];
      final actionRows = results[2] is List ? results[2] as List<dynamic> : const [];

      final entries = <BehaviorReviewEntry>[];
      for (final row in noteRows.whereType<Map>()) {
        final entry = BehaviorReviewService.mapNote(Map<String, dynamic>.from(row));
        if (entry != null) {
          entries.add(entry);
        }
      }
      for (final row in messageRows.whereType<Map>()) {
        final entry = BehaviorReviewService.mapAgentMessage(
          Map<String, dynamic>.from(row),
        );
        if (entry != null) {
          entries.add(entry);
        }
      }
      for (final row in actionRows.whereType<Map>()) {
        final entry = BehaviorReviewService.mapWealthStruggle(
          Map<String, dynamic>.from(row),
        );
        if (entry != null) {
          entries.add(entry);
        }
      }

      final sorted = BehaviorReviewService.sortEntries(entries);

      if (!mounted) return;
      setState(() {
        _entries = sorted;
        _summary = BehaviorReviewService.summarize(sorted);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entries = const <BehaviorReviewEntry>[];
        _summary = const BehaviorReviewSummary(
          totalCount: 0,
          actionCount: 0,
          utteranceCount: 0,
          sourceCounts: <String, int>{},
        );
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('レビュー用ログの読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _generateReflection() async {
    if (_entries.isEmpty || _isGeneratingReflection) return;

    setState(() => _isGeneratingReflection = true);

    try {
      final prompt = BehaviorReviewService.buildReflectionPrompt(
        _entries,
        days: _window.days,
      );
      final reflection = await widget.aiService.runCustomPrompt(prompt);
      if (!mounted) return;
      setState(() {
        _reflection = reflection.trim();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI考察の生成に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingReflection = false);
      }
    }
  }

  Future<void> _generateMyStruggleColumn() async {
    if (_entries.isEmpty || _isGeneratingColumn) return;

    setState(() => _isGeneratingColumn = true);

    try {
      final prompt = BehaviorReviewService.buildMyStruggleColumnPrompt(
        _entries,
        days: _window.days,
        summary: _summary,
      );
      final column = await widget.aiService.runCustomPrompt(prompt);
      if (!mounted) return;
      setState(() {
        _myStruggleColumn = column.trim();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AIコラムの生成に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingColumn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('行動・発言レビュー'),
        actions: [
          IconButton(
            onPressed: _loadEntries,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 12),
                  _buildWindowSelector(),
                  const SizedBox(height: 12),
                  _buildSummaryRow(),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _entries.isEmpty || _isGeneratingReflection
                            ? null
                            : _generateReflection,
                    icon: _isGeneratingReflection
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_alt_outlined),
                    label: Text(
                      _isGeneratingReflection ? '考察を生成中...' : 'AIで考察する',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed:
                        _entries.isEmpty || _isGeneratingColumn
                            ? null
                            : _generateMyStruggleColumn,
                    icon: _isGeneratingColumn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_stories_outlined),
                    label: Text(
                      _isGeneratingColumn
                          ? 'コラムを生成中...'
                          : '「我が闘争」を生成',
                    ),
                  ),
                  if (_reflection != null && _reflection!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReflectionCard(_reflection!),
                  ],
                  if (_myStruggleColumn != null &&
                      _myStruggleColumn!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildMyStruggleColumnCard(_myStruggleColumn!),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '記録された行動・発言',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'この期間の記録はまだありません。メモ、AI組織、資産フローを使うとここに蓄積されます。',
                        ),
                      ),
                    )
                  else
                    ..._entries.map(_buildEntryCard),
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
              'あとで後悔しないための振り返り',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'このアプリに記録された行動と発言を時系列で見返し、衝動・一貫性・繰り返しやすい失敗を整理します。対象はメモ、AI組織メッセージ、資産フローです。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _BehaviorReviewWindow.values.map((window) {
        final isSelected = _window == window;
        return ChoiceChip(
          label: Text('直近${window.label}'),
          selected: isSelected,
          onSelected: (selected) {
            if (!selected) return;
            setState(() => _window = window);
            _loadEntries();
          },
        );
      }).toList(),
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildSummaryCard('総件数', '${_summary.totalCount}件', Icons.timeline),
        _buildSummaryCard('行動', '${_summary.actionCount}件', Icons.directions_run),
        _buildSummaryCard(
          '発言',
          '${_summary.utteranceCount}件',
          Icons.record_voice_over_outlined,
        ),
        _buildSummaryCard(
          '最多ソース',
          _summary.topSource ?? '--',
          Icons.layers_outlined,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      child: SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReflectionCard(String reflection) {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology_alt_outlined, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'AI考察',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              reflection,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStruggleColumnCard(String column) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_stories_outlined, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'AIコラム「我が闘争」',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              column,
              style: const TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BehaviorReviewEntry entry) {
    final style = _styleForEntry(entry);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${entry.kind == BehaviorReviewEntryKind.action ? '行動' : '発言'} / ${entry.source}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: style.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entry.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(entry.detail),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('yyyy/MM/dd HH:mm').format(entry.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _BehaviorReviewStyle _styleForEntry(BehaviorReviewEntry entry) {
    switch (entry.source) {
      case '資産管理':
        return const _BehaviorReviewStyle(
          icon: Icons.payments_outlined,
          color: Colors.redAccent,
        );
      case 'AI組織':
        return const _BehaviorReviewStyle(
          icon: Icons.campaign_outlined,
          color: Colors.indigo,
        );
      case 'メモ':
        return const _BehaviorReviewStyle(
          icon: Icons.note_alt_outlined,
          color: Colors.blue,
        );
      default:
        return const _BehaviorReviewStyle(
          icon: Icons.timeline,
          color: Colors.blueGrey,
        );
    }
  }
}

class _BehaviorReviewStyle {
  const _BehaviorReviewStyle({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}
