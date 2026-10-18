import 'dart:async';

import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import '../models/echo_pump_room_walk.dart';

const _mint = Color(0xFF9BE0CF);
const _walkArt = AssetImage('assets/echo_pump/character_walk.png');

/// A small, safe-room exploration layer over the existing turn-based game.
class EchoPumpRoomStage extends StatefulWidget {
  const EchoPumpRoomStage({super.key, this.onMove, this.onFootstep});
  final ValueChanged<PumpRoom>? onMove;
  final VoidCallback? onFootstep;

  @override
  State<EchoPumpRoomStage> createState() => _EchoPumpRoomStageState();
}

class _EchoPumpRoomStageState extends State<EchoPumpRoomStage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _walk;
  EchoRoomPoint _position = EchoPumpRoomWalk.start;
  List<EchoRoomPoint> _route = [EchoPumpRoomWalk.start];
  bool _walking = false, _detail = false, _left = false, _foreground = true;
  bool _animateSteps = true;
  int _steps = 0;
  AssetBundle? _artBundle;
  int _artRequest = 0;
  bool _walkArtReady = false;
  bool _routeActive = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _walk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_tick);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeActive = ModalRoute.of(context)?.isCurrent ?? true;
    if (!_routeActive && _walking) {
      _walk.stop(canceled: true);
      _walking = false;
    }
    final bundle = DefaultAssetBundle.of(context);
    if (identical(bundle, _artBundle)) return;
    _artBundle = bundle;
    _walkArtReady = false;
    unawaited(_precacheWalkArt(++_artRequest));
  }

  Future<void> _precacheWalkArt(int request) async {
    var failed = false;
    await precacheImage(
      _walkArt,
      context,
      onError: (Object error, StackTrace? stack) => failed = true,
    );
    if (!mounted || request != _artRequest || failed) return;
    setState(() => _walkArtReady = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _walking) {
      _walk.stop(canceled: true);
      setState(() => _walking = false);
    }
  }

  void _tick() {
    if (!_walking || !mounted || !_routeActive) return;
    final next = EchoPumpRoomWalk.sample(_route, _walk.value);
    if ((next.x - _position.x).abs() > 0.0001) _left = next.x < _position.x;
    setState(() => _position = next);
    if (_animateSteps && _foreground) {
      for (final marker in [0.25, 0.75]) {
        final index = marker == 0.25 ? 1 : 2;
        if (_walk.value >= marker && _steps < index) {
          _steps = index;
          widget.onFootstep?.call();
        }
      }
    }
  }

  Future<void> _approach(EchoRoomTarget target) async {
    if (_walking || !_foreground || !_routeActive) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _route = EchoPumpRoomWalk.route(_position, target);
    _steps = 0;
    final distance = EchoPumpRoomWalk.length(_route);
    _animateSteps = !reduced && distance >= 0.0001;
    _walk.duration = reduced || distance < 0.0001
        ? Duration.zero
        : Duration(
            milliseconds: (distance * 1800).round().clamp(700, 1600).toInt(),
          );
    setState(() => _walking = true);
    try {
      await _walk.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || !_foreground) return;
    setState(() {
      _position = EchoPumpRoomWalk.destinations[target]!;
      _walking = false;
    });
    if (target == EchoRoomTarget.memo) {
      await showDialog<void>(
        context: context,
        builder: (_) => const _MaintenanceMemo(),
      );
    } else {
      final enter = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('中央廊下の扉'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.door_front_door, color: _mint, size: 72),
                SizedBox(height: 12),
                Text('中央廊下へ進むと1ターン経過します。敵の位置を確認してから進もう。'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: widget.onMove == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('扉を開けて進む'),
            ),
          ],
        ),
      );
      if (mounted && _foreground && enter == true) {
        widget.onMove?.call(PumpRoom.hall);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              '管理室を探索',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed:
                  _walking ? null : () => setState(() => _detail = !_detail),
              icon: Icon(_detail ? Icons.zoom_out : Icons.zoom_in),
              label: Text(_detail ? '全景へ' : '設備寄りに見る'),
            ),
          ],
        ),
        Semantics(
          container: true,
          label: '管理室の探索ビュー',
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 240,
                child: ColoredBox(
                  color: const Color(0xFF10282E),
                  child: AnimatedScale(
                    scale: _detail ? 1.12 : 1,
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 400),
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        const side = 112.0;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.35,
                                child: Image.asset(
                                  'assets/echo_pump/opening_background.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const SizedBox(),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter:
                                    _RoomFloor(_position, _route, _walking),
                              ),
                            ),
                            Positioned(
                              left: bounds.maxWidth * 0.1,
                              top: 72,
                              child: const Icon(
                                Icons.menu_book,
                                color: _mint,
                                size: 34,
                              ),
                            ),
                            Positioned(
                              right: bounds.maxWidth * 0.1,
                              top: 45,
                              child: const Icon(
                                Icons.door_front_door,
                                color: _mint,
                                size: 64,
                              ),
                            ),
                            Positioned(
                              key: const Key('echo-room-actor'),
                              left: _position.x * bounds.maxWidth - side / 2,
                              top: _position.y * 240 - side,
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.diagonal3Values(
                                  _left ? -1 : 1,
                                  1,
                                  1,
                                ),
                                child: _walking && _walkArtReady
                                    ? _WalkingSprite(
                                        frame: (_walk.value * 4)
                                            .floor()
                                            .clamp(0, 3)
                                            .toInt(),
                                        side: side,
                                      )
                                    : Image.asset(
                                        'assets/echo_pump/character_technician.png',
                                        width: side,
                                        height: side,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, error, stack) =>
                                            const SizedBox(
                                          width: side,
                                          height: side,
                                          child: Icon(
                                            Icons.engineering,
                                            color: _mint,
                                            size: 70,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(_walking ? '歩行中…' : '安全な管理室 / 室内の確認はターンを消費しません。'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _walking ? null : () => _approach(EchoRoomTarget.memo),
              icon: const Icon(Icons.menu_book),
              label: const Text('保守メモを調べる'),
            ),
            OutlinedButton.icon(
              onPressed: _walking ? null : () => _approach(EchoRoomTarget.door),
              icon: const Icon(Icons.door_front_door),
              label: const Text('中央廊下の扉を調べる'),
            ),
          ],
        ),
      ],
    );
  }
}

