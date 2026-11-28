import 'package:flutter/material.dart';

class HorseRacingTodayActionBar extends StatelessWidget {
  const HorseRacingTodayActionBar({
    super.key,
    required this.totalRaces,
    required this.predictedRaces,
    required this.entriesReadyRaces,
    required this.nextRaceLabel,
    required this.isPredicting,
    required this.onGeneratePredictions,
    this.predictionStatus,
  });

  static const barKey = Key('horse-racing-today-action-bar');
  static const generateButtonKey = Key('horse-racing-generate-predictions');

  final int totalRaces;
  final int predictedRaces;
  final int entriesReadyRaces;
  final String nextRaceLabel;
  final bool isPredicting;
  final VoidCallback? onGeneratePredictions;
  final String? predictionStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: barKey,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SummaryChip(
                label: 'レース',
                value: '$totalRaces件',
                icon: Icons.event_available,
              ),
              _SummaryChip(
                label: 'AI予想',
                value: '$predictedRaces/$totalRaces',
                icon: Icons.psychology,
              ),
              _SummaryChip(
                label: '出走馬あり',
                value: '$entriesReadyRaces件',
                icon: Icons.list_alt,
              ),
              _SummaryChip(
                label: '次走',
                value: nextRaceLabel,
                icon: Icons.schedule,
              ),
              FilledButton.icon(
                key: generateButtonKey,
                onPressed: isPredicting || totalRaces == 0
                    ? null
                    : onGeneratePredictions,
                icon: isPredicting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(isPredicting ? 'AI予想中' : '今日のAI予想を今すぐ生成'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          if (predictionStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              predictionStatus!,
              style: const TextStyle(
                color: Color(0xFFFFB199),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 14),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
