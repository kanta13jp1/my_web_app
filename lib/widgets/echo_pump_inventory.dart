import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';
import '../services/echo_pump_motion_stub.dart'
    if (dart.library.js_interop) '../services/echo_pump_motion_web.dart'
    as motion;

const _mint = Color(0xFF9BE0CF);

enum EchoPumpInventoryAction { repair }

/// A read-only view of the existing fuse flags; game actions stay in the page.
class EchoPumpInventoryStrip extends StatelessWidget {
  const EchoPumpInventoryStrip({
    super.key,
    required this.game,
    required this.onOpen,
  });
  final EchoPumpGame game;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF172B2E),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const Key('echo-inventory-open'),
                onPressed: onOpen,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  game.repaired
                      ? '所持品：装着済み'
                      : game.hasFuse
                          ? '所持品：ヒューズ 1'
                          : '所持品：空',
                ),
              ),
              _FuseJourney(game: game),
            ],
          ),
        ),
      );
}

class _FuseJourney extends StatelessWidget {
  const _FuseJourney({required this.game});
  final EchoPumpGame game;

  @override
  Widget build(BuildContext context) {
    final current = game.repaired
        ? 2
        : game.hasFuse
            ? 1
            : 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 4, right: 4, top: 6),
                child:
                    Icon(Icons.arrow_forward, size: 18, color: Colors.white38),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    [
                      Icons.handyman_outlined,
                      Icons.inventory_2_outlined,
                      Icons.settings_input_component,
                    ][i],
                    color: i <= current ? _mint : Colors.white24,
                    size: 28,
                  ),
                  Text(
                    ['工具庫', '所持', '装着'][i],
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: i == current ? _mint : Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Original Blender MCP render with vector fallback for loading or failure.
class EchoPumpFuseArt extends StatelessWidget {
  const EchoPumpFuseArt({super.key, this.present = true});
  final bool present;

  @override
  Widget build(BuildContext context) => Semantics(
        label: present ? '交換ヒューズの図' : '交換ヒューズの輪郭',
        image: true,
        child: SizedBox(
          width: 224,
          height: 144,
          child: present
              ? Image.asset(
                  'assets/echo_pump/fuse_blender.png',
                  key: const Key('echo-fuse-blender'),
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, synchronous) =>
                      synchronous || frame != null
                          ? child
                          : CustomPaint(painter: _FusePainter(present)),
                  errorBuilder: (context, error, stack) =>
                      CustomPaint(painter: _FusePainter(present)),
                )
              : CustomPaint(painter: _FusePainter(present)),
        ),
      );
}

class _FusePainter extends CustomPainter {
  const _FusePainter(this.present);
  final bool present;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 148, size.height / 88);
    final color = present ? _mint : Colors.white24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 28, 96, 32),
        const Radius.circular(8),
      ),
      Paint()..color = color.withValues(alpha: present ? 0.16 : 0.04),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 28, 96, 32),
        const Radius.circular(8),
      ),
      stroke,
    );
    for (final x in [18.0, 112.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 24, 18, 40),
          const Radius.circular(4),
        ),
        Paint()..color = color.withValues(alpha: present ? 0.85 : 0.2),
      );
    }
    final wire = Path()
      ..moveTo(36, 44)
      ..lineTo(48, 44);
    for (var i = 0; i < 6; i++) {
      wire.lineTo(52 + i * 7, i.isEven ? 35 : 53);
    }
    wire
      ..lineTo(100, 44)
      ..lineTo(112, 44);
    canvas.drawPath(wire, stroke);
    if (present) {
      canvas.drawLine(
        const Offset(40, 32),
        const Offset(104, 32),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FusePainter oldDelegate) =>
      oldDelegate.present != present;
}

