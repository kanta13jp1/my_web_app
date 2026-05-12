import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_web_app/services/maintenance_service.dart';

class MaintenanceModePage extends StatefulWidget {
  const MaintenanceModePage({super.key, this.window});

  final MaintenanceWindow? window;

  @override
  State<MaintenanceModePage> createState() => _MaintenanceModePageState();
}

class _MaintenanceModePageState extends State<MaintenanceModePage> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = widget.window;
    final endsAt = window?.endsAt.toLocal();
    final remaining = endsAt?.difference(_now);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.construction_rounded,
                          color: colors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'メンテナンス中',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      window?.displayMessage ?? 'ただいまシステムメンテナンスを実施しています。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    if (endsAt != null)
                      _InfoRow(
                        icon: Icons.event_available,
                        label: '終了予定',
                        value: _formatDateTime(endsAt),
                      ),
                    if (remaining != null)
                      _InfoRow(
                        icon: Icons.timer_outlined,
                        label: '残り時間',
                        value: _formatDuration(remaining),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      '管理画面はメンテナンス中も操作できます。復旧後は自動で通常画面に戻ります。',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}/${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _formatDuration(Duration value) {
  if (value.isNegative) return 'まもなく復旧します';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0) return '$hours時間 $minutes分';
  return '$minutes分';
}
