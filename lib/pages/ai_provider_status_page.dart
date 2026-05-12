import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_provider_registry.dart';

/// AI大学 プロバイダー実装ステータス一覧
///
/// 152社の実装状況をフィルタタブ付きで一覧表示する。
/// ステータス: 未実装 / 実装済 / 要APIキー / 要課金
class AiProviderStatusPage extends StatefulWidget {
  const AiProviderStatusPage({super.key});

  @override
  State<AiProviderStatusPage> createState() => _AiProviderStatusPageState();
}

class _AiProviderStatusPageState extends State<AiProviderStatusPage>
    with SingleTickerProviderStateMixin {
  AiProviderStatus? _filter; // null = 全件

  final Map<String, String> _testResults = {};
  final Set<String> _testing = {};

  final _supabase = Supabase.instance.client;

  Future<void> _testProvider(String providerId) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _testResults[providerId] = 'ログインが必要です');
      return;
    }
    setState(() {
      _testing.add(providerId);
      _testResults.remove(providerId);
    });
    try {
      final resp = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'provider.chat',
          'provider': providerId,
          'message': 'こんにちは。短く自己紹介してください。',
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      final success = data?['success'] == true;
      final status = data?['status'] as String? ?? 'unknown';
      final text = data?['text'] as String? ?? '';
      final reason =
          data?['message'] as String? ?? data?['detail'] as String? ?? '';
      String summary;
      if (success) {
        summary =
            '✅ 応答: ${text.length > 60 ? "${text.substring(0, 60)}..." : text}';
      } else {
        switch (status) {
          case 'apiKeyRequired':
            summary = '🟡 APIキー未設定 (${data?['secret_needed']})';
            break;
          case 'paidPlanRequired':
            summary = '🟠 プロバイダー側で課金が必要';
            break;
          case 'notImplemented':
            summary = '⚪ 未実装';
            break;
          default:
            summary =
                '❌ エラー: ${reason.length > 80 ? "${reason.substring(0, 80)}..." : reason}';
        }
      }
      setState(() => _testResults[providerId] = summary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResults[providerId] = '❌ 通信エラー: $e');
    } finally {
      if (mounted) setState(() => _testing.remove(providerId));
    }
  }

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
                    child: Text(
                      '該当なし',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
          Text(
            'AI大学 登録 $total 社',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '実装済 ${counts[AiProviderStatus.implemented] ?? 0} / 要APIキー ${counts[AiProviderStatus.apiKeyRequired] ?? 0} / 要課金 ${counts[AiProviderStatus.paidPlanRequired] ?? 0} / 未実装 ${counts[AiProviderStatus.notImplemented] ?? 0}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.5,
            ),
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
          _filterChip(
            AiProviderStatus.implemented,
            '実装済 ${counts[AiProviderStatus.implemented] ?? 0}',
          ),
          _filterChip(
            AiProviderStatus.apiKeyRequired,
            '要APIキー ${counts[AiProviderStatus.apiKeyRequired] ?? 0}',
          ),
          _filterChip(
            AiProviderStatus.paidPlanRequired,
            '要課金 ${counts[AiProviderStatus.paidPlanRequired] ?? 0}',
          ),
          _filterChip(
            AiProviderStatus.notImplemented,
            '未実装 ${counts[AiProviderStatus.notImplemented] ?? 0}',
          ),
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
        label: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
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
                child: Text(
                  entry.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  entry.status.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              if (entry.tier != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Color(entry.tier!.colorValue).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          Color(entry.tier!.colorValue).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    entry.tier!.label,
                    style: TextStyle(
                      color: Color(entry.tier!.colorValue),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.id,
            style: const TextStyle(
              color: Color(0xFF6366F1),
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          if (entry.entryPoint != null) ...[
            const SizedBox(height: 4),
            Text(
              '経路: ${entry.entryPoint}',
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (entry.envKeyName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Secret: ${entry.envKeyName}',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ],
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.note,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (_supportsTestCall(entry)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    icon: _testing.contains(entry.id)
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF97316),
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 16),
                    label: const Text(
                      'テスト呼び出し',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF97316),
                      side: const BorderSide(color: Color(0xFFF97316)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: _testing.contains(entry.id)
                        ? null
                        : () => _testProvider(entry.id),
                  ),
                ),
                if (_testResults.containsKey(entry.id)) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _testResults[entry.id] ?? '',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _supportsTestCall(AiProviderEntry entry) {
    const supported = {
      'openai',
      'anthropic',
      'google',
      'x',
      'deepseek',
      'groq',
      'sambanova',
      'openrouter',
      'fireworks_ai',
      'together_ai',
      'mistral',
      'perplexity',
      'cohere',
    };
    return supported.contains(entry.id);
  }
}