class EchoPumpFuseShelf extends StatelessWidget {
  const EchoPumpFuseShelf({
    super.key,
    required this.game,
    required this.onCollect,
  });
  final EchoPumpGame game;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final available = !game.hasFuse && !game.repaired;
    final powered = game.power.contains(PumpCircuit.b);
    final reduced =
        MediaQuery.disableAnimationsOf(context) || motion.prefersReducedMotion;
    return Card(
      color: const Color(0xFF172B2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  powered ? Icons.lock_open : Icons.lock_outline,
                  color: powered ? _mint : Colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(powered ? 'B 整備 ON' : 'B 整備 OFF')),
                if (!game.sealed && game.enemy == PumpRoom.workshop)
                  const Icon(Icons.warning_amber, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            _WorkshopScene(
              available: available,
              powered: powered,
              reduced: reduced,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(available ? Icons.search : Icons.check_circle,
                    color: _mint,),
                Text(available ? '作業台の交換ヒューズ' : '回収済み',
                    style: const TextStyle(color: _mint),),
                if (!powered && available) const Text('B 整備で工具棚を解錠'),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('echo-collect'),
              onPressed: game.finished || !available ? null : onCollect,
              icon: Icon(available ? Icons.pan_tool_alt_outlined : Icons.check),
              label: const Text('ヒューズを回収'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Finite lighting and collection transitions; no looping background ticker.
class _WorkshopScene extends StatelessWidget {
  const _WorkshopScene(
      {required this.available, required this.powered, required this.reduced,});
  final bool available, powered, reduced;

  @override
  Widget build(BuildContext context) {
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 700);
    return Semantics(
      image: true,
      label:
          '工具庫の探索画像：${powered ? 'B整備通電' : 'B整備停止'}、${available ? 'ヒューズ未回収' : 'ヒューズ回収済み'}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(builder: (context, constraints) {
            return SizedBox(
              height: (constraints.maxWidth * 9 / 16).clamp(180.0, 420.0),
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(
                  'assets/echo_pump/workshop_background.png',
                  key: const Key('echo-workshop-background'),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null && !synchronous
                          ? const _WorkshopFallback()
                          : child,
                  errorBuilder: (context, error, stack) =>
                      const _WorkshopFallback(),
                ),
                AnimatedOpacity(
                  duration: duration,
                  opacity: powered ? 0 : .62,
                  child: const ColoredBox(color: Colors.black),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: powered ? 1 : 0),
                  duration: duration,
                  builder: (context, light, child) => DecoratedBox(
                    key: const Key('echo-workshop-light'),
                    decoration: BoxDecoration(
                        gradient: RadialGradient(
                      center: const Alignment(-.25, -.1),
                      radius: .65,
                      colors: [
                        Color.fromRGBO(255, 198, 105, .2 * light),
                        Colors.transparent
                      ,],
                    ),),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: const Color(0xDD0B171D),
                        borderRadius: BorderRadius.circular(20),),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6,),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(powered ? Icons.lightbulb : Icons.lock_outline,
                              color: powered ? _mint : Colors.amber, size: 18,),
                          const SizedBox(width: 6),
                          Text(powered ? '工具棚 解錠' : '工具棚 施錠'),
                        ],),),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(-.2, .15),
                    child: FractionallySizedBox(
                      widthFactor: .4,
                      heightFactor: .5,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: available ? 1 : 0, end: available ? 1 : 0,),
                        duration: duration,
                        builder: (context, value, child) => Transform.translate(
                          offset: Offset(0, -70 * (1 - value)),
                          child: Opacity(
                              opacity: value.clamp(0.0, 1.0), child: child,),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: RadialGradient(colors: [
                            _mint.withValues(alpha: powered ? .35 : .06),
                            Colors.transparent,
                          ],),),
                          child: const FittedBox(child: EchoPumpFuseArt()),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: AnimatedScale(
                    scale: available ? 0 : 1,
                    duration: duration,
                    child: const Chip(
                        avatar: Icon(Icons.inventory_2_outlined, color: _mint),
                        label: Text('所持品へ', style: TextStyle(color: _mint)),),
                  ),
                ),
              ],),
            );
          },),
        ),
      ),
    );
  }
}

class _WorkshopFallback extends StatelessWidget {
  const _WorkshopFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        key: Key('echo-workshop-fallback'),
        decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF284249), Color(0xFF101F26)]),),
        child: Center(
            child:
                Icon(Icons.handyman_outlined, size: 96, color: Colors.white24),),
      );
}

class EchoPumpInventoryDialog extends StatefulWidget {
  const EchoPumpInventoryDialog({super.key, required this.game});
  final EchoPumpGame game;

  @override
  State<EchoPumpInventoryDialog> createState() =>
      _EchoPumpInventoryDialogState();
}

class _EchoPumpInventoryDialogState extends State<EchoPumpInventoryDialog> {
  bool _submitted = false;
  EchoPumpGame get game => widget.game;

  void _finish([EchoPumpInventoryAction? action]) {
    if (_submitted) return;
    setState(() => _submitted = true);
    Navigator.pop(context, action);
  }

  @override
  Widget build(BuildContext context) {
    final canInstall =
        !game.finished && game.hasFuse && game.room == PumpRoom.pump;
    return AlertDialog(
      title: const Text('所持品'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: EchoPumpFuseArt(present: game.hasFuse || game.repaired),
              ),
              const SizedBox(height: 8),
              Text(
                game.hasFuse
                    ? '交換ヒューズ'
                    : game.repaired
                        ? 'ポンプへ装着済み'
                        : '所持品は空',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('所持数 ${game.hasFuse ? 1 : 0}'),
              const SizedBox(height: 16),
              _FuseJourney(game: game),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    game.repaired
                        ? Icons.check_circle_outline
                        : game.hasFuse
                            ? Icons.build_outlined
                            : Icons.bolt,
                    color: _mint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      game.repaired
                          ? '制御盤は修理済み。'
                          : game.hasFuse
                              ? 'ポンプ室の制御盤に使う。'
                              : 'B系統を入れ、工具庫で探す。',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '閲覧中はターンが進みません。',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('echo-inventory-close'),
          onPressed: _submitted ? null : () => _finish(),
          child: const Text('所持品を閉じる'),
        ),
        if (canInstall)
          FilledButton.icon(
            key: const Key('echo-inventory-use'),
            onPressed: _submitted
                ? null
                : () => _finish(EchoPumpInventoryAction.repair),
            icon: const Icon(Icons.build),
            label: const Text('このヒューズで修理'),
          ),
      ],
    );
  }
}
