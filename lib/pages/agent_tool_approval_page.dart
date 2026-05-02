import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/agent_tool_approval_service.dart';

class AgentToolApprovalPage extends StatefulWidget {
  final AgentToolApprovalService service;

  AgentToolApprovalPage({
    super.key,
    AgentToolApprovalService? service,
  }) : service = service ?? AgentToolApprovalService();

  @override
  State<AgentToolApprovalPage> createState() => _AgentToolApprovalPageState();
}

class _AgentToolApprovalPageState extends State<AgentToolApprovalPage> {
  List<AgentToolApprovalLog> _logs = const <AgentToolApprovalLog>[];
  bool _isLoading = true;
  bool _showPendingOnly = true;
  String? _errorText;
  final Set<String> _decidingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final logs = await widget.service.fetchRecentLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _isLoading = false;
      });
    }
  }

  List<AgentToolApprovalLog> get _visibleLogs {
    if (!_showPendingOnly) return _logs;
    return _logs.where((log) => log.isPendingApproval).toList(growable: false);
  }

  Future<void> _decide(
    AgentToolApprovalLog log,
    AgentToolApprovalDecision decision,
  ) async {
    setState(() => _decidingIds.add(log.id));
    try {
      final updated = await widget.service.decide(
        logId: log.id,
        decision: decision,
      );
      if (!mounted) return;
      setState(() {
        _logs = _logs
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
      final verb = decision == AgentToolApprovalDecision.approved ? '承認' : '拒否';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$verbを監査ログへ記録しました')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('承認判断の保存に失敗しました: $error'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _decidingIds.remove(log.id));
      }
    }
  }

  Future<void> _copyApprovalPayload(AgentToolApprovalLog log) async {
    final payload = log.buildApprovalPayloadJson(
      approvedBy: 'ceo',
      approvedAt: DateTime.now(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('次回実行用の承認メタデータをコピーしました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _logs.where((log) => log.isPendingApproval).length;
    final approvedCount = _logs.where((log) => log.isApproved).length;
    final rejectedCount = _logs.where((log) => log.isRejected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI役員 承認ゲート'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummary(
              pendingCount: pendingCount,
              approvedCount: approvedCount,
              rejectedCount: rejectedCount,
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('承認待ち'),
                  icon: Icon(Icons.pending_actions_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('すべて'),
                  icon: Icon(Icons.history_outlined),
                ),
              ],
              selected: {_showPendingOnly},
              onSelectionChanged: (selection) {
                setState(() => _showPendingOnly = selection.first);
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorText != null)
              _buildNotice(
                icon: Icons.error_outline,
                title: '読み込みに失敗しました',
                message: _errorText!,
                color: const Color(0xFFB91C1C),
              )
            else if (_visibleLogs.isEmpty)
              _buildNotice(
                icon: Icons.verified_user_outlined,
                title: _showPendingOnly ? '承認待ちはありません' : '監査ログはありません',
                message: _showPendingOnly
                    ? '高リスク操作が停止されたとき、ここにCEO承認待ちとして表示されます。'
                    : 'agent_tool_execution_logs に記録が作成されると、この画面で確認できます。',
                color: const Color(0xFF0D9488),
              )
            else
              ..._visibleLogs.map(_buildLogCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '高リスク操作のCEO承認',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'send / delete / purchase / discount / external_share などは、AI役員が実行する前にここで監査できます。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip('承認待ち', pendingCount, const Color(0xFFFF6B35)),
              _buildMetricChip('承認済み', approvedCount, const Color(0xFF0D9488)),
              _buildMetricChip('拒否済み', rejectedCount, const Color(0xFFB91C1C)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, int value, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Text(
          '$value',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(AgentToolApprovalLog log) {
    final status = _statusText(log);
    final statusColor = _statusColor(log);
    final isBusy = _decidingIds.contains(log.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(log.createdAt),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              log.toolName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _smallChip('実行主体', log.actorRole ?? 'unknown'),
                _smallChip(
                  '要求スコープ',
                  log.requestedScopes.isEmpty
                      ? '未指定'
                      : log.requestedScopes.join(', '),
                ),
                if (log.highRiskScopes.isNotEmpty)
                  _smallChip('高リスク', log.highRiskScopes.join(', ')),
              ],
            ),
            if (log.sideEffects != null) ...[
              const SizedBox(height: 10),
              _infoBlock('想定される副作用', log.sideEffects!),
            ],
            if (log.blockedReason != null) ...[
              const SizedBox(height: 10),
              _infoBlock('停止理由', log.blockedReason!),
            ],
            if (log.payload.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoBlock('実行ペイロード', _compactPayload(log.payload)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: log.isPendingApproval && !isBusy
                      ? () => _decide(log, AgentToolApprovalDecision.approved)
                      : null,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('承認'),
                ),
                OutlinedButton.icon(
                  onPressed: log.isPendingApproval && !isBusy
                      ? () => _decide(log, AgentToolApprovalDecision.rejected)
                      : null,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('拒否'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyApprovalPayload(log),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('承認メタデータ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _infoBlock(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  String _statusText(AgentToolApprovalLog log) {
    if (log.isApproved) return '承認済み';
    if (log.isRejected) return '拒否済み';
    if (log.isPendingApproval) return '承認待ち';
    if (log.allowed) return '許可済み';
    return '停止済み';
  }

  Color _statusColor(AgentToolApprovalLog log) {
    if (log.isApproved || log.allowed) return const Color(0xFF0D9488);
    if (log.isRejected) return const Color(0xFFB91C1C);
    if (log.isPendingApproval) return const Color(0xFFFF6B35);
    return const Color(0xFF64748B);
  }

  String _compactPayload(Map<String, dynamic> payload) {
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    if (text.length <= 900) return text;
    return '${text.substring(0, 900)}...';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
