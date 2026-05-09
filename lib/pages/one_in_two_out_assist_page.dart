import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/home_tool_catalog.dart';
import '../services/home_tool_usage_service.dart';
import '../services/one_in_two_out_assist_service.dart';

class OneInTwoOutAssistPage extends StatefulWidget {
  const OneInTwoOutAssistPage({super.key});

  @override
  State<OneInTwoOutAssistPage> createState() => _OneInTwoOutAssistPageState();
}

class _OneInTwoOutAssistPageState extends State<OneInTwoOutAssistPage> {
  static const String _optOutKey = 'one_in_two_out_prompt_opt_out_v1';

  final _assistService = const OneInTwoOutAssistService();
  final _incomingController = TextEditingController(text: '新しい分析カード');

  bool _loading = true;
  bool _promptOptedOut = false;
  String? _statusMessage;
  List<WidgetUsageSignal> _signals = const <WidgetUsageSignal>[];
  OneInTwoOutSuggestion? _latestSuggestion;
  final Set<String> _hiddenWidgetIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  @override
  void dispose() {
    _incomingController.dispose();
    super.dispose();
  }

  Future<void> _loadSignals() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final catalog = buildHomeToolCatalog();
    final candidates = catalog.map(
      (entry) => HomeToolUsageCandidate(
        id: entry.id,
        title: entry.title,
        sectionId: entry.sectionId,
        routePath: entry.routePath,
        isPinned: _isProtectedWidget(entry.id),
        isVisible: !_hiddenWidgetIds.contains(entry.id),
      ),
    );
    final signals = await HomeToolUsageService.loadUsageSignals(
      candidates: candidates,
      prefs: prefs,
    );
    if (!mounted) return;
    setState(() {
      _signals = signals;
      _promptOptedOut = prefs.getBool(_optOutKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _triggerWidgetAdd() async {
    final incomingTitle = _incomingController.text.trim().isEmpty
        ? '新しいウィジェット'
        : _incomingController.text.trim();
    final suggestion = _assistService.buildSuggestion(
      incomingWidgetId: 'custom.${incomingTitle.hashCode}',
      incomingWidgetTitle: incomingTitle,
      existingWidgets: _signals.where(
        (signal) => !_hiddenWidgetIds.contains(signal.id),
      ),
    );

    setState(() {
      _latestSuggestion = suggestion;
      _statusMessage = null;
    });

    if (_promptOptedOut) {
      setState(() {
        _statusMessage = '提案を表示せずに「$incomingTitle」を追加しました。';
      });
      return;
    }

    await _showSuggestionDialog(suggestion);
  }

  Future<void> _showSuggestionDialog(OneInTwoOutSuggestion suggestion) async {
    final selected =
        suggestion.candidates.map((candidate) => candidate.signal.id).toSet();
    var optOut = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('「${suggestion.incomingWidgetTitle}」を追加します'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('あまり使われていないウィジェットを2つ整理できます。'),
                      const SizedBox(height: 12),
                      for (final candidate in suggestion.candidates)
                        CheckboxListTile(
                          value: selected.contains(candidate.signal.id),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value ?? false) {
                                selected.add(candidate.signal.id);
                              } else {
                                selected.remove(candidate.signal.id);
                              }
                            });
                          },
                          title: Text(candidate.signal.title),
                          subtitle: Text(candidate.reason),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      const Divider(height: 24),
                      CheckboxListTile(
                        value: optOut,
                        onChanged: (value) {
                          setDialogState(() => optOut = value ?? false);
                        },
                        title: const Text('今後この提案を表示しない'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _skipSuggestion(suggestion, optOut: optOut);
                  },
                  child: const Text('スキップして追加'),
                ),
                FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _acceptSuggestion(
                            suggestion,
                            selectedIds: selected,
                            optOut: optOut,
                          );
                        },
                  icon: const Icon(Icons.playlist_remove),
                  label: const Text('選んで整理'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _skipSuggestion(
    OneInTwoOutSuggestion suggestion, {
    required bool optOut,
  }) async {
    await _persistOptOutIfNeeded(optOut);
    if (!mounted) return;
    setState(() {
      _statusMessage = '整理をスキップして「${suggestion.incomingWidgetTitle}」を追加しました。';
    });
  }

  Future<void> _acceptSuggestion(
    OneInTwoOutSuggestion suggestion, {
    required Set<String> selectedIds,
    required bool optOut,
  }) async {
    await _persistOptOutIfNeeded(optOut);
    if (!mounted) return;
    setState(() {
      _hiddenWidgetIds.addAll(selectedIds);
      _signals = _signals
          .map(
            (signal) => selectedIds.contains(signal.id)
                ? WidgetUsageSignal(
                    id: signal.id,
                    title: signal.title,
                    sectionId: signal.sectionId,
                    routePath: signal.routePath,
                    openCount: signal.openCount,
                    lastUsedAt: signal.lastUsedAt,
                    isPinned: signal.isPinned,
                    isVisible: false,
                  )
                : signal,
          )
          .toList(growable: false);
      _statusMessage =
          '「${suggestion.incomingWidgetTitle}」を追加し、${selectedIds.length}件を非表示候補にしました。';
    });
  }

  Future<void> _persistOptOutIfNeeded(bool optOut) async {
    if (!optOut) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_optOutKey, true);
    if (mounted) {
      setState(() => _promptOptedOut = true);
    }
  }

  bool _isProtectedWidget(String id) {
    return id == 'settings' || id == 'user-tasks' || id == 'wbs-user-tasks';
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _latestSuggestion;
    return Scaffold(
      appBar: AppBar(
        title: const Text('1 In 2 Out UI整理アシスト'),
        actions: [
          IconButton(
            tooltip: '利用状況を再読み込み',
            onPressed: _loadSignals,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAddPanel(),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildStatusBanner(_statusMessage!),
                ],
                if (suggestion != null) ...[
                  const SizedBox(height: 16),
                  _buildSuggestionPreview(suggestion),
                ],
                const SizedBox(height: 16),
                _buildUsageList(),
              ],
            ),
    );
  }

  Widget _buildAddPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '新規ウィジェット追加',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _incomingController,
              decoration: const InputDecoration(
                labelText: '追加するウィジェット名',
                prefixIcon: Icon(Icons.add_box_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: !_promptOptedOut,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_optOutKey, !value);
                if (mounted) {
                  setState(() => _promptOptedOut = !value);
                }
              },
              title: const Text('追加時に整理提案を表示'),
              secondary: const Icon(Icons.rule_folder_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _triggerWidgetAdd,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('追加フローを開始'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionPreview(OneInTwoOutSuggestion suggestion) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新提案: ${suggestion.incomingWidgetTitle}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final candidate in suggestion.candidates)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: Text(candidate.signal.title),
                subtitle: Text(candidate.reason),
                trailing: Text(candidate.score.toStringAsFixed(0)),
              ),
            if (!suggestion.hasTwoCandidates)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('候補が2件未満です。固定済み/非表示の項目は除外しています。'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageList() {
    final visibleSignals = _signals
        .where((signal) => !_hiddenWidgetIds.contains(signal.id))
        .toList(growable: false);
    final hiddenSignals = _signals
        .where((signal) => _hiddenWidgetIds.contains(signal.id))
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '利用頻度データ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '表示中 ${visibleSignals.length} 件 / 非表示候補 ${hiddenSignals.length} 件',
            ),
            const SizedBox(height: 12),
            for (final signal in visibleSignals.take(12))
              ListTile(
                leading: Icon(
                  signal.isPinned ? Icons.push_pin : Icons.widgets_outlined,
                ),
                title: Text(signal.title),
                subtitle: Text(
                  signal.lastUsedAt == null
                      ? '利用履歴なし'
                      : '最終利用: ${signal.lastUsedAt}',
                ),
                trailing: Text('${signal.openCount}回'),
              ),
          ],
        ),
      ),
    );
  }
}