class _WalkingSprite extends StatelessWidget {
  const _WalkingSprite({required this.frame, required this.side});
  final int frame;
  final double side;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: side,
        height: side,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: side * 2,
            maxWidth: side * 2,
            minHeight: side * 2,
            maxHeight: side * 2,
            child: Transform.translate(
              offset: Offset(-(frame % 2) * side, -(frame ~/ 2) * side),
              child: Image.asset(
                'assets/echo_pump/character_walk.png',
                width: side * 2,
                height: side * 2,
                fit: BoxFit.fill,
                errorBuilder: (_, error, stack) => Column(
                  children: List.generate(
                    2,
                    (_) => Expanded(
                      child: Row(
                        children: List.generate(
                          2,
                          (_) => Expanded(
                            child: Icon(
                              Icons.engineering,
                              color: _mint,
                              size: side * 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _RoomFloor extends CustomPainter {
  const _RoomFloor(this.position, this.route, this.walking);
  final EchoRoomPoint position;
  final List<EchoRoomPoint> route;
  final bool walking;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0x303AA68D);
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.12,
        size.height * 0.6,
        size.width * 0.28,
        size.height * 0.92,
      ),
      fill,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.72,
        size.height * 0.6,
        size.width * 0.88,
        size.height * 0.92,
      ),
      fill,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.12,
        size.height * 0.86,
        size.width * 0.88,
        size.height * 0.92,
      ),
      fill,
    );
    final machine = Rect.fromLTRB(
      size.width * 0.4,
      size.height * 0.45,
      size.width * 0.6,
      size.height * 0.82,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(machine, const Radius.circular(6)),
      Paint()..color = const Color(0xEE20373D),
    );
    canvas.drawLine(
      Offset(machine.left + 8, machine.top + 15),
      Offset(machine.right - 8, machine.top + 15),
      Paint()
        ..color = _mint
        ..strokeWidth = 3,
    );
    if (walking && route.length > 1) {
      final path = Path()
        ..moveTo(route.first.x * size.width, route.first.y * size.height);
      for (final p in route.skip(1)) {
        path.lineTo(p.x * size.width, p.y * size.height);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _mint.withValues(alpha: 0.5)
          ..strokeWidth = 2,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(position.x * size.width, position.y * size.height),
        width: 40,
        height: 8,
      ),
      Paint()..color = const Color(0x90000000),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomFloor old) =>
      old.position != position || old.walking != walking || old.route != route;
}

class _MaintenanceMemo extends StatefulWidget {
  const _MaintenanceMemo();
  @override
  State<_MaintenanceMemo> createState() => _MaintenanceMemoState();
}

class _MaintenanceMemoState extends State<_MaintenanceMemo> {
  int _page = 0;

  Widget _line(IconData from, String label, IconData to, String destination) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(from, color: _mint),
            Text(label),
            const Icon(Icons.arrow_forward),
            Icon(to, color: _mint),
            Text(destination),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('夜間保守メモ ${_page + 1} / 2'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _page == 0
                  ? [
                      const Text('同時に通電できるのは2系統。'),
                      _line(Icons.bolt, 'B 整備', Icons.build, '工具庫のヒューズ'),
                      _line(
                        Icons.bolt,
                        'C 排水',
                        Icons.notifications_active,
                        '点検槽のベル',
                      ),
                    ]
                  : [
                      _line(
                        Icons.electrical_services,
                        'ヒューズ',
                        Icons.settings,
                        'ポンプ修理',
                      ),
                      _line(Icons.hearing, 'ベルで誘導', Icons.lock, '隔壁を閉じる'),
                      _line(
                        Icons.water_drop,
                        '排水',
                        Icons.exit_to_app,
                        '管理室から出口',
                      ),
                    ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _page == 0 ? null : () => setState(() => _page--),
            child: const Text('前のページ'),
          ),
          TextButton(
            onPressed: _page == 1 ? null : () => setState(() => _page++),
            child: const Text('次のページ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('メモを閉じる'),
          ),
        ],
      );
}
