import 'package:flutter/material.dart';
import '../models/ai_provider_registry.dart';

/// AI大学 プロバイダー実装ステータス一覧
///
/// 78社の実装状況をフィルタタブ付きで一覧表示する。
/// ステータス: 未実装 / 実装済 / 要APIキー / 要課金
class AiProviderStatusPage extends StatefulWidget {
  const AiProviderStatusPage({super.key});

  @override
  State<AiProviderStatusPage> createState() => _AiProviderStatusPageState();
}

class _AiProviderStatusPageState extends State<AiProviderStatusPage>
    with SingleTickerProviderStateMixin {
  AiProviderStatus? _filter; // null = 全件

  @override
  Widget build(BuildContext context) {
    final counts = aiProviderStatusCounts();
    final total = kAiProviderRegistry.length;
    final entries = _filter == null
        ? kAiProviderRegistry
        : kAiProviderRegistry.where((e) => e.status == _filter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('AIプロバイダー実装状況'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSummary(total, counts),
          _buildFilterTabs(total, counts),
          const Divider(height: 1, color: Color(0xFF1F1F1F)),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('該当なし',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _providerCard(entries[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(int total, Map<AiProviderStatus, int> counts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI大学 登録 $total 社',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '実装済 ${counts[AiProviderStatus.implemented] ?? 0} / 要APIキー ${counts[AiProviderStatus.apiKeyRequired] ?? 0} / 要課金 ${counts[AiProviderStatus.paidPlanRequired] ?? 0} / 未実装 ${counts[AiProviderStatus.notImplemented] ?? 0}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int total, Map<AiProviderStatus, int> counts) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _filterChip(null, '全件 $total'),
          _filterChip(AiProviderStatus.implemented,
              '実装済 ${counts[AiProviderStatus.implemented] ?? 0}'),
          _filterChip(AiProviderStatus.apiKeyRequired,
              '要APIキー ${counts[AiProviderStatus.apiKeyRequired] ?? 0}'),
          _filterChip(AiProviderStatus.paidPlanRequired,
              '要課金 ${counts[AiProviderStatus.paidPlanRequired] ?? 0}'),
          _filterChip(AiProviderStatus.notImplemented,
              '未実装 ${counts[AiProviderStatus.notImplemented] ?? 0}'),
        ],
      ),
    );
  }

  Widget _filterChip(AiProviderStatus? status, String label) {
    final active = _filter == status;
    final baseColor =
        status == null ? 0xFFF97316 : status.colorValue; // 全件=orange
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        selected: active,
        selectedColor: Color(baseColor),
        backgroundColor: const Color(0xFF1A1A1A),
        side: BorderSide(color: Color(baseColor).withValues(alpha: 0.4)),
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }

  Widget _providerCard(AiProviderEntry entry) {
    final color = Color(entry.status.colorValue);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(entry.status.label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(entry.id,
              style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 11,
                  fontFamily: 'monospace')),
          if (entry.entryPoint != null) ...[
            const SizedBox(height: 4),
            Text('経路: ${entry.entryPoint}',
                style: const TextStyle(
                    color: Color(0xFFCBD5E1), fontSize: 12, height: 1.5)),
          ],
          if (entry.envKeyName != null) ...[
            const SizedBox(height: 4),
            Text('Secret: ${entry.envKeyName}',
                style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ],
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.note,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 12, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
