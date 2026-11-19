import 'package:flutter/material.dart';

/// Prerendered views of one original pump; no network or game-state mutation.
class EchoPumpMotorArt extends StatelessWidget {
  const EchoPumpMotorArt({
    super.key,
    required this.repaired,
    required this.powered,
  });

  final bool repaired;
  final bool powered;

  @override
  Widget build(BuildContext context) {
    final state = !repaired ? 'fault' : (powered ? 'live' : 'idle');
    return Image.asset(
      'assets/echo_pump/pump_$state.png',
      key: ValueKey('echo-pump-motor-$state'),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      // The original vector motor remains underneath until decoding succeeds.
      frameBuilder: (context, child, frame, synchronous) => frame == null
          ? const SizedBox.shrink()
          : DecoratedBox(
              key: const Key('echo-pump-motor-surface'),
              decoration: BoxDecoration(
                color: const Color(0xFF0B191F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: child,
            ),
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}
