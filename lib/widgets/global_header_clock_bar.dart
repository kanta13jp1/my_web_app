import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GlobalHeaderClockShell extends StatelessWidget {
  final Widget child;

  const GlobalHeaderClockShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const GlobalHeaderClockBar(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class GlobalHeaderClockBar extends StatefulWidget {
  const GlobalHeaderClockBar({super.key});

  @override
  State<GlobalHeaderClockBar> createState() => _GlobalHeaderClockBarState();
}

class _GlobalHeaderClockBarState extends State<GlobalHeaderClockBar> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final backgroundColor =
        isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F7FF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final labelColor =
        isDark ? Colors.white70 : Colors.blueGrey.withValues(alpha: 0.85);
    final clockText = DateFormat('yyyy/MM/dd HH:mm:ss').format(_now);

    return Container(
      key: const Key('global_header_clock_bar'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  '今日の日付と時刻',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                const Spacer(),
                Text(
                  clockText,
                  key: const Key('global_header_clock_text'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
