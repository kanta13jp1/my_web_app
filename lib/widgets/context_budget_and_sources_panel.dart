import 'package:flutter/material.dart';

import '../services/context_budget_service.dart';

/// Displays live estimated context size vs plan limits, blocks oversized submits,
/// and enforces custom data source registration caps (#2701).
class ContextBudgetAndSourcesPanel extends StatefulWidget {
  const ContextBudgetAndSourcesPanel({
    super.key,
    this.repository,
    this.initialStatus,
    this.maxContextUnits = ContextBudgetEstimator.defaultMaxContextUnits,
    this.onSubmitPrompt,
  });

  final CustomDataSourceRepository? repository;
  final CustomDataSourceLimitStatus? initialStatus;
  final int maxContextUnits;
  final Future<void> Function(String text, int estimatedUnits)? onSubmitPrompt;

  @override
  State<ContextBudgetAndSourcesPanel> createState() =>
      _ContextBudgetAndSourcesPanelState();
}

class _ContextBudgetAndSourcesPanelState
    extends State<ContextBudgetAndSourcesPanel> {
  CustomDataSourceRepository? _lazyRepo;
  late final TextEditingController _promptController;
  late final TextEditingController _sourceNameController;
  CustomDataSourceLimitStatus? _status;
  bool _loading = false;
  String? _feedbackMessage;

  CustomDataSourceRepository _repo() =>
      _lazyRepo ??= widget.repository ?? SupabaseCustomDataSourceRepository();

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _sourceNameController = TextEditingController();
    _status = widget.initialStatus;
    if (_status == null) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _sourceNameController.dispose();
    super.dispose();
  }

  int get _effectiveMaxUnits =>
      _status?.maxContextUnits ?? widget.maxContextUnits;

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });
    try {
      final fetched = await _repo().fetchStatus();
      if (!mounted) return;
      setState(() {
        _status = fetched;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'データソース上限の取得に失敗しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _registerSource() async {
    final name = _sourceNameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _feedbackMessage = 'データソース名を入力してください';
      });
      return;
    }
    setState(() {
      _loading = true;
      _feedbackMessage = null;
    });
    try {
      final next = await _repo().registerSource(
        name: name,
        sourceType: 'text',
        sampleText: _promptController.text,
      );
      if (!mounted) return;
      _sourceNameController.clear();
      setState(() {
        _status = next;
        _feedbackMessage = 'データソース「$name」を登録しました';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackMessage = '登録に失敗しました: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final estimatedUnits =
        ContextBudgetEstimator.estimateTextUnits(_promptController.text);
    final maxUnits = _effectiveMaxUnits;
    final overContextLimit = estimatedUnits > maxUnits;
    final sourceCapReached = _status?.limitReached == true;

    final statusFg = overContextLimit
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
        : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46));
    final statusBg = overContextLimit
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
        : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5));

    return Card(
      key: const ValueKey<String>('context_budget_and_sources_panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.data_usage_outlined),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'コンテキスト容量・カスタムデータソース上限',
                    softWrap: true,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('context_budget_prompt_input'),
              controller: _promptController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: '送信テキスト（推定トークン数をリアルタイム計測）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              key: const ValueKey<String>('context_budget_counter_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    overContextLimit
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: statusFg,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      overContextLimit
                          ? '上限超過: 推定トークン数 $estimatedUnits / $maxUnits'
                          : '推定トークン数: $estimatedUnits / $maxUnits',
                      softWrap: true,
                      style: TextStyle(
                        color: statusFg,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton.icon(
                key: const ValueKey<String>('context_budget_submit_button'),
                onPressed: (_loading || overContextLimit)
                    ? null
                    : () async {
                        final cb = widget.onSubmitPrompt;
                        if (cb != null) {
                          await cb(_promptController.text, estimatedUnits);
                        }
                      },
                icon: const Icon(Icons.send),
                label: const Text('コンテキストを送信'),
              ),
            ),
            const Divider(height: 24),
            if (_status != null) ...[
              Text(
                '登録済みデータソース: ${_status!.used} / ${_status!.maxSources} '
                '(${_status!.plan}プラン)',
                key: const ValueKey<String>('custom_source_usage_text'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (sourceCapReached) ...[
                const SizedBox(height: 6),
                Text(
                  'カスタムデータソースの登録上限に達したため新規追加は無効化されています。',
                  key: const ValueKey<String>('custom_source_cap_warning'),
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF991B1B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            TextField(
              key: const ValueKey<String>('custom_source_name_input'),
              controller: _sourceNameController,
              enabled: !sourceCapReached,
              decoration: const InputDecoration(
                labelText: '新規データソース名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton.icon(
                key: const ValueKey<String>('custom_source_add_button'),
                onPressed:
                    (_loading || sourceCapReached) ? null : _registerSource,
                icon: const Icon(Icons.add),
                label: Text(sourceCapReached ? '上限到達のため追加不可' : 'データソースを追加'),
              ),
            ),
            if (_feedbackMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _feedbackMessage!,
                key: const ValueKey<String>('custom_source_feedback'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
