import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import 'echo_pump_cast.dart';
import 'echo_pump_room_stage.dart';

const _mint = Color(0xFF9BE0CF);
const _warning = Color(0xFFFFB49B);

/// Establishing artwork, with live game state kept in real accessible widgets.
class EchoPumpScene extends StatelessWidget {
  const EchoPumpScene(
      {super.key, required this.game, this.onExploreMove, this.onFootstep});

  final ValueChanged<PumpRoom>? onExploreMove;
  final VoidCallback? onFootstep;

  final EchoPumpGame game;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: const Color(0xFF12242B),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/echo_pump/opening_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x50071216), Color(0xF0071216)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.grain, color: _mint, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '夜間排水施設 / 施設全景',
                          style: TextStyle(color: _mint),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    game.escaped ? '雨の向こうへ。' : game.room.label,
                    key: const Key('echo-scene-location'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF0F5F2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (game.room == PumpRoom.control && !game.finished)
                    EchoPumpRoomStage(
                        key: ObjectKey(game),
                        onMove: onExploreMove,
                        onFootstep: onFootstep)
                  else
                    EchoPumpCast(game: game),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Semantics(
                        label: '体力 ${game.health} / 3',
                        child: ExcludeSemantics(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 2,
                            children: [
                              for (var index = 0; index < 3; index++)
                                Icon(
                                  index < game.health
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: index < game.health
                                      ? _mint
                                      : Colors.white54,
                                  size: 22,
                                ),
                              Text('体力 ${game.health} / 3'),
                            ],
                          ),
                        ),
                      ),
                      Text('ターン ${game.turn}'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            game.sealed ? Icons.lock_outline : Icons.radar,
                            color: game.sealed ? _mint : _warning,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              game.sealed ? '敵：封鎖済み' : '敵：${game.enemy.label}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// This is the actual game graph, not a decorative building floor plan.
class EchoPumpFacilityMap extends StatelessWidget {
  const EchoPumpFacilityMap({super.key, required this.game});

  final EchoPumpGame game;

  static const _positions = <PumpRoom, (int, int)>{
    PumpRoom.exit: (0, 0),
    PumpRoom.loading: (1, 0),
    PumpRoom.workshop: (2, 0),
    PumpRoom.control: (0, 1),
    PumpRoom.hall: (1, 1),
    PumpRoom.pump: (1, 2),
    PumpRoom.inspection: (2, 2),
  };

  static const _icons = <PumpRoom, IconData>{
    PumpRoom.control: Icons.tune,
    PumpRoom.hall: Icons.alt_route,
    PumpRoom.loading: Icons.local_shipping_outlined,
    PumpRoom.workshop: Icons.build_outlined,
    PumpRoom.pump: Icons.settings,
    PumpRoom.inspection: Icons.notifications_none,
    PumpRoom.exit: Icons.exit_to_app,
  };

  @override
  Widget build(BuildContext context) {
    final powered = {for (final circuit in game.power) circuit.noiseRoom};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final circuit in PumpCircuit.values)
              Text(
                '${game.power.contains(circuit) ? '●' : '○'} '
                '${circuit.label} ${game.power.contains(circuit) ? 'ON' : 'OFF'}',
                style: TextStyle(
                  color: game.power.contains(circuit) ? _mint : Colors.white70,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final nodeWidth = (width - 24) / 3;
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final nodeHeight = 112.0 * scale;
            final bounds = <PumpRoom, Rect>{
              for (final entry in _positions.entries)
                entry.key: Rect.fromLTWH(
                  entry.value.$1 * (nodeWidth + 12),
                  entry.value.$2 * (nodeHeight + 28),
                  nodeWidth,
                  nodeHeight,
                ),
            };
            return SizedBox(
              height: nodeHeight * 3 + 56,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _PassagesPainter(
                          bounds: bounds,
                          current: game.room,
                          sealed: game.sealed,
                        ),
                      ),
                    ),
                  ),
                  for (final entry in bounds.entries)
                    Positioned.fromRect(
                      rect: entry.value,
                      child: _node(entry.key, powered.contains(entry.key)),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text(
          '● 現在地　▲ 敵　通電中：稼働設備　線：区画の接続',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (game.noiseRoom != null)
          Text(
            '機械音の行き先 → ${game.noiseRoom!.label}',
            style: const TextStyle(color: _mint),
          ),
        ExpansionTile(
          title: const Text('区画の接続一覧'),
          tilePadding: EdgeInsets.zero,
          children: [
            for (final entry in EchoPumpGame.connections.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${entry.key.label}：'
                    '${entry.value.map((room) => room.label).join('・')}',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _node(PumpRoom room, bool powered) {
    final current = room == game.room;
    final enemy = room == game.enemy;
    final locked = (room == PumpRoom.exit && !game.drained) ||
        (room == PumpRoom.inspection && game.sealed);
    final status = [
      if (current) '● 現在地',
      if (enemy) game.sealed ? '■ 封鎖' : '▲ 敵',
      if (powered) '通電中',
      if (locked && !enemy) '閉鎖中',
    ].join(' ');
    return Semantics(
      label: '${room.label} ${status.isEmpty ? '区画' : status}',
      child: ExcludeSemantics(
        child: Container(
          key: Key('echo-map-${room.name}'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: current ? const Color(0xFF234F48) : const Color(0xFF17292E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: current
                  ? _mint
                  : enemy && !game.sealed
                      ? _warning
                      : const Color(0xFF54716F),
              width: current ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icons[room],
                color: powered ? _mint : Colors.white70,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                room.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (status.isNotEmpty)
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: enemy && !game.sealed ? _warning : _mint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassagesPainter extends CustomPainter {
  const _PassagesPainter({
    required this.bounds,
    required this.current,
    required this.sealed,
  });

  final Map<PumpRoom, Rect> bounds;
  final PumpRoom current;
  final bool sealed;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in EchoPumpGame.connections.entries) {
      for (final destination in entry.value) {
        if (entry.key.index > destination.index) {
          continue;
        }
        final from = bounds[entry.key]!.center;
        final to = bounds[destination]!.center;
        final closed = sealed && destination == PumpRoom.inspection;
        final path = Path()..moveTo(from.dx, from.dy);
        if (from.dx != to.dx && from.dy != to.dy) {
          path.lineTo(to.dx, from.dy);
        }
        path.lineTo(to.dx, to.dy);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = closed
                ? _warning
                : current == entry.key || current == destination
                    ? _mint
                    : const Color(0xFF486466),
        );
        if (closed) {
          canvas.drawCircle(
            Offset((from.dx + to.dx) / 2, from.dy),
            6,
            Paint()..color = _warning,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PassagesPainter oldDelegate) =>
      oldDelegate.bounds != bounds ||
      oldDelegate.current != current ||
      oldDelegate.sealed != sealed;
}
