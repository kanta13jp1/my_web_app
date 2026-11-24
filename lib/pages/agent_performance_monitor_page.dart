import 'package:flutter/material.dart';

import '../services/ai_suggested_action_monitor_service.dart';
import '../widgets/ai_suggested_action_audit_dashboard.dart';

class AgentPerformanceMonitorPage extends StatelessWidget {
  const AgentPerformanceMonitorPage({
    super.key,
    this.actionMonitorService = const AiSuggestedActionMonitorService(),
  });

  final AiSuggestedActionMonitorService actionMonitorService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('エージェント・UIアクション監査')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart,
                      size: 28,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI生成UIアクション意図外使用モニタリング',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          Text(
                            '汎用アクション（narrative_choice / scene_transition / generic_narrative_choice）のフォールバック耐性と、ボタンラベル・種別・会話文脈の整合性を監査します。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AiSuggestedActionAuditDashboard(
                  service: actionMonitorService,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
