import 'package:flutter/material.dart';

class LandingComparisonLinksSection extends StatelessWidget {
  const LandingComparisonLinksSection({super.key});

  @override
  Widget build(BuildContext context) {
    const competitors = [
      (key: 'notion', name: 'Notion', emoji: '📝', color: Color(0xFF1F2937)),
      (
        key: 'evernote',
        name: 'Evernote',
        emoji: '🐘',
        color: Color(0xFF00A82D),
      ),
      (
        key: 'moneyforward',
        name: 'MoneyForward',
        emoji: '💰',
        color: Color(0xFF0D47A1),
      ),
      (key: 'x', name: 'X (Twitter)', emoji: '𝕏', color: Color(0xFF1C1C1E)),
      (
        key: 'animaworks',
        name: 'Animaworks',
        emoji: '🎯',
        color: Color(0xFFFF6B35),
      ),
      (
        key: 'claude-code',
        name: 'Claude Code',
        emoji: '🤖',
        color: Color(0xFFD97706),
      ),
      (key: 'codex', name: 'Codex', emoji: '⚡', color: Color(0xFF10B981)),
      (key: 'replit', name: 'Replit', emoji: '💻', color: Color(0xFFF5821B)),
      (
        key: 'netkeiba',
        name: 'netkeiba',
        emoji: '🐎',
        color: Color(0xFF7C3AED),
      ),
      (
        key: 'openclaw',
        name: 'OpenClaw',
        emoji: '🦾',
        color: Color(0xFF0EA5E9),
      ),
      (
        key: 'claude-cowork',
        name: 'Claude Cowork',
        emoji: '🏛️',
        color: Color(0xFF6366F1),
      ),
      (
        key: 'chatwork',
        name: 'Chatwork',
        emoji: '🏢',
        color: Color(0xFFE53935),
      ),
      (key: 'slack', name: 'Slack', emoji: '💬', color: Color(0xFF4A154B)),
      (key: 'jobcan', name: 'ジョブカン', emoji: '📋', color: Color(0xFF059669)),
      (key: 'amazon', name: 'Amazon', emoji: '📦', color: Color(0xFFFF9900)),
      (key: 'google', name: 'Google', emoji: '🔍', color: Color(0xFF4285F4)),
      (
        key: 'google_agent_builder',
        name: 'Google Agent Builder',
        emoji: '🤖',
        color: Color(0xFF34A853),
      ),
      (
        key: 'microsoft',
        name: 'Microsoft',
        emoji: '🪟',
        color: Color(0xFF00A4EF),
      ),
      (key: 'discord', name: 'Discord', emoji: '🎮', color: Color(0xFF5865F2)),
      (key: 'line', name: 'LINE', emoji: '💚', color: Color(0xFF06C755)),
      (
        key: 'facebook',
        name: 'Facebook',
        emoji: '👥',
        color: Color(0xFF1877F2),
      ),
      (key: 'liven', name: 'Liven', emoji: '🍽️', color: Color(0xFFFF6B35)),
      (key: 'github', name: 'GitHub', emoji: '🐙', color: Color(0xFF24292E)),
    ];

    return Card(
      key: const Key('landing_comparison_links'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    color: Color(0xFF3949AB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1894社との機能比較',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '気になるサービスをタップして機能・価格を比較しよう',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: competitors
                  .map(
                    (competitor) => _CompetitorRow(
                      name: competitor.name,
                      emoji: competitor.emoji,
                      color: competitor.color,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/vs-${competitor.key}'),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/competitors'),
                icon: const Icon(Icons.grid_view_rounded, size: 14),
                label: const Text(
                  '全1894社を見る →',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetitorRow extends StatelessWidget {
  final String name;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _CompetitorRow({
    required this.name,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            '$emoji  vs $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
