import 'package:flutter/material.dart';

import '../models/echo_pump_game.dart';

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
    final reduced = MediaQuery.disableAnimationsOf(context);
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: powered ? _mint : Colors.white24,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF0F1D22),
              ),
              child: AnimatedSwitcher(
                duration:
                    reduced ? Duration.zero : const Duration(milliseconds: 280),
                child: Column(
                  key: ValueKey(available),
                  children: [
                    EchoPumpFuseArt(present: available),
                    Text(
                      available ? '交換ヒューズ' : '回収済み',
                      style: const TextStyle(color: _mint),
                    ),
                    const Divider(color: Colors.white24),
                    Icon(
                      available
                          ? Icons.arrow_downward
                          : Icons.check_circle_outline,
                      color: _mint,
                    ),
                    const Icon(Icons.inventory_2_outlined, color: _mint),
                  ],
                ),
              ),
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
