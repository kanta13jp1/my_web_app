import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import 'echo_pump_cast.dart';
import 'echo_pump_room_stage.dart';

const _mint = Color(0xFF9BE0CF);
const _warning = Color(0xFFFFB49B);

/// Establishing artwork, with live game state kept in real accessible widgets.
class EchoPumpScene extends StatelessWidget {
  const EchoPumpScene({
    super.key,
    required this.game,
    this.onExploreMove,
    this.onFootstep,
  });

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
              child:
                  EchoPumpRoomBackdrop(room: game.room, drained: game.drained),
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
                      onFootstep: onFootstep,
                    )
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

/// Original vector scenery remains available without downloading room images.
class EchoPumpRoomBackdrop extends StatelessWidget {
  const EchoPumpRoomBackdrop(
      {super.key, required this.room, this.drained = false});
  final PumpRoom room;
  final bool drained;

  static const features = <PumpRoom, String>{
    PumpRoom.control: '配電盤と計器の管理室',
    PumpRoom.hall: '奥へ続く扉と配管の中央廊下',
    PumpRoom.loading: '木箱と搬入口の搬入区画',
    PumpRoom.workshop: '工具壁と作業台の工具庫',
    PumpRoom.pump: '大型配管と排水機のポンプ室',
    PumpRoom.inspection: '水路と格子床の点検槽',
    PumpRoom.exit: '雨と外光が差す出口',
  };

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: '部屋の背景：${features[room]}',
        child: ExcludeSemantics(
          child: CustomPaint(painter: _RoomBackdropPainter(room, drained)),
        ),
      );
}

class _RoomBackdropPainter extends CustomPainter {
  const _RoomBackdropPainter(this.room, this.drained);
  final PumpRoom room;
  final bool drained;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 180);
    final bounds = const Rect.fromLTWH(0, 0, 320, 180);
    final tint = switch (room) {
      PumpRoom.control => const Color(0xFF365B57),
      PumpRoom.hall => const Color(0xFF253F55),
      PumpRoom.loading => const Color(0xFF65533B),
      PumpRoom.workshop => const Color(0xFF4C5554),
      PumpRoom.pump => const Color(0xFF20536A),
      PumpRoom.inspection => const Color(0xFF284A3E),
      PumpRoom.exit => const Color(0xFF746746),
    };
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint, const Color(0xFF071116)],
          ).createShader(bounds));
    final metal = Paint()..color = const Color(0xFF567578);
    final dark = Paint()..color = const Color(0xFF101F25);
    final light = Paint()..color = const Color(0xFF91C7B5);
    final line = Paint()
      ..color = const Color(0xFF65848A)
      ..strokeWidth = 1;
    for (var x = -160.0; x < 600; x += 55) {
      canvas.drawLine(Offset(160, 85), Offset(x, 180), line);
    }
    for (final y in [114.0, 137.0, 165.0]) {
      canvas.drawLine(Offset(0, y), Offset(320, y), line);
    }
    switch (room) {
      case PumpRoom.control:
        for (var x = 158.0; x < 310; x += 45) {
          canvas.drawRect(Rect.fromLTWH(x, 16, 38, 101), metal);
          canvas.drawRect(Rect.fromLTWH(x + 4, 22, 30, 22), dark);
          for (var y = 53.0; y < 108; y += 15) {
            canvas.drawCircle(Offset(x + 10, y), 3, light);
            canvas.drawLine(Offset(x + 19, y), Offset(x + 30, y), line);
          }
        }
      case PumpRoom.hall:
        for (var i = 0; i < 5; i++) {
          final inset = i * 22.0;
          canvas.drawRect(
              Rect.fromLTRB(inset, inset * .45, 320 - inset, 150 - inset * .3),
              Paint()
                ..color = const Color(0xFF567578)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
        }
        canvas.drawRect(const Rect.fromLTWH(143, 49, 35, 61), dark);
        canvas.drawCircle(const Offset(172, 83), 2, light);
      case PumpRoom.loading:
        for (final (x, y, w, h) in [
          (170.0, 62.0, 55.0, 52.0),
          (226.0, 81.0, 62.0, 48.0),
          (184.0, 25.0, 42.0, 37.0)
        ]) {
          final box = Rect.fromLTWH(x, y, w, h);
          canvas.drawRect(box, Paint()..color = const Color(0xFF927A52));
          canvas.drawRect(
              box.deflate(4),
              Paint()
                ..color = const Color(0xFF493D2E)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
          canvas.drawLine(box.topLeft, box.bottomRight, line);
          canvas.drawLine(box.topRight, box.bottomLeft, line);
        }
      case PumpRoom.workshop:
        canvas.drawRect(const Rect.fromLTWH(155, 18, 150, 73), metal);
        for (var x = 165.0; x < 300; x += 22) {
          canvas.drawLine(
              Offset(x, 33),
              Offset(x, 77),
              Paint()
                ..color = const Color(0xFFD0C5A0)
                ..strokeWidth = 4);
          canvas.drawCircle(Offset(x, 32), 6, dark);
        }
        canvas.drawRect(const Rect.fromLTWH(149, 95, 160, 8), metal);
        canvas.drawRect(const Rect.fromLTWH(158, 103, 7, 34), metal);
        canvas.drawRect(const Rect.fromLTWH(291, 103, 7, 34), metal);
      case PumpRoom.pump:
        for (var x = 166.0; x < 310; x += 64) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x, 0, 35, 139), const Radius.circular(12)),
              metal);
          for (var y = 18.0; y < 140; y += 32) {
            canvas.drawRect(Rect.fromLTWH(x - 6, y, 47, 7), dark);
          }
        }
        canvas.drawOval(const Rect.fromLTWH(201, 103, 77, 40), dark);
      case PumpRoom.inspection:
        canvas.drawRect(const Rect.fromLTWH(160, 30, 137, 129), dark);
        canvas.drawRect(
            Rect.fromLTWH(164, drained ? 137 : 81, 129, drained ? 17 : 77),
            Paint()..color = const Color(0xFF34666B));
        for (var y = 35.0; y < 160; y += 14) {
          canvas.drawLine(Offset(156, y), Offset(300, y), line);
        }
        for (var x = 165.0; x < 300; x += 18) {
          canvas.drawLine(Offset(x, 29), Offset(x, 160), line);
        }
      case PumpRoom.exit:
        canvas.drawRect(const Rect.fromLTWH(158, 18, 123, 132), metal);
        canvas.drawRect(
            const Rect.fromLTWH(164, 24, 111, 126),
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFBDD8DB), Color(0xFFB9A36D)],
              ).createShader(bounds));
        for (var x = 170.0; x < 275; x += 12) {
          canvas.drawLine(Offset(x, 27), Offset(x - 7, 110), line);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RoomBackdropPainter oldDelegate) =>
      oldDelegate.room != room || oldDelegate.drained != drained;
}
