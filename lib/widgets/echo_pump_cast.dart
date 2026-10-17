import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';

/// Two separate location panels; this is not a shared camera view.
class EchoPumpCast extends StatelessWidget {
  const EchoPumpCast({super.key, required this.game});

  final EchoPumpGame game;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 560);
    final nearby = !game.sealed &&
        !game.finished &&
        (game.room == game.enemy ||
            (game.room != PumpRoom.control &&
                EchoPumpGame.connections[game.room]!.contains(game.enemy)));
    final enemyState = game.sealed
        ? '封鎖済み'
        : game.escaped
            ? '施設に残留'
            : nearby
                ? '接近注意'
                : '別区画';
    final heroState = game.escaped
        ? '脱出成功'
        : game.health == 0
            ? '探索失敗'
            : game.room == PumpRoom.control
                ? '安全な拠点'
                : '探索中';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Figure(
                id: 'hero',
                title: 'あなた / 保守員',
                location: game.room.label,
                state: heroState,
                asset: 'assets/echo_pump/character_technician.png',
                fallback: Icons.engineering,
                statusIcon:
                    game.escaped ? Icons.wb_twilight : Icons.person_pin_circle,
                color: const Color(0xFF9BE0CF),
                duration: duration,
                revision: '${game.room.name}-${game.health}-${game.escaped}',
                dimmed: game.health == 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Figure(
                id: 'enemy',
                title: '敵 / 音を追う影',
                location: game.enemy.label,
                state: enemyState,
                asset: 'assets/echo_pump/character_stalker.png',
                fallback: Icons.visibility,
                statusIcon: game.sealed
                    ? Icons.lock
                    : nearby
                        ? Icons.warning_amber
                        : Icons.hearing,
                color: game.sealed
                    ? const Color(0xFF9BE0CF)
                    : const Color(0xFFFFB49B),
                duration: duration,
                revision: '${game.enemy.name}-${game.sealed}-${game.escaped}',
                dimmed: game.sealed || game.escaped,
                sealed: game.sealed,
              ),
            ),
          ],
        ),
        if (!game.sealed && !game.finished && game.noiseRoom != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              label: '敵の誘導先：${game.noiseRoom!.label}の機械音',
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.graphic_eq,
                        color: Color(0xFFFFB49B), size: 20),
                    Text(game.noiseRoom!.label),
                    const Icon(Icons.arrow_back, size: 18),
                    const Icon(Icons.hearing, size: 20),
                    const Text('音で誘導'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.id,
    required this.title,
    required this.location,
    required this.state,
    required this.asset,
    required this.fallback,
    required this.statusIcon,
    required this.color,
    required this.duration,
    required this.revision,
    required this.dimmed,
    this.sealed = false,
  });

  final String id, title, location, state, asset, revision;
  final IconData fallback, statusIcon;
  final Color color;
  final Duration duration;
  final bool dimmed, sealed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title：$location、$state',
      key: Key('echo-cast-$id'),
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: duration,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xCC0B171D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 184,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: duration,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(0.12, 0),
                                    end: Offset.zero)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: Opacity(
                          key: ValueKey(revision),
                          opacity: dimmed ? 0.45 : 1,
                          child: Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                              child: Icon(fallback, color: color, size: 80),
                            ),
                          ),
                        ),
                      ),
                      if (sealed)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                              5,
                              (_) => Container(
                                  width: 5, color: const Color(0xB39BE0CF))),
                        ),
                    ],
                  ),
                ),
              ),
              Text(location,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(statusIcon, color: color, size: 18),
                  Text(state, style: TextStyle(color: color))
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
